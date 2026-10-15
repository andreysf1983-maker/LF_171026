/*
* Copyright (C) 2017-2018 LEGIONFORGE <https://github.com/LEGIONFORGE>
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

#include "MotionMaster.h"
#include "ScriptedCreature.h"
#include "Creature.h"
#include "PhasingHandler.h"
#include "Player.h"
#include "ScriptedGossip.h"
#include "ScriptMgr.h"
#include "SpellInfo.h"
#include "TemporarySummon.h"
#include "World.h"

class npc_rate_xp_modifier : public CreatureScript
{
    public:
        npc_rate_xp_modifier() : CreatureScript("npc_rate_xp_modifier") { }

#define MAX_RATE uint32(10)

        bool OnGossipHello(Player* player, Creature* creature) override
        {
            for (uint32 i = 1; i <= MAX_RATE; ++i)
            {
                if (i == player->GetPersonnalXpRate())
                    continue;

                if (i == sWorld->getRate(RATE_XP_KILL))
                    continue;

                std::ostringstream gossipText;
                gossipText << "Rate x" << i;
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, gossipText.str(), GOSSIP_SENDER_MAIN, i);
            }

            if (player->GetPersonnalXpRate())
            {
                std::ostringstream gossipText;
                gossipText << "Default Rate - x" << sWorld->getRate(RATE_XP_KILL);
                AddGossipItemFor(player, GOSSIP_ICON_CHAT, gossipText.str(), GOSSIP_SENDER_MAIN, 0);
            }

            SendGossipMenuFor(player, player->GetGossipTextId(creature), creature->GetGUID());
            return true;
        }

        bool OnGossipSelect(Player* player, Creature* /*creature*/, uint32 /*uiSender*/, uint32 uiAction) override
        {
            CloseGossipMenuFor(player);
            player->SetPersonnalXpRate(float(std::min(MAX_RATE, uiAction)));
            return true;
        }
};

enum SwiftclawQuest
{
    QUEST_YOUNG_AND_VICIOUS = 24626,
    NPC_SWIFTCLAW           = 37989,
};

static Position const SWIFTCLAW_SPAWN = { -1613.27f, -5379.43f, 1.49129f, 0.f };

class quest_young_and_vicious : public QuestScript
{
public:
    quest_young_and_vicious() : QuestScript("quest_young_and_vicious") { }

    void OnQuestStatusChange(Player* player, Quest const* quest, QuestStatus /*oldStatus*/, QuestStatus newStatus) override
    {
        if (!player || quest->GetQuestId() != QUEST_YOUNG_AND_VICIOUS)
            return;

        if (newStatus == QUEST_STATUS_INCOMPLETE)
        {
            PhasingHandler::OnConditionChange(player);
            if (player->FindNearestCreature(NPC_SWIFTCLAW, 250.f))
                return;
            if (TempSummon* swift = player->SummonCreature(NPC_SWIFTCLAW, SWIFTCLAW_SPAWN,
                TEMPSUMMON_MANUAL_DESPAWN, 0, 0, true))
            {
                swift->SetReactState(REACT_PASSIVE);
                swift->GetMotionMaster()->MoveRandom(25.f);
            }
        }
        else if (newStatus == QUEST_STATUS_NONE || newStatus == QUEST_STATUS_COMPLETE || newStatus == QUEST_STATUS_REWARDED)
        {
            std::list<Creature*> found;
            player->GetCreatureListWithEntryInGrid(found, NPC_SWIFTCLAW, 300.f);
            for (Creature* c : found)
            {
                if (!c || !c->IsSummon())
                    continue;
                if (c->ToTempSummon()->GetSummonerGUID() != player->GetGUID())
                    continue;
                c->DespawnOrUnsummon();
            }
        }
    }
};

void AddSC_custom_npcs()
{
    new npc_rate_xp_modifier();
    new quest_young_and_vicious();
}
