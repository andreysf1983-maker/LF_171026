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

#ifndef _BOT_SHAMAN_AI_H
#define _BOT_SHAMAN_AI_H

#include "ScriptSystem.h"
#include "BotAI.h"
#include "AIWaypointsMgr.h"
#include "Totem.h"

enum ShamanTalentType
{
	ShamanTalent_Element,
	ShamanTalent_Power,
	ShamanTalent_Heal
};

class LF_GAME_API BotShamanAI : public BotBGAI
{
public:
	BotShamanAI(Player* player) :
		BotBGAI(player),
		m_BotTalentType(0),
		m_CurrentPattern(ShamanTotemPattern::ShamanTP_None),
		m_NonFearTotemTick(0),
		m_SummonFireTotemTick(0),
		m_IsUpedWeapon(0)
	{}
	~BotShamanAI() {}

	void ResetBotAI() override;

protected:
	uint32 GetManaPowerPer();
	void InitializeSpells();
	void UpdateTalentType();
	bool ProcessUpWeapon();
	void EachTick() override;
	bool NeedFlee() override;
	void ProcessReady() override;
	void ProcessFlee() override;
	bool ProcessNormalSpell() override;
	void ProcessHealthSpell(Unit* pTarget) override;
	void ProcessMeleeSpell(Unit* pTarget) override;
	void ProcessRangeSpell(Unit* pTarget) override;
	bool ProcessDispel();
	bool ProcessHeroic();
	bool ProcessArenaHealthMember();

	bool CastingControlCommandSpell() override;
	bool TryStartControlCommand() override;
	float TryPushControlCommand(Player* pTarget) override;
	bool ProcessShield();
	bool ProcessTotem();
	bool ExistTotemByType(PlayerTotemType totemType, float range);
	bool IsMeleeBotAI() override;
	bool IsRangeBotAI() override;
	bool IsHealerBotAI() override;
	bool IsAttacker() override;
	bool TargetIsSuppress(Unit* pTarget);
	bool TryRecycleTotem(ShamanTotemPattern pattern);

private:
	uint32 m_BotTalentType;
	ShamanTotemPattern m_CurrentPattern;
	uint32 m_NonFearTotemTick;
	uint32 m_SummonFireTotemTick;
	uint8 m_IsUpedWeapon;

	uint32 ShamanIDLE_LifeWeapon;// 51994		��������
	uint32 ShamanIDLE_IceWeapon;// 58796		��˪����
	uint32 ShamanIDLE_FireWeapon;// 58790		��������
	uint32 ShamanIDLE_PhyWeapon;// 10399		ʯ������
	uint32 ShamanIDLE_FastWeapon;// 58804		��ŭ����

	uint32 ShamanShield_Earth;// 49284			���֮��(�ָ�ϵ)
	uint32 ShamanShield_Water;// 57960			ˮ֮��
	uint32 ShamanShield_Lightning;// 49281		����֮��

	uint32 ShamanAssist_Frog;// 51514			��������
	uint32 ShamanAssist_HealCrit;// 55198		next3�������Ʊ���(�ָ�ϵ)
	uint32 ShamanAssist_MomentHeal;// 16188		nextHealʩ��˲��(�ָ�ϵ)
	uint32 ShamanAssist_MomentCast;// 16166		nextCastʩ��˲��(Ԫ��ϵ)
	uint32 ShamanAssist_BlockCast;// 57994		���ʩ��
	uint32 ShamanAssist_Cleansing;// 8012		����Ŀ��2��BUFF
	uint32 ShamanAssist_FireNova;// 61657		�û���ͼ��AOEһ��
	uint32 ShamanAssist_Heroic;// 32182			����Ӣ��

	uint32 ShamanAtt_StormStrike;// 17364		�籩���(��ǿϵ)
	uint32 ShamanAtt_FireStrike;// 60103		���Ҵ��(��ǿϵ)

	uint32 ShamanCast_LightningArrow;// 49238	�����
	uint32 ShamanCast_LightningChain;// 49271	������
	uint32 ShamanCast_LightningStorm;// 59159	����籩(Ԫ��ϵ)
	uint32 ShamanCast_FireThud;// 49233			�������
	uint32 ShamanCast_IceThud;// 49236			��˪���
	uint32 ShamanCast_EarthThud;// 49231		������
	uint32 ShamanCast_FireStrike;// 60043		���Ҵ�� Զ�̷���

	uint32 ShamanHealth_Fast;// 49276			��������
	uint32 ShamanHealth_Bast;// 49273			��������
	uint32 ShamanHealth_Chain;// 55459			������
	uint32 ShamanHealth_Torrent;// 61301		���� ˲��С����+��������(�ָ�ϵ)
	uint32 ShamanDispel_Refine;// 51886			��ɢ

	uint32 ShamanTotem_Recycle;// 36936			����ͼ��

	uint32 ShamanTotem_Life;// 58757			����ͼ��
	uint32 ShamanTotem_Mana;// 58774			����ͼ��
	uint32 ShamanTotem_BMana;// 16190			����ͼ��
	uint32 ShamanTotem_NonFear;// 8143			ս��ͼ��
	uint32 ShamanTotem_SummonFire;// 2894		�ٻ���Ԫ��ͼ��
	uint32 ShamanTotem_MgcPower;// 57722		��������ͼ��(Ԫ��ϵ)
	uint32 ShamanTotem_Attack;// 58704			�������湥��ͼ��
	uint32 ShamanTotem_AOEAttack;// 58734		��������Ⱥ��ͼ��
	uint32 ShamanTotem_MgcHeal;// 58656			��������������Ч��ͼ��

	uint32 ShamanTotem_DecMove;// 2484			���ƶ��ٶ�ͼ��
	uint32 ShamanTotem_SummonSoil;// 2062		�ٻ���Ԫ��ͼ��
	uint32 ShamanTotem_PhyPower;// 58643		��������ͼ��
	uint32 ShamanTotem_Armor;// 58753			����ͼ��

	uint32 ShamanTotem_AbsorbBuff;// 8177		�����к�BUFFͼ��
	uint32 ShamanTotem_AttSpeed;// 8512			��ս�����ٶ�ͼ��
	uint32 ShamanTotem_MgcSpeed;// 3738			����ʩ���ٶ�ͼ��

	uint32 ShamanFlag_NoHeroic;// 57723			�޷�giveӢ��״̬��ʶ
};

#endif // !_BOT_SHAMAN_AI_H
