/*
 * Door for scenario maps that have a landing and no teleport spell of their own.
 * A listed NPC casts 84338 (Teleport Player) when its quest is accepted.
 * The spell saves where the player is standing, then sends them to that NPC's landing.
 * Casting 84338 again while standing on that landing sends them back.
 */

#include "Creature.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellScript.h"

#include <unordered_map>

enum ScenarioDoorSpell
{
    SPELL_TELEPORT_PLAYER = 84338
};

struct ScenarioLanding
{
    uint32 QuestId;
    uint32 MapId;
    float X;
    float Y;
    float Z;
    float O;
};

struct ScenarioReturn
{
    uint32 FromMap;
    float FromX;
    float FromY;
    float FromZ;
    float FromO;
    uint32 DestMap;
    bool GaveSpell;
};

static std::unordered_map<uint32, ScenarioLanding> s_landingsByNpc;

// [LEGIONFORGE FIX 2026-10-13] КРАШ из ОШИБКИ.txt:
//   "[1146] Table 'world.scenario_npc_landing' doesn't exist" ->
//   MySQLConnection::_HandleMySQLErrno -> std::abort() сразу после "ready...".
// SQL sql/stitch/010_scenario_npc_landing.sql не был подключён к установщику.
// Теперь (1) установщик его применяет, (2) ядро само создаёт пустые таблицы
// (CREATE TABLE IF NOT EXISTS идемпотентен и не трогает данные) и
// (3) перед SELECT проверяет наличие через information_schema - при любой
// проблеме функция "двери сценария" отключается с ошибкой в логе, а не abort().
static bool s_scenarioDoorEnabled = false;
static bool s_scenarioReturnEnabled = false;

static bool TableExists(char const* schemaFn, bool world, char const* table)
{
    std::string sql = std::string("SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = ")
        + schemaFn + " AND TABLE_NAME = '" + table + "'";
    QueryResult r = world ? WorldDatabase.Query(sql.c_str()) : CharacterDatabase.Query(sql.c_str());
    return r != nullptr;
}

static void EnsureScenarioDoorSchema()
{
    WorldDatabase.DirectExecute(
        "CREATE TABLE IF NOT EXISTS `scenario_map_landing` ("
        "`map_id` int unsigned NOT NULL, `pos_x` float NOT NULL, `pos_y` float NOT NULL, "
        "`pos_z` float NOT NULL, `pos_o` float NOT NULL DEFAULT 0, PRIMARY KEY (`map_id`)"
        ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    WorldDatabase.DirectExecute(
        "CREATE TABLE IF NOT EXISTS `scenario_npc_landing` ("
        "`npc_entry` int unsigned NOT NULL, `quest_id` int unsigned NOT NULL, "
        "`map_id` int unsigned NOT NULL, PRIMARY KEY (`npc_entry`, `quest_id`)"
        ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    CharacterDatabase.DirectExecute(
        "CREATE TABLE IF NOT EXISTS `character_scenario_return` ("
        "`guid` bigint unsigned NOT NULL, `from_map` int unsigned NOT NULL, "
        "`from_x` float NOT NULL, `from_y` float NOT NULL, `from_z` float NOT NULL, "
        "`from_o` float NOT NULL, `dest_map` int unsigned NOT NULL, "
        "`gave_spell` tinyint unsigned NOT NULL DEFAULT 0, PRIMARY KEY (`guid`)"
        ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    s_scenarioDoorEnabled = TableExists("DATABASE()", true, "scenario_npc_landing")
        && TableExists("DATABASE()", true, "scenario_map_landing");
    s_scenarioReturnEnabled = TableExists("DATABASE()", false, "character_scenario_return");

    if (!s_scenarioDoorEnabled)
        LF_LOG_ERROR("sql.sql", "ScenarioDoor: tables world.scenario_npc_landing/scenario_map_landing are missing and could not be created "
            "(no CREATE privilege?). Scenario doors are DISABLED. Apply sql/stitch/010_scenario_npc_landing.sql to the world DB.");
    if (!s_scenarioReturnEnabled)
        LF_LOG_ERROR("sql.sql", "ScenarioDoor: table characters.character_scenario_return is missing and could not be created. "
            "Scenario doors are DISABLED. Apply sql/stitch/010_scenario_return_characters.sql to the characters DB.");
    if (!s_scenarioReturnEnabled)
        s_scenarioDoorEnabled = false;
}

static void LoadScenarioNpcLandings()
{
    s_landingsByNpc.clear();

    EnsureScenarioDoorSchema();
    if (!s_scenarioDoorEnabled)
        return;

    QueryResult result = WorldDatabase.Query(
        "SELECT n.npc_entry, n.quest_id, n.map_id, m.pos_x, m.pos_y, m.pos_z, m.pos_o "
        "FROM scenario_npc_landing n "
        "JOIN scenario_map_landing m ON m.map_id = n.map_id");
    if (!result)
        return;

    do
    {
        Field* fields = result->Fetch();
        ScenarioLanding landing;
        uint32 npc = fields[0].GetUInt32();
        landing.QuestId = fields[1].GetUInt32();
        landing.MapId = fields[2].GetUInt32();
        landing.X = fields[3].GetFloat();
        landing.Y = fields[4].GetFloat();
        landing.Z = fields[5].GetFloat();
        landing.O = fields[6].GetFloat();
        s_landingsByNpc[npc] = landing;
    } while (result->NextRow());

    LF_LOG_INFO("server.loading", ">> ScenarioDoor: loaded %u scenario NPC landings", uint32(s_landingsByNpc.size()));
}

static bool LoadScenarioReturn(uint64 guid, ScenarioReturn& out)
{
    if (!s_scenarioReturnEnabled)
        return false;

    QueryResult result = CharacterDatabase.PQuery(
        "SELECT from_map, from_x, from_y, from_z, from_o, dest_map, gave_spell "
        "FROM character_scenario_return WHERE guid = " UI64FMTD, guid);
    if (!result)
        return false;

    Field* fields = result->Fetch();
    out.FromMap = fields[0].GetUInt32();
    out.FromX = fields[1].GetFloat();
    out.FromY = fields[2].GetFloat();
    out.FromZ = fields[3].GetFloat();
    out.FromO = fields[4].GetFloat();
    out.DestMap = fields[5].GetUInt32();
    out.GaveSpell = fields[6].GetUInt8() != 0;
    return true;
}

static void SaveScenarioReturn(uint64 guid, Player* player, uint32 destMap, bool gaveSpell)
{
    if (!s_scenarioReturnEnabled)
        return;
    CharacterDatabase.PExecute(
        "REPLACE INTO character_scenario_return "
        "(guid, from_map, from_x, from_y, from_z, from_o, dest_map, gave_spell) "
        "VALUES (" UI64FMTD ", %u, %f, %f, %f, %f, %u, %u)",
        guid, player->GetMapId(), player->GetPositionX(), player->GetPositionY(),
        player->GetPositionZ(), player->GetOrientation(), destMap, gaveSpell ? 1u : 0u);
}

static void ClearScenarioReturn(uint64 guid, Player* player, bool gaveSpell)
{
    if (gaveSpell)
        player->RemoveSpell(SPELL_TELEPORT_PLAYER);
    if (!s_scenarioReturnEnabled)
        return;
    CharacterDatabase.PExecute(
        "DELETE FROM character_scenario_return WHERE guid = " UI64FMTD, guid);
}

class ScenarioDoorWorldScript : public WorldScript
{
public:
    ScenarioDoorWorldScript() : WorldScript("ScenarioDoorWorldScript") { }

    void OnStartup() override
    {
        LoadScenarioNpcLandings();
    }
};

class npc_scenario_door : public CreatureScript
{
public:
    npc_scenario_door() : CreatureScript("npc_scenario_door") { }

    bool OnQuestAccept(Player* player, Creature* creature, Quest const* quest) override
    {
        auto itr = s_landingsByNpc.find(creature->GetEntry());
        if (itr == s_landingsByNpc.end() || itr->second.QuestId != quest->GetQuestId())
            return false;

        creature->CastSpell(player, SPELL_TELEPORT_PLAYER, true);
        return false;
    }
};

class spell_scenario_npc_landing : public SpellScriptLoader
{
public:
    spell_scenario_npc_landing() : SpellScriptLoader("spell_scenario_npc_landing") { }

    class spell_scenario_npc_landing_SpellScript : public SpellScript
    {
        PrepareSpellScript(spell_scenario_npc_landing_SpellScript);

        bool _done = false;

        void HandleTeleport(SpellEffIndex effIndex)
        {
            if (_done)
                return;

            Player* player = nullptr;
            if (Unit* expl = GetExplTargetUnit())
                player = expl->ToPlayer();
            if (!player && GetCaster())
                player = GetCaster()->ToPlayer();
            if (!player && GetHitUnit())
                player = GetHitUnit()->ToPlayer();
            if (!player)
                return;

            uint64 guid = player->GetGUID().GetCounter();
            ScenarioReturn back;
            if (LoadScenarioReturn(guid, back) && player->GetMapId() == back.DestMap)
            {
                _done = true;
                PreventHitDefaultEffect(effIndex);
                bool gaveSpell = back.GaveSpell;
                uint32 fromMap = back.FromMap;
                float x = back.FromX;
                float y = back.FromY;
                float z = back.FromZ;
                float o = back.FromO;
                ClearScenarioReturn(guid, player, gaveSpell);
                player->TeleportTo(fromMap, x, y, z, o);
                return;
            }

            Creature* npc = GetCaster() ? GetCaster()->ToCreature() : nullptr;
            if (!npc)
                return;

            auto itr = s_landingsByNpc.find(npc->GetEntry());
            if (itr == s_landingsByNpc.end())
                return;

            _done = true;
            PreventHitDefaultEffect(effIndex);
            bool gaveSpell = !player->HasSpell(SPELL_TELEPORT_PLAYER);
            SaveScenarioReturn(guid, player, itr->second.MapId, gaveSpell);
            if (!player->TeleportTo(itr->second.MapId, itr->second.X, itr->second.Y, itr->second.Z, itr->second.O))
            {
                ClearScenarioReturn(guid, player, false);
                return;
            }
            if (gaveSpell)
                player->LearnSpell(SPELL_TELEPORT_PLAYER, false);
        }

        void Register() override
        {
            OnEffectHitTarget += SpellEffectFn(spell_scenario_npc_landing_SpellScript::HandleTeleport, EFFECT_0, SPELL_EFFECT_TELEPORT_UNITS);
        }
    };

    SpellScript* GetSpellScript() const override
    {
        return new spell_scenario_npc_landing_SpellScript();
    }
};

class player_scenario_door : public PlayerScript
{
public:
    player_scenario_door() : PlayerScript("player_scenario_door") { }

    void OnLogin(Player* player, bool /*firstLogin*/) override
    {
        ScenarioReturn back;
        if (!LoadScenarioReturn(player->GetGUID().GetCounter(), back))
            return;
        if (player->GetMapId() == back.DestMap && back.GaveSpell && !player->HasSpell(SPELL_TELEPORT_PLAYER))
            player->LearnSpell(SPELL_TELEPORT_PLAYER, false);
    }

    void OnMapChanged(Player* player) override
    {
        uint64 guid = player->GetGUID().GetCounter();
        ScenarioReturn back;
        if (!LoadScenarioReturn(guid, back))
            return;
        if (player->GetMapId() == back.DestMap)
            return;
        ClearScenarioReturn(guid, player, back.GaveSpell);
    }
};

void AddSC_scenario_door()
{
    new ScenarioDoorWorldScript();
    new npc_scenario_door();
    new spell_scenario_npc_landing();
    new player_scenario_door();
}
