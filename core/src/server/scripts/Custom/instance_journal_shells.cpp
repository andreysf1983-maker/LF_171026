/*
 * Instance scripts for dungeons and raids whose database script name had no
 * C++ file. Each shell sets the Adventure Guide boss count so the map has an
 * InstanceScript. Boss spells, doors, and creature spawns are not in these
 * shells. Maps that already have a script file are not listed here.
 */

#include "InstanceScript.h"
#include "ScriptMgr.h"

struct JournalShell
{
    char const* ScriptName;
    uint32 MapId;
    uint32 Bosses;
};

static JournalShell const JournalShells[] =
{
    { "instance_scarlet_halls", 1001, 3 },
    { "instance_scarlet_monastery_mop", 1004, 3 },
    { "instance_scholomance_mop", 1007, 5 },
    { "instance_terrace_of_endless_spring", 996, 4 },
    { "instance_heart_of_fear", 1009, 6 },
    { "instance_mogu_shan_vault", 1008, 6 },
    { "instance_throne_of_thunder", 1098, 13 },
    { "instance_siege_of_orgrimmar", 1136, 14 },
    { "instance_auchindoun", 1182, 4 },
    { "instance_grimrail_depot", 1208, 3 },
    { "instance_iron_docks", 1195, 4 },
    { "instance_skyreach", 1209, 4 },
    { "instance_upper_blackrock_spire", 1358, 5 },
    { "instance_highmaul", 1228, 7 },
    { "instance_blackrock_foundry", 1205, 10 },
    { "instance_hellfire_citadel", 1448, 13 },
    { "instance_the_arcway", 1516, 5 },
    { "instance_the_nighthold", 1530, 10 },
    { "instance_trial_of_valor", 1648, 3 },
    { "instance_return_to_karazhan", 1651, 10 },
    { "instance_cathedral_of_eternal_night", 1677, 4 },
    { "instance_antorus_the_burning_throne", 1712, 11 },
    { "instance_seat_of_triumvirate", 1753, 4 },
};

class JournalInstanceScript : public InstanceMapScript
{
    public:
        JournalInstanceScript(char const* name, uint32 mapId, uint32 bosses)
            : InstanceMapScript(name, mapId), _bosses(bosses) { }

        struct AI : public InstanceScript
        {
            AI(Map* map, uint32 bosses) : InstanceScript(map), _bosses(bosses) { }

            void Initialize() override
            {
                SetBossNumber(_bosses);
            }

        private:
            uint32 _bosses;
        };

        InstanceScript* GetInstanceScript(InstanceMap* map) const override
        {
            return new AI(map, _bosses);
        }

    private:
        uint32 _bosses;
};

void AddSC_instance_journal_shells()
{
    for (JournalShell const& shell : JournalShells)
        new JournalInstanceScript(shell.ScriptName, shell.MapId, shell.Bosses);
}
