/*
 * Pattern-based quest fixes (P05 item-use, data-driven from legion_quest_item_target).
 */

#include "Creature.h"
#include "DatabaseEnv.h"
#include "MotionMaster.h"
#include "PhasingHandler.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "SpellInfo.h"
#include <unordered_map>
#include <vector>

struct QuestItemTargetEntry
{
    uint32 CreatureEntry;
    uint32 SpellId;
    uint32 QuestId;
    uint32 ItemId;
    uint32 CreditEntry;
    uint8  FollowPlayer;
    uint32 DespawnMs;
};

static std::vector<QuestItemTargetEntry> s_questItemTargets;
static std::unordered_map<uint32, std::vector<size_t>> s_targetsByCreature;

static void LoadQuestItemTargets()
{
    s_questItemTargets.clear();
    s_targetsByCreature.clear();

    QueryResult result = WorldDatabase.Query(
        "SELECT creature_entry, IFNULL(spell_id,0), quest_id, IFNULL(item_id,0), credit_entry, "
        "IFNULL(follow_player,0), IFNULL(despawn_ms,0) FROM legion_quest_item_target");
    if (!result)
        return;

    do
    {
        Field* fields = result->Fetch();
        QuestItemTargetEntry e;
        e.CreatureEntry = fields[0].GetUInt32();
        e.SpellId       = fields[1].GetUInt32();
        e.QuestId       = fields[2].GetUInt32();
        e.ItemId        = fields[3].GetUInt32();
        e.CreditEntry   = fields[4].GetUInt32();
        e.FollowPlayer  = fields[5].GetUInt8();
        e.DespawnMs     = fields[6].GetUInt32();

        size_t idx = s_questItemTargets.size();
        s_questItemTargets.push_back(e);
        s_targetsByCreature[e.CreatureEntry].push_back(idx);
    } while (result->NextRow());
}

class QuestItemTargetWorldScript : public WorldScript
{
public:
    QuestItemTargetWorldScript() : WorldScript("QuestItemTargetWorldScript") { }

    void OnStartup() override
    {
        LoadQuestItemTargets();
    }
};

class npc_quest_item_target : public CreatureScript
{
public:
    npc_quest_item_target() : CreatureScript("npc_quest_item_target") { }

    struct npc_quest_item_targetAI : public ScriptedAI
    {
        npc_quest_item_targetAI(Creature* creature) : ScriptedAI(creature), _used(false) { }

        bool _used;

        void SpellHit(Unit* caster, SpellInfo const* spell) override
        {
            if (_used || !spell || !caster)
                return;

            Player* player = caster->ToPlayer();
            if (!player)
                return;

            auto it = s_targetsByCreature.find(me->GetEntry());
            if (it == s_targetsByCreature.end())
                return;

            for (size_t idx : it->second)
            {
                QuestItemTargetEntry const& e = s_questItemTargets[idx];
                if (e.SpellId && e.SpellId != spell->Id)
                    continue;
                if (e.ItemId && !player->HasItemCount(e.ItemId, 1))
                    continue;
                if (player->GetQuestStatus(e.QuestId) != QUEST_STATUS_INCOMPLETE)
                    continue;

                player->KilledMonsterCredit(e.CreditEntry, me->GetGUID());

                if (e.FollowPlayer)
                {
                    me->RemoveAllAuras();
                    me->GetMotionMaster()->MoveFollow(player, PET_FOLLOW_DIST, PET_FOLLOW_ANGLE);
                }

                if (e.DespawnMs)
                {
                    _used = true;
                    me->DespawnOrUnsummon(e.DespawnMs);
                }
                return;
            }
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_quest_item_targetAI(creature);
    }
};

class quest_generic_phase : public QuestScript
{
public:
    quest_generic_phase() : QuestScript("quest_generic_phase") { }

    void OnQuestStatusChange(Player* player, Quest const* /*quest*/, QuestStatus /*oldStatus*/, QuestStatus newStatus) override
    {
        if (!player)
            return;

        if (newStatus == QUEST_STATUS_INCOMPLETE || newStatus == QUEST_STATUS_COMPLETE
            || newStatus == QUEST_STATUS_REWARDED || newStatus == QUEST_STATUS_NONE)
            PhasingHandler::OnConditionChange(player);
    }
};

void AddSC_custom_quest_fixes()
{
    new QuestItemTargetWorldScript();
    new npc_quest_item_target();
    new quest_generic_phase();
}
