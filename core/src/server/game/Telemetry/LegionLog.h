/*
 * Legion session telemetry. One JSON object per line.
 * See docs/systems/LOGGING-SYSTEM.md.
 */

#ifndef LEGION_LOG_H
#define LEGION_LOG_H

#include "Define.h"
#include "LogCommon.h"
#include <cstdint>
#include <string>

class Player;
class WorldObject;
class Item;

class LF_GAME_API LegionEvent
{
public:
    LegionEvent(char const* file, int line, LogLevel level, char const* cat, char const* evt);
    LegionEvent& AttachedPlayer(Player* player);
    LegionEvent& AttachedObject(WorldObject* object);
    LegionEvent& AttachedItem(Item* item);
    LegionEvent& Field(char const* key, char const* value);
    LegionEvent& Field(char const* key, std::string const& value);
    LegionEvent& Field(char const* key, int64 value);
    LegionEvent& FieldBool(char const* key, bool value);
    void Emit();

private:
    void AddData(std::string const& key, std::string const& rawJson);

    LogLevel _level;
    std::string _cat;
    std::string _evt;
    std::string _src;
    Player* _player;
    std::string _objJson;
    std::string _data;
    bool _emitted;
};

#define LLOG(level, cat, evt) LegionEvent(__FILE__, __LINE__, level, cat, evt)

#endif
