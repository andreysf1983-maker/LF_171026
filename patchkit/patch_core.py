#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LEGIONFORGE 7.3.5 (build 26124) - патчер C++ ядра.

Исправляет три класса проблем, из-за которых сервер не запускается / не
поддерживает кастомный клиент:

  1. Кастомные расы 31..44 (MAX_RACES=31, 32-битные racemask-и,
     обязательное наличие расы в серверном ChrRaces.db2).
  2. bnetserver: "Failed to initialize SSL context" - неразрешимые
     относительные пути к .pem, несовпадающая пара cert/key, отсутствие
     детальной диагностики в логе.
  3. vmap4extractor: "Can't open World\\Maps\\test\\test.wdt: FILE_NOT_FOUND"
     в stderr -> PowerShell 5.1 превращает это в NativeCommandError и рвёт
     extract_delta.ps1.

Запуск:  python3 patch_core.py <путь к корню репозитория>
Скрипт идемпотентен: повторный запуск ничего не ломает.
"""
import os
import re
import sys

MARK = "[LEGIONFORGE PATCH 2026-10]"


def read(path):
    with open(path, "rb") as fh:
        raw = fh.read()
    bom = raw.startswith(b"\xef\xbb\xbf")
    text = raw.decode("utf-8-sig" if bom else "utf-8")
    crlf = "\r\n" in text
    return text.replace("\r\n", "\n"), bom, crlf


def write(path, text, bom, crlf):
    if crlf:
        text = text.replace("\n", "\r\n")
    data = text.encode("utf-8")
    if bom:
        data = b"\xef\xbb\xbf" + data
    with open(path, "wb") as fh:
        fh.write(data)


class Patch:
    def __init__(self, root):
        self.root = root
        self.applied = 0
        self.skipped = 0

    def path(self, *parts):
        return os.path.join(self.root, *parts)

    def sub(self, relpath, old, new, count=1, required=True):
        path = self.path(*relpath.split("/"))
        text, bom, crlf = read(path)
        found = text.count(old)
        if found == 0:
            if new in text:
                self.skipped += 1
                print("  = уже применено: %s" % relpath)
                return True
            if required:
                raise SystemExit("!! НЕ НАЙДЕН ФРАГМЕНТ в %s:\n%s" % (relpath, old[:400]))
            print("  - пропущено (не найдено): %s" % relpath)
            return False
        text = text.replace(old, new, count if count else found)
        write(path, text, bom, crlf)
        self.applied += 1
        print("  + %s  (замен: %d)" % (relpath, found))
        return True

    def regex(self, relpath, pattern, repl, required=True):
        path = self.path(*relpath.split("/"))
        text, bom, crlf = read(path)
        new_text, found = re.subn(pattern, repl, text)
        if found == 0:
            if required:
                raise SystemExit("!! РЕГУЛЯРКА НЕ СРАБОТАЛА в %s: %s" % (relpath, pattern))
            print("  - пропущено (regex): %s" % relpath)
            return 0
        write(path, new_text, bom, crlf)
        self.applied += 1
        print("  + %s  (regex замен: %d)" % (relpath, found))
        return found

    def write_file(self, relpath, content):
        path = self.path(*relpath.split("/"))
        os.makedirs(os.path.dirname(path), exist_ok=True)
        write(path, content, False, False)
        self.applied += 1
        print("  + записан файл: %s (%d байт)" % (relpath, len(content)))


def patch_shared_defines(p):
    rel = "core/src/server/game/Miscellaneous/SharedDefines.h"
    p.sub(rel, """    RACE_NIGHTBORNE             = 27,
    RACE_HIGHMOUNTAIN_TAUREN    = 28,
    RACE_VOID_ELF               = 29,
    RACE_LIGHTFORGED_DRAENEI    = 30
};

// max+1 for player race
#define MAX_RACES         31""",
          """    RACE_NIGHTBORNE             = 27,
    RACE_HIGHMOUNTAIN_TAUREN    = 28,
    RACE_VOID_ELF               = 29,
    RACE_LIGHTFORGED_DRAENEI    = 30,
    // [LEGIONFORGE CUSTOM-RACES 2026-10] -----------------------------------
    // Кастомный клиент (UWoW-подобная сборка 7.3.5 build 26124) содержит в
    // ChrRaces.db2 расы 31..44. Имена констант условные: отображаемое имя
    // ядро всегда берёт из ChrRaces.db2 клиента (DB2Manager::GetChrRaceName).
    // Константы нужны, чтобы снять жёсткий лимит MAX_RACES=31 и дать SQL и
    // worldserver.conf стабильные идентификаторы.
    RACE_CUSTOM_31              = 31,
    RACE_CUSTOM_32              = 32,
    RACE_CUSTOM_33              = 33,
    RACE_CUSTOM_34              = 34,
    RACE_CUSTOM_35              = 35,
    RACE_CUSTOM_36              = 36,
    RACE_CUSTOM_37              = 37,
    RACE_CUSTOM_38              = 38,
    RACE_CUSTOM_39              = 39,
    RACE_CUSTOM_40              = 40,
    RACE_CUSTOM_41              = 41,
    RACE_CUSTOM_42              = 42,
    RACE_CUSTOM_43              = 43,
    RACE_CUSTOM_44              = 44
};

// Диапазон кастомных рас клиента (включительно).
#define RACE_CUSTOM_FIRST   31
#define RACE_CUSTOM_LAST    44

// max+1 for player race
// [LEGIONFORGE CUSTOM-RACES] было 31: расы 31..44 отбрасывались при загрузке
// `playercreateinfo`, `race_unlock_requirement` и при создании персонажа.
#define MAX_RACES         45""")

    # 32-битные маски -> 64-битные (сдвиг 1<<32 и больше = UB)
    p.sub(rel, """#define RACEMASK_ALL_PLAYABLE      \\
    ((1<<(RACE_HUMAN-1))         | \\
     (1<<(RACE_ORC-1))           | \\
     (1<<(RACE_DWARF-1))         | \\
     (1<<(RACE_NIGHTELF-1))      | \\
     (1<<(RACE_UNDEAD_PLAYER-1)) | \\
     (1<<(RACE_TAUREN-1))        | \\
     (1<<(RACE_GNOME-1))         | \\
     (1<<(RACE_TROLL-1))         | \\
     (1<<(RACE_BLOODELF-1))      | \\
     (1<<(RACE_DRAENEI-1))       | \\
     (1<<(RACE_GOBLIN-1))        | \\
     (1<<(RACE_WORGEN-1))        | \\
     (1<<(RACE_PANDAREN_NEUTRAL-1))  |\\
     (1<<(RACE_PANDAREN_ALLIANCE-1)) |\\
     (1<<(RACE_PANDAREN_HORDE-1))|\\
     (1<<(RACE_NIGHTBORNE-1))|\\
     (1<<(RACE_HIGHMOUNTAIN_TAUREN-1))|\\
     (1<<(RACE_VOID_ELF-1))|\\
     (1<<(RACE_LIGHTFORGED_DRAENEI-1)))

#define RACEMASK_NEUTRAL (1<<(RACE_PANDAREN_NEUTRAL-1))""",
          """#define RACEMASK_ALL_PLAYABLE      \\
    ((UI64LIT(1)<<(RACE_HUMAN-1))         | \\
     (UI64LIT(1)<<(RACE_ORC-1))           | \\
     (UI64LIT(1)<<(RACE_DWARF-1))         | \\
     (UI64LIT(1)<<(RACE_NIGHTELF-1))      | \\
     (UI64LIT(1)<<(RACE_UNDEAD_PLAYER-1)) | \\
     (UI64LIT(1)<<(RACE_TAUREN-1))        | \\
     (UI64LIT(1)<<(RACE_GNOME-1))         | \\
     (UI64LIT(1)<<(RACE_TROLL-1))         | \\
     (UI64LIT(1)<<(RACE_BLOODELF-1))      | \\
     (UI64LIT(1)<<(RACE_DRAENEI-1))       | \\
     (UI64LIT(1)<<(RACE_GOBLIN-1))        | \\
     (UI64LIT(1)<<(RACE_WORGEN-1))        | \\
     (UI64LIT(1)<<(RACE_PANDAREN_NEUTRAL-1))  |\\
     (UI64LIT(1)<<(RACE_PANDAREN_ALLIANCE-1)) |\\
     (UI64LIT(1)<<(RACE_PANDAREN_HORDE-1))|\\
     (UI64LIT(1)<<(RACE_NIGHTBORNE-1))|\\
     (UI64LIT(1)<<(RACE_HIGHMOUNTAIN_TAUREN-1))|\\
     (UI64LIT(1)<<(RACE_VOID_ELF-1))|\\
     (UI64LIT(1)<<(RACE_LIGHTFORGED_DRAENEI-1)))

// [LEGIONFORGE CUSTOM-RACES] маска кастомных рас 31..44.
#define RACEMASK_CUSTOM_PLAYABLE   \\
    ((UI64LIT(1)<<(RACE_CUSTOM_31-1)) | \\
     (UI64LIT(1)<<(RACE_CUSTOM_32-1)) | \\
     (UI64LIT(1)<<(RACE_CUSTOM_33-1)) | \\
     (UI64LIT(1)<<(RACE_CUSTOM_34-1)) | \\
     (UI64LIT(1)<<(RACE_CUSTOM_35-1)) | \\
     (UI64LIT(1)<<(RACE_CUSTOM_36-1)) | \\
     (UI64LIT(1)<<(RACE_CUSTOM_37-1)) | \\
     (UI64LIT(1)<<(RACE_CUSTOM_38-1)) | \\
     (UI64LIT(1)<<(RACE_CUSTOM_39-1)) | \\
     (UI64LIT(1)<<(RACE_CUSTOM_40-1)) | \\
     (UI64LIT(1)<<(RACE_CUSTOM_41-1)) | \\
     (UI64LIT(1)<<(RACE_CUSTOM_42-1)) | \\
     (UI64LIT(1)<<(RACE_CUSTOM_43-1)) | \\
     (UI64LIT(1)<<(RACE_CUSTOM_44-1)))

// Бит расы в 64-битной маске (безопасно для race 1..64; race 0 -> 0).
inline uint64 RaceMaskForRace(uint8 race)
{
    return (race == 0 || race > 64) ? UI64LIT(0) : (UI64LIT(1) << (race - 1));
}

// Расы, которые можно адресовать 32-битной маской в БД (spell_area,
// mail_level_reward, quest_template.AllowableRaces и т.п.).
#define RACEMASK_DB32_LIMIT   32

#define RACEMASK_NEUTRAL (UI64LIT(1)<<(RACE_PANDAREN_NEUTRAL-1))""")

    p.sub(rel, "#define RACEMASK_ALLIANCE     \\\n    ((1<<(RACE_HUMAN-1))    | \\\n     (1<<(RACE_DWARF-1))    | \\\n     (1<<(RACE_NIGHTELF-1)) | \\\n     (1<<(RACE_GNOME-1))    | \\\n     (1<<(RACE_DRAENEI-1))  | \\\n     (1<<(RACE_WORGEN-1))   | \\\n     (1<<(RACE_PANDAREN_ALLIANCE-1)) |\\\n     (1<<(RACE_VOID_ELF-1)) |\\\n     (1<<(RACE_LIGHTFORGED_DRAENEI-1)))\n\n#define RACEMASK_HORDE RACEMASK_ALL_PLAYABLE & ~RACEMASK_ALLIANCE",
          "#define RACEMASK_ALLIANCE     \\\n    ((UI64LIT(1)<<(RACE_HUMAN-1))    | \\\n     (UI64LIT(1)<<(RACE_DWARF-1))    | \\\n     (UI64LIT(1)<<(RACE_NIGHTELF-1)) | \\\n     (UI64LIT(1)<<(RACE_GNOME-1))    | \\\n     (UI64LIT(1)<<(RACE_DRAENEI-1))  | \\\n     (UI64LIT(1)<<(RACE_WORGEN-1))   | \\\n     (UI64LIT(1)<<(RACE_PANDAREN_ALLIANCE-1)) |\\\n     (UI64LIT(1)<<(RACE_VOID_ELF-1)) |\\\n     (UI64LIT(1)<<(RACE_LIGHTFORGED_DRAENEI-1)))\n\n// [LEGIONFORGE CUSTOM-RACES] скобки обязательны: макрос подставляется в\n// выражения вида `mask & RACEMASK_HORDE`, где без скобок менялся приоритет.\n#define RACEMASK_HORDE (RACEMASK_ALL_PLAYABLE & ~RACEMASK_ALLIANCE)")


def patch_player(p):
    relh = "core/src/server/game/Entities/Player/Player.h"
    p.sub(relh, "        static bool IsValidRace(uint8 Race) { return ((1 << (Race - 1)) & RACEMASK_ALL_PLAYABLE) != 0; }",
          "        // [LEGIONFORGE CUSTOM-RACES] 64-битная маска + реестр кастомных рас.\n"
          "        static bool IsValidRace(uint8 Race) { return ((RaceMaskForRace(Race) & RACEMASK_ALL_PLAYABLE) != 0) || IsCustomRace(Race); }")

    p.sub(relh, "        static uint32 TeamForRace(uint8 race);",
          "        static uint32 TeamForRace(uint8 race);\n"
          "        // [LEGIONFORGE CUSTOM-RACES] реестр кастомных рас клиента (31..44):\n"
          "        // описывается в worldserver.conf (CustomRaces.Enable /\n"
          "        // CustomRaces.Definitions) и используется когда расы нет в\n"
          "        // серверном ChrRaces.db2.\n"
          "        static bool IsCustomRace(uint8 race);\n"
          "        static uint8 GetCustomRaceBase(uint8 race);\n"
          "        static uint32 GetCustomRaceTeam(uint8 race);")

    relc = "core/src/server/game/Entities/Player/Player.cpp"
    text, bom, crlf = read(p.path(*relc.split("/")))
    registry_present = "LegionForgeCustomRaces" in text
    if "#include \"Config.h\"" not in text:
        text = text.replace('#include "Player.h"',
                            '#include "Player.h"\n#include "Config.h"\n'
                            '// [LEGIONFORGE CUSTOM-RACES] для реестра кастомных рас 31..44\n'
                            '#include <cctype>\n#include <unordered_map>', 1)
        write(p.path(*relc.split("/")), text, bom, crlf)
        print("  + %s: добавлены #include Config.h/cctype/unordered_map" % relc)

    registry = '''
// [LEGIONFORGE CUSTOM-RACES 2026-10] ---------------------------------------
// Реестр кастомных рас клиента (31..44). Кастомный клиент хранит их в своём
// ChrRaces.db2, а серверный ChrRaces.db2 (официальный 7.3.5) - нет. Без
// реестра ядро:
//   * отбрасывало строки `playercreateinfo` ("Wrong race %u ... ignoring"),
//   * запрещало создание персонажа ("Race (%u) not found in DBC"),
//   * назначало всем расам 31+ команду ALLIANCE и спамило ошибками.
// Настройка (worldserver.conf):
//   CustomRaces.Enable = 1
//   CustomRaces.Definitions = "31:ALLIANCE:1,32:HORDE:2,..."
// Формат записи:  raceId:team:baseRace
//   team     - ALLIANCE | HORDE | NEUTRAL (или 0 | 1 | 2)
//   baseRace - раса-донор из ChrRaces.db2: её FactionID и стартовое
//              наследие применяются к кастомной расе.
namespace LegionForgeCustomRaces
{
    struct CustomRaceDef
    {
        uint8  Race     = 0;
        uint32 Team     = TEAM_NEUTRAL;
        uint8  BaseRace = 0;
    };

    typedef std::unordered_map<uint8, CustomRaceDef> CustomRaceMap;

    static char const* const DEFAULT_DEFINITIONS =
        "31:ALLIANCE:1,32:HORDE:2,33:ALLIANCE:4,34:ALLIANCE:3,35:HORDE:5,"
        "36:HORDE:6,37:ALLIANCE:7,38:HORDE:8,39:HORDE:10,40:ALLIANCE:11,"
        "41:ALLIANCE:22,42:HORDE:9,43:NEUTRAL:24,44:ALLIANCE:27";

    static uint32 ParseTeam(std::string const& text)
    {
        std::string value;
        value.reserve(text.size());
        for (char c : text)
        {
            if (isspace(static_cast<unsigned char>(c)))
                continue;
            value.push_back(static_cast<char>(toupper(static_cast<unsigned char>(c))));
        }

        if (value == "ALLIANCE" || value == "A" || value == "0")
            return ALLIANCE;
        if (value == "HORDE" || value == "H" || value == "1")
            return HORDE;
        return TEAM_NEUTRAL;
    }

    static uint32 ParseUInt(std::string const& text, bool& ok)
    {
        ok = false;
        uint32 value = 0;
        for (char c : text)
        {
            if (isspace(static_cast<unsigned char>(c)))
                continue;
            if (!isdigit(static_cast<unsigned char>(c)))
                return 0;
            value = value * 10 + uint32(c - '0');
            ok = true;
        }
        return value;
    }

    static CustomRaceMap BuildMap()
    {
        CustomRaceMap map;

        if (!sConfigMgr->GetBoolDefault("CustomRaces.Enable", true))
            return map;

        std::string const definitions = sConfigMgr->GetStringDefault("CustomRaces.Definitions", DEFAULT_DEFINITIONS);

        size_t pos = 0;
        while (pos <= definitions.size())
        {
            size_t end = definitions.find(',', pos);
            if (end == std::string::npos)
                end = definitions.size();

            std::string entry = definitions.substr(pos, end - pos);
            pos = end + 1;

            size_t firstSep = entry.find(':');
            if (firstSep == std::string::npos)
                continue;

            size_t secondSep = entry.find(':', firstSep + 1);

            std::string const raceText = entry.substr(0, firstSep);
            std::string const teamText = (secondSep == std::string::npos)
                ? entry.substr(firstSep + 1)
                : entry.substr(firstSep + 1, secondSep - firstSep - 1);
            std::string const baseText = (secondSep == std::string::npos)
                ? std::string()
                : entry.substr(secondSep + 1);

            bool ok = false;
            uint32 const race = ParseUInt(raceText, ok);
            if (!ok || race < RACE_CUSTOM_FIRST || race > RACE_CUSTOM_LAST)
            {
                LF_LOG_ERROR("entities.player", "[CustomRaces] Definition '%s' ignored: race id must be %u..%u",
                    entry.c_str(), uint32(RACE_CUSTOM_FIRST), uint32(RACE_CUSTOM_LAST));
                continue;
            }

            uint32 const base = ParseUInt(baseText, ok);
            if (!ok || base < RACE_HUMAN || base >= MAX_RACES || base == race)
            {
                LF_LOG_ERROR("entities.player", "[CustomRaces] Definition '%s' ignored: baseRace must be 1..%u and differ from race",
                    entry.c_str(), uint32(MAX_RACES - 1));
                continue;
            }

            CustomRaceDef def;
            def.Race = uint8(race);
            def.Team = ParseTeam(teamText);
            def.BaseRace = uint8(base);
            map[uint8(race)] = def;
        }

        if (!map.empty())
            LF_LOG_INFO("entities.player", ">> Registered " SZFMTD " custom client race(s) (ids 31-44) from CustomRaces.Definitions", map.size());

        return map;
    }

    static CustomRaceMap const& Get()
    {
        static CustomRaceMap const map = BuildMap();
        return map;
    }
}

bool Player::IsCustomRace(uint8 race)
{
    return LegionForgeCustomRaces::Get().find(race) != LegionForgeCustomRaces::Get().end();
}

uint8 Player::GetCustomRaceBase(uint8 race)
{
    LegionForgeCustomRaces::CustomRaceMap const& map = LegionForgeCustomRaces::Get();
    auto itr = map.find(race);
    return itr == map.end() ? 0 : itr->second.BaseRace;
}

uint32 Player::GetCustomRaceTeam(uint8 race)
{
    LegionForgeCustomRaces::CustomRaceMap const& map = LegionForgeCustomRaces::Get();
    auto itr = map.find(race);
    if (itr == map.end())
        return ALLIANCE;
    return itr->second.Team == TEAM_NEUTRAL ? ALLIANCE : itr->second.Team;
}

uint32 Player::TeamForRace(uint8 race)
'''
    p.sub(relc, "\nuint32 Player::TeamForRace(uint8 race)\n", registry)

    p.sub(relc, """    else
        LF_LOG_ERROR("entities.player", "Race (%u) not found in DBC: wrong DBC files?", uint32(race));

    return ALLIANCE;
}

TeamId Player::TeamIdForRace(uint8 race)
{
    if (ChrRacesEntry const* rEntry = sChrRacesStore.LookupEntry(race))
        return TeamId(rEntry->Alliance);

    LF_LOG_ERROR("entities.player", "Race (%u) not found in DBC: wrong DBC files?", race);
    return TEAM_NEUTRAL;
}

void Player::setFactionForRace(uint8 race)
{
    m_team = TeamForRace(race);

    ChrRacesEntry const* rEntry = sChrRacesStore.LookupEntry(race);
    setFaction(rEntry ? rEntry->FactionID : 0);
}""",
          """    else
    {
        // [LEGIONFORGE CUSTOM-RACES] расы 31..44 отсутствуют в серверном
        // ChrRaces.db2 - команду берём из реестра кастомных рас.
        if (IsCustomRace(race))
            return GetCustomRaceTeam(race);

        LF_LOG_ERROR("entities.player", "Race (%u) not found in DBC: wrong DBC files?", uint32(race));
    }

    return ALLIANCE;
}

TeamId Player::TeamIdForRace(uint8 race)
{
    if (ChrRacesEntry const* rEntry = sChrRacesStore.LookupEntry(race))
        return TeamId(rEntry->Alliance);

    // [LEGIONFORGE CUSTOM-RACES] TEAM_ALLIANCE == ALLIANCE, TEAM_HORDE == HORDE,
    // поэтому значение из реестра можно привести к TeamId напрямую.
    if (IsCustomRace(race))
    {
        LegionForgeCustomRaces::CustomRaceMap const& map = LegionForgeCustomRaces::Get();
        auto itr = map.find(race);
        if (itr != map.end())
            return TeamId(itr->second.Team);
    }

    LF_LOG_ERROR("entities.player", "Race (%u) not found in DBC: wrong DBC files?", race);
    return TEAM_NEUTRAL;
}

void Player::setFactionForRace(uint8 race)
{
    m_team = TeamForRace(race);

    ChrRacesEntry const* rEntry = sChrRacesStore.LookupEntry(race);
    if (!rEntry)
    {
        // [LEGIONFORGE CUSTOM-RACES] берём FactionID расы-донора: у кастомной
        // расы 31..44 в серверном ChrRaces.db2 записи нет.
        if (uint8 const baseRace = GetCustomRaceBase(race))
            rEntry = sChrRacesStore.LookupEntry(baseRace);
    }

    setFaction(rEntry ? rEntry->FactionID : 0);
}""")


def patch_objectmgr(p):
    rel = "core/src/server/game/Globals/ObjectMgr.cpp"

    p.sub(rel, """                ChrRacesEntry const* rEntry = sChrRacesStore.LookupEntry(current_race);
                if (!rEntry)
                {
                    LF_LOG_ERROR("sql.sql", "Wrong race %u in `playercreateinfo` table, ignoring.", current_race);
                    continue;
                }""",
          """                ChrRacesEntry const* rEntry = sChrRacesStore.LookupEntry(current_race);
                // [LEGIONFORGE CUSTOM-RACES] расы 31..44 есть только в клиентском
                // ChrRaces.db2. Если раса описана в CustomRaces.Definitions -
                // стартовая позиция принимается, иначе PlayerInfo не создаётся и
                // клиент получает CHAR_CREATE_FAILED.
                if (!rEntry && !Player::IsCustomRace(uint8(current_race)))
                {
                    LF_LOG_ERROR("sql.sql", "Wrong race %u in `playercreateinfo` table, ignoring.", current_race);
                    continue;
                }""")

    # rEntry разыменовывается ниже (displayId_m/displayId_f) -> для кастомных рас
    # нужен fallback на расу-донора, иначе null-deref при старте worldserver.
    p.sub(rel, """                PlayerInfo* info = new PlayerInfo();
                info->mapId = mapId;
                info->areaId = areaId;
                info->positionX = positionX;
                info->positionY = positionY;
                info->positionZ = positionZ;
                info->orientation = orientation;
                info->displayId_m = rEntry->MaleDisplayId;
                info->displayId_f = rEntry->FemaleDisplayId;""",
          """                // [LEGIONFORGE CUSTOM-RACES] у рас 31..44 нет записи в серверном
                // ChrRaces.db2, поэтому display id берётся у расы-донора
                // (baseRace из CustomRaces.Definitions). Без этого здесь был бы
                // гарантированный null-deref при старте worldserver.
                ChrRacesEntry const* displayEntry = rEntry;
                if (!displayEntry)
                {
                    if (uint8 const baseRace = Player::GetCustomRaceBase(uint8(current_race)))
                        displayEntry = sChrRacesStore.LookupEntry(baseRace);
                    if (!displayEntry)
                        displayEntry = sChrRacesStore.LookupEntry(RACE_HUMAN);
                }

                PlayerInfo* info = new PlayerInfo();
                info->mapId = mapId;
                info->areaId = areaId;
                info->positionX = positionX;
                info->positionY = positionY;
                info->positionZ = positionZ;
                info->orientation = orientation;
                info->displayId_m = displayEntry ? displayEntry->MaleDisplayId : 0;
                info->displayId_f = displayEntry ? displayEntry->FemaleDisplayId : 0;""")

    # проверка, что других разыменований rEntry в этом блоке не осталось
    text, _, _ = read(p.path(*rel.split("/")))
    idx = text.find("if (!rEntry && !Player::IsCustomRace(uint8(current_race)))")
    if idx > 0:
        window = text[idx: idx + 2500]
        if "rEntry->" in window:
            raise SystemExit("!! В LoadPlayerCreateInfo после проверки осталось rEntry-> : нужен доп. guard")

    p.sub(rel, """            ChrRacesEntry const* raceEntry = sChrRacesStore.LookupEntry(raceID);
            if (!raceEntry)
            {
                LF_LOG_ERROR("sql.sql", "Race %u defined in `race_unlock_requirement` does not exists, skipped.", raceID);
                continue;
            }""",
          """            ChrRacesEntry const* raceEntry = sChrRacesStore.LookupEntry(raceID);
            // [LEGIONFORGE CUSTOM-RACES] без записи в _raceUnlockRequirementStore
            // HandleCharCreateOpcode отвечает CHAR_CREATE_FAILED ("tried to create
            // character with unavailable race"), поэтому кастомные расы обязаны
            // проходить эту проверку даже без строки в ChrRaces.db2.
            if (!raceEntry && !Player::IsCustomRace(raceID))
            {
                LF_LOG_ERROR("sql.sql", "Race %u defined in `race_unlock_requirement` does not exists, skipped.", raceID);
                continue;
            }""")

    # racemask-и: uint32 -> uint64 (иначе биты рас 33..44 теряются)
    n = p.regex(rel, r"uint32 raceMask = fields\[0\]\.GetUInt32\(\);",
                "uint64 raceMask = fields[0].GetUInt64();  // " + MARK + " 64 бита для рас 33..44")
    print("    (расширено raceMask: %d)" % n)
    p.regex(rel, r'Wrong race mask %u in `(\w+)` table, ignoring\.", raceMask\)',
            r'Wrong race mask " UI64FMTD " in `\1` table, ignoring.", raceMask)')
    p.regex(rel, r"\(1 << \(raceIndex - 1\)\) & raceMask",
            "(UI64LIT(1) << (raceIndex - 1)) & raceMask")


def patch_character_handler(p):
    rel = "core/src/server/game/Handlers/CharacterHandler.cpp"

    p.sub(rel, """    ChrRacesEntry const* raceEntry = sChrRacesStore.LookupEntry(charCreate.CreateInfo->Race);
    if (!raceEntry)
    {
        LF_LOG_ERROR("network", "Race (%u) not found in DBC while creating new char for account (ID: %u): wrong DBC files or cheater?", charCreate.CreateInfo->Race, GetAccountId());
        SendCharCreate(CHAR_CREATE_FAILED);
        return;
    }""",
          """    ChrRacesEntry const* raceEntry = sChrRacesStore.LookupEntry(charCreate.CreateInfo->Race);
    // [LEGIONFORGE CUSTOM-RACES] кастомный клиент предлагает расы 31..44, которых
    // нет в серверном ChrRaces.db2. Расы из реестра CustomRaces.Definitions
    // считаются валидными: иначе персонаж невозможно создать, хотя окно выбора
    // расы клиент уже показал.
    if (!raceEntry && !Player::IsCustomRace(charCreate.CreateInfo->Race))
    {
        LF_LOG_ERROR("network", "Race (%u) not found in DBC while creating new char for account (ID: %u): wrong DBC files or cheater?", charCreate.CreateInfo->Race, GetAccountId());
        SendCharCreate(CHAR_CREATE_FAILED);
        return;
    }""")

    p.regex(rel, r"\(1 << \(charCreate\.CreateInfo->Race - 1\)\) & raceMaskDisabled",
            "(RaceMaskForRace(charCreate.CreateInfo->Race) & raceMaskDisabled)")

    # Маска 64-битная: при смене фракции выбираем расу из полного диапазона.
    p.regex(rel, r"uint64 newRaceMask = \(newTeamId == TEAM_ALLIANCE\) \? RACEMASK_ALLIANCE : RACEMASK_HORDE;",
            "uint64 newRaceMask = (newTeamId == TEAM_ALLIANCE) ? uint64(RACEMASK_ALLIANCE) : uint64(RACEMASK_HORDE);  // " + MARK,
            required=False)


def patch_masks_misc(p):
    rel = "core/src/server/game/Achievements/CriteriaHandler.cpp"
    p.regex(rel, r"\(1 << \(ClassRace\.Race-1\)\) & RACEMASK_ALL_PLAYABLE",
            "RaceMaskForRace(ClassRace.Race) & RACEMASK_ALL_PLAYABLE")

    rel = "core/src/server/game/Conditions/ConditionMgr.cpp"
    p.regex(rel, r"cond->ConditionValue1 & ~RACEMASK_ALL_PLAYABLE\)",
            "uint32(cond->ConditionValue1 & ~RACEMASK_ALL_PLAYABLE))")


def patch_vmap_extractor(p):
    rel = "core/src/tools/vmap4_extractor/wdtfile.cpp"
    p.sub(rel, """WDTFile::WDTFile(char const* storagePath, std::string mapName, bool cache)
    : _file(CascStorage, storagePath), _mapName(std::move(mapName))""",
          """WDTFile::WDTFile(char const* storagePath, std::string mapName, bool cache)
    // [LEGIONFORGE PATCH 2026-10] warnNoExist = false: у dev/test-карт
    // (World\\Maps\\test\\test.wdt и т.п.) файла в CASC нет, и это НЕ ошибка.
    // Раньше сообщение шло в stderr, а PowerShell 5.1 при
    // $ErrorActionPreference = 'Stop' превращал его в NativeCommandError и
    // обрывал extract_delta.ps1 на шаге 2/4 (vmaps).
    : _file(CascStorage, storagePath, false), _mapName(std::move(mapName))""")

    p.sub(rel, """bool WDTFile::init(uint32 mapId)
{
    if (_file.isEof())
        return false;""",
          """bool WDTFile::init(uint32 mapId)
{
    if (_file.isEof())
    {
        // Диагностика - в stdout (не в stderr!), чтобы не ломать вызывающие
        // PowerShell-скрипты.
        printf("Skipping map '%s': no WDT in the client storage (dev/test map)\\n", _mapName.c_str());
        return false;
    }""")

    rel = "core/src/tools/vmap4_extractor/vmapexport.cpp"
    p.sub(rel, """    std::unordered_map<uint32, WDTFile> wdts;
    auto getWDT = [&wdts](uint32 mapId) -> WDTFile*""",
          """    std::unordered_map<uint32, WDTFile> wdts;
    uint32 skippedNoWdt = 0;
    auto getWDT = [&wdts, &skippedNoWdt](uint32 mapId) -> WDTFile*""")

    p.sub(rel, """            if (!itr->second.init(mapId))
            {
                wdts.erase(itr);
                return nullptr;
            }""",
          """            if (!itr->second.init(mapId))
            {
                wdts.erase(itr);
                ++skippedNoWdt;
                return nullptr;
            }""")

    p.sub(rel, """            printf("]\\n");
        }
    }
}

bool processArgv(int argc, char ** argv, const char *versionString)""",
          """            printf("]\\n");
        }
    }

    if (skippedNoWdt)
        printf("\\n[INFO] Skipped %u map(s) without WDT in the client storage.\\n"
               "       These are dev/test maps (e.g. 'test'); they have no geometry\\n"
               "       to extract, so this is NOT an error and vmaps stay consistent.\\n", skippedNoWdt);
}

bool processArgv(int argc, char ** argv, const char *versionString)""")


SSL_CONTEXT_CPP = r'''/*
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

#include "SslContext.h"
#include "Log.h"
#include "Config.h"

#include <openssl/err.h>
#include <openssl/evp.h>
#include <openssl/pem.h>
#include <openssl/x509.h>

#include <cstdio>
#include <fstream>
#include <string>
#include <vector>

#ifdef _WIN32
#include <Windows.h>
#else
#include <limits.h>
#include <unistd.h>
#endif

// [LEGIONFORGE PATCH 2026-10] -------------------------------------------------
// bnetserver падал сразу после шапки с единственной строкой
//   "Failed to initialize SSL context"
// Причины, которые встречались в поле:
//   1. CertificatesFile/PrivateKeyFile заданы относительными путями
//      ("./bnetserver.cert.pem"), а bnetserver запускается с другим рабочим
//      каталогом (ярлык, планировщик, NSSM, start /D ...) -> файл не находится.
//   2. .pem вообще не скопированы в каталог сборки (build_server.ps1 копировал
//      только *.exe/*.dll).
//   3. Сертификат и ключ от разных пар (обновлён один из файлов).
//   4. Подробная причина логировалась в категорию "server.ssl", которой нет в
//      bnetserver.conf -> в консоль ничего не выводилось.
// Теперь: пути разрешаются по нескольким каталогам, пара cert/key проверяется,
// при отсутствии/рассинхроне генерируется самоподписанная пара (OpenSSL 3.x,
// SHA-256, RSA-2048, 10 лет), а все ошибки OpenSSL печатаются явно.
// -----------------------------------------------------------------------------

namespace
{
    std::string GetExecutableDir()
    {
#ifdef _WIN32
        char path[MAX_PATH] = { };
        if (::GetModuleFileNameA(nullptr, path, MAX_PATH) != 0)
        {
            std::string full(path);
            size_t pos = full.find_last_of("\\/");
            if (pos != std::string::npos)
                return full.substr(0, pos);
        }
#else
        char path[PATH_MAX] = { };
        ssize_t len = ::readlink("/proc/self/exe", path, sizeof(path) - 1);
        if (len > 0)
        {
            path[len] = '\0';
            std::string full(path);
            size_t pos = full.find_last_of('/');
            if (pos != std::string::npos)
                return full.substr(0, pos);
        }
#endif
        return std::string();
    }

    bool FileExists(std::string const& path)
    {
        if (path.empty())
            return false;

        std::ifstream file(path.c_str(), std::ios::binary);
        return file.good();
    }

    std::string JoinPath(std::string const& dir, std::string const& file)
    {
        if (dir.empty())
            return file;

        char const last = dir[dir.size() - 1];
        if (last == '/' || last == '\\')
            return dir + file;

#ifdef _WIN32
        return dir + "\\" + file;
#else
        return dir + "/" + file;
#endif
    }

    std::string BaseName(std::string const& path)
    {
        size_t pos = path.find_last_of("\\/");
        return pos == std::string::npos ? path : path.substr(pos + 1);
    }

    // Пробует найти pem-файл: как задано в конфиге (относительно CWD), рядом с
    // exe, в родительском каталоге и в <root>/server.
    bool ResolvePemPath(std::string& path)
    {
        if (FileExists(path))
            return true;

        std::string const fileName = BaseName(path);
        std::string const exeDir = GetExecutableDir();

        std::vector<std::string> candidates;
        candidates.push_back(fileName);
        if (!exeDir.empty())
        {
            candidates.push_back(JoinPath(exeDir, fileName));
            candidates.push_back(JoinPath(exeDir, path));
            candidates.push_back(JoinPath(JoinPath(exeDir, ".."), fileName));
            candidates.push_back(JoinPath(JoinPath(exeDir, "../server"), fileName));
            candidates.push_back(JoinPath(JoinPath(exeDir, "..\\server"), fileName));
        }

        for (std::string const& candidate : candidates)
        {
            if (FileExists(candidate))
            {
                if (candidate != path)
                    LF_LOG_WARN("server.ssl", "'%s' not found at the configured path, using '%s' instead", path.c_str(), candidate.c_str());

                path = candidate;
                return true;
            }
        }

        return false;
    }

    std::string GetOpenSSLErrors()
    {
        std::string result;
        char buffer[256];
        unsigned long code;
        while ((code = ERR_get_error()) != 0)
        {
            ERR_error_string_n(code, buffer, sizeof(buffer));
            if (!result.empty())
                result += "; ";
            result += buffer;
        }

        return result;
    }

    bool CheckPairMatches(std::string const& certPath, std::string const& keyPath)
    {
        FILE* certFp = fopen(certPath.c_str(), "rb");
        FILE* keyFp = fopen(keyPath.c_str(), "rb");
        if (!certFp || !keyFp)
        {
            if (certFp) fclose(certFp);
            if (keyFp) fclose(keyFp);
            return false;
        }

        X509* cert = PEM_read_X509(certFp, nullptr, nullptr, nullptr);
        EVP_PKEY* pkey = PEM_read_PrivateKey(keyFp, nullptr, nullptr, nullptr);
        fclose(certFp);
        fclose(keyFp);

        if (!cert || !pkey)
        {
            std::string errors = GetOpenSSLErrors();
            LF_LOG_ERROR("server.ssl", "Unable to parse PEM pair (cert='%s', key='%s')%s%s",
                certPath.c_str(), keyPath.c_str(), errors.empty() ? "" : ": ", errors.c_str());
            X509_free(cert);
            EVP_PKEY_free(pkey);
            return false;
        }

        bool const matches = X509_check_private_key(cert, pkey) == 1;
        if (!matches)
            LF_LOG_ERROR("server.ssl", "Certificate '%s' does NOT match private key '%s' - they are from different key pairs",
                certPath.c_str(), keyPath.c_str());

        X509_free(cert);
        EVP_PKEY_free(pkey);
        return matches;
    }

    // Самоподписанная пара: SHA-256 + RSA-2048 (OpenSSL 3.x принимает её без
    // legacy-провайдера), срок 10 лет, CN/SAN не критичны - клиент 7.3.5 не
    // проверяет цепочку доверия для battle.net.
    bool GenerateSelfSignedPair(std::string const& certPath, std::string const& keyPath)
    {
        EVP_PKEY* pkey = nullptr;
#if OPENSSL_VERSION_NUMBER >= 0x30000000L
        pkey = EVP_RSA_gen(2048);
#else
        RSA* rsa = RSA_generate_key(2048, RSA_F4, nullptr, nullptr);
        if (rsa)
        {
            pkey = EVP_PKEY_new();
            if (pkey && EVP_PKEY_assign_RSA(pkey, rsa) != 1)
            {
                EVP_PKEY_free(pkey);
                pkey = nullptr;
                RSA_free(rsa);
            }
        }
#endif
        if (!pkey)
        {
            std::string errors = GetOpenSSLErrors();
            LF_LOG_ERROR("server.ssl", "Failed to generate an RSA key%s%s", errors.empty() ? "" : ": ", errors.c_str());
            return false;
        }

        X509* x509 = X509_new();
        if (!x509)
        {
            EVP_PKEY_free(pkey);
            return false;
        }

        bool ok = true;
        X509_set_version(x509, 2);
        ASN1_INTEGER_set(X509_get_serialNumber(x509), 1);
        X509_gmtime_adj(X509_getm_notBefore(x509), -60 * 60 * 24);
        X509_gmtime_adj(X509_getm_notAfter(x509), 60 * 60 * 24 * 3650);
        ok = ok && X509_set_pubkey(x509, pkey) == 1;

        X509_NAME* name = X509_get_subject_name(x509);
        ok = ok && X509_NAME_add_entry_by_txt(name, "C", MBSTRING_ASC, reinterpret_cast<unsigned char const*>("RU"), -1, -1, 0) == 1;
        ok = ok && X509_NAME_add_entry_by_txt(name, "O", MBSTRING_ASC, reinterpret_cast<unsigned char const*>("LegionForge"), -1, -1, 0) == 1;
        ok = ok && X509_NAME_add_entry_by_txt(name, "CN", MBSTRING_ASC, reinterpret_cast<unsigned char const*>("LegionForge Battle.net Server"), -1, -1, 0) == 1;
        ok = ok && X509_set_issuer_name(x509, name) == 1;
        ok = ok && X509_sign(x509, pkey, EVP_sha256()) != 0;

        if (ok)
        {
            FILE* certFp = fopen(certPath.c_str(), "wb");
            if (certFp)
            {
                ok = PEM_write_X509(certFp, x509) == 1;
                fclose(certFp);
            }
            else
                ok = false;
        }

        if (ok)
        {
            FILE* keyFp = fopen(keyPath.c_str(), "wb");
            if (keyFp)
            {
                ok = PEM_write_PrivateKey(keyFp, pkey, nullptr, nullptr, 0, nullptr, nullptr) == 1;
                fclose(keyFp);
            }
            else
                ok = false;
        }

        if (!ok)
        {
            std::string errors = GetOpenSSLErrors();
            LF_LOG_ERROR("server.ssl", "Failed to write the self-signed PEM pair (cert='%s', key='%s')%s%s",
                certPath.c_str(), keyPath.c_str(), errors.empty() ? "" : ": ", errors.c_str());
        }

        X509_free(x509);
        EVP_PKEY_free(pkey);
        return ok;
    }

    std::string GetWritableDir(std::string const& configuredPath)
    {
        std::string exeDir = GetExecutableDir();
        if (!exeDir.empty())
            return exeDir;

        size_t pos = configuredPath.find_last_of("\\/");
        if (pos != std::string::npos && !configuredPath.substr(0, pos).empty())
            return configuredPath.substr(0, pos);

        return ".";
    }
}

bool Battlenet::SslContext::Initialize()
{
    boost::system::error_code err;

    std::string certificateChainFile = sConfigMgr->GetStringDefault("CertificatesFile", "./bnetserver.cert.pem");
    std::string privateKeyFile = sConfigMgr->GetStringDefault("PrivateKeyFile", "./bnetserver.key.pem");
    bool const autoGenerate = sConfigMgr->GetBoolDefault("SSLCertAutoGenerate", true);

    bool const certFound = ResolvePemPath(certificateChainFile);
    bool const keyFound = ResolvePemPath(privateKeyFile);
    bool pairOk = certFound && keyFound && CheckPairMatches(certificateChainFile, privateKeyFile);

    if (!pairOk)
    {
        if (!certFound)
            LF_LOG_ERROR("server.ssl", "Certificate file not found: '%s' (looked in the current directory, next to bnetserver.exe and in ./server)",
                sConfigMgr->GetStringDefault("CertificatesFile", "./bnetserver.cert.pem").c_str());
        if (!keyFound)
            LF_LOG_ERROR("server.ssl", "Private key file not found: '%s'",
                sConfigMgr->GetStringDefault("PrivateKeyFile", "./bnetserver.key.pem").c_str());

        if (!autoGenerate)
        {
            LF_LOG_ERROR("server.ssl", "SSLCertAutoGenerate = 0: refusing to start. Copy a valid bnetserver.cert.pem/bnetserver.key.pem pair next to bnetserver.exe or run tools\\ensure_ssl_cert.ps1");
            return false;
        }

        std::string const dir = GetWritableDir(certificateChainFile);
        certificateChainFile = JoinPath(dir, "bnetserver.cert.pem");
        privateKeyFile = JoinPath(dir, "bnetserver.key.pem");

        LF_LOG_WARN("server.ssl", "Generating a self-signed certificate: '%s' + '%s'", certificateChainFile.c_str(), privateKeyFile.c_str());
        if (!GenerateSelfSignedPair(certificateChainFile, privateKeyFile))
            return false;

        LF_LOG_WARN("server.ssl", "Self-signed pair generated. It is fine for a private realm; replace it with your own pair if you need a trusted certificate.");
    }

#define LOAD_CHECK(fn) do { fn; \
    if (err) \
    { \
        std::string sslErrors = GetOpenSSLErrors(); \
        LF_LOG_ERROR("server.ssl", #fn " failed: %s%s%s", err.message().c_str(), sslErrors.empty() ? "" : " | OpenSSL: ", sslErrors.c_str()); \
        return false; \
    } } while (0)

    LOAD_CHECK(instance().set_options(boost::asio::ssl::context::no_sslv2, err));
    LOAD_CHECK(instance().set_options(boost::asio::ssl::context::no_sslv3, err));
    LOAD_CHECK(instance().use_certificate_chain_file(certificateChainFile, err));
    LOAD_CHECK(instance().use_private_key_file(privateKeyFile, boost::asio::ssl::context::pem, err));

#undef LOAD_CHECK

    LF_LOG_INFO("server.ssl", "SSL context initialized (cert='%s', key='%s', auto-generated=%s)",
        certificateChainFile.c_str(), privateKeyFile.c_str(), pairOk ? "no" : "yes");

    return true;
}

boost::asio::ssl::context& Battlenet::SslContext::instance()
{
    static boost::asio::ssl::context context(boost::asio::ssl::context::sslv23);
    return context;
}
'''


def patch_ssl(p):
    p.write_file("core/src/server/bnetserver/Server/SslContext.cpp", SSL_CONTEXT_CPP)

    rel = "core/src/server/bnetserver/Main.cpp"
    p.sub(rel, '        LF_LOG_ERROR("server.bnetserver", "Failed to initialize SSL context");',
          '        LF_LOG_ERROR("server.bnetserver", "Failed to initialize SSL context");\n'
          '        // [LEGIONFORGE PATCH 2026-10] точная причина пишется в категорию\n'
          '        // "server.ssl"; если её не видно - в bnetserver.conf нет строки\n'
          '        // Logger.server.ssl (добавлена в bnetserver.conf.dist).\n'
          '        LF_LOG_ERROR("server.bnetserver", "Hint: check CertificatesFile/PrivateKeyFile, run tools\\\\ensure_ssl_cert.ps1, and add \\"Logger.server.ssl=3,Console Bnet\\" to bnetserver.conf to see the exact OpenSSL error.");')


def main():
    if len(sys.argv) < 2:
        raise SystemExit("Использование: patch_core.py <корень репозитория>")
    root = os.path.abspath(sys.argv[1])
    if not os.path.isdir(os.path.join(root, "core")):
        raise SystemExit("Это не похоже на корень LegionForge: нет каталога core/")

    print("== Патчу ядро LegionForge: %s" % root)
    p = Patch(root)

    print("\n[1/6] SharedDefines.h - MAX_RACES=45, 64-битные маски рас")
    patch_shared_defines(p)

    print("\n[2/6] Player.h/Player.cpp - реестр кастомных рас 31..44")
    patch_player(p)

    print("\n[3/6] ObjectMgr.cpp - playercreateinfo / race_unlock_requirement / racemask")
    patch_objectmgr(p)

    print("\n[4/6] CharacterHandler.cpp + Criteria/Condition - 64-битные проверки")
    patch_character_handler(p)
    patch_masks_misc(p)

    print("\n[5/6] vmap4extractor - пропуск карт без WDT без stderr")
    patch_vmap_extractor(p)

    print("\n[6/6] bnetserver SSL context - автопоиск/генерация пары и диагностика")
    patch_ssl(p)

    print("\nГотово. Применено правок: %d, пропущено (уже было): %d" % (p.applied, p.skipped))


if __name__ == "__main__":
    main()
