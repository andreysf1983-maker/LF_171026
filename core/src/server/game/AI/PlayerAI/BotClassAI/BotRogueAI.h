/*

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

#ifndef _BOT_ROGUE_AI_H
#define _BOT_ROGUE_AI_H

#include "ScriptSystem.h"
#include "BotAI.h"
#include "AIWaypointsMgr.h"

enum RogueTalentType
{
	RogueTalent_Kill,
	RogueTalent_Combat,
	RogueTalent_Keen
};

class LF_GAME_API BotRogueAI : public BotBGAI
{
public:
	BotRogueAI(Player* player) :
		BotBGAI(player),
		m_BotTalentType(0),
		m_IsUpedPoison(0)
	{}
	~BotRogueAI() {}

	void ResetBotAI() override;

protected:
	uint32 GetEnergyPowerPer();
	uint32 GetPoisonEntryByWeaponType(EquipmentSlots equipSlot);
	void InitializeSpells();
	void UpdateTalentType();
	void EachTick() override;
	void ProcessReady() override;
	bool ProcessNormalSpell() override;
	void ProcessMeleeSpell(Unit* pTarget) override;
	void ProcessRangeSpell(Unit* pTarget) override;
	void ProcessFlee() override;
	bool ProcessSneakSpell(Unit* pTarget);
	bool ProcessMeleeDance(Unit* pTarget);
	bool ProcessMeleeBlind(Unit* pTarget);

	bool TryStartControlCommand() override;
	float TryPushControlCommand(Player* pTarget) override;
	bool CanConsumeCombo(Unit* pTarget);
	bool CastCloakByNeed();
	bool CanBlind(Unit* pTarget);
	bool CanStartSpell();
	void OnCastSneak();
	void OnCastFlash(Unit* pTarget);
	void UpEnergy();

private:
	uint32 m_BotTalentType;
	uint8 m_IsUpedPoison;

	uint32 RogueGuard_Sneak;// 1784				Ǳ��
	uint32 RogueGuard_ShadowCloak;// 31224		��Ӱ����
	uint32 RogueGuard_Disappear;// 26889		��ʧ
	uint32 RogueGuard_Dodge;// 26669			����
	uint32 RogueGuard_Sprint;// 11305			����

	uint32 RogueSneak_Stick;// 51724			�ƹ�
	uint32 RogueSneak_Premeditate;// 14183		Ԥı(����ϵ)
	uint32 RogueSneak_Ambush;// 48691			����
	uint32 RogueSneak_Surprise;// 1833			͵Ϯ

	uint32 RogueAssist_ShadowDance;// 51713		��Ӱ֮��(����ϵ)
	uint32 RogueAssist_ShadowFlash;// 36554		��Ӱ��(����ϵ)
	uint32 RogueAssist_ReadyCD;// 14185			Ԥ��(����ϵ)
	uint32 RogueAssist_Blind;// 2094			��ä
	uint32 RogueAssist_Disarm;// 51722			��е
	uint32 RogueAssist_NextCrit;// 14177		��Ѫ next����(��ɱϵ)
	uint32 RogueAssist_blood;// 51662			��Ѫ Ŀ����Ѫʱʩ��(��ɱϵ)
	uint32 RogueAssist_FastEnergy;// 13750		�������ٻظ�(ս��ϵ)
	uint32 RogueAssist_BlockCast;// 1766		���� ���ʩ��
	uint32 RogueAssist_Paralyze;// 1776			��� ̱��Ŀ��
	uint32 RogueAssist_FastSpeed;// 13877		�ӹ����ٶ�20(ս��ϵ)

	uint32 RogueAOE_Knife;// 51723				���з���
	uint32 RogueAOE_AllDance;// 51690			����ɱ��(ս��ϵ)

	uint32 RogueAttack_Blood;// 48660			��Ѫ(����ϵ)
	uint32 RogueAttack_Ghost;// 14278			���ȹ���(����ϵ) ������+����
	uint32 RogueAttack_Injure;// 48666			����(��ɱϵ)
	uint32 RogueAttack_PoisonAtt;// 5938		����
	uint32 RogueAttack_BackAtt;// 48657			����
	uint32 RogueAttack_EvilAtt;// 48638			а�񹥻�

	uint32 RogueAttack_Damage;// 48668			�޹�
	uint32 RogueAttack_Separate;// 48672		����
	uint32 RogueAttack_Stun;// 8643				����
	uint32 RogueAttack_PoisonDmg;// 57993		����
	uint32 RogueRange_Throw;// 48674			����Ͷ��

	uint32 RogueFlag_Dance;// 51713				��Ӱ֮����
};

#endif // !_BOT_ROGUE_AI_H
