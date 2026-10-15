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

#ifndef _BOT_WARLOCK_AI_H
#define _BOT_WARLOCK_AI_H

#include "ScriptSystem.h"
#include "BotAI.h"
#include "AIWaypointsMgr.h"

enum WarlockTalentType
{
	HunterTalent_Pain,
	HunterTalent_Demon,
	HunterTalent_Ruin
};

class LF_GAME_API BotWarlockAI : public BotBGAI
{
public:
	BotWarlockAI(Player* player) :
		BotBGAI(player),
		m_BotTalentType(0),
		m_IsInitedPetSpells(false),
		m_IsSummonPeted(false),
		m_LastAOEDotTick(0),
		m_GatePos(),
		m_LastCharmTarget(ObjectGuid::Empty),
		m_LastCharmTick(0)
	{}
	~BotWarlockAI() {}

	void ResetBotAI() override;

protected:
	uint32 GetManaPowerPer();
	void InitializeSpells();
	void InitializePetSpells();
	void UpdateTalentType();
	void EachTick() override;
	bool NeedFlee() override;
	void ProcessReady() override;
	void ProcessFlee() override;
	bool ProcessNormalSpell() override;
	void ProcessMeleeSpell(Unit* pTarget) override;
	void ProcessRangeSpell(Unit* pTarget) override;
	void ProcessPetSpell(Unit* pTarget, bool fleeing);

	bool CastingControlCommandSpell() override;
	bool TryStartControlCommand() override;
	float TryPushControlCommand(Player* pTarget) override;
	bool ProcessGate(Unit* pTarget, bool onlyBuild);
	bool ProcessMana(bool isMoveing);
	bool ProcessDot(Unit* pTarget, bool canCastTime);
	bool ProcessFear(Unit* pTarget);
	void PetAction(Pet* pPet, Unit* pTarget);
	bool TargetIsFear(Unit* pTarget);
	void OnCastTeleGate();
	void InsureSoulItem();
	uint32 TryCastSummonRiteSpell() override;

private:
	uint32 m_BotTalentType;
	bool m_IsInitedPetSpells;
	uint32 m_LastAOEDotTick;
	Position m_GatePos;
	bool m_IsSummonPeted;
	ObjectGuid m_LastCharmTarget;
	uint32 m_LastCharmTick;

	uint32 WarlockIDLE_LowArmor;// 696			�ͼ�����
	uint32 WarlockIDLE_Armor;// 47889			�м�����
	uint32 WarlockIDLE_HighArmor;// 47893		�߼�����
	uint32 WarlockIDLE_SoulLink;// 19028		�����������(��ħϵ)
	uint32 WarlockIDLE_ShadowShield;// 47891		��Ӱ��
	uint32 WarlockIDLE_SummonFireDemon;// 688	�ٻ�С��
	uint32 WarlockIDLE_SummonHollowDemon;// 697	�ٻ����
	uint32 WarlockIDLE_SummonSuccubus;// 712		�ٻ���ħ
	uint32 WarlockIDLE_SummonDogDemon;// 691		�ٻ���Ȯ
	uint32 WarlockIDLE_SummonGuardDemon;// 30146	�ٻ���������
	uint32 WarlockIDLE_FastSummon;// 18708		�����ٻ�(��ħϵ)
	uint32 WarlockIDLE_OpenGate;// 48018		�������ͷ���
	uint32 WarlockIDLE_TeleGate;// 48020		˲�Ƶ����ͷ���
	uint32 WarlockIDLE_SummonRite;// 29893		�����ʽ

	uint32 WarlockDemon_ToDemon;// 47241		�������ħ
	uint32 WarlockDemon_Charge;// 54785			��ħ���
	uint32 WarlockDemon_MeleeAOE;// 50581		��ħ˳��ն
	uint32 WarlockDemon_Sacrifice;// 50589		��ħ�׼�

	uint32 WarlockAssist_DemonPower;// 47193		ǿ���ٻ��Ķ�ħ(��ħϵ)
	uint32 WarlockAssist_ExtractMana;// 59092	�������ϳ���(ʹ��ϵ)
	uint32 WarlockAssist_ConvertMana;// 57946	�������� Ѫת��
	uint32 WarlockAssist_StealLife;// 47857		��ȡ����
	uint32 WarlockAssist_StealMana;// 5138		��ȡ����
	uint32 WarlockAssist_BaseFear;// 6215		�־���
	uint32 WarlockAssist_FastFear;// 47860		��������
	uint32 WarlockAssist_AOEFear;// 17928		Ⱥ��־���

	uint32 WarlockAOE_MeleeFire;// 61290		��սǰ��AOE
	uint32 WarlockAOE_RainFire;// 47820			������AOE
	uint32 WarlockAOE_ShadowRage;// 47847		��Ӱ֮ŭAOEȺ�����(����ϵ)

	uint32 WarlockCurse_UpDmg;// 47865			Ԫ���˺��������
	uint32 WarlockCurse_MoveLow;// 18223		ƣ������ �ƶ��ٶȽ���(ʹ��ϵ)
	uint32 WarlockCurse_MgcDmg;// 47864			ʹ������ DOT�˺�
	uint32 WarlockCurse_MeleeLow;// 50511		�������� ��ǿ����
	uint32 WarlockCurse_CastLow;// 11719		�������� ʩ��ʱ���ӳ�

	uint32 WarlockDot_LeechSoul;// 59164		�ǻ���(ʹ��ϵ)
	uint32 WarlockDot_HighDmg;// 47843			ʹ�ද��(ʹ��ϵ)
	uint32 WarlockDot_LowDmg;// 47813			������
	uint32 WarlockDot_AOEDmg;// 47836			�������� dot��Χ�˺�
	uint32 WarlockDot_Sacrifice;// 47811		�����׼�

	uint32 WarlockCast_ShadowArrow;// 47809		��Ӱ֮��
	uint32 WarlockCast_ShadowShock;// 47827		��Ӱ���24��(����ϵ)
	uint32 WarlockCast_ChaosArrow;// 59172		����֮��(����ϵ)
	uint32 WarlockCast_FullBurn;// 47838		ȼ�� ���׼�ʱ��ǿЧ��(����ϵ)
	uint32 WarlockCast_FireBurn;// 17962		���� �����׼�(����ϵ)
	uint32 WarlockCast_BigFireBall;// 47825		�������

	uint32 WarlockPetDemon_Charge;// 47996		��ħpet���
	uint32 WarlockPetDemon_Melee;// 47994		��ħpet˳��ն
	uint32 WarlockPetDog_MagicBuf;// 57567		��Ȯpet�Ŷ�BUF
	uint32 WarlockPetDog_EatMgc;// 48011		��Ȯpet��ʳħ��
	uint32 WarlockPetDog_Bite;// 54053			��Ȯpetҧ��
	uint32 WarlockPetDog_Silence;// 19647		��Ȯpet��Ĭ
	uint32 WarlockPetSuccubus_Lash;// 47992		��ħpet�޴�
	uint32 WarlockPetSuccubus_Sneak;// 7870		��ħpetǱ��
	uint32 WarlockPetSuccubus_Charm;// 6358		��ħpet�Ȼ�
	uint32 WarlockPetGhost_Shield;// 47983		С��pet���
	uint32 WarlockPetGhost_Sneak;// 4511		С��petǱ��
	uint32 WarlockPetGhost_Stamp;// 47982		С��petѪӡ��
	uint32 WarlockPetGhost_FireArrow;// 47964	С��pet�����

	uint32 WarlockFlag_SoulItem;// 6265			�����Ƭ����
	uint32 WarlockFlag_SoulLink;// 25228		�����������BUF
	uint32 WarlockFlag_OpenGate;// 48018		���ͷ���BUF
	uint32 WarlockFlag_Sacrifice;// 50589		��ħ�׼�BUF
};

#endif // !_BOT_WARLOCK_AI_H
