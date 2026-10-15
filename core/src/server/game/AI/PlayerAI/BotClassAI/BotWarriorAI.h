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

#ifndef _BOT_WARRIOR_AI_H_
#define _BOT_WARRIOR_AI_H_

#include "ScriptSystem.h"
#include "BotAI.h"
#include "AIWaypointsMgr.h"

enum WarriorTalentType
{
	WarriorTalent_Weapon,
	WarriorTalent_Defance,
	WarriorTalent_Rage
};

class LF_GAME_API BotWarriorAI : public BotBGAI
{
public:
	BotWarriorAI(Player* player) :
		BotBGAI(player),
		m_NeedPuniness(-1),
		m_BotTalentType(0),
		m_ChargeWaitTick(0),
		m_IsIDLEBuff(false)
	{}
	~BotWarriorAI() {}

	void ResetBotAI() override;

protected:
	uint32 GetRagePowerPer();
	void EachTick() override;
	void ClearMechanicAura() override;
	bool NeedWaitSpecialSpell(uint32 diff) override;
	void InitializeSpells();
	void UpdateTalentType();
	void ProcessReady() override;
	bool ProcessNormalSpell() override;
	void ProcessMeleeSpell(Unit* pTarget) override;
	void ProcessRangeSpell(Unit* pTarget) override;
	void ProcessFlee() override;

	void UpdateWarriorPose();

	void ProcessWeaponRangeSpell(Unit* pTarget);
	void ProcessRageRangeSpell(Unit* pTarget);
	void ProcessDefanceRangeSpell(Unit* pTarget);
	void ProcessWeaponMeleeSpell(Unit* pTarget);
	void ProcessRageMeleeSpell(Unit* pTarget);
	void ProcessDefanceMeleeSpell(Unit* pTarget);
	bool ProcessSurviveSpell();
	bool ProcessFullAttack(Unit* pTarget);
	void OnCastCharge(Unit* pTarget);

private:
	int32 m_NeedPuniness;
	uint32 m_BotTalentType;
	int32 m_ChargeWaitTick;
	bool m_IsIDLEBuff;

	uint32 WarriorIDLE_AOEAddLife;// = 47440;			// ����ŭ��
	uint32 WarriorIDLE_AOEAddPower;// = 47436;			// ��ǿŭ��

	uint32 WarriorWeapon_Status;// = 2457;
	uint32 WarriorDefance_Status;// = 71;
	uint32 WarriorRage_Status;// = 2458;

	uint32 WarriorCommon_PowerAtt;// = 47450;			// Ӣ�´��
	uint32 WarriorCommon_PowerThrow;// = 57755;			// Ӣ��Ͷ��
	uint32 WarriorCommon_PowerRelife;// = 55694;		// ��ŭ�ָ����п�ʱʹ�û�Ѫ��
	uint32 WarriorCommon_ClearCtrl;// = 18499;			// ��֮ŭ���Ƴ����ƣ�
	uint32 WarriorCommon_AOEFear;// = 5246;			// ��ս��ΧȺ�־�
	uint32 WarriorCommon_SweepAtt;// = 47520;			// ˳��ն
	uint32 WarriorCommon_AddPower;// = 2687;			// ��ŭ��
	uint32 WarriorCommon_AOEDecPower;// = 47437;		// Ⱥ�����ǿ��

	uint32 WarriorDefance_HPojia;// = 47498;			// ������
	uint32 WarriorDefance_Fuchou;// = 57823;			// ����
	uint32 WarriorDefance_ShieldBlock;// = 2565;		// ���Ƹ�
	uint32 WarriorDefance_ShieldAtt;// = 47488;			// �����ͻ�
	uint32 WarriorDefance_Pojia;// = 7386;				// �Ƽ�
	uint32 WarriorDefance_MaxLife;// = 12975;			// �Ƹ�����
	uint32 WarriorDefance_ShiledWall;// = 871;			// ��ǽ
	uint32 WarriorDefance_Disarm;// = 676;				// ��е
	uint32 WarriorDefance_Support;// = 3411;			// Ԯ��
	uint32 WarriorDefance_Conk;// = 12809;				// �������
	uint32 WarriorDefance_AOEConk;// = 46968;			// ǰ����Χ����

	uint32 WarriorWeaponDefance_AOEAtt;// = 47502;		// ����һ��
	uint32 WarriorWeaponDefance_Bleed;// = 47465;		// ˺��
	uint32 WarriorWeaponDefance_SpellReflect;// = 23920;	// ��������
	uint32 WarriorWeaponDefance_ShieldHit;// = 72;		// �ܻ���ʩ����ϣ�

	uint32 WarriorWeapon_SwordStorm;// = 46924;			// ���з籩
	uint32 WarriorWeapon_HighThrow;// = 64382;			// ���޵�Ͷ��
	uint32 WarriorWeapon_Charge;// = 11578;			// ���
	uint32 WarriorWeapon_Suppress;// = 7384;			// ѹ��
	uint32 WarriorWeapon_Backstorm;// = 20230;			// �����籩
	uint32 WarriorWeapon_DeadAtt;// = 47486;			// �������

	uint32 WarriorWeaponRage_FullKill;// = 47471;		// նɱ
	uint32 WarriorWeaponRage_WinAttack;// = 34428;		// ��ʤ׷��
	uint32 WarriorWeaponRage_Backfillet;// = 1715;		// �Ͻ�

	uint32 WarriorRage_Harsh;// = 12323;				// �̶�ŭ��
	uint32 WarriorRage_HeadAtt;// = 6552;				// ȭ����ʩ����ϣ�
	uint32 WarriorRage_Intercept;// = 20252;			// ����
	uint32 WarriorRage_Whirlwind;// = 1680;			// ����ն
	uint32 WarriorRage_Impertinency;// = 1719;			// ³ç
	uint32 WarriorRage_Needdead;// = 12292;			// ����֮Ը
	uint32 WarriorRage_Bloodthirsty;// = 23881;			// ��Ѫ
	uint32 WarriorRage_ReIntercept;// = 60970;			// ����ƶ����ƺͽ������CD
};

#endif // !_BOT_WARRIOR_AI_H_
