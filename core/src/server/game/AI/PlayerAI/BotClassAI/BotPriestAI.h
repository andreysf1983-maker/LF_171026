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

#ifndef _BOT_PRIEST_AI_H
#define _BOT_PRIEST_AI_H

#include "ScriptSystem.h"
#include "BotAI.h"
#include "AIWaypointsMgr.h"

enum PriestTalentType
{
	PriestTalent_Precept,
	PriestTalent_Holy,
	PriestTalent_Shadow
};

class LF_GAME_API BotPriestAI : public BotBGAI
{
public:
	BotPriestAI(Player* player) :
		BotBGAI(player),
		m_BotTalentType(0),
		m_ReadyCurrentPrayer(0)
	{}
	~BotPriestAI() {}

	void ResetBotAI() override;

protected:
	uint32 GetManaPowerPer();
	bool HaveManaStore() override;
	bool CastBuffPrayer();
	bool NeedWaitSpecialSpell(uint32 diff) override;
	void InitializeSpells();
	void UpdateTalentType();
	void EachTick() override;
	bool NeedFlee() override;
	void ProcessReady() override;
	void ProcessFlee() override;
	bool ProcessNormalSpell() override;
	void ProcessHealthSpell(Unit* pTarget) override;
	void ProcessMeleeSpell(Unit* pTarget) override;
	void ProcessRangeSpell(Unit* pTarget) override;
	bool ProcessArenaHealthMember();

	void ProcessNormalRangeSpell(Unit* pTarget);
	void ProcessShadowRangeSpell(Unit* pTarget);

	bool ProcessManaBurn();
	bool ProcessManaRevive();
	bool ProcessDispel();

	bool IsHealerBotAI() override;
	bool IsAttacker() override;

private:
	uint32 m_BotTalentType;
	uint32 m_ReadyCurrentPrayer;

	uint32 PriestIDLE_AllHardRes;// 48162			ȫ�����
	uint32 PriestIDLE_HardRes;// 48161				�������
	uint32 PriestIDLE_SoulFire;// 48168				����֮��
	uint32 PriestIDLE_AllSpiritRes;// 48074			ȫ�徫��
	uint32 PriestIDLE_SpiritRes;// 48073			���徫��
	uint32 PriestIDLE_Bloodsucker;// 15286			��Ѫ��ӵ��
	uint32 PriestIDLE_AllShadowRes;// 48170			ȫ�尵Ӱ����
	uint32 PriestIDLE_ShadowRes;// 48169			���尵Ӱ����
	uint32 PriestIDLE_ShadowStatus;// 15473			��Ӱ��̬

	uint32 PriestGuard_ShadowFear;// 64044			����־�(��Ӱϵ)
	uint32 PriestGuard_AOEFear;// 10890				��ս��ΧȺ�־�
	uint32 PriestGuard_DefFear;// 6346				���־���
	uint32 PriestGuard_RecoverMana;// 47585			��Ӱ����������(��Ӱϵ)
	uint32 PriestGuard_DmgAnnul;// 33206			ʹ��ѹ��(����ϵ)
	uint32 PriestGuard_DefShield;// 48066			������ ��
	uint32 PriestGuard_SelfHealth;// 48173			�������� �Լ�˲������(��ʥϵ)
	uint32 PriestGuard_GuardSoul;// 47788			����ػ� target����ʱ�ػ�(��ʥϵ)

	uint32 PriestAssist_SoulAbs;// 14751			����רעnext0����(����ϵ)
	uint32 PriestAssist_AddHolyPower;// 10060		����ע��targetʩ�����ٺͱ���(����ϵ)
	uint32 PriestAssist_AllDispel;// 32375			ȫ����ɢħ��
	uint32 PriestAssist_Dispel;// 988				������ɢħ��
	uint32 PriestAssist_ShadowDemon;// 34433			��Ӱ��ħ
	uint32 PriestAssist_Silence;// 15487			��Ӱ��Ĭ(��Ӱϵ)
	uint32 PriestAssist_AllResMana;// 64901			����ȫ�����
	uint32 PriestAssist_AllResLife;// 64843			����ȫ���Ѫ

	uint32 PriestDebuf_Ache;// 48125				ʹ
	uint32 PriestDebuf_Drown;// 48158				��
	uint32 PriestDebuf_Plague;// 48300				����

	uint32 PriestAOE_ShadowExplode;// 53023			��Ӱ��ըAOE(��Ӱϵ)
	uint32 PriestAOE_HolyNova;// 48078				��ʥ����

	uint32 PriestShadow_ShadowTouch;// 48160			��Ѫ֮��(��Ӱϵ)
	uint32 PriestShadow_Knocking;// 48127			������
	uint32 PriestShadow_Lech;// 48156				�����̢(��Ӱϵ)
	uint32 PriestHoly_Smite;// 48123				�ͻ�
	uint32 PriestHoly_BigFire;// 48135				��ʥ֮��
	uint32 PriestPrecept_ManaBurn;// 8129			����ȼ��

	uint32 PriestHeal_LowHeal;// 6064				�ͼ�����
	uint32 PriestHeal_Resume;// 48068				�ָ�
	uint32 PriestHeal_FastHeal;// 48071				��������
	uint32 PriestHeal_BigHeal;// 48063				������
	uint32 PriestHeal_LinkHeal;// 48120				�����Լ���Ŀ������
	uint32 PriestHeal_UnionHeal;// 48113			���ϵ��� target next heal
	uint32 PriestHeal_RingHeal;// 48089				����֮��(��ʥϵ)
	uint32 PriestHeal_AOEHeal;// 48072				���Ƶ��� aoe heal
	uint32 PriestHeal_Awareness;// 53007			���� ����3�������ӵ�����Ŀ��(����ϵ)

	uint32 PriestFlag_DeadSoul;// 27827				����֮�� ����������
	uint32 PriestFlag_NonShield;// 6788				���Զ�DEBUFF
};

#endif // !_BOT_PRIEST_AI_H
