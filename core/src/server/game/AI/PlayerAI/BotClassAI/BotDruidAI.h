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

#ifndef _BOT_DRUID_AI_H
#define _BOT_DRUID_AI_H

#include "ScriptSystem.h"
#include "BotAI.h"
#include "AIWaypointsMgr.h"

enum DruidTalentType
{
	DruidTalent_Balance,
	DruidTalent_Ferity,
	DruidTalent_Revive
};

class LF_GAME_API BotDruidAI : public BotBGAI
{
public:
	BotDruidAI(Player* player) :
		BotBGAI(player),
		m_BotTalentType(0)
	{}
	~BotDruidAI() {}

	void ResetBotAI() override;

protected:
	uint32 GetManaPowerPer();
	uint32 GetEnergyPowerPer();
	uint32 GetRagePowerPer();
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

	bool ProcessSneak();
	void ProcessBearCombat(Unit* pTarget);
	void ProcessCatCombat(Unit* pTarget);
	void ProcessBalanceCombat(Unit* pTarget);
	bool ProcessActive();

	bool CastingControlCommandSpell() override;
	bool TryStartControlCommand() override;
	float TryPushControlCommand(Player* pTarget) override;
	bool CanMeleeHealthMe();
	bool CanConsumeCombo(Unit* pTarget);
	bool TargetHasMechanic(Unit* pTarget);
	bool IsMeleeBotAI() override;
	bool IsRangeBotAI() override;
	bool IsHealerBotAI() override;
	bool IsAttacker() override;
	bool HasEnergyStore();
	void UpEnergy();
	void UpPower();
	void UpMana();
	void SwitchStatus(uint32 status);
	bool CanAttackSpell();
	bool ProcessControl(Unit* pTarget);

	void OnCastSneak();
	void OnCastCharge(Unit* pTarget);

private:
	uint32 m_BotTalentType;

	uint32 DruidIDLE_AOEFerityWish;// 48470		Ⱥ��Ұ��ף��

	uint32 DruidStatus_Travel;// 783			������̬
	uint32 DruidStatus_Bear;// 9634				������̬
	uint32 DruidStatus_Cat;// 768				�Ա���̬
	uint32 DruidStatus_Bird;// 24858			������̬(ƽ��ϵ)
	uint32 DruidStatus_Tree;// 33891			������̬(�ָ�ϵ)

	uint32 DruidGuard_Sneak;// 5215				�Ա�Ǳ��
	uint32 DruidGuard_Harden;// 22812			��Ƥ�� ����20%
	uint32 DruidGuard_Thorns;// 53307			������ ��������
	uint32 DruidGuard_AutoTwine;// 53312		�ܻ�����Ŀ��
	uint32 DruidGuard_Twine;// 53308			����Ŀ��
	uint32 DruidGuard_Control;// 33786			���� ����Ŀ��Ŀ�����
	uint32 DruidGuard_Pofu;// 61336				Ұ����̬�Ƹ�����(Ұ��ϵ)
	uint32 DruidGuard_TreeMan;// 33831			��Ȼ֮���ٻ�����(ƽ��ϵ)

	uint32 DruidAssist_PersonSpirit;// 770		����̬����֮��
	uint32 DruidAssist_BeastSpirit;// 16857		Ұ����̬����֮��
	uint32 DruidAssist_Active;// 29166			���� Ŀ�����

	uint32 DruidCast_Moonfire;// 48463			�»� �����˺�����
	uint32 DruidCast_Insect;// 48468			��Ⱥ �����˺�����(ƽ��ϵ)
	uint32 DruidCast_Anger;// 48461				��ŭ
	uint32 DruidCast_Spark;// 48465				�ǻ� cast��

	uint32 DruidAOE_Hurricane;// 48467			쫷� AOE
	uint32 DruidAOE_Typhoon;// 61384			̨�� AOE(ƽ��ϵ)
	uint32 DruidAOE_FallStar;// 48505			Ⱥ��׹�� AOE(ƽ��ϵ)

	uint32 DruidHeal_Nourishing;// 50464		�̲��� С�����Ѫ �г�������Ч��ʱ��ǿ
	uint32 DruidHeal_Relife;// 48441			�ش��� С������Ѫ
	uint32 DruidHeal_Coalescence;// 48443		������ С��Ѫ
	uint32 DruidHeal_Touch;// 48378				����֮�� ���Ѫ
	uint32 DruidHeal_LifeBurst;// 48451			�������� ����Ч������ʱ�ټ�Ѫ
	uint32 DruidHeal_MergerLife;// 18562		Ѹ������ �̲��ش������� ��Ѫ(�ָ�ϵ)
	uint32 DruidHeal_MomentHeal;// 17116		��Ȼ֮�� nextHealʩ��˲��(�ָ�ϵ)

	uint32 DruidHeal_AOETranquility;// 48447		����
	uint32 DruidHeal_AOEFerity;// 53251			Ұ��Ⱥ������(�ָ�ϵ)

	uint32 DruidCat_Stun;// 49802				è ���� �սἼ
	uint32 DruidCat_Bite;// 48577				è ����ҧ �����˺��սἼ
	uint32 DruidCat_Roar;// 52610				è ���� ���Լ����˺����սἼ
	uint32 DruidCat_Separate;// 49800			è ���� �����˺��սἼ

	uint32 DruidCat_Tiger;// 50213				è �ͻ�֮ŭ �˺�BUF
	uint32 DruidCat_FastMove;// 33357			è ����
	uint32 DruidCat_Charge;// 49376				è ���(Ұ��ϵ)
	uint32 DruidCat_Surprise;// 49803			è Ǳ��ʱ��1������
	uint32 DruidCat_Sack;// 48579				è Ǳ��ʱ��1���˺�
	uint32 DruidCat_Claw;// 48570				è צ��
	uint32 DruidCat_BackStab;// 48572			è ����
	uint32 DruidCat_Attack;// 62078				è �ӻ�Ⱥ��
	uint32 DruidCat_Sweep;// 48574				è ��Ѫ����
	uint32 DruidCat_Laceration;// 48566			è ����(Ұ��ϵ)

	uint32 DruidBear_DecAtt;// 48560			�� ����ǿ��
	uint32 DruidBear_AddPower;// 5229			�� ��ŭ��
	uint32 DruidBear_PowerLife;// 22842			�� ŭ����Ѫ
	uint32 DruidBear_Laceration;// 48564		�� ����(Ұ��ϵ)
	uint32 DruidBear_Sweep;// 48568				�� ��Ѫ����
	uint32 DruidBear_Attack;// 48562			�� �ӻ�Ⱥ��
	uint32 DruidBear_NextAtt;// 48480			�� Next������ǿ
	uint32 DruidBear_Stun;// 8983				�� ����
	uint32 DruidBear_Charge;// 16979			�� ���(Ұ��ϵ)
};

#endif // !_BOT_DRUID_AI_H
