/*
 * Makeshift council scripts for encounters whose creatures are already spawned
 * and whose creature_template spell slots name real 7.3.5 spells.
 *
 * Each member pulls the others in the room and casts those spells on a timer.
 * Encounter credit is granted only when every member is dead. The credit spell
 * is a token passed to UpdateEncounterStateForSpellCast. Casting that spell
 * during the fight does not by itself complete the encounter.
 *
 * Hans'gar & Franzok and Twin Ogron are not here. Their spell slots are empty,
 * so an ability script would have to invent spell ids. They are recorded with
 * the Empty set in docs/quests/INSTANCING.md.
 */

#include "PassiveAI.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "SpellMgr.h"

#include <list>

enum CouncilGroups
{
    GROUP_STONE_GUARD = 1,
    GROUP_SPIRIT_KINGS,
    GROUP_WILL_OF_EMPEROR,
    GROUP_IRON_MAIDENS,
    GROUP_GRIMRAIL_ENFORCERS
};

struct CouncilMember
{
    uint32 Entry;
    uint32 Group;
    uint32 EncounterId;
    uint32 CreditSpell;
    uint32 Spells[4];
};

static CouncilMember const Members[] =
{
    // The Stone Guard. Overload, petrification, and rend. Solid Stone and True Form
    // are the proximity auras, so they are not cast on a timer.
    { 60047, GROUP_STONE_GUARD, 1395, 115844, { 115844, 116060, 125206, 130774 } }, // Amethyst Guardian
    { 60051, GROUP_STONE_GUARD, 1395, 115844, { 115840, 115861, 125206, 0 } },      // Cobalt Guardian
    { 60043, GROUP_STONE_GUARD, 1395, 115844, { 115842, 116008, 116223, 125206 } }, // Jade Guardian
    { 59915, GROUP_STONE_GUARD, 1395, 115844, { 130395, 115843, 116038, 125206 } }, // Jasper Guardian

    // The Spirit Kings. One damage spell each, plus Qiang's shield and flank order.
    { 60708, GROUP_SPIRIT_KINGS, 1436, 117948, { 117708, 0, 0, 0 } },               // Meng the Demented
    { 60709, GROUP_SPIRIT_KINGS, 1436, 117948, { 117948, 117910, 117961, 0 } },     // Qiang the Merciless
    { 60710, GROUP_SPIRIT_KINGS, 1436, 117948, { 118049, 118094, 0, 0 } },          // Subetai the Swift
    { 60701, GROUP_SPIRIT_KINGS, 1436, 117948, { 117685, 117628, 117697, 117506 } }, // Zian of the Endless Shadow

    // Will of the Emperor. Both creatures only have Stomp in their spell slots.
    { 60400, GROUP_WILL_OF_EMPEROR, 1407, 116969, { 116969, 0, 0, 0 } },            // Jan-xi
    { 60399, GROUP_WILL_OF_EMPEROR, 1407, 116969, { 132425, 0, 0, 0 } },            // Qin-xi

    // The Iron Maidens. Rifle shots, blade dash, and blood ritual.
    { 77557, GROUP_IRON_MAIDENS, 1695, 156629, { 156666, 156629, 0, 0 } },          // Admiral Gar'an
    { 77231, GROUP_IRON_MAIDENS, 1695, 156629, { 160796, 155841, 0, 0 } },          // Enforcer Sorka
    { 77477, GROUP_IRON_MAIDENS, 1695, 156629, { 158079, 158080, 0, 0 } },          // Marak the Blooded

    // Grimrail Enforcers. Blood bolt, flaming slash, gut shot, and traps.
    { 80816, GROUP_GRIMRAIL_ENFORCERS, 1748, 163668, { 165122, 163740, 0, 0 } },    // Ahri'ok Dugru
    { 80805, GROUP_GRIMRAIL_ENFORCERS, 1748, 163668, { 163668, 164956, 0, 0 } },    // Makogg Emberblade
    { 80808, GROUP_GRIMRAIL_ENFORCERS, 1748, 163668, { 163334, 163390, 0, 0 } },    // Neesa Nox
};

static CouncilMember const* FindMember(uint32 entry)
{
    for (CouncilMember const& member : Members)
        if (member.Entry == entry)
            return &member;

    return nullptr;
}

class council_member_AI : public ScriptedAI
{
    public:
        council_member_AI(Creature* creature) : ScriptedAI(creature), _member(FindMember(creature->GetEntry())) { }

        void Reset() override
        {
            _events.Reset();
        }

        void EnterCombat(Unit* who) override
        {
            if (!_member || !who)
                return;

            _events.Reset();
            PullGroup(who);

            uint32 delay = 4000;
            for (uint32 spellId : _member->Spells)
            {
                if (!spellId)
                    break;

                if (sSpellMgr->GetSpellInfo(spellId))
                    _events.ScheduleEvent(spellId, delay);

                delay += 2000;
            }
        }

        void JustDied(Unit* /*killer*/) override
        {
            if (!_member)
                return;

            if (AnyPartnerAlive())
                return;

            if (InstanceScript* instance = me->GetInstanceScript())
            {
                instance->UpdateEncounterStateForSpellCast(_member->CreditSpell, me);
                instance->SendBossKillCredit(_member->EncounterId);
                instance->SaveToDB();
            }
        }

        void UpdateAI(uint32 diff) override
        {
            if (!UpdateVictim())
                return;

            _events.Update(diff);

            if (me->HasUnitState(UNIT_STATE_CASTING))
                return;

            if (uint32 spellId = _events.ExecuteEvent())
            {
                if (sSpellMgr->GetSpellInfo(spellId))
                    DoCast(spellId);

                _events.ScheduleEvent(spellId, 15000);
            }
            else
                DoMeleeAttackIfReady();
        }

    private:
        void PullGroup(Unit* who)
        {
            for (CouncilMember const& member : Members)
            {
                if (member.Group != _member->Group || member.Entry == me->GetEntry())
                    continue;

                std::list<Creature*> found;
                me->GetCreatureListWithEntryInGrid(found, member.Entry, 250.0f);
                for (Creature* creature : found)
                    if (creature->IsAlive() && !creature->IsInCombat() && creature->AI())
                        creature->AI()->AttackStart(who);
            }
        }

        bool AnyPartnerAlive() const
        {
            for (CouncilMember const& member : Members)
            {
                if (member.Group != _member->Group)
                    continue;

                std::list<Creature*> found;
                me->GetCreatureListWithEntryInGrid(found, member.Entry, 250.0f);
                for (Creature* creature : found)
                    if (creature != me && creature->IsAlive())
                        return true;
            }

            return false;
        }

        CouncilMember const* _member;
        EventMap _events;
};

class CouncilMemberScript : public CreatureScript
{
    public:
        CouncilMemberScript(char const* name) : CreatureScript(name) { }

        CreatureAI* GetAI(Creature* creature) const override
        {
            // Ghostcrawler also uses boss_generic_guardian. Leave any creature
            // that is not one of these council members on its database AI.
            if (!FindMember(creature->GetEntry()))
                return nullptr;

            return new council_member_AI(creature);
        }
};

// The Stone Guard controller is a spawned helper, not a boss. The database
// already names this script. It stays passive so it does not join the fight.
class boss_stone_guard_controler : public CreatureScript
{
    public:
        boss_stone_guard_controler() : CreatureScript("boss_stone_guard_controler") { }

        CreatureAI* GetAI(Creature* creature) const override
        {
            return new NullCreatureAI(creature);
        }
};

void AddSC_council_makeshift()
{
    new CouncilMemberScript("boss_generic_guardian");
    new CouncilMemberScript("boss_spirit_kings");
    new CouncilMemberScript("boss_will_of_emperor");
    new CouncilMemberScript("boss_iron_maidens");
    new CouncilMemberScript("boss_grimrail_enforcers");
    new boss_stone_guard_controler();
}
