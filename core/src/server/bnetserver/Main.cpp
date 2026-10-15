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

/**
* @file main.cpp
* @brief Authentication Server main program
*
* This file contains the main program for the
* authentication server
*/

#include "AppenderDB.h"
#include "Banner.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "DatabaseLoader.h"
#include "GitRevision.h"
#include "LoginRESTService.h"
#include "MySQLThreading.h"
#include "ProcessPriority.h"
#include "RealmList.h"
#include "SessionManager.h"
#include "SslContext.h"
#include "Util.h"
#include "AsioHacksFwd.h"
#include <boost/asio/signal_set.hpp>
#include <chrono>
#include <boost/program_options.hpp>
#include <boost/filesystem/operations.hpp>
#include <google/protobuf/stubs/common.h>
#include <iostream>
#include <csignal>

// ---------------------------------------------------------------------------
// [LEGIONFORGE FIX 2026-10] OPENSSL_Applink: фатальный выход bnetserver/worldserver
//
// Симптом (последняя строка перед закрытием окна):
//   OPENSSL_Uplink(00007FFFB2656C58,08): no OPENSSL_Applink
//
// Причина. Сборка линкуется с ДИНАМИЧЕСКИМ OpenSSL (build_server.ps1 в
// Find-OpenSslLayout намеренно отбирает не-static каталог:
//   $all | Where-Object { $_.FullName -notmatch 'MDd|MTd|\\MT\\|static' }),
// а сам исполняемый файл собирается со статическим CRT (баннер: "Release, Static").
// Когда libcrypto-3-x64.dll нужно вывести сообщение, она вызывает функцию stdio
// (индекс 8 таблицы = fputs) ЧЕРЕЗ таблицу OPENSSL_ApplinkTable, потому что у DLL
// и у EXE РАЗНЫЕ CRT и разные файловые дескрипторы. Таблицу заполняет функция
// OPENSSL_Applink(), которую ОБЯЗАНО экспортировать приложение. Ядро её не
// экспортировало, поэтому OPENSSL_Uplink() вызывал OPENSSL_die() и процесс
// завершался мгновенно - до загрузки конфига, до подключения к БД, без крэш-дампа.
//
// Исправление. <openssl/applink.c> компилируется ровно в ОДНУ единицу трансляции
// исполняемого файла и экспортирует OPENSSL_Applink (внутри файла объявлено
// __declspec(dllexport)). DLL находит её через
// GetProcAddress(GetModuleHandle(NULL), "OPENSSL_Applink") - и фатальный путь
// исчезает. Это штатный способ из документации OpenSSL (INSTALL.WIN),
// а не обходной хак.
//
// Безопасность. Файл включается только под Windows и только один раз на EXE.
// Если в какой-то конфигурации OpenSSL всё же линкуется статически, включение
// безвредно: экспортируемая функция просто никогда не будет вызвана.
// ---------------------------------------------------------------------------
#if LEGIONFORGE_PLATFORM == LEGIONFORGE_PLATFORM_WINDOWS
#include <openssl/opensslv.h>
#include <openssl/crypto.h>
#include <openssl/applink.c>
#endif

using boost::asio::ip::tcp;
using namespace boost::program_options;
namespace fs = boost::filesystem;

#ifndef _LEGIONFORGE_BNET_CONFIG
# define _LEGIONFORGE_BNET_CONFIG  "bnetserver.conf"
#endif

#if LEGIONFORGE_PLATFORM == LEGIONFORGE_PLATFORM_WINDOWS
#include "ServiceWin32.h"
char serviceName[] = "bnetserver";
char serviceLongName[] = "LEGIONFORGE bnet service";
char serviceDescription[] = "LEGIONFORGE Battle.net emulator authentication service";
/*
* -1 - not in service mode
*  0 - stopped
*  1 - running
*  2 - paused
*/
int m_ServiceStatus = -1;

void ServiceStatusWatcher(std::weak_ptr<boost::asio::steady_timer> serviceStatusWatchTimerRef, std::weak_ptr<LegionForge::Asio::IoContext> ioContextRef, boost::system::error_code const& error);
#endif

bool StartDB();
void StopDB();
void SignalHandler(std::weak_ptr<LegionForge::Asio::IoContext> ioContextRef, boost::system::error_code const& error, int signalNumber);
void KeepDatabaseAliveHandler(std::weak_ptr<boost::asio::steady_timer> dbPingTimerRef, int32 dbPingInterval, boost::system::error_code const& error);
void BanExpiryHandler(std::weak_ptr<boost::asio::steady_timer> banExpiryCheckTimerRef, int32 banExpiryCheckInterval, boost::system::error_code const& error);
variables_map GetConsoleArguments(int argc, char** argv, fs::path& configFile, std::string& configService);

int main(int argc, char** argv)
{
    signal(SIGABRT, &LegionForge::AbortHandler);

    auto configFile = fs::absolute(_LEGIONFORGE_BNET_CONFIG);
    std::string configService;
    auto vm = GetConsoleArguments(argc, argv, configFile, configService);
    // exit if help or version is enabled
    if (vm.count("help") || vm.count("version"))
        return 0;

    GOOGLE_PROTOBUF_VERIFY_VERSION;

    std::shared_ptr<void> protobufHandle(nullptr, [](void*) { google::protobuf::ShutdownProtobufLibrary(); });

#if LEGIONFORGE_PLATFORM == LEGIONFORGE_PLATFORM_WINDOWS
    if (configService.compare("install") == 0)
        return WinServiceInstall() ? 0 : 1;
    else if (configService.compare("uninstall") == 0)
        return WinServiceUninstall() ? 0 : 1;
    else if (configService.compare("run") == 0)
        return WinServiceRun() ? 0 : 1;
#endif

    std::string configError;
    if (!sConfigMgr->LoadInitial(configFile.generic_string(),
                                 std::vector<std::string>(argv, argv + argc),
                                 configError))
    {
        printf("Error in config file: %s\n", configError.c_str());
        return 1;
    }

    sLog->RegisterAppender<AppenderDB>();
    sLog->Initialize(nullptr);

    LegionForge::Banner::Show("bnetserver",
        [](char const* text)
        {
            LF_LOG_INFO("server.bnetserver", "%s", text);
        },
            []()
        {
            LF_LOG_INFO("server.bnetserver", "Using configuration file %s.", sConfigMgr->GetFilename().c_str());
            LF_LOG_INFO("server.bnetserver", "Using SSL version: %s (library: %s)", OPENSSL_VERSION_TEXT, SSLeay_version(SSLEAY_VERSION));
            LF_LOG_INFO("server.bnetserver", "Using Boost version: %i.%i.%i", BOOST_VERSION / 100000, BOOST_VERSION / 100 % 1000, BOOST_VERSION % 100);
        }
    );

    // Seed the OpenSSL's PRNG here.
    // That way it won't auto-seed when calling BigNumber::SetRand and slow down the first world login
    BigNumber seed;
    seed.SetRand(16 * 8);

    // bnetserver PID file creation
    std::string pidFile = sConfigMgr->GetStringDefault("PidFile", "");
    if (!pidFile.empty())
    {
        if (uint32 pid = CreatePIDFile(pidFile))
            LF_LOG_INFO("server.bnetserver", "Daemon PID: %u\n", pid);
        else
        {
            LF_LOG_ERROR("server.bnetserver", "Cannot create PID file %s.\n", pidFile.c_str());
            return 1;
        }
    }

    if (!Battlenet::SslContext::Initialize())
    {
        LF_LOG_ERROR("server.bnetserver", "Failed to initialize SSL context");
        // [LEGIONFORGE PATCH 2026-10] точная причина пишется в категорию
        // "server.ssl"; если её не видно - в bnetserver.conf нет строки
        // Logger.server.ssl (добавлена в bnetserver.conf.dist).
        LF_LOG_ERROR("server.bnetserver", "Hint: check CertificatesFile/PrivateKeyFile, run tools\\ensure_ssl_cert.ps1, and add \"Logger.server.ssl=3,Console Bnet\" to bnetserver.conf to see the exact OpenSSL error.");
        return 1;
    }

    // Initialize the database connection
    if (!StartDB())
        return 1;

    std::shared_ptr<void> dbHandle(nullptr, [](void*) { StopDB(); });

    std::shared_ptr<LegionForge::Asio::IoContext> ioContext = std::make_shared<LegionForge::Asio::IoContext>();

    // Start the listening port (acceptor) for auth connections
    int32 bnport = sConfigMgr->GetIntDefault("BattlenetPort", 1119);
    if (bnport < 0 || bnport > 0xFFFF)
    {
        LF_LOG_ERROR("server.bnetserver", "Specified battle.net port (%d) out of allowed range (1-65535)", bnport);
        return 1;
    }

    if (!sLoginService.Start(ioContext.get()))
    {
        LF_LOG_ERROR("server.bnetserver", "Failed to initialize login service");
        return 1;
    }

    std::shared_ptr<void> sLoginServiceHandle(nullptr, [](void*) { sLoginService.Stop(); });

    // Get the list of realms for the server
    sRealmList->Initialize(*ioContext, sConfigMgr->GetIntDefault("RealmsStateUpdateDelay", 10));

    std::shared_ptr<void> sRealmListHandle(nullptr, [](void*) { sRealmList->Close(); });

    std::string bindIp = sConfigMgr->GetStringDefault("BindIP", "0.0.0.0");

    if (!sSessionMgr.StartNetwork(*ioContext, bindIp, bnport))
    {
        LF_LOG_ERROR("server.bnetserver", "Failed to initialize network");
        return 1;
    }

    std::shared_ptr<void> sSessionMgrHandle(nullptr, [](void*) { sSessionMgr.StopNetwork(); });

    // Set signal handlers
    boost::asio::signal_set signals(*ioContext, SIGINT, SIGTERM);
#if LEGIONFORGE_PLATFORM == LEGIONFORGE_PLATFORM_WINDOWS
    signals.add(SIGBREAK);
#endif
    signals.async_wait(std::bind(&SignalHandler, std::weak_ptr<LegionForge::Asio::IoContext>(ioContext), std::placeholders::_1, std::placeholders::_2));

    // Set process priority according to configuration settings
    SetProcessPriority("server.bnetserver", sConfigMgr->GetIntDefault(CONFIG_PROCESSOR_AFFINITY, 0), sConfigMgr->GetBoolDefault(CONFIG_HIGH_PRIORITY, false));

    // Enabled a timed callback for handling the database keep alive ping
    int32 dbPingInterval = sConfigMgr->GetIntDefault("MaxPingTime", 30);
    std::shared_ptr<boost::asio::steady_timer> dbPingTimer = std::make_shared<boost::asio::steady_timer>(*ioContext);
    dbPingTimer->expires_after(std::chrono::minutes(dbPingInterval));
    dbPingTimer->async_wait(std::bind(&KeepDatabaseAliveHandler, std::weak_ptr<boost::asio::steady_timer>(dbPingTimer), dbPingInterval, std::placeholders::_1));

    int32 banExpiryCheckInterval = sConfigMgr->GetIntDefault("BanExpiryCheckInterval", 60);
    std::shared_ptr<boost::asio::steady_timer> banExpiryCheckTimer = std::make_shared<boost::asio::steady_timer>(*ioContext);
    banExpiryCheckTimer->expires_after(std::chrono::seconds(banExpiryCheckInterval));
    banExpiryCheckTimer->async_wait(std::bind(&BanExpiryHandler, std::weak_ptr<boost::asio::steady_timer>(banExpiryCheckTimer), banExpiryCheckInterval, std::placeholders::_1));

#if LEGIONFORGE_PLATFORM == LEGIONFORGE_PLATFORM_WINDOWS
    std::shared_ptr<boost::asio::steady_timer> serviceStatusWatchTimer;
    if (m_ServiceStatus != -1)
    {
        serviceStatusWatchTimer = std::make_shared<boost::asio::steady_timer>(*ioContext);
        serviceStatusWatchTimer->expires_after(std::chrono::seconds(1));
        serviceStatusWatchTimer->async_wait(std::bind(&ServiceStatusWatcher,
            std::weak_ptr<boost::asio::steady_timer>(serviceStatusWatchTimer),
            std::weak_ptr<LegionForge::Asio::IoContext>(ioContext),
            std::placeholders::_1));
    }
#endif

    // Start the io service worker loop
    ioContext->run();

    banExpiryCheckTimer->cancel();
    dbPingTimer->cancel();

    LF_LOG_INFO("server.bnetserver", "Halting process...");

    signals.cancel();

    return 0;
}

/// Initialize connection to the database
bool StartDB()
{
    MySQL::Library_Init();

    // Load databases
    DatabaseLoader loader("server.bnetserver", DatabaseLoader::DATABASE_NONE);
    loader
        .AddDatabase(LoginDatabase, "Login");

    if (!loader.Load())
        return false;

    LF_LOG_INFO("server.bnetserver", "Started auth database connection pool.");
    sLog->SetRealmId(0); // Enables DB appenders when realm is set.
    return true;
}

/// Close the connection to the database
void StopDB()
{
    LoginDatabase.Close();
    MySQL::Library_End();
}

void SignalHandler(std::weak_ptr<LegionForge::Asio::IoContext> ioContextRef, boost::system::error_code const& error, int /*signalNumber*/)
{
    if (!error)
        if (std::shared_ptr<LegionForge::Asio::IoContext> ioContext = ioContextRef.lock())
            ioContext->stop();
}

void KeepDatabaseAliveHandler(std::weak_ptr<boost::asio::steady_timer> dbPingTimerRef, int32 dbPingInterval, boost::system::error_code const& error)
{
    if (!error)
    {
        if (std::shared_ptr<boost::asio::steady_timer> dbPingTimer = dbPingTimerRef.lock())
        {
            LF_LOG_INFO("server.bnetserver", "Ping MySQL to keep connection alive");
            LoginDatabase.KeepAlive();

            dbPingTimer->expires_after(std::chrono::minutes(dbPingInterval));
            dbPingTimer->async_wait(std::bind(&KeepDatabaseAliveHandler, dbPingTimerRef, dbPingInterval, std::placeholders::_1));
        }
    }
}

void BanExpiryHandler(std::weak_ptr<boost::asio::steady_timer> banExpiryCheckTimerRef, int32 banExpiryCheckInterval, boost::system::error_code const& error)
{
    if (!error)
    {
        if (std::shared_ptr<boost::asio::steady_timer> banExpiryCheckTimer = banExpiryCheckTimerRef.lock())
        {
            LoginDatabase.Execute(LoginDatabase.GetPreparedStatement(LOGIN_DEL_EXPIRED_IP_BANS));
            LoginDatabase.Execute(LoginDatabase.GetPreparedStatement(LOGIN_UPD_EXPIRED_ACCOUNT_BANS));
            LoginDatabase.Execute(LoginDatabase.GetPreparedStatement(LOGIN_DEL_BNET_EXPIRED_ACCOUNT_BANNED));

            banExpiryCheckTimer->expires_after(std::chrono::seconds(banExpiryCheckInterval));
            banExpiryCheckTimer->async_wait(std::bind(&BanExpiryHandler, banExpiryCheckTimerRef, banExpiryCheckInterval, std::placeholders::_1));
        }
    }
}

#if LEGIONFORGE_PLATFORM == LEGIONFORGE_PLATFORM_WINDOWS
void ServiceStatusWatcher(std::weak_ptr<boost::asio::steady_timer> serviceStatusWatchTimerRef, std::weak_ptr<LegionForge::Asio::IoContext> ioContextRef, boost::system::error_code const& error)
{
    if (!error)
    {
        if (std::shared_ptr<LegionForge::Asio::IoContext> ioContext = ioContextRef.lock())
        {
            if (m_ServiceStatus == 0)
            {
                ioContext->stop();
            }
            else if (std::shared_ptr<boost::asio::steady_timer> serviceStatusWatchTimer = serviceStatusWatchTimerRef.lock())
            {
                serviceStatusWatchTimer->expires_after(std::chrono::seconds(1));
                serviceStatusWatchTimer->async_wait(std::bind(&ServiceStatusWatcher, serviceStatusWatchTimerRef, ioContext, std::placeholders::_1));
            }
        }
    }
}
#endif

variables_map GetConsoleArguments(int argc, char** argv, fs::path& configFile, std::string& configService)
{
    (void)configService;

    options_description all("Allowed options");
    all.add_options()
        ("help,h", "print usage message")
        ("version,v", "print version build info")
        ("config,c", value<fs::path>(&configFile)->default_value(fs::absolute(_LEGIONFORGE_BNET_CONFIG)),
                     "use <arg> as configuration file")
        ;
#if LEGIONFORGE_PLATFORM == LEGIONFORGE_PLATFORM_WINDOWS
    options_description win("Windows platform specific options");
    win.add_options()
        ("service,s", value<std::string>(&configService)->default_value(""), "Windows service options: [install | uninstall]")
        ;

    all.add(win);
#endif
    variables_map variablesMap;
    try
    {
        store(command_line_parser(argc, argv).options(all).allow_unregistered().run(), variablesMap);
        notify(variablesMap);
    }
    catch (std::exception& e)
    {
        std::cerr << e.what() << "\n";
    }

    if (variablesMap.count("help"))
    {
        std::cout << all << "\n";
    }
    else if (variablesMap.count("version"))
    {
        std::cout << GitRevision::GetFullVersion() << "\n";
    }

    return variablesMap;
}
