/*
 * Copyright (C) 2008-2018 LEGIONFORGE <https://www.legionforge.ru/>
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "DatabaseLoader.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "DBUpdater.h"
#include "Log.h"

#include <mysqld_error.h>

namespace
{
template <class T>
bool ColumnExists(DatabaseWorkerPool<T>& pool, char const* table, char const* column)
{
    std::string const sql = "SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '"
        + std::string(table) + "' AND COLUMN_NAME = '" + std::string(column) + "' LIMIT 1";
    return pool.Query(sql.c_str()) != nullptr;
}

template <class T>
bool TableExists(DatabaseWorkerPool<T>& pool, char const* table)
{
    std::string const sql = "SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '"
        + std::string(table) + "' LIMIT 1";
    return pool.Query(sql.c_str()) != nullptr;
}

// VMaNGOS on this machine uses databases realmd/characters/mangos and world port 8085.
// Legion must not prepare its statements against those schemas.
template <class T>
bool CheckExpectedSchema(std::string const& logger, DatabaseWorkerPool<T>& pool, std::string const& name)
{
    if (name == "Login")
    {
        if (ColumnExists(pool, "account", "battlenet_account"))
            return true;

        LF_LOG_ERROR(logger, "Login database is not a Legion auth schema (account.battlenet_account is missing). "
            "VMaNGOS uses database `realmd`. Point LoginDatabaseInfo at `auth` and leave `realmd` for VMaNGOS. Refusing to start.");
        return false;
    }

    if (name == "Character")
    {
        if (ColumnExists(pool, "characters", "hairStyle"))
            return true;

        if (ColumnExists(pool, "characters", "hair_style"))
        {
            LF_LOG_ERROR(logger, "Character database is a vanilla VMaNGOS schema (characters.hair_style). "
                "Legion needs characters.hairStyle. VMaNGOS owns database `characters` on this MySQL instance. "
                "Point CharacterDatabaseInfo at `legion_characters` and leave `characters` for VMaNGOS. Refusing to start.");
            return false;
        }

        LF_LOG_ERROR(logger, "Character database is missing Legion column characters.hairStyle. "
            "Refusing to prepare statements against the wrong schema.");
        return false;
    }

    if (name == "World")
    {
        if (ColumnExists(pool, "creature_template", "VerifiedBuild"))
            return true;

        LF_LOG_ERROR(logger, "World database is not a Legion world schema (creature_template.VerifiedBuild is missing). "
            "VMaNGOS uses database `mangos`. Point WorldDatabaseInfo at `world` and leave `mangos` for VMaNGOS. Refusing to start.");
        return false;
    }

    if (name == "Hotfix")
    {
        if (TableExists(pool, "item_sparse"))
            return true;

        LF_LOG_ERROR(logger, "Hotfix database is missing Legion table item_sparse. "
            "Point HotfixDatabaseInfo at `hotfixes`. Refusing to start.");
        return false;
    }

    return true;
}
}

DatabaseLoader::DatabaseLoader(std::string const& logger, uint32 const defaultUpdateMask)
    : _logger(logger), _autoSetup(sConfigMgr->GetBoolDefault("Updates.AutoSetup", true)),
    _updateFlags(sConfigMgr->GetIntDefault("Updates.EnableDatabases", defaultUpdateMask))
{
}

template <class T>
DatabaseLoader& DatabaseLoader::AddDatabase(DatabaseWorkerPool<T>& pool, std::string const& name)
{
    bool const updatesEnabledForThis = DBUpdater<T>::IsEnabled(_updateFlags);

    _open.push([this, name, updatesEnabledForThis, &pool]() -> bool
    {
        std::string const dbString = sConfigMgr->GetStringDefault(name + "DatabaseInfo", "");
        if (dbString.empty())
        {
            LF_LOG_ERROR(_logger, "Database %s not specified in configuration file!", name.c_str());
            return false;
        }

        uint8 const asyncThreads = uint8(sConfigMgr->GetIntDefault(name + "Database.WorkerThreads", 1));
        if (asyncThreads < 1 || asyncThreads > 32)
        {
            LF_LOG_ERROR(_logger, "%s database: invalid number of worker threads specified. "
                "Please pick a value between 1 and 32.", name.c_str());
            return false;
        }

        uint8 const synchThreads = uint8(sConfigMgr->GetIntDefault(name + "Database.SynchThreads", 1));

        pool.SetConnectionInfo(dbString, asyncThreads, synchThreads);
        if (uint32 error = pool.Open())
        {
            // Database does not exist
            if ((error == ER_BAD_DB_ERROR) && updatesEnabledForThis && _autoSetup)
            {
                // Try to create the database and connect again if auto setup is enabled
                if (DBUpdater<T>::Create(pool) && (!pool.Open()))
                    error = 0;
            }

            // If the error wasn't handled quit
            if (error)
            {
                LF_LOG_ERROR("sql.driver", "\nDatabasePool %s NOT opened. There were errors opening the MySQL connections. Check your SQLDriverLogFile "
                    "for specific errors. Read wiki at https://www.legionforge.ru/display/tc/LEGIONFORGE+Home", name.c_str());

                return false;
            }
        }
        // Add the close operation
        _close.push([&pool]
        {
            pool.Close();
        });
        return true;
    });

    // Populate and update only if updates are enabled for this pool
    if (updatesEnabledForThis)
    {
        _populate.push([this, name, &pool]() -> bool
        {
            if (!DBUpdater<T>::Populate(pool))
            {
                LF_LOG_ERROR(_logger, "Could not populate the %s database, see log for details.", name.c_str());
                return false;
            }
            return true;
        });

        _update.push([this, name, &pool]() -> bool
        {
            if (!DBUpdater<T>::Update(pool))
            {
                LF_LOG_ERROR(_logger, "Could not update the %s database, see log for details.", name.c_str());
                return false;
            }
            return true;
        });
    }

    _prepare.push([this, name, &pool]() -> bool
    {
        if (!CheckExpectedSchema(_logger, pool, name))
            return false;

        if (!pool.PrepareStatements())
        {
            LF_LOG_ERROR(_logger, "Could not prepare statements of the %s database, see log for details.", name.c_str());
            return false;
        }
        return true;
    });

    return *this;
}

bool DatabaseLoader::Load()
{
    if (!_updateFlags)
        LF_LOG_INFO("sql.updates", "Automatic database updates are disabled for all databases!");

    if (!OpenDatabases())
        return false;

    if (!PopulateDatabases())
        return false;

    if (!UpdateDatabases())
        return false;

    if (!PrepareStatements())
        return false;

    return true;
}

bool DatabaseLoader::OpenDatabases()
{
    return Process(_open);
}

bool DatabaseLoader::PopulateDatabases()
{
    return Process(_populate);
}

bool DatabaseLoader::UpdateDatabases()
{
    return Process(_update);
}

bool DatabaseLoader::PrepareStatements()
{
    return Process(_prepare);
}

bool DatabaseLoader::Process(std::queue<Predicate>& queue)
{
    while (!queue.empty())
    {
        if (!queue.front()())
        {
            // Close all open databases which have a registered close operation
            while (!_close.empty())
            {
                _close.top()();
                _close.pop();
            }

            return false;
        }

        queue.pop();
    }
    return true;
}

template LF_DATABASE_API
DatabaseLoader& DatabaseLoader::AddDatabase<LoginDatabaseConnection>(DatabaseWorkerPool<LoginDatabaseConnection>&, std::string const&);
template LF_DATABASE_API
DatabaseLoader& DatabaseLoader::AddDatabase<CharacterDatabaseConnection>(DatabaseWorkerPool<CharacterDatabaseConnection>&, std::string const&);
template LF_DATABASE_API
DatabaseLoader& DatabaseLoader::AddDatabase<HotfixDatabaseConnection>(DatabaseWorkerPool<HotfixDatabaseConnection>&, std::string const&);
template LF_DATABASE_API
DatabaseLoader& DatabaseLoader::AddDatabase<WorldDatabaseConnection>(DatabaseWorkerPool<WorldDatabaseConnection>&, std::string const&);
