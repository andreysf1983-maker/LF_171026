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

#include "DBUpdater.h"
#include "BuiltInConfig.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "DatabaseLoader.h"
#include "GitRevision.h"
#include "Log.h"
#include "QueryResult.h"
#include "StartProcess.h"
#include "UpdateFetcher.h"
#include <boost/filesystem.hpp>
#include <boost/filesystem/operations.hpp>
#include <fstream>
#include <iostream>
#include <vector>

std::string DBUpdaterUtil::GetCorrectedMySQLExecutable()
{
    if (!corrected_path().empty())
        return corrected_path();
    else
        return BuiltInConfig::GetMySQLExecutable();
}

// LegionForge: the mysql CLI is looked up in this order:
//   1. MySQLExecutable from *.conf / path baked in by CMake
//   2. mysql(.exe) in PATH
//   3. the portable MySQL shipped by setup.bat (tools\mysql\server\bin) relative to the
//      working directory (server\) and its parents
//   4. standard "MySQL Server x.y" installs under Program Files (Windows)
// Previously only 1 and 2 were tried and the build always baked an empty path, so
// worldserver died with "Didn't find any executable MySQL binary at '<server dir>'".
static boost::filesystem::path FindMySQLExecutableCandidate()
{
    namespace fs = boost::filesystem;
    boost::system::error_code ec;

#if LEGIONFORGE_PLATFORM == LEGIONFORGE_PLATFORM_WINDOWS
    std::string const exeName = "mysql.exe";
#else
    std::string const exeName = "mysql";
#endif

    std::vector<fs::path> candidates;
    fs::path const cwd = fs::current_path(ec);
    if (!ec)
    {
        fs::path dir = cwd;
        for (int depth = 0; depth < 4 && !dir.empty(); ++depth)
        {
            candidates.push_back(dir / exeName);
            candidates.push_back(dir / "tools" / "mysql" / "server" / "bin" / exeName);
            candidates.push_back(dir / "tools" / "mysql" / "bin" / exeName);
            candidates.push_back(dir / "mysql" / "bin" / exeName);
            if (!dir.has_parent_path() || dir.parent_path() == dir)
                break;
            dir = dir.parent_path();
        }
    }

#if LEGIONFORGE_PLATFORM == LEGIONFORGE_PLATFORM_WINDOWS
    for (char const* root : { "C:/Program Files/MySQL", "C:/Program Files (x86)/MySQL", "C:/tools/mysql" })
    {
        fs::path const base(root);
        if (!fs::is_directory(base, ec))
            continue;
        for (fs::directory_iterator itr(base, ec), end; !ec && itr != end; itr.increment(ec))
        {
            candidates.push_back(itr->path() / "bin" / exeName);
            candidates.push_back(itr->path() / exeName);
        }
    }
#else
    candidates.push_back("/usr/bin/mysql");
    candidates.push_back("/usr/local/bin/mysql");
    candidates.push_back("/usr/local/mysql/bin/mysql");
#endif

    for (fs::path const& candidate : candidates)
        if (fs::is_regular_file(candidate, ec))
            return candidate;

    return fs::path();
}

bool DBUpdaterUtil::CheckExecutable()
{
    boost::filesystem::path exe(GetCorrectedMySQLExecutable());
    boost::system::error_code ec;
    if (!exe.empty() && boost::filesystem::is_regular_file(exe, ec))
        return true;

    std::string const configured = exe.generic_string();

    boost::filesystem::path found = LegionForge::SearchExecutableInPath("mysql");
    if (found.empty() || !boost::filesystem::exists(found, ec))
        found = FindMySQLExecutableCandidate();

    if (!found.empty())
    {
        // Correct the path to the cli
        corrected_path() = boost::filesystem::absolute(found).generic_string();
        LF_LOG_INFO("sql.updates", "Using MySQL client: %s", corrected_path().c_str());
        return true;
    }

    LF_LOG_ERROR("sql.updates", "Didn't find any executable MySQL binary (MySQLExecutable = \"%s\"), not in PATH and not in tools/mysql/server/bin. "
        "Set MySQLExecutable in the *.conf, e.g. \"D:/legionforge/tools/mysql/server/bin/mysql.exe\".",
        configured.c_str());

    return false;
}

std::string& DBUpdaterUtil::corrected_path()
{
    static std::string path;
    return path;
}

// Auth Database
template<>
std::string DBUpdater<LoginDatabaseConnection>::GetConfigEntry()
{
    return "Updates.Auth";
}

template<>
std::string DBUpdater<LoginDatabaseConnection>::GetTableName()
{
    return "Auth";
}

template<>
std::string DBUpdater<LoginDatabaseConnection>::GetBaseFile()
{
    return BuiltInConfig::GetSourceDirectory() +
        "/sql/base/auth_database.sql";
}

template<>
bool DBUpdater<LoginDatabaseConnection>::IsEnabled(uint32 const updateMask)
{
    // This way silences warnings under msvc
    return (updateMask & DatabaseLoader::DATABASE_LOGIN) ? true : false;
}

// World Database
template<>
std::string DBUpdater<WorldDatabaseConnection>::GetConfigEntry()
{
    return "Updates.World";
}

template<>
std::string DBUpdater<WorldDatabaseConnection>::GetTableName()
{
    return "World";
}

template<>
std::string DBUpdater<WorldDatabaseConnection>::GetBaseFile()
{
    return GitRevision::GetFullDatabase();
}

template<>
bool DBUpdater<WorldDatabaseConnection>::IsEnabled(uint32 const updateMask)
{
    // This way silences warnings under msvc
    return (updateMask & DatabaseLoader::DATABASE_WORLD) ? true : false;
}

template<>
BaseLocation DBUpdater<WorldDatabaseConnection>::GetBaseLocationType()
{
    return LOCATION_DOWNLOAD;
}

// Character Database
template<>
std::string DBUpdater<CharacterDatabaseConnection>::GetConfigEntry()
{
    return "Updates.Character";
}

template<>
std::string DBUpdater<CharacterDatabaseConnection>::GetTableName()
{
    return "Character";
}

template<>
std::string DBUpdater<CharacterDatabaseConnection>::GetBaseFile()
{
    return BuiltInConfig::GetSourceDirectory() +
        "/sql/base/characters_database.sql";
}

template<>
bool DBUpdater<CharacterDatabaseConnection>::IsEnabled(uint32 const updateMask)
{
    // This way silences warnings under msvc
    return (updateMask & DatabaseLoader::DATABASE_CHARACTER) ? true : false;
}

// Hotfix Database
template<>
std::string DBUpdater<HotfixDatabaseConnection>::GetConfigEntry()
{
    return "Updates.Hotfix";
}

template<>
std::string DBUpdater<HotfixDatabaseConnection>::GetTableName()
{
    return "Hotfixes";
}

template<>
std::string DBUpdater<HotfixDatabaseConnection>::GetBaseFile()
{
    return GitRevision::GetHotfixesDatabase();
}

template<>
bool DBUpdater<HotfixDatabaseConnection>::IsEnabled(uint32 const updateMask)
{
    // This way silences warnings under msvc
    return (updateMask & DatabaseLoader::DATABASE_HOTFIX) ? true : false;
}

template<>
BaseLocation DBUpdater<HotfixDatabaseConnection>::GetBaseLocationType()
{
    return LOCATION_DOWNLOAD;
}

// All
template<class T>
BaseLocation DBUpdater<T>::GetBaseLocationType()
{
    return LOCATION_REPOSITORY;
}

template<class T>
bool DBUpdater<T>::Create(DatabaseWorkerPool<T>& pool)
{
    LF_LOG_INFO("sql.updates", "Database \"%s\" does not exist, do you want to create it? [yes (default) / no]: ",
        pool.GetConnectionInfo()->database.c_str());

    std::string answer;
    std::getline(std::cin, answer);
    if (!answer.empty() && !(answer.substr(0, 1) == "y"))
        return false;

    LF_LOG_INFO("sql.updates", "Creating database \"%s\"...", pool.GetConnectionInfo()->database.c_str());

    // Path of temp file
    static Path const temp("create_table.sql");

    // Create temporary query to use external MySQL CLi
    std::ofstream file(temp.generic_string());
    if (!file.is_open())
    {
        LF_LOG_FATAL("sql.updates", "Failed to create temporary query file \"%s\"!", temp.generic_string().c_str());
        return false;
    }

    file << "CREATE DATABASE `" << pool.GetConnectionInfo()->database << "` DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci\n\n";

    file.close();

    try
    {
        DBUpdater<T>::ApplyFile(pool, pool.GetConnectionInfo()->host, pool.GetConnectionInfo()->user, pool.GetConnectionInfo()->password,
            pool.GetConnectionInfo()->port_or_socket, "", temp);
    }
    catch (UpdateException&)
    {
        LF_LOG_FATAL("sql.updates", "Failed to create database %s! Does the user (named in *.conf) have `CREATE`, `ALTER`, `DROP`, `INSERT` and `DELETE` privileges on the MySQL server?", pool.GetConnectionInfo()->database.c_str());
        boost::filesystem::remove(temp);
        return false;
    }

    LF_LOG_INFO("sql.updates", "Done.");
    boost::filesystem::remove(temp);
    return true;
}

template<class T>
bool DBUpdater<T>::Update(DatabaseWorkerPool<T>& pool)
{
    // LegionForge: setup.bat / play.bat apply every SQL patch themselves, so the built-in
    // updater is only a convenience. A missing mysql CLI must not kill the server.
    if (!DBUpdaterUtil::CheckExecutable())
    {
        LF_LOG_WARN("sql.updates", "Skipping automatic updates of the %s database: mysql client not found. "
            "SQL patches are applied by setup.bat / play.bat.", DBUpdater<T>::GetTableName().c_str());
        return true;
    }

    LF_LOG_INFO("sql.updates", "Updating %s database...", DBUpdater<T>::GetTableName().c_str());

    Path sourceDirectory(BuiltInConfig::GetSourceDirectory());

    // LegionForge: sql\ lives in the repository root, not in core\. Fall back to the
    // parent folders of the working directory (server\) when the configured path has no sql\.
    {
        boost::system::error_code ec;
        if (!is_directory(sourceDirectory / "sql", ec))
        {
            Path dir = boost::filesystem::current_path(ec);
            for (int depth = 0; depth < 4 && !ec && !dir.empty(); ++depth)
            {
                if (is_directory(dir / "sql", ec))
                {
                    sourceDirectory = dir;
                    break;
                }
                if (!dir.has_parent_path() || dir.parent_path() == dir)
                    break;
                dir = dir.parent_path();
            }
        }
    }

    if (!is_directory(sourceDirectory))
    {
        LF_LOG_WARN("sql.updates", "DBUpdater: source directory %s does not exist - skipping automatic updates of the %s database. "
            "Set SourceDirectory in the *.conf to the folder that contains sql\\.",
            sourceDirectory.generic_string().c_str(), DBUpdater<T>::GetTableName().c_str());
        return true;
    }

    UpdateFetcher updateFetcher(sourceDirectory, [&](std::string const& query) { DBUpdater<T>::Apply(pool, query); },
        [&](Path const& file) { DBUpdater<T>::ApplyFile(pool, file); },
            [&](std::string const& query) -> QueryResult { return DBUpdater<T>::Retrieve(pool, query); });

    UpdateResult result;
    try
    {
        result = updateFetcher.Update(
            sConfigMgr->GetBoolDefault("Updates.Redundancy", true),
            sConfigMgr->GetBoolDefault("Updates.AllowRehash", true),
            sConfigMgr->GetBoolDefault("Updates.ArchivedRedundancy", false),
            sConfigMgr->GetIntDefault("Updates.CleanDeadRefMaxCount", 3));
    }
    catch (UpdateException&)
    {
        return false;
    }

    std::string const info = LegionForge::StringFormat("Containing " SZFMTD " new and " SZFMTD " archived updates.",
        result.recent, result.archived);

    if (!result.updated)
        LF_LOG_INFO("sql.updates", ">> %s database is up-to-date! %s", DBUpdater<T>::GetTableName().c_str(), info.c_str());
    else
        LF_LOG_INFO("sql.updates", ">> Applied " SZFMTD " %s. %s", result.updated, result.updated == 1 ? "query" : "queries", info.c_str());

    return true;
}

template<class T>
bool DBUpdater<T>::Populate(DatabaseWorkerPool<T>& pool)
{
    {
        QueryResult const result = Retrieve(pool, "SHOW TABLES");
        if (result && (result->GetRowCount() > 0))
            return true;
    }

    if (!DBUpdaterUtil::CheckExecutable())
        return false;

    LF_LOG_INFO("sql.updates", "Database %s is empty, auto populating it...", DBUpdater<T>::GetTableName().c_str());

    std::string const p = DBUpdater<T>::GetBaseFile();
    if (p.empty())
    {
        LF_LOG_INFO("sql.updates", ">> No base file provided, skipped!");
        return true;
    }

    Path const base(p);
    if (!exists(base))
    {
        switch (DBUpdater<T>::GetBaseLocationType())
        {
            case LOCATION_REPOSITORY:
            {
                LF_LOG_ERROR("sql.updates", ">> Base file \"%s\" is missing. Try fixing it by cloning the source again.",
                    base.generic_string().c_str());

                break;
            }
            case LOCATION_DOWNLOAD:
            {
                const char* filename = base.filename().generic_string().c_str();
                const char* workdir = boost::filesystem::current_path().generic_string().c_str();
                LF_LOG_ERROR("sql.updates", ">> File \"%s\" is missing, download it from \"https://github.com/LEGIONFORGE/LEGIONFORGE/releases\"" \
                    " uncompress it and place the file \"%s\" in the directory \"%s\".", filename, filename, workdir);
                break;
            }
        }
        return false;
    }

    // Update database
    LF_LOG_INFO("sql.updates", ">> Applying \'%s\'...", base.generic_string().c_str());
    try
    {
        ApplyFile(pool, base);
    }
    catch (UpdateException&)
    {
        return false;
    }

    LF_LOG_INFO("sql.updates", ">> Done!");
    return true;
}

template<class T>
QueryResult DBUpdater<T>::Retrieve(DatabaseWorkerPool<T>& pool, std::string const& query)
{
    return pool.Query(query.c_str());
}

template<class T>
void DBUpdater<T>::Apply(DatabaseWorkerPool<T>& pool, std::string const& query)
{
    pool.DirectExecute(query.c_str());
}

template<class T>
void DBUpdater<T>::ApplyFile(DatabaseWorkerPool<T>& pool, Path const& path)
{
    DBUpdater<T>::ApplyFile(pool, pool.GetConnectionInfo()->host, pool.GetConnectionInfo()->user, pool.GetConnectionInfo()->password,
        pool.GetConnectionInfo()->port_or_socket, pool.GetConnectionInfo()->database, path);
}

template<class T>
void DBUpdater<T>::ApplyFile(DatabaseWorkerPool<T>& pool, std::string const& host, std::string const& user,
    std::string const& password, std::string const& port_or_socket, std::string const& database, Path const& path)
{
    std::vector<std::string> args;
    args.reserve(8);

    // args[0] represents the program name
    args.push_back("mysql");

    // CLI Client connection info
    args.push_back("-h" + host);
    args.push_back("-u" + user);

    if (!password.empty())
        args.push_back("-p" + password);

    // Check if we want to connect through ip or socket (Unix only)
#ifdef _WIN32

    args.push_back("-P" + port_or_socket);

#else

    if (!std::isdigit(port_or_socket[0]))
    {
        // We can't check if host == "." here, because it is named localhost if socket option is enabled
        args.push_back("-P0");
        args.push_back("--protocol=SOCKET");
        args.push_back("-S" + port_or_socket);
    }
    else
        // generic case
        args.push_back("-P" + port_or_socket);

#endif

    // Set the default charset to utf8
    args.push_back("--default-character-set=utf8");

    // Set max allowed packet to 1 GB
    args.push_back("--max-allowed-packet=1GB");

    // Database
    if (!database.empty())
        args.push_back(database);

    // Invokes a mysql process which doesn't leak credentials to logs
    int const ret = LegionForge::StartProcess(DBUpdaterUtil::GetCorrectedMySQLExecutable(), args,
                                 "sql.updates", path.generic_string(), true);

    if (ret != EXIT_SUCCESS)
    {
        LF_LOG_FATAL("sql.updates", "Applying of file \'%s\' to database \'%s\' failed!" \
            " If you are a user, please pull the latest revision from the repository. "
            "Also make sure you have not applied any of the databases with your sql client. "
            "You cannot use auto-update system and import sql files from LEGIONFORGE repository with your sql client. "
            "If you are a developer, please fix your sql query.",
            path.generic_string().c_str(), pool.GetConnectionInfo()->database.c_str());

        throw UpdateException("update failed");
    }
}

template class LF_DATABASE_API DBUpdater<LoginDatabaseConnection>;
template class LF_DATABASE_API DBUpdater<WorldDatabaseConnection>;
template class LF_DATABASE_API DBUpdater<CharacterDatabaseConnection>;
template class LF_DATABASE_API DBUpdater<HotfixDatabaseConnection>;
