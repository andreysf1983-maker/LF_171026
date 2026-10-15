#include "LegionLog.h"
#include "Config.h"
#include "Item.h"
#include "Log.h"
#include "Object.h"
#include "PhaseShift.h"
#include "Player.h"
#include "WorldSession.h"

#include <boost/filesystem.hpp>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <ctime>
#include <fstream>
#include <map>
#include <memory>
#include <mutex>
#include <sstream>

namespace
{
std::mutex g_mu;
bool g_ready = false;
bool g_enabled = true;
LogLevel g_minLevel = LOG_LEVEL_INFO;
std::string g_runId;
boost::filesystem::path g_runDir;
uint64 g_seq = 0;
std::map<std::string, std::unique_ptr<std::ofstream>> g_streams;

std::string JsonEscape(char const* value)
{
    std::string out;
    if (!value)
        return out;

    for (unsigned char c : std::string(value))
    {
        switch (c)
        {
            case '"': out += "\\\""; break;
            case '\\': out += "\\\\"; break;
            case '\b': out += "\\b"; break;
            case '\f': out += "\\f"; break;
            case '\n': out += "\\n"; break;
            case '\r': out += "\\r"; break;
            case '\t': out += "\\t"; break;
            default:
                if (c < 0x20)
                {
                    char buf[8];
                    snprintf(buf, sizeof(buf), "\\u%04x", c);
                    out += buf;
                }
                else
                    out += char(c);
                break;
        }
    }
    return out;
}

std::string Quoted(char const* value)
{
    return "\"" + JsonEscape(value) + "\"";
}

std::string UtcTimestamp()
{
    using namespace std::chrono;
    auto now = system_clock::now();
    auto ms = duration_cast<milliseconds>(now.time_since_epoch());
    std::time_t sec = static_cast<std::time_t>(ms.count() / 1000);
    int millis = static_cast<int>(ms.count() % 1000);
    if (millis < 0)
        millis = 0;

    std::tm tm{};
#if LEGIONFORGE_PLATFORM == LEGIONFORGE_PLATFORM_WINDOWS
    gmtime_s(&tm, &sec);
#else
    gmtime_r(&sec, &tm);
#endif
    char buf[40];
    std::strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%S", &tm);
    char full[48];
    snprintf(full, sizeof(full), "%s.%03dZ", buf, millis);
    return full;
}

std::string BaseName(char const* path)
{
    if (!path)
        return "unknown";
    std::string s(path);
    size_t slash = s.find_last_of("\\/");
    if (slash != std::string::npos)
        s = s.substr(slash + 1);
    return s;
}

void WriteTextFile(boost::filesystem::path const& path, std::string const& text)
{
    boost::filesystem::create_directories(path.parent_path());
    std::ofstream out(path.string(), std::ios::trunc | std::ios::binary);
    if (out)
        out << text;
}

std::ofstream* Stream(std::string const& relative)
{
    auto itr = g_streams.find(relative);
    if (itr != g_streams.end())
        return itr->second.get();

    boost::filesystem::path path = g_runDir / relative;
    boost::filesystem::create_directories(path.parent_path());
    auto stream = std::make_unique<std::ofstream>(path.string(), std::ios::app | std::ios::binary);
    if (!stream->is_open())
        return nullptr;

    std::ofstream* raw = stream.get();
    g_streams.emplace(relative, std::move(stream));
    return raw;
}

void EnsureLocked()
{
    if (g_ready)
        return;
    g_ready = true;

    g_enabled = sConfigMgr->GetBoolDefault("LegionLog.Enabled", true);
    int configured = sConfigMgr->GetIntDefault("LegionLog.Level", LOG_LEVEL_INFO);
    if (configured < LOG_LEVEL_DISABLED)
        configured = LOG_LEVEL_DISABLED;
    if (configured > LOG_LEVEL_FATAL)
        configured = LOG_LEVEL_FATAL;
    g_minLevel = static_cast<LogLevel>(configured);

    if (char const* env = std::getenv("LEGION_RUN_ID"))
    {
        if (*env)
            g_runId = env;
    }

    if (g_runId.empty())
    {
        std::time_t now = std::time(nullptr);
        std::tm tm{};
#if LEGIONFORGE_PLATFORM == LEGIONFORGE_PLATFORM_WINDOWS
        gmtime_s(&tm, &now);
#else
        gmtime_r(&now, &tm);
#endif
        char buf[32];
        std::strftime(buf, sizeof(buf), "%Y%m%d-%H%M%S", &tm);
        g_runId = buf;
    }

    std::string logsRoot = sLog->GetLogsDir();
    if (logsRoot.empty())
        logsRoot = "logs";
    while (!logsRoot.empty() && (logsRoot.back() == '/' || logsRoot.back() == '\\'))
        logsRoot.pop_back();

    g_runDir = boost::filesystem::path(logsRoot) / "runs" / g_runId;
    try
    {
        boost::filesystem::create_directories(g_runDir / "sessions");
        WriteTextFile(boost::filesystem::path(logsRoot) / "current_run.txt", g_runId + "\n");
        if (logsRoot != "logs")
            WriteTextFile(boost::filesystem::path("logs") / "current_run.txt", g_runId + "\n");

        std::ostringstream meta;
        meta << "{\"run\":\"" << JsonEscape(g_runId.c_str())
             << "\",\"started\":\"" << UtcTimestamp()
             << "\",\"dir\":\"" << JsonEscape(g_runDir.string().c_str()) << "\"}\n";
        WriteTextFile(g_runDir / "meta.json", meta.str());
    }
    catch (...)
    {
        g_enabled = false;
    }
}

bool Accepts(LogLevel level)
{
    // LogLevel increases with severity: trace=1 ... fatal=6.
    return g_enabled && level != LOG_LEVEL_DISABLED && level >= g_minLevel;
}

std::string PhaseArray(Player* player)
{
    std::ostringstream out;
    out << '[';
    bool first = true;
    if (player && player->IsInWorld())
    {
        for (PhaseShift::PhaseRef const& phase : player->GetPhaseShift().GetPhases())
        {
            if (!first)
                out << ',';
            first = false;
            out << uint32(phase.Id);
        }
    }
    out << ']';
    return out.str();
}
}

LegionEvent::LegionEvent(char const* file, int line, LogLevel level, char const* cat, char const* evt)
    : _level(level), _cat(cat ? cat : ""), _evt(evt ? evt : ""), _player(nullptr), _emitted(false)
{
    std::ostringstream src;
    src << BaseName(file) << ':' << line;
    _src = src.str();
}

LegionEvent& LegionEvent::AttachedPlayer(Player* player)
{
    _player = player;
    return *this;
}

LegionEvent& LegionEvent::AttachedObject(WorldObject* object)
{
    if (!object)
        return *this;

    std::ostringstream json;
    json << "{\"guid\":" << Quoted(object->GetGUID().ToString().c_str())
         << ",\"entry\":" << uint32(object->GetEntry())
         << ",\"name\":" << Quoted(object->GetName().c_str()) << '}';
    _objJson = json.str();
    return *this;
}

LegionEvent& LegionEvent::AttachedItem(Item* item)
{
    if (!item || !item->GetTemplate())
        return *this;

    std::ostringstream json;
    json << "{\"guid\":" << Quoted(item->GetGUID().ToString().c_str())
         << ",\"entry\":" << uint32(item->GetEntry())
         << ",\"name\":" << Quoted(item->GetTemplate()->GetName(LOCALE_enUS)) << '}';
    _objJson = json.str();
    return *this;
}

void LegionEvent::AddData(std::string const& key, std::string const& rawJson)
{
    if (!_data.empty())
        _data += ',';
    _data += Quoted(key.c_str());
    _data += ':';
    _data += rawJson;
}

LegionEvent& LegionEvent::Field(char const* key, char const* value)
{
    if (key)
        AddData(key, Quoted(value));
    return *this;
}

LegionEvent& LegionEvent::Field(char const* key, std::string const& value)
{
    return Field(key, value.c_str());
}

LegionEvent& LegionEvent::Field(char const* key, int64 value)
{
    if (key)
        AddData(key, std::to_string(value));
    return *this;
}

LegionEvent& LegionEvent::FieldBool(char const* key, bool value)
{
    if (key)
        AddData(key, value ? "true" : "false");
    return *this;
}

void LegionEvent::Emit()
{
    if (_emitted)
        return;
    _emitted = true;

    std::lock_guard<std::mutex> lock(g_mu);
    EnsureLocked();
    if (!Accepts(_level))
        return;

    char const* levelName = "info";
    switch (_level)
    {
        case LOG_LEVEL_FATAL: levelName = "fatal"; break;
        case LOG_LEVEL_ERROR: levelName = "error"; break;
        case LOG_LEVEL_WARN: levelName = "warn"; break;
        case LOG_LEVEL_INFO: levelName = "info"; break;
        case LOG_LEVEL_DEBUG: levelName = "debug"; break;
        case LOG_LEVEL_TRACE: levelName = "trace"; break;
        default: break;
    }

    std::string session;
    uint32 account = 0;
    uint64 character = 0;
    std::string name;
    bool located = false;
    uint32 map = 0, zone = 0, area = 0;
    float x = 0, y = 0, z = 0;

    if (_player && _player->GetSession())
    {
        account = _player->GetSession()->GetAccountId();
        character = _player->GetGUID().GetCounter();
        name = _player->GetName();
        session = _player->GetSession()->GetLegionSessionId();
        map = _player->GetMapId();
        x = _player->GetPositionX();
        y = _player->GetPositionY();
        z = _player->GetPositionZ();
        if (_player->IsInWorld())
        {
            located = true;
            zone = _player->GetZoneId();
            area = _player->GetAreaId();
        }
    }

    ++g_seq;

    std::ostringstream line;
    line << "{\"ts\":" << Quoted(UtcTimestamp().c_str())
         << ",\"run\":" << Quoted(g_runId.c_str())
         << ",\"seq\":" << g_seq
         << ",\"lvl\":" << Quoted(levelName)
         << ",\"cat\":" << Quoted(_cat.c_str())
         << ",\"evt\":" << Quoted(_evt.c_str());

    if (_player)
    {
        line << ",\"acct\":" << account
             << ",\"char\":" << character
             << ",\"charName\":" << Quoted(name.c_str());
        if (!session.empty())
            line << ",\"sess\":" << Quoted(session.c_str());
        line << ",\"map\":" << map;
        if (located)
        {
            line << ",\"zone\":" << zone
                 << ",\"area\":" << area
                 << ",\"phase\":" << PhaseArray(_player);
        }
        char coord[96];
        snprintf(coord, sizeof(coord), ",\"x\":%.1f,\"y\":%.1f,\"z\":%.1f", x, y, z);
        line << coord;
    }

    if (!_objJson.empty())
        line << ",\"obj\":" << _objJson;

    line << ",\"data\":{" << _data << '}'
         << ",\"src\":" << Quoted(_src.c_str())
         << '}';

    std::string text = line.str();
    if (std::ofstream* runLog = Stream("events.jsonl"))
    {
        *runLog << text << '\n';
        runLog->flush();
    }

    if (!session.empty())
    {
        std::string relative = "sessions/" + session + "/events.jsonl";
        if (std::ofstream* sessionLog = Stream(relative))
        {
            *sessionLog << text << '\n';
            sessionLog->flush();
        }
    }
}
