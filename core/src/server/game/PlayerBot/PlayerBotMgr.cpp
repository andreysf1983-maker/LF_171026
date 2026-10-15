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

#include "PlayerBotMgr.h"
#include "Errors.h"
#include "World.h"
#include "DB2Stores.h"
#include "Player.h"
#include "BattlegroundMgr.h"
#include "BotAI.h"
#include "BotFieldAI.h"
#include "BotGroupAI.h"
#include "BotDuelAI.h"
#include "BotArenaAI.h"
#include "Config.h"
#include "Group.h"
#include "GroupMgr.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Map.h"
#include <algorithm>
#include "MovementPackets.h"
#include "SocialMgr.h"
#include "LFGMgr.h"
#include "PlayerBotSession.h"
#include "AccountMgr.h"
#include "BattlenetAccountMgr.h"
#include "CharacterPackets.h"
#include "MotionMaster.h"
#include <boost/algorithm/string.hpp>
 //#include <boost/format.hpp>

PlayerBotCharBaseInfo PlayerBotBaseInfo::empty;
std::map<uint32, std::list<UnitAI*> > PlayerBotMgr::m_DelayDestroyAIs;
std::mutex PlayerBotMgr::g_uniqueLock;

std::string PlayerBotCharBaseInfo::GetNameANDClassesText()
{
    //std::string clsName;
    uint32 clsEntry = 620000;
    switch (profession)
    {
    case 1:
        //clsName = "  ?  ? : ";
        clsEntry += 1;
        break;
    case 2:
        //clsName = "  ?��? : ";
        clsEntry += 2;
        break;
    case 3:
        //clsName = "  ��  �� : ";
        clsEntry += 3;
        break;
    case 4:
        //clsName = "  ��  �� : ";
        clsEntry += 4;
        break;
    case 5:
        //clsName = "  ��  ? : ";
        clsEntry += 5;
        break;
    case 6:
        //clsName = "  ��  �� : ";
        clsEntry += 6;
        break;
    case 7:
        //clsName = "  ��  �� : ";
        clsEntry += 7;
        break;
    case 8:
        //clsName = "  ��  ? : ";
        clsEntry += 8;
        break;
    case 9:
        //clsName = "  ��  ? : ";
        clsEntry += 9;
        break;
    case 11:
        //clsName = "  ����� : ";
        clsEntry += 10;
        break;
    }
    std::string clsText = sObjectMgr->GetLegionForgeStringForDBCLocale(clsEntry);
    //consoleToUtf8(clsName, clsText);
    return clsText + name;
}

uint32 PlayerBotBaseInfo::GetCharIDByNoArenaType(bool faction, uint32 prof, uint32 arenaType, std::vector<ObjectGuid>& fliters)
{
    for (ObjectGuid& guid : fliters)
    {
        if (ExistCharacterByGUID(guid))
            return 0;
    }
    if (characters.size() <= 0)
        return 0;
    for (CharInfoMap::iterator it = characters.begin();
        it != characters.end();
        it++)
    {
        if (!MatchRaceByFuction(faction, it->second.race))
            continue;
        if (it->second.profession != prof)
            continue;
    }
    return 0;
}

PlayerBotMgr::PlayerBotMgr() :
    m_BotAccountAmount(25),
    m_LastBotAccountIndex(0),
    m_MaxOnlineBot(180),
    m_BotOnlineCount(0),
    m_LFGSearchTick(0),
    m_ArenaSearchTick(0)
{
    m_BGTypes.push_back(BattlegroundTypeId::BATTLEGROUND_WS);
    m_BGTypes.push_back(BattlegroundTypeId::BATTLEGROUND_AB);
    m_BGTypes.push_back(BattlegroundTypeId::BATTLEGROUND_EY);
#ifndef NON_SINGLE_GAME
    m_BGTypes.push_back(BattlegroundTypeId::BATTLEGROUND_AV);
    m_BGTypes.push_back(BattlegroundTypeId::BATTLEGROUND_IC);
    //m_BGTypes.push_back(BattlegroundTypeId::BATTLEGROUND_SA);
#endif
}

PlayerBotMgr::~PlayerBotMgr()
{
    ClearBaseInfo();
}

PlayerBotMgr* PlayerBotMgr::instance()
{
    static PlayerBotMgr instance;
    return &instance;
}

void PlayerBotMgr::SwitchPlayerBotAI(Player* player, PlayerBotAIType aiType, bool force)
{
    if (!force && player->IsInCombat())
        return;
    if (force && player->IsInCombat())
        player->ClearInCombat();
    player->SetSelection(ObjectGuid::Empty);
    UnitAI* pAI = player->GetAI();
    player->IsAIEnabled = false;
    switch (aiType)
    {
    case PlayerBotAIType::PBAIT_FIELD:
        if (pAI)
        {
            if (dynamic_cast<BotFieldAI*>(pAI) != NULL)
            {
                player->IsAIEnabled = true;
                return;
            }
            PlayerBotMgr::m_DelayDestroyAIs[getMSTime()].push_back(pAI);
            player->SetAI(NULL);
        }
        pAI = BotFieldAI::CreateBotFieldAIByPlayerClass(player);
        if (pAI)
        {
            pAI->Reset();
            player->SetAI(pAI);
            player->IsAIEnabled = true;
        }
        break;
    case PlayerBotAIType::PBAIT_GROUP:
        if (pAI)
        {
            if (dynamic_cast<BotGroupAI*>(pAI) != NULL)
            {
                player->IsAIEnabled = true;
                return;
            }
            PlayerBotMgr::m_DelayDestroyAIs[getMSTime()].push_back(pAI);
            player->SetAI(NULL);
        }
        pAI = BotGroupAI::CreateBotGroupAIByPlayerClass(player);
        if (pAI)
        {
            pAI->Reset();
            player->SetAI(pAI);
            player->IsAIEnabled = true;
        }
        break;
    case PlayerBotAIType::PBAIT_DUEL:
        if (pAI)
        {
            if (dynamic_cast<BotDuelAI*>(pAI) != NULL)
            {
                player->IsAIEnabled = true;
                return;
            }
            PlayerBotMgr::m_DelayDestroyAIs[getMSTime()].push_back(pAI);
            player->SetAI(NULL);
        }
        pAI = BotDuelAI::CreateBotDuelAIByPlayerClass(player);
        if (pAI)
        {
            pAI->Reset();
            player->SetAI(pAI);
            player->IsAIEnabled = true;
            ((BotDuelAI*)pAI)->ResetBotAI();
        }
        break;
    case PlayerBotAIType::PBAIT_ARENA:
#ifndef CONVERT_ARENAAI_TOBG
        if (pAI)
        {
            if (dynamic_cast<BotArenaAI*>(pAI) != NULL)
            {
                player->IsAIEnabled = true;
                return;
            }
            PlayerBotMgr::m_DelayDestroyAIs[getMSTime()].push_back(pAI);
            player->SetAI(NULL);
        }
        pAI = BotArenaAI::CreateBotArenaAIByPlayerClass(player);
        if (pAI)
        {
            pAI->Reset();
            player->SetAI(pAI);
            player->IsAIEnabled = true;
        }
        break;
#endif
    case PlayerBotAIType::PBAIT_BG:
        if (pAI)
        {
            if (dynamic_cast<BotBGAI*>(pAI) != NULL)
            {
                player->IsAIEnabled = true;
                return;
            }
            PlayerBotMgr::m_DelayDestroyAIs[getMSTime()].push_back(pAI);
            player->SetAI(NULL);
        }
        player->SetAI(BotBGAI::CreateBotBGAIByPlayerClass(player));
        player->IsAIEnabled = true;
        break;
    case PlayerBotAIType::PBAIT_DUNGEON:
        if (pAI)
        {
            if (dynamic_cast<BotGroupAI*>(pAI) != NULL)
            {
                player->IsAIEnabled = true;
                return;
            }
            PlayerBotMgr::m_DelayDestroyAIs[getMSTime()].push_back(pAI);
            player->SetAI(NULL);
        }
        pAI = BotGroupAI::CreateBotGroupAIByPlayerClass(player);
        if (pAI)
        {
            pAI->Reset();
            player->SetAI(pAI);
            player->IsAIEnabled = true;
        }
        break;
    }
}

std::string PlayerBotMgr::GetPlayerLinkText(Player const* player) const
{
    const std::string& name = player->GetName();
    if (player->GetTeamId() == TeamId::TEAM_ALLIANCE)
        return "|cff0000ff|Hplayer:" + name + "|h[" + name + "]|h|r";
    else if (player->GetTeamId() == TeamId::TEAM_HORDE)
        return "|cffff0000|Hplayer:" + name + "|h[" + name + "]|h|r";
    return "|cffffffff|Hplayer:" + name + "|h[" + name + "]|h|r";
}

PlayerBotSession* PlayerBotMgr::GetBotSessionByCharGUID(ObjectGuid& guid)
{
    for (std::map<uint32, PlayerBotBaseInfo*>::iterator itInfo = m_idPlayerBotBase.begin();
        itInfo != m_idPlayerBotBase.end();
        itInfo++)
    {
        PlayerBotBaseInfo* pInfo = itInfo->second;
        if (!(pInfo->ExistCharacterByGUID(guid)))
            continue;
        WorldSession* pWorldSession = sWorld->FindSession(pInfo->id);
        if (!pWorldSession)
            return NULL;
        PlayerBotSession* pSession = dynamic_cast<PlayerBotSession*>(pWorldSession);
        return pSession;
    }
    return NULL;
}

TeamId PlayerBotMgr::GetTeamIDByPlayerBotGUID(ObjectGuid& guid)
{
    for (std::map<uint32, PlayerBotBaseInfo*>::iterator itInfo = m_idPlayerBotBase.begin();
        itInfo != m_idPlayerBotBase.end();
        itInfo++)
    {
        PlayerBotBaseInfo* pInfo = itInfo->second;
        TeamId team = pInfo->GetTeamIDByChar(guid);
        if (team == TeamId::TEAM_NEUTRAL)
            continue;
        return team;
    }
    return TeamId::TEAM_NEUTRAL;
}

bool PlayerBotMgr::IsPlayerBot(WorldSession* pSession)
{
    if (pSession && dynamic_cast<PlayerBotSession*> (pSession))
        return true;
    return false;
}

bool PlayerBotMgr::IsBotAccuntName(std::string name)
{
    if (name.size() < 10)
        return false;
    std::string head = name.substr(0, 9);
    if (head != "playerbot")
        return false;
    std::string numText = name.substr(9);
    int num = atoi(numText.c_str());
    return num > 0;
}

bool PlayerBotMgr::IsIDLEPlayerBot(Player* player)
{
    if (!player || player->IsLoading() || !player->IsInWorld())
        return false;
    if (player->IsInCombat() || !player->IsAlive())
        return false;
    if (player->InBattleground() || player->InArena() || player->GetMap()->IsDungeon() ||
        player->GetGroup() || player->isUsingLfg())
        return false;
    if (player->InBattlegroundQueue())
        return false;
    if (!player->IsSettingFinish())
        return false;
    if (player->HasAura(26013))
        return false;
    return true;
}

std::set<uint32> PlayerBotMgr::GetArenaTeamPlayerBotIDCountByTeam(TeamId team, int32 count, ArenaGroupTypes type)
{
    std::vector<uint32> allInfoEntrys;
    for (std::map<uint32, PlayerBotBaseInfo*>::iterator itInfo = m_idPlayerBotBase.begin(); itInfo != m_idPlayerBotBase.end(); itInfo++)
        allInfoEntrys.push_back(itInfo->first);
    LegionForge::Containers::RandomShuffle(allInfoEntrys);
    //unsigned seed = std::chrono::system_clock::now().time_since_epoch().count();
    //std::shuffle(allInfoEntrys.begin(), allInfoEntrys.end(), std::default_random_engine(seed));

    std::set<uint32> ids;
    if (allInfoEntrys.empty())
        return ids;
    for (uint32 infoEntry : allInfoEntrys)
    {
        PlayerBotBaseInfo* info = GetPlayerBotAccountInfo(infoEntry);
        if (!info)
            continue;
        std::vector<uint32> faildIDs = info->GetNoArenaTeamCharacterIDsByFuction((team == TEAM_ALLIANCE) ? true : false, type);
        if (faildIDs.empty())
            continue;
        for (uint32 id : faildIDs)
        {
            if (ids.find(id) != ids.end())
                continue;
            ids.insert(id);
            break;
        }
        if (ids.size() >= uint32(count))
            return ids;
    }
    ids.clear();
    return ids;
}

PlayerBotBaseInfo* PlayerBotMgr::GetPlayerBotAccountInfo(uint32 guid)
{
    std::map<uint32, PlayerBotBaseInfo*>::iterator it = m_idPlayerBotBase.find(guid);
    if (it == m_idPlayerBotBase.end())
        return NULL;
    return it->second;
}

PlayerBotBaseInfo* PlayerBotMgr::GetAccountBotAccountInfo(uint32 guid)
{
    std::map<uint32, PlayerBotBaseInfo*>::iterator it = m_idAccountBotBase.find(guid);
    if (it == m_idAccountBotBase.end())
        return NULL;
    return it->second;
}

bool PlayerBotMgr::ExistClassByRace(uint8 race, uint8 prof)
{
    switch (prof)
    {
    case 1:
        return (race != 10);
    case 2:
        return (race == 1 || race == 3 || race == 10 || race == 11);
    case 3:
        return (race == 2 || race == 3 || race == 4 || race == 6 || race == 8 || race == 10 || race == 11);
    case 4:
        return (race == 1 || race == 2 || race == 3 || race == 4 || race == 5 || race == 7 || race == 8 || race == 10);
    case 5:
        return (race == 1 || race == 3 || race == 4 || race == 5 || race == 8 || race == 10 || race == 11);
    case 6:
        return true;
    case 7:
        return (race == 2 || race == 6 || race == 8 || race == 11);
    case 8:
        return (race == 1 || race == 5 || race == 7 || race == 8 || race == 10 || race == 11);
    case 9:
        return (race == 1 || race == 2 || race == 5 || race == 7 || race == 10);
    case 11:
        return (race == 4 || race == 6);
    }
    return false;
}
void PlayerBotMgr::InitializeCreatePlayerBotName()
{
    allName.clear();
    PreparedStatement* stmt = LoginDatabase.GetPreparedStatement(LOGIN_SEL_ALLRANDOM_NAME);
    PreparedQueryResult result = LoginDatabase.Query(stmt);
    if (result)
    {
        do
        {
            Field* fields = result->Fetch();
            std::string dbName = fields[0].GetString();
            if (dbName.size() > 0)
                allName.push_back(dbName);
        } while (result->NextRow());
    }

    allArenaName.clear();
    PreparedStatement* stmt2 = LoginDatabase.GetPreparedStatement(LOGIN_SEL_ALLARENA_NAME);
    PreparedQueryResult result2 = LoginDatabase.Query(stmt2);
    if (result2)
    {
        do
        {
            Field* fields = result2->Fetch();
            std::string dbName = fields[0].GetString();
            if (dbName.size() > 0)
                allArenaName.push_back(dbName);
        } while (result2->NextRow());
    }
}

std::string PlayerBotMgr::RandomName()
{
    if (allName.size() <= 0)
        InitializeCreatePlayerBotName();

    int32 maxLoop = allName.size() / 2;
    if (maxLoop <= 0)
        return "";

    do
    {
        uint32 index = irand(0, allName.size() - 1);
        std::string selectName = allName[index];

        PreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_CHECK_NAME);
        stmt->setString(0, selectName);
        PreparedQueryResult result = CharacterDatabase.Query(stmt);

        if (!result)
            return selectName;

        --maxLoop;
        if (maxLoop <= 0)
            break;
    } while (true);

    return "";
}

std::string PlayerBotMgr::RandomArenaName()
{
    if (allArenaName.empty())
        InitializeCreatePlayerBotName();
    if (allArenaName.empty())
        return "Arena" + std::to_string(urand(0, 100));
    return allArenaName[irand(0, allArenaName.size() - 1)];
}

uint8 PlayerBotMgr::RandomRace(bool group, uint8 prof)
{
    std::vector<uint8> validRaces;

    if (group) // Alliance
        validRaces = { 1, 3, 4, 7, 11, 22 }; // Human, Dwarf, NightElf, Gnome, Draenei, Worgen
    else // Horde
        validRaces = { 2, 5, 6, 8, 9, 10, 26 }; // Orc, Undead, Tauren, Troll, Goblin, BloodElf, Pandaren(H)

    std::vector<uint8> compatibleRaces;
    for (uint8 race : validRaces)
    {
        if (ExistClassByRace(race, prof))
            compatibleRaces.push_back(race);
    }

    if (compatibleRaces.empty())
    {
        LF_LOG_ERROR("server.loading", ">> No compatible race found for class %u", prof);
        return group ? 1 : 2;
    }

    return compatibleRaces[irand(0, compatibleRaces.size() - 1)];
}

uint8 PlayerBotMgr::RandomSkinColor(uint8 race, uint8 gender, uint8 prof)
{
    uint8 maxSkinColor = 10;

    switch (race)
    {
    case RACE_HUMAN:
    case RACE_DWARF:
    case RACE_GNOME:
        maxSkinColor = 9;
        break;
    case RACE_NIGHTELF:
        maxSkinColor = 8;
        break;
    case RACE_DRAENEI:
        maxSkinColor = 13;
        break;
    case RACE_WORGEN:
        maxSkinColor = 8;
        break;
    case RACE_PANDAREN_NEUTRAL:
    case RACE_PANDAREN_ALLIANCE:
    case RACE_PANDAREN_HORDE:
        maxSkinColor = 14;
        break;
    default:
        maxSkinColor = 10;
        break;
    }

    return irand(0, maxSkinColor - 1);
}

uint8 PlayerBotMgr::RandomFace(uint8 race, uint8 gender, uint8 skinColor, uint8 prof)
{
    uint8 maxFace = 10;

    switch (race)
    {
    case RACE_WORGEN:
        maxFace = 8;
        break;
    case RACE_GOBLIN:
        maxFace = 6;
        break;
    case RACE_PANDAREN_NEUTRAL:
    case RACE_PANDAREN_ALLIANCE:
    case RACE_PANDAREN_HORDE:
        maxFace = 10;
        break;
    default:
        maxFace = 10;
        break;
    }

    return irand(0, maxFace - 1);
}

uint8 PlayerBotMgr::RandomHair(uint8 race, uint8 gender, uint8 prof)
{
    uint8 maxHair = 15;

    switch (race)
    {
    case RACE_HUMAN:
        maxHair = gender == GENDER_MALE ? 11 : 18;
        break;
    case RACE_DWARF:
        maxHair = gender == GENDER_MALE ? 10 : 13;
        break;
    case RACE_NIGHTELF:
        maxHair = gender == GENDER_MALE ? 8 : 7;
        break;
    case RACE_GNOME:
        maxHair = gender == GENDER_MALE ? 10 : 12;
        break;
    case RACE_DRAENEI:
        maxHair = gender == GENDER_MALE ? 11 : 13;
        break;
    case RACE_WORGEN:
        maxHair = gender == GENDER_MALE ? 8 : 12;
        break;
    case RACE_PANDAREN_NEUTRAL:
    case RACE_PANDAREN_ALLIANCE:
    case RACE_PANDAREN_HORDE:
        maxHair = gender == GENDER_MALE ? 9 : 10;
        break;
    default:
        maxHair = 10;
        break;
    }

    return irand(0, maxHair - 1);
}

uint8 PlayerBotMgr::RandomHairColor(uint8 race, uint8 gender, uint8 hairID, uint8 prof)
{
    uint8 maxHairColor = 10;

    switch (race)
    {
    case RACE_NIGHTELF:
        maxHairColor = 8;
        break;
    case RACE_DRAENEI:
        maxHairColor = 7;
        break;
    case RACE_WORGEN:
        maxHairColor = 11;
        break;
    case RACE_PANDAREN_NEUTRAL:
    case RACE_PANDAREN_ALLIANCE:
    case RACE_PANDAREN_HORDE:
        maxHairColor = 6;
        break;
    default:
        maxHairColor = 10;
        break;
    }

    return irand(0, maxHairColor - 1);
}

uint8 PlayerBotMgr::RandomFacialHair(uint8 race, uint8 gender, uint8 hairColor, uint8 prof)
{
    if (gender == GENDER_FEMALE)
        return 0;

    uint8 maxFacialHair = 8;

    switch (race)
    {
    case RACE_HUMAN:
        maxFacialHair = 8;
        break;
    case RACE_DWARF:
        maxFacialHair = 10;
        break;
    case RACE_NIGHTELF:
        maxFacialHair = 5;
        break;
    case RACE_GNOME:
        maxFacialHair = 7;
        break;
    case RACE_DRAENEI:
        maxFacialHair = 6;
        break;
    case RACE_WORGEN:
        maxFacialHair = 5;
        break;
    case RACE_PANDAREN_NEUTRAL:
    case RACE_PANDAREN_ALLIANCE:
    case RACE_PANDAREN_HORDE:
        maxFacialHair = 6;
        break;
    default:
        maxFacialHair = 8;
        break;
    }

    return irand(0, maxFacialHair - 1);
}

WorldPacket PlayerBotMgr::BuildCreatePlayerData(bool group, uint8 prof)
{
    std::string name = RandomName();

    if (name.empty())
    {
        LF_LOG_ERROR("server.loading", ">> Bot name generation failed!");
        name = "Bot" + std::to_string(irand(1000, 9999));
    }

    // WoW character names: max 12 chars
    if (name.length() > 12)
        name.resize(12);

    uint8 race = RandomRace(group, prof);
    uint8 gender = irand(0, 1);

    // Safe defaults, damit Player::Create nicht wegen ung�ltiger Appearance ablehnt
    uint8 skinColor = 0;
    uint8 faceID = 0;
    uint8 hairID = 0;
    uint8 hairColor = 0;
    uint8 facialHair = 0;

    LF_LOG_INFO("server.loading", ">> Building bot data: %s - Race: %u, Class: %u, Gender: %u",
        name.c_str(), race, prof, gender);

    WorldPacket data(CMSG_CREATE_CHARACTER);

    data.WriteBits(name.length(), 6);
    data.WriteBit(false);
    data.FlushBits();

    data << uint8(race);
    data << uint8(prof);
    data << uint8(gender);
    data << uint8(skinColor);
    data << uint8(faceID);
    data << uint8(hairID);
    data << uint8(hairColor);
    data << uint8(facialHair);
    data << uint8(0);  // OutfitId

    data << uint8(0);
    data << uint8(0);
    data << uint8(0);

    data.WriteString(name);

    return data;
}

void PlayerBotMgr::CreateOncePlayerBot()
{
    LF_LOG_INFO("server.loading", ">> CreateOncePlayerBot START");

    for (std::map<uint32, PlayerBotBaseInfo*>::iterator it = m_idPlayerBotBase.begin();
        it != m_idPlayerBotBase.end();
        it++)
    {
        PlayerBotBaseInfo* pInfo = it->second;

        if (pInfo->needCreateBots.size() > 0)
        {
            LF_LOG_INFO("server.loading", ">> Found %u bots in queue", (uint32)pInfo->needCreateBots.size());

            WorldPacket packet = pInfo->needCreateBots.front();
            WorldSession* pSession = sWorld->FindSession(pInfo->id);

            if (pSession)
            {
                LF_LOG_INFO("server.loading", ">> Session found, parsing packet manually");

                // Reset read position
                packet.rpos(0);

                auto createInfo = std::make_shared<WorldPackets::Character::CharacterCreateInfo>();

                uint32 nameLength = packet.ReadBits(6);
                bool hasTemplateSet = packet.ReadBit();
                packet.FlushBits();

                packet >> createInfo->Race;
                packet >> createInfo->Class;
                packet >> createInfo->Sex;
                packet >> createInfo->Skin;
                packet >> createInfo->Face;
                packet >> createInfo->HairStyle;
                packet >> createInfo->HairColor;
                packet >> createInfo->FacialHairStyle;
                packet >> createInfo->OutfitId;

                // CustomDisplay array (3 bytes)
                packet.read(createInfo->CustomDisplay.data(), createInfo->CustomDisplay.size());

                createInfo->Name = packet.ReadString(nameLength);

                if (hasTemplateSet)
                    createInfo->TemplateSet = packet.read<int32>();

                LF_LOG_INFO("server.loading", ">> Parsed character: %s, Race: %u, Class: %u",
                    createInfo->Name.c_str(), createInfo->Race, createInfo->Class);

                Player newChar(pSession);
                newChar.GetMotionMaster()->Initialize();

                if (newChar.Create(sObjectMgr->GetGenerator<HighGuid::Player>().Generate(), createInfo.get()))
                {
                    LF_LOG_INFO("server.loading", ">> Character created successfully!");

                    newChar.setCinematic(2);
                    newChar.SetAtLoginFlag(AT_LOGIN_FIRST);
                    newChar.SaveToDB(true);

                    sWorld->AddCharacterInfo(newChar.GetGUID(), pSession->GetAccountId(),
                        newChar.GetName(), newChar.GetByteValue(PLAYER_BYTES_3, PLAYER_BYTES_3_OFFSET_GENDER),
                        newChar.getRace(), newChar.getClass(), newChar.getLevel(), false);

                    sPlayerBotMgr->OnPlayerBotCreate(newChar.GetGUID(), pSession->GetAccountId(),
                        newChar.GetName(), newChar.GetByteValue(PLAYER_BYTES_3, PLAYER_BYTES_3_OFFSET_GENDER),
                        newChar.getRace(), newChar.getClass(), newChar.getLevel());

                    newChar.CleanupsBeforeDelete();
                }
                else
                {
                    LF_LOG_ERROR("server.loading", ">> Player::Create failed!");
                    newChar.CleanupsBeforeDelete();
                }
            }
            else
            {
                LF_LOG_ERROR("server.loading", ">> Bot session not found!");
            }

            pInfo->needCreateBots.pop();
            break;
        }
    }

    LF_LOG_INFO("server.loading", ">> CreateOncePlayerBot END");
}

bool PlayerBotMgr::CreateQueuedPlayerBotForSession(PlayerBotBaseInfo* pInfo, WorldSession* pSession)
{
    if (!pInfo)
        return false;

    if (!pSession)
    {
        LF_LOG_ERROR("server.loading", ">> CreateQueuedPlayerBotForSession failed: no session");
        return false;
    }

    if (pInfo->needCreateBots.empty())
        return false;

    WorldPacket packet = pInfo->needCreateBots.front();
    pInfo->needCreateBots.pop();

    packet.rpos(0);

    auto createInfo = std::make_shared<WorldPackets::Character::CharacterCreateInfo>();

    uint32 nameLength = packet.ReadBits(6);
    bool hasTemplateSet = packet.ReadBit();
    packet.FlushBits();

    packet >> createInfo->Race;
    packet >> createInfo->Class;
    packet >> createInfo->Sex;
    packet >> createInfo->Skin;
    packet >> createInfo->Face;
    packet >> createInfo->HairStyle;
    packet >> createInfo->HairColor;
    packet >> createInfo->FacialHairStyle;
    packet >> createInfo->OutfitId;

    packet.read(createInfo->CustomDisplay.data(), createInfo->CustomDisplay.size());
    createInfo->Name = packet.ReadString(nameLength);

    if (hasTemplateSet)
        createInfo->TemplateSet = packet.read<int32>();

    LF_LOG_INFO("server.loading", ">> Creating startup bot: %s, Race: %u, Class: %u, Account: %u",
        createInfo->Name.c_str(), createInfo->Race, createInfo->Class, pSession->GetAccountId());

    Player newChar(pSession);
    newChar.GetMotionMaster()->Initialize();

    if (!newChar.Create(sObjectMgr->GetGenerator<HighGuid::Player>().Generate(), createInfo.get()))
    {
        LF_LOG_ERROR("server.loading", ">> Startup Player::Create failed for account %u", pSession->GetAccountId());
        newChar.CleanupsBeforeDelete();
        return false;
    }

    newChar.setCinematic(2);
    newChar.SetAtLoginFlag(AT_LOGIN_FIRST);
    newChar.SaveToDB(true);

    sWorld->AddCharacterInfo(newChar.GetGUID(), pSession->GetAccountId(),
        newChar.GetName(), newChar.GetByteValue(PLAYER_BYTES_3, PLAYER_BYTES_3_OFFSET_GENDER),
        newChar.getRace(), newChar.getClass(), newChar.getLevel(), false);

    sPlayerBotMgr->OnPlayerBotCreate(newChar.GetGUID(), pSession->GetAccountId(),
        newChar.GetName(), newChar.GetByteValue(PLAYER_BYTES_3, PLAYER_BYTES_3_OFFSET_GENDER),
        newChar.getRace(), newChar.getClass(), newChar.getLevel());

    newChar.CleanupsBeforeDelete();
    return true;
}

void PlayerBotMgr::ClearBaseInfo()
{
    for (std::map<uint32, PlayerBotBaseInfo*>::iterator it = m_idPlayerBotBase.begin();
        it != m_idPlayerBotBase.end();
        it++)
    {
        delete it->second;
    }
    m_idPlayerBotBase.clear();
    for (std::map<uint32, PlayerBotBaseInfo*>::iterator it = m_idAccountBotBase.begin();
        it != m_idAccountBotBase.end();
        it++)
    {
        delete it->second;
    }
    m_idAccountBotBase.clear();
    for (std::map<uint32, PlayerBotBaseInfo*>::iterator it = m_cloneAccounts.begin();
        it != m_cloneAccounts.end();
        it++)
    {
        delete it->second;
    }
    m_cloneAccounts.clear();
    m_cloneRecords.clear();
}

void PlayerBotMgr::UpdateLastAccountIndex(std::string& username)
{
    //std::unique_lock<std::mutex> sessionGuard(PlayerBotMgr::g_uniqueLock);
    if (username.empty())
        return;
    std::string querySql = "SELECT id FROM account WHERE username='" + username + "'";
    QueryResult result = LoginDatabase.Query(querySql.c_str());
    if (result)
    {
        Field* fields = result->Fetch();
        if (fields)
        {
            uint32 id = fields[0].GetUInt32();
            m_LastBotAccountIndex = id;
        }
    }
}

void PlayerBotMgr::SupplementAccount()
{
    uint32 needAccount = m_BotAccountAmount * 2 - m_idPlayerBotBase.size();
    if (needAccount <= 0)
        return;

    for (uint32 i = 0; i < needAccount; ++i)
    {
        ++m_LastBotAccountIndex;
        std::string userName = "playerbot" + std::to_string(m_LastBotAccountIndex);
        std::string password = userName;
        std::string bnetEmail = userName + "@botaccounts";

        // Create Account or get, if available
        AccountOpResult accRes = sAccountMgr->CreateAccount(userName, password);
        if (accRes != AccountOpResult::AOR_OK && accRes != AccountOpResult::AOR_NAME_ALREADY_EXIST)
            continue;

        QueryResult accResQr = LoginDatabase.PQuery(
            "SELECT id, username, sha_pass_hash FROM account WHERE username='%s'",
            userName.c_str());
        if (!accResQr)
            continue;

        Field* accF = accResQr->Fetch();
        uint32 accountId = accF[0].GetUInt32();
        std::string accName = accF[1].GetString();
        std::string accHash = accF[2].GetString();

        // Create BattlenetAccount
        // createGameAccount = false -> we do NOT want an automatically generated game account,
        // so that we can link our own "playerbotX" cleanly and index 1 is free
        AccountOpResult bnetRes = Battlenet::AccountMgr::CreateBattlenetAccount(
            bnetEmail, password, /*createGameAccount=*/false, /*outGameAccountName=*/nullptr);

        if (bnetRes != AccountOpResult::AOR_OK && bnetRes != AccountOpResult::AOR_NAME_ALREADY_EXIST)
            continue;

        // Determine BNet ID
        QueryResult bnQr = LoginDatabase.PQuery(
            "SELECT id FROM battlenet_accounts WHERE email='%s'",
            bnetEmail.c_str());
        if (!bnQr)
            continue;

        uint32 battlenetId = bnQr->Fetch()[0].GetUInt32();

        // Determine the next battlenet_index
        uint32 bnIndex = 1;
        if (QueryResult idxQr = LoginDatabase.PQuery(
            "SELECT COALESCE(MAX(battlenet_index), 0) FROM account WHERE battlenet_account=%u",
            battlenetId))
        {
            bnIndex = idxQr->Fetch()[0].GetUInt32() + 1;
        }

        // Link
        LoginDatabase.PExecute(
            "UPDATE account SET battlenet_account=%u, battlenet_index=%u WHERE id=%u",
            battlenetId, bnIndex, accountId);

        // Maintain internal structure
        if (m_idPlayerBotBase.find(accountId) == m_idPlayerBotBase.end())
        {
            PlayerBotBaseInfo* pInfo = new PlayerBotBaseInfo(accountId, accName.c_str(), accHash, false, battlenetId);
            m_idPlayerBotBase[accountId] = pInfo;
        }

        m_LastBotAccountIndex = accountId;
    }
}

void PlayerBotMgr::DestroyBotMail(uint32 guid)
{
    char sql[256] = { 0 };
    snprintf(sql, 255, "DELETE FROM mail WHERE receiver = %d", guid);
    CharacterDatabase.Execute(sql);
    //memset(sql, 0, 256);
    //snprintf(sql, 255, "DELETE FROM mail_items WHERE receiver = %d", guid);
    //CharacterDatabase.Execute(sql);
    PreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_DEL_MAIL_ITEMS);
    stmt->setUInt32(0, guid);
    CharacterDatabase.Execute(stmt);
}

void PlayerBotMgr::AddNewAccountBotBaseInfo(std::string name)
{
    std::string upperName = boost::algorithm::to_upper_copy(name);
    std::string sql("SELECT id, username, sha_pass_hash FROM account WHERE `username`='"); sql += upperName + "'";
    QueryResult result = LoginDatabase.Query(sql.c_str());
    if (!result)
        return;
    Field* fields = result->Fetch();
    uint32 id = fields[0].GetUInt32();
    std::string username = fields[1].GetString();
    std::string pass = fields[2].GetString();
    uint32 bnetId = fields[3].GetUInt32();

    if (m_idAccountBotBase.find(id) == m_idAccountBotBase.end())
    {
        PlayerBotBaseInfo* pInfo = new PlayerBotBaseInfo(id, username.c_str(), pass, true, bnetId);
        m_idAccountBotBase[id] = pInfo;
    }
}

void PlayerBotMgr::LoadPlayerBotBaseInfo()
{
    uint32 oldMSTime = getMSTime();

    if (sConfigMgr->GetIntDefault("pbot", 1) == 0)
        return;

    m_BotAccountAmount = uint32(sConfigMgr->GetIntDefault("PlayerBot.AccountsPerTeam", 25));
    if (m_BotAccountAmount < 1)
        m_BotAccountAmount = 1;

    ClearBaseInfo();
    QueryResult result = LoginDatabase.Query("SELECT id, username, sha_pass_hash, battlenet_account FROM account");
    if (!result)
    {
        LF_LOG_INFO("server.loading", ">> LoadPlayerBot Find 0 account!");
        return;
    }

    do
    {
        Field* fields = result->Fetch();

        uint32 id = fields[0].GetUInt32();
        std::string username = fields[1].GetString();
        std::string pass = fields[2].GetString();
        uint32 bnetId = fields[3].GetUInt32();

        std::string lowerName = boost::algorithm::to_lower_copy(username);
        if (IsBotAccuntName(lowerName))
        {
            if (m_idPlayerBotBase.find(id) == m_idPlayerBotBase.end())
            {
                PlayerBotBaseInfo* pInfo = new PlayerBotBaseInfo(id, username.c_str(), pass, false, bnetId);
                m_idPlayerBotBase[id] = pInfo;
            }
            m_LastBotAccountIndex = id;
        }
        else
        {
            if (m_idAccountBotBase.find(id) == m_idAccountBotBase.end())
            {
                PlayerBotBaseInfo* pInfo = new PlayerBotBaseInfo(id, username.c_str(), pass, true, bnetId);
                m_idAccountBotBase[id] = pInfo;
            }
        }
        //if (m_idPlayerBotBase.size() >= m_BotAccountAmount * 2)
        //	break;
    } while (result->NextRow());

    SupplementAccount();
    LoadCloneAccounts();

    if (m_idPlayerBotBase.size() > 0 || m_idAccountBotBase.size() > 0 || m_cloneAccounts.size() > 0)
        LoadCharBaseInfo();

    LF_LOG_INFO("server.loading", ">> Loaded %u Player bot account base info in %u ms", m_idPlayerBotBase.size(), GetMSTimeDiffToNow(oldMSTime));
}

void PlayerBotMgr::LoadCharBaseInfo()
{
    QueryResult result = CharacterDatabase.Query("SELECT guid, account, name, race, class, gender, level FROM characters");

    if (!result)
    {
        LF_LOG_INFO("server.loading", ">> LoadPlayerBot Find 0 characters!");
        return;
    }

    do
    {
        Field* fields = result->Fetch();

        uint64 guid = fields[0].GetUInt64();
        uint32 accID = fields[1].GetUInt32();
        PlayerBotBaseInfo* pInfo = GetPlayerBotAccountInfo(accID);
        if (pInfo)
        {
            if (pInfo->characters.find(guid) == pInfo->characters.end())
            {
                std::string charName = fields[2].GetString();
                uint16 race = fields[3].GetInt16();
                uint16 pro = fields[4].GetInt16();
                uint16 gender = fields[5].GetInt16();
                uint16 level = fields[6].GetInt16();
                pInfo->characters.emplace(guid, PlayerBotCharBaseInfo{ guid, accID, charName, race, pro, gender, level });
                DestroyBotMail(guid);
            }
        }
        else if (pInfo = GetAccountBotAccountInfo(accID))
        {
            if (pInfo->characters.find(guid) == pInfo->characters.end())
            {
                std::string charName = fields[2].GetString();
                uint16 race = fields[3].GetInt16();
                uint16 pro = fields[4].GetInt16();
                uint16 gender = fields[5].GetInt16();
                uint16 level = fields[6].GetInt16();
                pInfo->characters.emplace(guid, PlayerBotCharBaseInfo{ guid, accID, charName, race, pro, gender, level });
                //DestroyBotMail(guid);
            }
        }
        else if (pInfo = GetCloneAccountInfo(accID))
        {
            if (pInfo->characters.find(guid) == pInfo->characters.end())
            {
                std::string charName = fields[2].GetString();
                uint16 race = fields[3].GetInt16();
                uint16 pro = fields[4].GetInt16();
                uint16 gender = fields[5].GetInt16();
                uint16 level = fields[6].GetInt16();
                pInfo->characters.emplace(guid, PlayerBotCharBaseInfo{ guid, accID, charName, race, pro, gender, level });
            }
        }
    } while (result->NextRow());
}

void PlayerBotMgr::UpAllPlayerBotSession()
{
    PlayerBotSetting::Initialize();
    for (std::map<uint32, PlayerBotBaseInfo*>::iterator it = m_idPlayerBotBase.begin();
        it != m_idPlayerBotBase.end();
        it++)
    {
        PlayerBotBaseInfo* pInfo = it->second;
        UpPlayerBotSessionByBaseInfo(pInfo, false);
    }
}

PlayerBotSession* PlayerBotMgr::UpPlayerBotSessionByBaseInfo(PlayerBotBaseInfo* pAcc, bool accountInfo)
{
    if (!pAcc)
        return NULL;
    WorldSession* pSession = sWorld->FindSession(pAcc->id);
    if (pSession)
        return NULL;
    std::string name = pAcc->username.c_str();
    std::string battlenetAccountName;
    PlayerBotSession* pBotSession = new PlayerBotSession{ pAcc->id, name, pAcc->battlenetAccountId, AccountTypes::SEC_GAMEMASTER, 2, 0, LocaleConstant::LOCALE_deDE, 0, false, std::string(battlenetAccountName) };
    //pbSession->ReadAddonsInfo("");
    if (accountInfo)
        pBotSession->SetAccountBotSession();

    pBotSession->LoadPermissions();
    sWorld->AddSession(pBotSession);
    return pBotSession;
}

void PlayerBotMgr::OnPlayerBotCreate(ObjectGuid const& guid, uint32 accountId, std::string const& name, uint8 gender, uint8 race, uint8 playerClass, uint8 level)
{
    PlayerBotBaseInfo* pInfo = GetPlayerBotAccountInfo(accountId);
    if (!pInfo)
        pInfo = GetCloneAccountInfo(accountId);
    if (!pInfo)
        return;
    uint32 id = uint32(guid.GetCounter());
    if (pInfo->characters.find(id) != pInfo->characters.end())
    {
        return;
    }
    pInfo->characters[id] = PlayerBotCharBaseInfo(id, accountId, name, uint16(race), uint16(playerClass), uint16(gender), uint16(level));
}

void PlayerBotMgr::OnAccountBotCreate(ObjectGuid const& guid, uint32 accountId, std::string const& name, uint8 gender, uint8 race, uint8 playerClass, uint8 level)
{
    PlayerBotBaseInfo* pInfo = GetAccountBotAccountInfo(accountId);
    if (!pInfo)
        return;
    uint32 id = uint32(guid.GetCounter());
    if (pInfo->characters.find(id) != pInfo->characters.end())
    {
        return;
    }
    pInfo->characters[id] = PlayerBotCharBaseInfo(id, accountId, name, uint16(race), uint16(playerClass), uint16(gender), uint16(level));
}

void PlayerBotMgr::OnAccountBotDelete(ObjectGuid& guid, uint32 accountId)
{
    PlayerBotBaseInfo* pInfo = GetAccountBotAccountInfo(accountId);
    if (!pInfo)
        return;
    pInfo->RemoveCharacterByGUID(guid);
}

void PlayerBotMgr::PlaceRecruitTemplate(Player* bot)
{
    if (!bot || !bot->IsInWorld() || !IsRecruitTemplate(bot))
        return;

    PlayerInfo const* info = sObjectMgr->GetPlayerInfo(bot->getRace(), bot->getClass());
    if (!info || info->mapId != bot->GetMapId())
        return;

    float dx = bot->GetPositionX() - info->positionX;
    float dy = bot->GetPositionY() - info->positionY;
    if ((dx * dx + dy * dy) <= 1.0f && bot->GetMapId() == info->mapId)
        return;

    bot->UpdatePosition(info->positionX, info->positionY, info->positionZ, info->orientation, true);
    bot->SetStandState(UNIT_STAND_STATE_STAND);
    bot->SaveToDB(false);
}

void PlayerBotMgr::OnPlayerBotLogin(WorldSession* pSession, Player* pPlayer)
{
    LegionForge::SetCrashBreadcrumb("PlayerBotMgr::OnPlayerBotLogin");
    bool loggingClone = false;
    for (BotCloneRecord& record : m_cloneRecords)
    {
        if (record.accountId == pSession->GetAccountId() && record.loggingIn && !record.release)
        {
            loggingClone = true;
            if (pPlayer->getLevel() < record.level)
                pPlayer->GiveLevel(record.level);
            break;
        }
    }

    ++m_BotOnlineCount;
    Group* pGroup = pPlayer->GetGroup();
    if (pGroup)
    {
        if (!pGroup->GroupExistRealPlayer())
        {
            pPlayer->RemoveFromGroup(RemoveMethod::GROUP_REMOVEMETHOD_LEAVE);
        }
        else
            SwitchPlayerBotAI(pPlayer, PlayerBotAIType::PBAIT_GROUP, false);
    }
    else
        SwitchPlayerBotAI(pPlayer, PlayerBotAIType::PBAIT_FIELD, false);

    if (pPlayer->GetBattleground())
    {
        pPlayer->LeaveBattleground();
        if (pSession)
            pSession->HandleMoveWorldportAck();
    }

    BotUtility::RemoveArenaBotSpellsByPlayer(pPlayer);
    sPlayerBotTalkMgr->JoinDefaultChannel(pPlayer);

    if (PlayerBotSession* pBotSession = dynamic_cast<PlayerBotSession*>(pSession))
    {
        if (!loggingClone && !pSession->HasSchedules() && !pPlayer->EquipIsTidiness())
        {
            uint32 curTType = pPlayer->FindTalentType();
            uint32 newTType = curTType;
            while (newTType == curTType)
                newTType = urand(0, 2);
            BotGlobleSchedule schedule2(BotGlobleScheduleType::BGSType_Settting, 0);
            schedule2.parameter1 = pPlayer->getLevel();
            schedule2.parameter2 = pPlayer->getLevel();
            schedule2.parameter3 = newTType + 1;
            pBotSession->PushScheduleToQueue(schedule2);
        }
    }

    if (IsRecruitTemplate(pPlayer))
        PlaceRecruitTemplate(pPlayer);

    FinishCloneJoin(pPlayer);
}

void PlayerBotMgr::OnPlayerBotLogout(WorldSession* pSession)
{
    --m_BotOnlineCount;
    if (m_BotOnlineCount < 0) m_BotOnlineCount = 0;

    PlayerBotSession* pBotSession = dynamic_cast<PlayerBotSession*>(pSession);
    if (pBotSession && !pBotSession->HasScheduleByType(BotGlobleScheduleType::BGSType_Online) &&
        !pBotSession->HasScheduleByType(BotGlobleScheduleType::BGSType_Online_GUID))
        pBotSession->ClearAllSchedule();
}

void PlayerBotMgr::OnPlayerBotLeaveOriginalGroup(Player* pPlayer)
{
    SwitchPlayerBotAI(pPlayer, PlayerBotAIType::PBAIT_FIELD, true);
}

void PlayerBotMgr::LoginGroupBotByPlayer(Player* pPlayer)
{
#ifndef INCOMPLETE_BOT
    if (pPlayer->IsPlayerBot())
        return;
    int32 isok = sConfigMgr->GetIntDefault("pbot", 1);
    Group* pGroup = pPlayer->GetGroup();
    if (!pGroup || pGroup->isBFGroup() || pGroup->isBGGroup())
        return;
    Group::MemberSlotList const& memList = pGroup->GetMemberSlots();
    for (Group::MemberSlot const& slot : memList)
    {
        ObjectGuid guid = slot.guid;
        if (guid == pPlayer->GetGUID())
            continue;
        Player* friendPlayer = ObjectAccessor::FindPlayer(guid);
        if (friendPlayer)
            continue;
        if (isok == 0)
            AddNewPlayerBotByGUID2(guid);
        else
            DelayLoginPlayerBotByGUID(guid);
    }
#endif
}

void PlayerBotMgr::LoginFriendBotByPlayer(Player* pPlayer)
{
    //#ifndef INCOMPLETE_BOT
    //	if (pPlayer->IsPlayerBot())
    //		return;
    //	int32 isok = sConfigMgr->GetIntDefault("pbot", 1);
    //
    //	std::vector<ObjectGuid> friends = pPlayer->GetSocial()->Get();
    //	for (ObjectGuid& guid : friends)
    //	{
    //
    //	if (isok==0)
    //		AddNewPlayerBotByGUID2(guid);
    //		else
    //		DelayLoginPlayerBotByGUID(guid);
    //	}
    //#else
    //	std::string allonlineText;
    //	consoleToUtf8(std::string("|cffff8800������?��?����?��������?�|r"), allonlineText);
    //	sWorld->SendGlobalText(allonlineText.c_str(), NULL);
    //#endif
}

void PlayerBotMgr::LogoutAllGroupPlayerBot(Group* pGroup, bool force)
{
    if (!pGroup)
        return;
    if (!force && pGroup->GroupExistRealPlayer())
        return;
    Group::MemberSlotList const& memList = pGroup->GetMemberSlots();
    for (Group::MemberSlot const& slot : memList)
    {
        ObjectGuid guid = slot.guid;
        Player* player = ObjectAccessor::FindPlayer(guid);
        if (!player || !player->IsPlayerBot())
            continue;
        WorldSession* pSession = player->GetSession();
        if (pSession)
            pSession->LogoutPlayer(false);
    }
}

bool PlayerBotMgr::AllPlayerLeaveBG(uint32 account)
{
    if (account == 0)
        return false;
    //std::unique_lock<std::mutex> sessionGuard(PlayerBotMgr::g_uniqueLock);
    WorldSession* pSession = sWorld->FindSession(account);
    if (pSession && pSession->IsBotSession() && !pSession->PlayerLoading())
    {
        Player* pPlayer = pSession->GetPlayer();
        if (!pPlayer || pPlayer->GetTransport() || !pPlayer->InBattleground())
            return false;
        const Battleground* bg = pPlayer->GetBattleground();
        if (!bg || bg->GetStatus() == BattlegroundStatus::STATUS_WAIT_LEAVE || bg->GetStatus() == BattlegroundStatus::STATUS_WAIT_JOIN)
            return false;
        ((Battleground*)bg)->EndBattleground((pPlayer->GetTeamId() == TEAM_ALLIANCE) ? HORDE : ALLIANCE);
        return true;
    }
    return false;
}

void PlayerBotMgr::AllPlayerBotRandomLogin(const char* name)
{
    int32 needOnline = m_MaxOnlineBot - m_BotOnlineCount;
    if (needOnline <= 0)
        return;
    for (std::map<uint32, PlayerBotBaseInfo*>::iterator it = m_idPlayerBotBase.begin();
        it != m_idPlayerBotBase.end();
        it++)
    {
        PlayerBotBaseInfo* pInfo = it->second;
        WorldSession* pSession = sWorld->FindSession(pInfo->id);
        if (pSession && pSession->IsBotSession() && !pSession->PlayerLoading() && !pSession->GetPlayer())
        {
            if (pInfo->characters.size() <= 0)
                continue;

            if (name[0] != '\0')
            {
                for (auto i = 0; i < pInfo->characters.size(); ++i)
                {
                    if (strcmp(name, pInfo->characters[i].name.c_str()) == 0)
                    {
                        PlayerBotCharBaseInfo& charInfo = pInfo->characters[i];
                        WorldPacket _worldPacket(CMSG_PLAYER_LOGIN);
                        WorldPackets::Character::PlayerLogin cmd(std::move(_worldPacket));
                        cmd.Guid = ObjectGuid::Create<HighGuid::Player>(charInfo.guid);
                        cmd.FarClip = 0.0f;
                        pSession->AddLegitCharacter(cmd.Guid);
                        pSession->HandlePlayerLoginOpcode(cmd);
                        pSession->HandleContinuePlayerLogin();
                        return;
                    }
                }
            }
            else
            {
                int sel = irand(0, pInfo->characters.size() - 1);
                for (auto itChar = pInfo->characters.begin();
                    itChar != pInfo->characters.end();
                    itChar++)
                {
                    if (sel <= 0)
                    {
                        PlayerBotCharBaseInfo& charInfo = itChar->second;
                        WorldPacket _worldPacket(CMSG_PLAYER_LOGIN);
                        WorldPackets::Character::PlayerLogin cmd(std::move(_worldPacket));
                        cmd.Guid = ObjectGuid::Create<HighGuid::Player>(charInfo.guid);
                        cmd.FarClip = 0.0f;
                        pSession->AddLegitCharacter(cmd.Guid);
                        pSession->HandlePlayerLoginOpcode(cmd);
                        pSession->HandleContinuePlayerLogin();
                        --needOnline;
                        break;
                    }
                    --sel;
                }
            }
            if (needOnline <= 0)
                return;
        }
    }
}

void PlayerBotMgr::AllPlayerBotLogout()
{
    //std::unique_lock<std::mutex> sessionGuard(PlayerBotMgr::g_uniqueLock);
    for (std::map<uint32, PlayerBotBaseInfo*>::iterator it = m_idPlayerBotBase.begin();
        it != m_idPlayerBotBase.end();
        it++)
    {
        PlayerBotBaseInfo* pInfo = it->second;
        PlayerBotLogout(pInfo->id);
    }
    for (std::map<uint32, PlayerBotBaseInfo*>::iterator it = m_idAccountBotBase.begin();
        it != m_idAccountBotBase.end();
        it++)
    {
        PlayerBotBaseInfo* pInfo = it->second;
        PlayerBotLogout(pInfo->id);
    }
}

bool PlayerBotMgr::PlayerBotLogout(uint32 account)
{
    if (account == 0)
        return false;
    //std::unique_lock<std::mutex> sessionGuard(PlayerBotMgr::g_uniqueLock);
    WorldSession* pSession = sWorld->FindSession(account);
    if (pSession && pSession->IsBotSession() && !pSession->PlayerLoading())
    {
        Player* pBot = pSession->GetPlayer();
        if (!pBot || !pBot->IsPlayerBot() || !pBot->IsSettingFinish())
            return false;
        PlayerBotSession* pBotSession = dynamic_cast<PlayerBotSession*>(pSession);
        if (pBotSession)
        {
            if (pBotSession->HasSchedules())
                pBotSession->ClearAllSchedule();

            pSession->LogoutPlayer(false);
            return true;
        }
    }
    return false;
}

void PlayerBotMgr::SupplementPlayerBot()
{
    LF_LOG_INFO("server.loading", ">> SupplementPlayerBot START");

    for (std::map<uint32, PlayerBotBaseInfo*>::iterator itInfo = m_idPlayerBotBase.begin();
        itInfo != m_idPlayerBotBase.end(); itInfo++)
    {
        PlayerBotBaseInfo* pInfo = itInfo->second;

        LF_LOG_INFO("server.loading", ">> Processing bot info ID: %u", itInfo->first);

        if (pInfo->username.size() <= 0)
        {
            LF_LOG_INFO("server.loading", ">> Bot username empty, skipping");
            continue;
        }

        if (pInfo->characters.size() >= 18)
        {
            LF_LOG_INFO("server.loading", ">> Bot already has 18 chars, skipping");
            continue;
        }

        WorldSession* pSession = sWorld->FindSession(pInfo->id);
        if (!pSession)
        {
            LF_LOG_INFO("server.loading", ">> Create bot, but session offline.");
            continue;
        }

        LF_LOG_INFO("server.loading", ">> Bot session found, username: %s", pInfo->username.c_str());

        std::string firstName = pInfo->username.substr(6);
        char botname[30] = { 0 };

        LF_LOG_INFO("server.loading", ">> FirstName extracted: %s", firstName.c_str());

        for (int i = 1; i < 10; i++)
        {
            if (i == 6) continue;

            if (!pInfo->ExistClass(true, i))
            {
                memset(botname, 0, 30);
                sprintf(botname, "%sA%d", firstName.c_str(), i);
                LF_LOG_INFO("server.loading", ">> Pushing Alliance bot: %s, class: %u", botname, i);
                pInfo->needCreateBots.push(BuildCreatePlayerData(true, i));
            }

            if (!pInfo->ExistClass(false, i))
            {
                memset(botname, 0, 30);
                sprintf(botname, "%sB%d", firstName.c_str(), i);
                LF_LOG_INFO("server.loading", ">> Pushing Horde bot: %s, class: %u", botname, i);
                pInfo->needCreateBots.push(BuildCreatePlayerData(false, i));
            }
        }

        if (!pInfo->ExistClass(true, 11))
        {
            memset(botname, 0, 30);
            sprintf(botname, "%sA11", firstName.c_str());
            LF_LOG_INFO("server.loading", ">> Pushing Alliance Druid bot: %s", botname);
            pInfo->needCreateBots.push(BuildCreatePlayerData(true, 11));
        }

        if (!pInfo->ExistClass(false, 11))
        {
            memset(botname, 0, 30);
            sprintf(botname, "%sB11", firstName.c_str());
            LF_LOG_INFO("server.loading", ">> Pushing Horde Druid bot: %s", botname);
            pInfo->needCreateBots.push(BuildCreatePlayerData(false, 11));
        }

        LF_LOG_INFO("server.loading", ">> Total bots in queue: %u", (uint32)pInfo->needCreateBots.size());
    }

    LF_LOG_INFO("server.loading", ">> Calling CreateOncePlayerBot()");
    CreateOncePlayerBot();
}

void PlayerBotMgr::SupplementOneRandomPlayerBotPerAccount()
{
    LF_LOG_INFO("server.loading", ">> SupplementOneRandomPlayerBotPerAccount START");

    // Valid classes for this core/expansion. Death Knight (6) is intentionally skipped,
    // same as SupplementPlayerBot(), because these are normal starter bots.
    static uint8 const botClasses[] = { 1, 2, 3, 4, 5, 7, 8, 9, 11 };

    uint32 queuedCreateCount = 0;

    for (std::map<uint32, PlayerBotBaseInfo*>::iterator itInfo = m_idPlayerBotBase.begin();
        itInfo != m_idPlayerBotBase.end(); ++itInfo)
    {
        PlayerBotBaseInfo* pInfo = itInfo->second;
        if (!pInfo)
            continue;

        // Idempotent: if this bot account already owns a character,
        // do not create another one on the next restart.
        if (!pInfo->characters.empty())
            continue;

        // Character creation uses the existing Player::Create path and needs a WorldSession.
        // Startup calls this after UpAllPlayerBotSession(), but keep the fallback so the
        // function is also safe when called manually.
        WorldSession* pSession = sWorld->FindSession(pInfo->id);
        if (!pSession)
            pSession = UpPlayerBotSessionByBaseInfo(pInfo, false);

        if (!pSession)
        {
            LF_LOG_ERROR("server.loading", ">> Could not create startup bot for account %u: no session", pInfo->id);
            continue;
        }

        uint8 playerClass = botClasses[urand(0, (sizeof(botClasses) / sizeof(uint8)) - 1)];
        bool alliance = urand(0, 1) == 0;

        pInfo->needCreateBots.push(BuildCreatePlayerData(alliance, playerClass));

        if (CreateQueuedPlayerBotForSession(pInfo, pSession))
        {
            ++queuedCreateCount;
            LF_LOG_INFO("server.loading", ">> Created one random startup bot for account %u", pInfo->id);
        }
    }

    LF_LOG_INFO("server.loading", ">> SupplementOneRandomPlayerBotPerAccount END - created %u bots", queuedCreateCount);
}

void PlayerBotMgr::OnRealPlayerJoinBattlegroundQueue(uint32 bgTypeId, uint32 level)
{
    BattlegroundTypeId _bgTypeId = BattlegroundTypeId(bgTypeId);
    BattlegroundQueueTypeId bgQueueTypeId = BattlegroundMgr::BGQueueTypeId(BattlegroundTypeId(bgTypeId), 0);
    BattlegroundQueue& bgQueue = sBattlegroundMgr->GetBattlegroundQueue(bgQueueTypeId);
    Battleground* bg = sBattlegroundMgr->GetBattlegroundTemplate(BattlegroundTypeId(bgTypeId));
    if (!bg)
        return;

    uint32 needAlliancePlayerCount = 5;
    uint32 needHordePlayerCount = 5;
    uint32 _time = 0;

    for (uint32 j = BattlegroundBracketId::BG_BRACKET_ID_FIRST; j <= BattlegroundBracketId::BG_BRACKET_ID_LAST; j++)
    {
        BattlegroundBracketId bracket = BattlegroundBracketId(j);
        PVPDifficultyEntry const* bracketEntry = DB2Manager::GetBattlegroundBracketById(bg->GetMapId(), bracket);
        if (!bracketEntry)
            continue;
        if (!bgQueue.ExistRealPlayer(bracketEntry))
            continue;
        if (needAlliancePlayerCount > 0)
        {
            for (uint32 k = 0; k <= needAlliancePlayerCount; k++)
                AddNewPlayerBotToBG(TeamId::TEAM_ALLIANCE, bracketEntry->MinLevel, bracketEntry->MaxLevel, _bgTypeId);
        }

        if (needHordePlayerCount > 0)
        {
            for (uint32 k = 0; k <= needHordePlayerCount; k++)
                AddNewPlayerBotToBG(TeamId::TEAM_HORDE, bracketEntry->MinLevel, bracketEntry->MaxLevel, _bgTypeId);
        }

        printf("QueryNeedPlayerCount %d %d \n", needAlliancePlayerCount, needHordePlayerCount);
        return;
    }
}

void PlayerBotMgr::OnRealPlayerLeaveBattlegroundQueue(uint32 bgTypeId, uint32 level)
{
    BattlegroundQueueTypeId bgQueueTypeId = BattlegroundMgr::BGQueueTypeId(BattlegroundTypeId(bgTypeId), 0);
    BattlegroundQueue& bgQueue = sBattlegroundMgr->GetBattlegroundQueue(bgQueueTypeId);
    Battleground* bg = sBattlegroundMgr->GetBattlegroundTemplate(BattlegroundTypeId(bgTypeId));
    if (!bg)
        return;
    PVPDifficultyEntry const* bracketEntry = sDB2Manager.GetBattlegroundBracketByLevel(bg->GetMapId(), level);
    if (!bracketEntry)
        return;

    if (bgQueue.ExistRealPlayer(bracketEntry))
        return;
    const SessionMap& allSession = sWorld->GetAllSessions();
    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {
        PlayerBotSession* pSession = dynamic_cast<PlayerBotSession*>((WorldSession*)itSession->second);
        if (!pSession)
            continue;
        Player* player = pSession->GetPlayer();
        if (!player || player->IsLoading())
            continue;
        if (player->InBattleground() || player->InArena() || !player->IsInWorld())
            continue;
        uint32 lv = player->getLevel();
        if (lv < bracketEntry->MinLevel || lv > bracketEntry->MaxLevel)
            continue;
        if (player->InBattlegroundQueue())
        {
            BotGlobleSchedule schedule1(BotGlobleScheduleType::BGSType_OutBGQueue, 0);
            schedule1.parameter1 = bgTypeId;
            pSession->PushScheduleToQueue(schedule1);
        }
    }
}

void PlayerBotMgr::OnRealPlayerLeaveArenaQueue(uint32 bgTypeId, uint32 level, uint32 aaType)
{
    BattlegroundQueueTypeId bgQueueTypeId = BattlegroundMgr::BGQueueTypeId(BattlegroundTypeId(bgTypeId), aaType);
    BattlegroundQueue& bgQueue = sBattlegroundMgr->GetBattlegroundQueue(bgQueueTypeId);
    Battleground* bg = sBattlegroundMgr->GetBattlegroundTemplate(BattlegroundTypeId(bgTypeId));
    if (!bg)
        return;
    PVPDifficultyEntry const* bracketEntry = sDB2Manager.GetBattlegroundBracketByLevel(bg->GetMapId(), level);
    if (!bracketEntry)
        return;

    if (bgQueue.ExistRealPlayer(bracketEntry))
        return;
    const SessionMap& allSession = sWorld->GetAllSessions();
    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {
        PlayerBotSession* pSession = dynamic_cast<PlayerBotSession*>((WorldSession*)itSession->second);
        if (!pSession)
            continue;
        Player* player = pSession->GetPlayer();
        if (!player || player->IsLoading())
            continue;
        if (player->InBattleground() || player->InArena() || !player->IsInWorld())
            continue;
        uint32 lv = player->getLevel();
        if (lv < bracketEntry->MinLevel || lv > bracketEntry->MaxLevel)
            continue;
        if (player->InBattlegroundQueue())
        {
            BotGlobleSchedule schedule1(BotGlobleScheduleType::BGSType_OutAAQueue, 0);
            schedule1.parameter1 = bgTypeId;
            schedule1.parameter2 = bracketEntry->RangeIndex;
            schedule1.parameter3 = aaType;
            pSession->PushScheduleToQueue(schedule1);
        }
    }
}

void PlayerBotMgr::OnRealPlayerEnterBattleground(uint32 bgTypeId, uint32 level)
{
}

void PlayerBotMgr::OnRealPlayerLeaveBattleground(const Player* player)
{
    Battleground* bg = player->GetBattleground();
    if (!bg || bg->GetStatus() != BattlegroundStatus::STATUS_WAIT_LEAVE)
        return;
    PVPDifficultyEntry const* bracketEntry = sDB2Manager.GetBattlegroundBracketByLevel(bg->GetMapId(), player->getLevel());
    if (!bracketEntry)
        return;

    auto& allPlayerIDs = bg->GetPlayers();
    for (auto itIDs = allPlayerIDs.begin(); itIDs != allPlayerIDs.end(); itIDs++)
    {
        Player* otherPlayer = ObjectAccessor::FindPlayer(itIDs->first);
        if (!otherPlayer || otherPlayer->IsLoading())
            continue;
        if (!otherPlayer->InBattleground())
            continue;
        PlayerBotSession* pSession = dynamic_cast<PlayerBotSession*>((WorldSession*)otherPlayer->GetSession());
        if (pSession)
        {
            BotGlobleSchedule schedule1(BotGlobleScheduleType::BGSType_LeaveBG, 0);
            pSession->PushScheduleToQueue(schedule1);
        }
    }
}

bool PlayerBotMgr::LoginBotByAccountIndex(uint32 account, uint32 index)
{
#ifndef INCOMPLETE_BOT
    PlayerBotBaseInfo* botInfo = GetPlayerBotAccountInfo(account);
    if (!botInfo)
        return false;
    if (index >= botInfo->characters.size())
        return false;
    for (auto itChar = botInfo->characters.begin();
        itChar != botInfo->characters.end();
        itChar++)
    {
        if (index > 0)
        {
            --index;
            continue;
        }
        PlayerBotCharBaseInfo& charInfo = itChar->second;
        WorldSession* pWorldSession = sWorld->FindSession(account);
        PlayerBotSession* pSession = dynamic_cast<PlayerBotSession*>(pWorldSession);
        if (!pSession || pSession->PlayerLoading() || pSession->HasSchedules() || pSession->GetPlayer())
            return false;
        BotGlobleSchedule schedule1(BotGlobleScheduleType::BGSType_Online_GUID, charInfo.guid);
        pSession->PushScheduleToQueue(schedule1);
        return true;
    }
#endif
    return false;
}

bool PlayerBotMgr::AddNewPlayerBotByGUID(ObjectGuid& guid)
{
    int32 isok = sConfigMgr->GetIntDefault("pbot", 1);

    if (isok == 0 && !guid)
        return false;

    int32 allianceCount = (int32)sPlayerBotMgr->GetOnlineBotCount(TEAM_ALLIANCE, true);
    int32 hordeCount = (int32)sPlayerBotMgr->GetOnlineBotCount(TEAM_HORDE, true);

    if ((allianceCount + hordeCount) >= m_MaxOnlineBot)
        return false;


    const SessionMap& allSession = sWorld->GetAllSessions();
    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {

        Player* player = itSession->second->GetPlayer();
        if (player)
        {
            if (player->IsLoading())
                return false;
            if (player->GetSession()->PlayerLoading())
                return false;

        }
    }

    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {

        Player* player = itSession->second->GetPlayer();
        if (player)
        {
            if (player->IsLoading())
                return false;
            if (player->GetSession()->PlayerLoading())
                return false;

        }
    }


    for (std::map<uint32, PlayerBotBaseInfo*>::iterator itInfo = m_idPlayerBotBase.begin();
        itInfo != m_idPlayerBotBase.end();
        itInfo++)
    {
        if (!(itInfo->second->ExistCharacterByGUID(guid)))
            continue;
        WorldSession* pWorldSession = sWorld->FindSession(itInfo->first);
        PlayerBotSession* pSession = dynamic_cast<PlayerBotSession*>(pWorldSession);
        if (!pSession || pSession->PlayerLoading() || pSession->HasSchedules())
            return false;
        if (Player* player = pSession->GetPlayer())
        {
            if (!player->GetGroup() && !player->IsInCombat() && pSession->GetPlayer()->GetGUID() != guid)
            {
                BotGlobleSchedule schedule(BotGlobleScheduleType::BGSType_Offline, 0);
                pSession->PushScheduleToQueue(schedule);
            }
            else
                return false;
        }
        BotGlobleSchedule schedule1(BotGlobleScheduleType::BGSType_Online_GUID, guid);
        pSession->PushScheduleToQueue(schedule1);
        return true;
    }

    for (std::map<uint32, PlayerBotBaseInfo*>::iterator itInfo = m_idAccountBotBase.begin();
        itInfo != m_idAccountBotBase.end();
        itInfo++)
    {
        if (!(itInfo->second->ExistCharacterByGUID(guid)))
            continue;
        WorldSession* pWorldSession = sWorld->FindSession(itInfo->first);
        if (pWorldSession)
        {
            PlayerBotSession* pSession = dynamic_cast<PlayerBotSession*>(pWorldSession);
            if (!pSession || pSession->PlayerLoading() || pSession->HasSchedules())
                return false;
            if (Player* player = pSession->GetPlayer())
            {
                if (!player->GetGroup() && !player->IsInCombat() && pSession->GetPlayer()->GetGUID() != guid)
                {
                    BotGlobleSchedule schedule(BotGlobleScheduleType::BGSType_Offline, 0);
                    pSession->PushScheduleToQueue(schedule);
                }
                else
                    return false;
            }
            BotGlobleSchedule schedule1(BotGlobleScheduleType::BGSType_Online_GUID, guid);
            pSession->PushScheduleToQueue(schedule1);
            return true;
        }
        else
        {
            PlayerBotSession* pSession = UpPlayerBotSessionByBaseInfo(itInfo->second, true);
            if (!pSession)
                return false;
            BotGlobleSchedule schedule1(BotGlobleScheduleType::BGSType_Online_GUID, guid);
            pSession->PushScheduleToQueue(schedule1);
            return true;
        }
    }
    return false;
}


bool PlayerBotMgr::AddNewPlayerBotByGUID2(ObjectGuid& guid)
{
    int32 allianceCount = (int32)sPlayerBotMgr->GetOnlineBotCount(TEAM_ALLIANCE, true);
    int32 hordeCount = (int32)sPlayerBotMgr->GetOnlineBotCount(TEAM_HORDE, true);

    if ((allianceCount + hordeCount) >= m_MaxOnlineBot) return false;


    const SessionMap& allSession = sWorld->GetAllSessions();
    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {

        Player* player = itSession->second->GetPlayer();
        if (player)
        {
            if (player->IsLoading())
                return false;
            if (player->GetSession()->PlayerLoading())
                return false;

        }
    }

    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {

        Player* player = itSession->second->GetPlayer();
        if (player)
        {
            if (player->IsLoading())
                return false;
            if (player->GetSession()->PlayerLoading())
                return false;

        }
    }

    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {

        Player* player = itSession->second->GetPlayer();
        if (player)
        {
            if (player->IsLoading())
                return false;
            if (player->GetSession()->PlayerLoading())
                return false;

        }
    }

    for (std::map<uint32, PlayerBotBaseInfo*>::iterator itInfo = m_idPlayerBotBase.begin();
        itInfo != m_idPlayerBotBase.end();
        itInfo++)
    {
        if (!(itInfo->second->ExistCharacterByGUID(guid)))
            continue;
        WorldSession* pWorldSession = sWorld->FindSession(itInfo->first);
        PlayerBotSession* pSession = dynamic_cast<PlayerBotSession*>(pWorldSession);
        if (!pSession || pSession->PlayerLoading() || pSession->HasSchedules())
            return false;
        if (Player* player = pSession->GetPlayer())
        {
            if (!player->GetGroup() && !player->IsInCombat() && pSession->GetPlayer()->GetGUID() != guid)
            {
                BotGlobleSchedule schedule(BotGlobleScheduleType::BGSType_Offline, 0);
                pSession->PushScheduleToQueue(schedule);
            }
            else
                return false;
        }
        BotGlobleSchedule schedule1(BotGlobleScheduleType::BGSType_Online_GUID, guid);
        pSession->PushScheduleToQueue(schedule1);
        return true;
    }

    for (std::map<uint32, PlayerBotBaseInfo*>::iterator itInfo = m_idAccountBotBase.begin();
        itInfo != m_idAccountBotBase.end();
        itInfo++)
    {
        if (!(itInfo->second->ExistCharacterByGUID(guid)))
            continue;
        WorldSession* pWorldSession = sWorld->FindSession(itInfo->first);
        if (pWorldSession)
        {
            PlayerBotSession* pSession = dynamic_cast<PlayerBotSession*>(pWorldSession);
            if (!pSession || pSession->PlayerLoading() || pSession->HasSchedules())
                return false;
            if (Player* player = pSession->GetPlayer())
            {
                if (!player->GetGroup() && !player->IsInCombat() && pSession->GetPlayer()->GetGUID() != guid)
                {
                    BotGlobleSchedule schedule(BotGlobleScheduleType::BGSType_Offline, 0);
                    pSession->PushScheduleToQueue(schedule);
                }
                else
                    return false;
            }
            BotGlobleSchedule schedule1(BotGlobleScheduleType::BGSType_Online_GUID, guid);
            pSession->PushScheduleToQueue(schedule1);
            return true;
        }
        else
        {
            PlayerBotSession* pSession = UpPlayerBotSessionByBaseInfo(itInfo->second, true);
            if (!pSession)
                return false;
            BotGlobleSchedule schedule1(BotGlobleScheduleType::BGSType_Online_GUID, guid);
            pSession->PushScheduleToQueue(schedule1);
            return true;
        }
    }
    return false;
}

void PlayerBotMgr::AddNewPlayerBot(bool faction, Classes prof, uint32 count)
{

    int32 isok = sConfigMgr->GetIntDefault("pbot", 1);
    if (isok == 0 && prof == CLASS_NONE)
        return;

    int32 allianceCount = (int32)sPlayerBotMgr->GetOnlineBotCount(TEAM_ALLIANCE, true);
    int32 hordeCount = (int32)sPlayerBotMgr->GetOnlineBotCount(TEAM_HORDE, true);

    if ((allianceCount + hordeCount) >= m_MaxOnlineBot)
        return;

    const SessionMap& allSession = sWorld->GetAllSessions();
    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {
        Player* player = itSession->second->GetPlayer();
        if (player)
        {
            if (player->IsLoading())
                return;
            if (player->GetSession()->PlayerLoading())
                return;

        }
    }


    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {

        Player* player = itSession->second->GetPlayer();
        if (player)
        {
            if (player->IsLoading())
                return;
            if (player->GetSession()->PlayerLoading())
                return;

        }
    }

    if (count <= 0)
        return;



    if (prof == CLASS_NONE)
    {
        uint32 rndCls = 0;
        while (rndCls == 0 || rndCls == 6 || rndCls == 10 || rndCls > 11)
        {
            rndCls = urand(Classes::CLASS_WARRIOR, Classes::CLASS_DRUID);
        }
        prof = Classes(rndCls);
    }
#ifdef INCOMPLETE_BOT
    if (prof != 1 && prof != 5 && prof != 9)
    {
        if (prof == 2 || prof == 6)
            prof = Classes::CLASS_WARRIOR;
        else if (prof == 3 || prof == 4 || prof == 8 || prof == 10)
            prof = Classes::CLASS_WARLOCK;
        else if (prof == 7 || prof == 11)
            prof = Classes::CLASS_PRIEST;
    }
#endif
    //const SessionMap& allSession = sWorld->GetAllSessions();
    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {
        if (count <= 0)
            return;
        if (!itSession->second->IsBotSession())
            continue;
        PlayerBotSession* pSession = dynamic_cast<PlayerBotSession*>((WorldSession*)itSession->second);
        if (!pSession || pSession->PlayerLoading() || pSession->HasSchedules() || pSession->IsAccountBotSession())
            continue;
        Player* player = pSession->GetPlayer();
        if (player)
            continue;
        BotGlobleSchedule schedule1(BotGlobleScheduleType::BGSType_Online, 0);
        if (faction)
        {
            schedule1.parameter1 = 1;
        }
        else
        {
            schedule1.parameter1 = 2;
        }
        schedule1.parameter2 = prof;
        pSession->PushScheduleToQueue(schedule1);
        --count;
    }

    if (count > 0)
    {
        std::string allonlineText;
        consoleToUtf8(std::string("|cffff8800���?������?��?�?�����?��?�����������?�|r"), allonlineText);
        sWorld->SendGlobalText(allonlineText.c_str(), NULL);
    }
}

void PlayerBotMgr::AddNewAccountBot(bool faction, Classes prof)
{
    int32 isok = sConfigMgr->GetIntDefault("pbotall", 1);
    if (isok == 0)
        return;

    int32 allianceCount = (int32)sPlayerBotMgr->GetOnlineBotCount(TEAM_ALLIANCE, true);
    int32 hordeCount = (int32)sPlayerBotMgr->GetOnlineBotCount(TEAM_HORDE, true);

    if ((allianceCount + hordeCount) >= m_MaxOnlineBot)
        return;


    const SessionMap& allSession = sWorld->GetAllSessions();
    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {

        Player* player = itSession->second->GetPlayer();
        if (player)
        {
            if (player->IsLoading())
                return;
            if (player->GetSession()->PlayerLoading())
                return;

        }
    }

    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {

        Player* player = itSession->second->GetPlayer();
        if (player)
        {
            if (player->IsLoading())
                return;
            if (player->GetSession()->PlayerLoading())
                return;

        }
    }
    std::string allonlineText;
#ifdef INCOMPLETE_BOT
    consoleToUtf8(std::string("|cffff8800������?��?������?��?��?|r"), allonlineText);
    sWorld->SendGlobalText(allonlineText.c_str(), NULL);
    return;
#endif
    if (prof == CLASS_NONE)
    {
        uint32 rndCls = 0;
        while (rndCls == 0 || rndCls == 6 || rndCls == 10 || rndCls > 11)
        {
            rndCls = urand(Classes::CLASS_WARRIOR, Classes::CLASS_DRUID);
        }
        prof = Classes(rndCls);
    }
    //std::set<uint32> hasSessionIDs;
//	const SessionMap& allSession = sWorld->GetAllSessions();
    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {
        if (!itSession->second->IsBotSession())
            continue;
        PlayerBotSession* pSession = dynamic_cast<PlayerBotSession*>((WorldSession*)itSession->second);
        if (!pSession || pSession->PlayerLoading() || pSession->HasSchedules() || !pSession->IsAccountBotSession())
            continue;
        //hasSessionIDs.insert(pSession->GetAccountId());
        Player* player = pSession->GetPlayer();
        if (player)
            continue;
        PlayerBotBaseInfo* pBaseInfo = GetAccountBotAccountInfo(pSession->GetAccountId());
        if (!pBaseInfo)
            continue;
        if (!pBaseInfo->ExistClass(faction, prof))
            continue;
        BotGlobleSchedule schedule1(BotGlobleScheduleType::BGSType_Online, 0);
        if (faction)
            schedule1.parameter1 = 1;
        else
            schedule1.parameter1 = 2;
        schedule1.parameter2 = prof;
        pSession->PushScheduleToQueue(schedule1);
        return;
    }

    for (std::map<uint32, PlayerBotBaseInfo*>::iterator it = m_idAccountBotBase.begin();
        it != m_idAccountBotBase.end();
        it++)
    {
        PlayerBotBaseInfo* pInfo = it->second;
        WorldSession* pSession = sWorld->FindSession(pInfo->id);
        if (pSession)
            continue;
        if (!pInfo->ExistClass(faction, prof))
            continue;
        PlayerBotSession* pBotSession = UpPlayerBotSessionByBaseInfo(pInfo, true);
        if (pBotSession)
        {
            BotGlobleSchedule schedule1(BotGlobleScheduleType::BGSType_Online, 0);
            if (faction)
                schedule1.parameter1 = 1;
            else
                schedule1.parameter1 = 2;
            schedule1.parameter2 = prof;
            pBotSession->PushScheduleToQueue(schedule1);
            return;
        }
    }

    consoleToUtf8(std::string("|cffff8800����?�������?��?��?��??���?��?��?|r"), allonlineText);
    sWorld->SendGlobalText(allonlineText.c_str(), NULL);
}

void PlayerBotMgr::AddNewPlayerBotByClass(uint32 count, Classes prof)
{
    int32 isok = sConfigMgr->GetIntDefault("pbotall", 1);
    if (isok == 0)
        return;

    int32 allianceCount = (int32)sPlayerBotMgr->GetOnlineBotCount(TEAM_ALLIANCE, true);
    int32 hordeCount = (int32)sPlayerBotMgr->GetOnlineBotCount(TEAM_HORDE, true);

    if ((allianceCount + hordeCount) >= m_MaxOnlineBot) return;

    const SessionMap& allSession = sWorld->GetAllSessions();
    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {

        Player* player = itSession->second->GetPlayer();
        if (player)
        {
            if (player->IsLoading())
                return;
            if (player->GetSession()->PlayerLoading())
                return;

        }
    }


    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {

        Player* player = itSession->second->GetPlayer();
        if (player)
        {
            if (player->IsLoading())
                return;
            if (player->GetSession()->PlayerLoading())
                return;

        }
    }

#ifdef INCOMPLETE_BOT
    if (prof != 1 && prof != 5 && prof != 9)
    {
        if (prof == 2 || prof == 6)
            prof = Classes::CLASS_WARRIOR;
        else if (prof == 3 || prof == 4 || prof == 8 || prof == 10)
            prof = Classes::CLASS_WARLOCK;
        else if (prof == 7 || prof == 11)
            prof = Classes::CLASS_PRIEST;
    }
#endif

    //	const SessionMap& allSession = sWorld->GetAllSessions();
    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {
        if (allianceCount <= 0 && hordeCount <= 0)
            return;
        if (!itSession->second->IsBotSession())
            continue;
        PlayerBotSession* pSession = dynamic_cast<PlayerBotSession*>((WorldSession*)itSession->second);
        if (!pSession || pSession->PlayerLoading() || pSession->HasSchedules() || pSession->IsAccountBotSession())
            continue;
        Player* player = pSession->GetPlayer();
        if (player && player->getClass() != prof)
            continue;
        if (player)
        {
            if (player->GetTeamId() == TeamId::TEAM_ALLIANCE)
                --allianceCount;
            else
                --hordeCount;
        }
        else
        {
            BotGlobleSchedule schedule1(BotGlobleScheduleType::BGSType_Online, 0);
            if (allianceCount > 0)
            {
                schedule1.parameter1 = 1;
                --allianceCount;
            }
            else if (hordeCount > 0)
            {
                schedule1.parameter1 = 2;
                --hordeCount;
            }
            else
                continue;
            schedule1.parameter2 = prof;
            pSession->PushScheduleToQueue(schedule1);
        }
    }

    if (allianceCount > 0 || hordeCount > 0)
    {
        std::string allonlineText;
        consoleToUtf8(std::string("|cffff8800���?������?��?�?�����?��?�����������?�|r"), allonlineText);
        sWorld->SendGlobalText(allonlineText.c_str(), NULL);
    }
}

bool PlayerBotMgr::ChangePlayerBotSetting(uint32 account, uint32 minLV, uint32 maxLV, uint32 talent)
{
    if (account == 0)
        return false;
    maxLV = PlayerBotSetting::CheckMaxLevel(maxLV);
    if (maxLV < minLV)
        maxLV = minLV;
    WorldSession* pWorldSession = sWorld->FindSession(account);
    if (pWorldSession && pWorldSession->IsBotSession() && !pWorldSession->PlayerLoading())
    {
        Player* player = pWorldSession->GetPlayer();
        if (!player || player->InBattlegroundQueue() || player->InBattleground() ||
            player->GetBattleground() || player->IsInCombat())
            return false;
        PlayerBotSession* pSession = dynamic_cast<PlayerBotSession*>(pWorldSession);
        if (!pSession || pSession->HasSchedules())
            return false;
        BotGlobleSchedule schedule2(BotGlobleScheduleType::BGSType_Settting, 0);
        schedule2.parameter1 = minLV;
        schedule2.parameter2 = maxLV;
        schedule2.parameter3 = talent + 1;
        pSession->PushScheduleToQueue(schedule2);
        return true;
    }
    return false;
}

void PlayerBotMgr::AddNewPlayerBotToBG(TeamId team, uint32 minLV, uint32 maxLV, BattlegroundTypeId bgTypeID)
{
    const SessionMap& allSession = sWorld->GetAllSessions();
    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {
        Player* player = itSession->second->GetPlayer();
        if (player)
        {
            if (player->IsLoading())
                return;
            if (player->GetSession()->PlayerLoading())
                return;
        }
    }

    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {
        Player* player = itSession->second->GetPlayer();
        if (player)
        {
            if (player->IsLoading())
                return;
            if (player->GetSession()->PlayerLoading())
                return;

        }
    }

    maxLV = PlayerBotSetting::CheckMaxLevel(maxLV);
    if (maxLV < minLV)
        maxLV = minLV;
    //	const SessionMap& allSession = sWorld->GetAllSessions();
    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {
        if (!itSession->second->IsBotSession())
            continue;
        PlayerBotSession* pSession = dynamic_cast<PlayerBotSession*>((WorldSession*)itSession->second);
        if (!pSession || pSession->PlayerLoading() || pSession->HasSchedules() || pSession->IsAccountBotSession())
            continue;
        Player* player = pSession->GetPlayer();
        if (player)
        {
            if (!player || player->IsLoading() || !player->IsInWorld())
                continue;
            if (player->InBattleground() || player->InArena() || player->GetMap()->IsDungeon() || player->isUsingLfg())
                continue;
            if (player->InBattlegroundQueue())
                continue;
            if (!player->IsSettingFinish())
                continue;
            if (player->GetTeamId() != team)
                continue;

            BotGlobleSchedule schedule2(BotGlobleScheduleType::BGSType_Settting, 0);
            schedule2.parameter1 = maxLV;
            schedule2.parameter2 = maxLV;
            schedule2.parameter3 = 4;
            pSession->PushScheduleToQueue(schedule2);

            BotGlobleSchedule schedule3(BotGlobleScheduleType::BGSType_InBGQueue, 0);
            schedule3.parameter1 = bgTypeID;
            pSession->PushScheduleToQueue(schedule3);
            return;
        }
    }

    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {
        if (!itSession->second->IsBotSession())
            continue;
        PlayerBotSession* pSession = dynamic_cast<PlayerBotSession*>((WorldSession*)itSession->second);
        if (!pSession || pSession->PlayerLoading() || pSession->HasSchedules() || pSession->IsAccountBotSession())
            continue;
        Player* player = pSession->GetPlayer();
        if (!player)
        {
            BotGlobleSchedule schedule1(BotGlobleScheduleType::BGSType_Online, 0);
            schedule1.parameter1 = (team == TeamId::TEAM_ALLIANCE) ? 1 : 2;
            pSession->PushScheduleToQueue(schedule1);

            BotGlobleSchedule schedule2(BotGlobleScheduleType::BGSType_Settting, 0);
            schedule2.parameter1 = minLV;
            schedule2.parameter2 = maxLV;
            schedule2.parameter3 = 4;
            pSession->PushScheduleToQueue(schedule2);

            BotGlobleSchedule schedule3(BotGlobleScheduleType::BGSType_InBGQueue, 0);
            schedule3.parameter1 = bgTypeID;
            pSession->PushScheduleToQueue(schedule3);
            return;
        }
    }

    std::string allonlineText;
    consoleToUtf8(std::string("|cffff8800���?������?��?�?�����?��?�����������?�?���?�|r"), allonlineText);
    sWorld->SendGlobalText(allonlineText.c_str(), NULL);
}

void PlayerBotMgr::AddNewPlayerBotToLFG(lfg::LFGBotRequirement* botRequirement)
{
    if (!botRequirement || botRequirement->selectedDungeons.empty())
        return;

    int32 isok = sConfigMgr->GetIntDefault("pbotall", 1);
    if (isok == 0)
        return;

    int32 isoka = sConfigMgr->GetIntDefault("pbotasl", 88);

    int32 allianceCount = (int32)sPlayerBotMgr->GetOnlineBotCount(TEAM_ALLIANCE, true);
    int32 hordeCount = (int32)sPlayerBotMgr->GetOnlineBotCount(TEAM_HORDE, true);

    if ((allianceCount + hordeCount) > isoka) return;


    const SessionMap& allSession = sWorld->GetAllSessions();
    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {

        Player* player = itSession->second->GetPlayer();
        if (player)
        {
            if (player->IsLoading())
                return;
            if (player->GetSession()->PlayerLoading())
                return;
            //if (player->IsInCombat())
            //return;
        }
    }


    //const SessionMap& allSession = sWorld->GetAllSessions();
    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {

        Player* player = itSession->second->GetPlayer();
        if (player)
        {
            if (player->IsLoading())
                return;
            if (player->GetSession()->PlayerLoading())
                return;
            //if (player->IsInCombat())
            //return;
        }
    }

    std::vector<uint32> duns;
    for (lfg::LfgDungeonSet::iterator itLfgSet = botRequirement->selectedDungeons.begin(); itLfgSet != botRequirement->selectedDungeons.end(); itLfgSet++)
    {
        uint32 dun = *itLfgSet;
        duns.push_back(dun);
    }
    //	const SessionMap& allSession = sWorld->GetAllSessions();
    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {
        if (!itSession->second->IsBotSession())
            continue;
        PlayerBotSession* pSession = dynamic_cast<PlayerBotSession*>((WorldSession*)itSession->second);
        if (!pSession || pSession->PlayerLoading() || pSession->HasSchedules() || pSession->IsAccountBotSession())
            continue;
        Player* player = pSession->GetPlayer();
        if (!player)
        {
            BotGlobleSchedule schedule1(BotGlobleScheduleType::BGSType_Online, 0);
            if (!FillOnlineBotScheduleByLFGRequirement(botRequirement, &schedule1))
                continue;
            pSession->PushScheduleToQueue(schedule1);

            BotGlobleSchedule schedule2(BotGlobleScheduleType::BGSType_Settting, 0);
            schedule2.parameter1 = botRequirement->needLevel;
            schedule2.parameter2 = botRequirement->needLevel;
            schedule2.parameter3 = GetScheduleTalentByLFGRequirement(botRequirement->needRole, schedule1.parameter2) + 1;
            pSession->PushScheduleToQueue(schedule2);

            BotGlobleSchedule schedule3(BotGlobleScheduleType::BGSType_InLFGQueue, 0);
            schedule3.parameter1 = uint32(botRequirement->needRole);
            uint32 count = botRequirement->selectedDungeons.size();
            schedule3.parameter2 = (count > 3) ? 3 : count;
            if (count >= 1)
                schedule3.parameter3 = duns[0];
            if (count >= 2)
                schedule3.parameter4 = duns[1];
            if (count >= 3)
                schedule3.parameter5 = duns[2];
            pSession->PushScheduleToQueue(schedule3);

            return;
        }
        else if (IsIDLEPlayerBot(player))
        {
            if (player->GetTeamId() != botRequirement->needTeam)
                continue;
            lfg::LfgRoles playerRole = lfg::LfgRoles::PLAYER_ROLE_NONE;
            if (BotFieldAI* pFieldAI = dynamic_cast<BotFieldAI*>(player->GetAI()))
            {
                if ((player->getClass() == 1 && player->FindTalentType() == 2) || (player->getClass() == 2 && player->FindTalentType() == 1))
                    playerRole = lfg::LfgRoles::PLAYER_ROLE_TANK;
                else if (pFieldAI->IsHealerBotAI())
                    playerRole = lfg::LfgRoles::PLAYER_ROLE_HEALER;
                else
                    playerRole = lfg::LfgRoles::PLAYER_ROLE_DAMAGE;
            }
            else if (BotGroupAI* pGroupAI = dynamic_cast<BotGroupAI*>(player->GetAI()))
            {
                if (pGroupAI->IsTankBotAI())
                    playerRole = lfg::LfgRoles::PLAYER_ROLE_TANK;
                else if (pGroupAI->IsHealerBotAI())
                    playerRole = lfg::LfgRoles::PLAYER_ROLE_HEALER;
                else
                    playerRole = lfg::LfgRoles::PLAYER_ROLE_DAMAGE;
            }
            if (playerRole != botRequirement->needRole)
                continue;

            BotGlobleSchedule schedule2(BotGlobleScheduleType::BGSType_Settting, 0);
            schedule2.parameter1 = botRequirement->needLevel;
            schedule2.parameter2 = botRequirement->needLevel;
            schedule2.parameter3 = player->FindTalentType() + 1;
            pSession->PushScheduleToQueue(schedule2);

            BotGlobleSchedule schedule3(BotGlobleScheduleType::BGSType_InLFGQueue, 0);
            schedule3.parameter1 = uint32(botRequirement->needRole);
            uint32 count = botRequirement->selectedDungeons.size();
            schedule3.parameter2 = (count > 3) ? 3 : count;
            if (count >= 1)
                schedule3.parameter3 = duns[0];
            if (count >= 2)
                schedule3.parameter4 = duns[1];
            if (count >= 3)
                schedule3.parameter5 = duns[2];
            pSession->PushScheduleToQueue(schedule3);

            return;
        }
    }

    std::string allonlineText;
    consoleToUtf8(std::string("|cffff8800All bot accounts are currently online, preventing new bots from joining the dungeon queue.|r"), allonlineText);
    sWorld->SendGlobalText(allonlineText.c_str(), NULL);
}

void PlayerBotMgr::AddNewPlayerBotToAA(TeamId team, BattlegroundTypeId bgTypeID, uint32 bracketID, uint32 aaType)
{
    const SessionMap& allSession = sWorld->GetAllSessions();
    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {

        Player* player = itSession->second->GetPlayer();
        if (player)
        {
            if (player->IsLoading())
                return;
            if (player->GetSession()->PlayerLoading())
                return;
            //if (player->IsInCombat())
            //return;
        }
    }

    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {

        Player* player = itSession->second->GetPlayer();
        if (player)
        {
            if (player->IsLoading())
                return;
            if (player->GetSession()->PlayerLoading())
                return;
            //if (player->IsInCombat())
            //return;
        }
    }


    if (aaType != 2 && aaType != 3 && aaType != 5)
        return;
    //	const SessionMap& allSession = sWorld->GetAllSessions();
    std::vector<uint32> rndIDs;
    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
        rndIDs.push_back(itSession->first);
    LegionForge::Containers::RandomShuffle(rndIDs);
    for (uint32 account : rndIDs)
    {
        WorldSession* pWorldSession = sWorld->FindSession(account);
        if (!pWorldSession || !pWorldSession->IsBotSession())
            continue;
        PlayerBotSession* pSession = dynamic_cast<PlayerBotSession*>(pWorldSession);
        if (!pSession || pSession->PlayerLoading() || pSession->HasSchedules() || pSession->IsAccountBotSession())
            continue;
        Player* player = pSession->GetPlayer();
        if (player)
        {
            if (!player || player->IsLoading() || !player->IsInWorld())
                continue;
            if (player->InBattleground() || player->InArena() || player->GetMap()->IsDungeon() || player->isUsingLfg())
                continue;
            if (player->InBattlegroundQueue())
                continue;
            if (!player->IsSettingFinish())
                continue;
            if (player->GetTeamId() != team)
                continue;

            BotGlobleSchedule schedule2(BotGlobleScheduleType::BGSType_Settting, 0);
            schedule2.parameter1 = 110;
            schedule2.parameter2 = 110;
            schedule2.parameter3 = 4;
            pSession->PushScheduleToQueue(schedule2);

            BotGlobleSchedule schedule3(BotGlobleScheduleType::BGSType_InAAQueue, 0);
            schedule3.parameter1 = 14;
            schedule3.parameter2 = 4;
            pSession->PushScheduleToQueue(schedule3);

            return;
        }
    }

    for (uint32 account : rndIDs)
    {
        WorldSession* pWorldSession = sWorld->FindSession(account);
        if (!pWorldSession || !pWorldSession->IsBotSession())
            continue;
        PlayerBotSession* pSession = dynamic_cast<PlayerBotSession*>(pWorldSession);
        if (!pSession || pSession->PlayerLoading() || pSession->HasSchedules() || pSession->IsAccountBotSession())
            continue;
        Player* player = pSession->GetPlayer();
        if (!player)
        {
            BotGlobleSchedule schedule1(BotGlobleScheduleType::BGSType_Online, 0);
            schedule1.parameter1 = (team == TeamId::TEAM_ALLIANCE) ? 1 : 2;
            pSession->PushScheduleToQueue(schedule1);

            BotGlobleSchedule schedule2(BotGlobleScheduleType::BGSType_Settting, 0);
            schedule2.parameter1 = 110;
            schedule2.parameter2 = 110;
            schedule2.parameter3 = 4;
            pSession->PushScheduleToQueue(schedule2);

            BotGlobleSchedule schedule3(BotGlobleScheduleType::BGSType_InAAQueue, 0);
            schedule3.parameter1 = 14;
            schedule3.parameter2 = 4;
            pSession->PushScheduleToQueue(schedule3);

            return;
        }
    }

    std::string allonlineText;
    consoleToUtf8(std::string("|cffff8800���?������?��?�?�����?��?�����������?��������?�|r"), allonlineText);
    sWorld->SendGlobalText(allonlineText.c_str(), NULL);
}

void PlayerBotMgr::AddTeamBotToRatedArena(uint32 arenaTeamId)
{
    //	int32 isok = sConfigMgr->GetIntDefault("pbot", 1);
    //	if (isok==0)
    //		return;
    //
    //int32 isoka = sConfigMgr->GetIntDefault("pbotasl", 88);
    //
    //	int32 allianceCount = (int32)sPlayerBotMgr->GetOnlineBotCount(TEAM_ALLIANCE, true);
    //	int32 hordeCount = (int32)sPlayerBotMgr->GetOnlineBotCount(TEAM_HORDE, true);
    //
    //if ((allianceCount+hordeCount) >isoka) return;
    //
    //
    //	const SessionMap& allSession = sWorld->GetAllSessions();
    //	for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    //	{
    //
    //		Player* player = itSession->second->GetPlayer();
    //		if (player)
    //{
    //		if (player->IsLoading())
    //			return;
    //if (player->GetSession()->PlayerLoading())
    //return;
    //
    ////if (player->IsInCombat())
    ////return;
    //	}
    //	}
    //	
    //
    //	if (arenaTeamId == 0)
    //		return;
    //	ArenaTeam* arenaTeam = sArenaTeamMgr->GetArenaTeamById(arenaTeamId);
    //	if (!arenaTeam)
    //		return;
    //	BattlegroundQueueTypeId bgQueueTypeID = BattlegroundMgr::BGQueueTypeId(BattlegroundTypeId(BattlegroundTypeId::BATTLEGROUND_AA), arenaTeam->GetType());
    //	BattlegroundQueue& bgQueue = sBattlegroundMgr->GetBattlegroundQueue(bgQueueTypeID);
    //	for (ArenaTeam::MemberList::iterator itaMem = arenaTeam->m_membersBegin(); itaMem != arenaTeam->m_membersEnd(); itaMem++)
    //	{
    //		ArenaTeamMember& mem = *itaMem;
    //		ObjectGuid guid = mem.Guid;
    //		if (bgQueue.ExistQueueByRatedArena(guid, true))
    //			continue;
    //		if (Player* player = ObjectAccessor::FindConnectedPlayer(guid))
    //		{
    //			if (!player->IsPlayerBot() || player->GetGroup())
    //				continue;
    //			if (PlayerBotSession* pSession = dynamic_cast<PlayerBotSession*>(player->GetSession()))
    //			{
    //				BotGlobleSchedule schedule2(BotGlobleScheduleType::BGSType_Settting, 0);
    //				schedule2.parameter1 = 80;
    //				schedule2.parameter2 = 80;
    //				schedule2.parameter3 = sArenaTeamMgr->FindArenaTeamPlayerBotTalent(guid) + 1;
    //				schedule2.parameter4 = (pSession->IsAccountBotSession()) ? 0 : 1;
    //				pSession->PushScheduleToQueue(schedule2);
    //
    //				BotGlobleSchedule schedule3(BotGlobleScheduleType::BGSType_InAAQueue, 0);
    //				schedule3.parameter1 = BattlegroundTypeId::BATTLEGROUND_AA;
    //				if (arenaTeam->GetType() == 2)
    //					schedule3.parameter2 = 0;
    //				else if (arenaTeam->GetType() == 3)
    //					schedule3.parameter2 = 1;
    //				else if (arenaTeam->GetType() == 5)
    //					schedule3.parameter2 = 2;
    //				schedule3.parameter3 = 1;
    //				pSession->PushScheduleToQueue(schedule3);
    //
    //				BotGlobleSchedule schedule4(BotGlobleScheduleType::BGSType_EnterAA, 0);
    //				schedule4.parameter1 = BattlegroundTypeId::BATTLEGROUND_AA;
    //				schedule4.parameter2 = 14;
    //				schedule4.parameter3 = arenaTeam->GetType();
    //				schedule4.parameter4 = 1;
    //				pSession->PushScheduleToQueue(schedule4);
    //			}
    //		}
    //		else if (PlayerBotSession* pSession = GetBotSessionByCharGUID(guid))
    //		{
    //			Player* player = pSession->GetPlayer();
    //			if (player)
    //			{
    //				BotGlobleSchedule schedule(BotGlobleScheduleType::BGSType_Offline, 0);
    //				pSession->PushScheduleToQueue(schedule);
    //			}
    //			BotGlobleSchedule schedule1(BotGlobleScheduleType::BGSType_Online_GUID, 0);
    //			schedule1.parameter1 = guid.GetCounter();
    //			pSession->PushScheduleToQueue(schedule1);
    //
    //			BotGlobleSchedule schedule2(BotGlobleScheduleType::BGSType_Settting, 0);
    //			schedule2.parameter1 = 80;
    //			schedule2.parameter2 = 80;
    //			schedule2.parameter3 = sArenaTeamMgr->FindArenaTeamPlayerBotTalent(guid) + 1;
    //			schedule2.parameter4 = (pSession->IsAccountBotSession()) ? 0 : 1;
    //			pSession->PushScheduleToQueue(schedule2);
    //
    //			BotGlobleSchedule schedule3(BotGlobleScheduleType::BGSType_InAAQueue, 0);
    //			schedule3.parameter1 = BattlegroundTypeId::BATTLEGROUND_AA;
    //			if (arenaTeam->GetType() == 2)
    //				schedule3.parameter2 = 0;
    //			else if (arenaTeam->GetType() == 3)
    //				schedule3.parameter2 = 1;
    //			else if (arenaTeam->GetType() == 5)
    //				schedule3.parameter2 = 2;
    //			schedule3.parameter3 = 1;
    //			pSession->PushScheduleToQueue(schedule3);
    //
    //			BotGlobleSchedule schedule4(BotGlobleScheduleType::BGSType_EnterAA, 0);
    //			schedule4.parameter1 = BattlegroundTypeId::BATTLEGROUND_AA;
    //			schedule4.parameter2 = 14;
    //			schedule4.parameter3 = arenaTeam->GetType();
    //			schedule4.parameter4 = 1;
    //			pSession->PushScheduleToQueue(schedule4);
    //		}
    //	}
}

bool PlayerBotMgr::FillOnlineBotScheduleByLFGRequirement(lfg::LFGBotRequirement* botRequirement, BotGlobleSchedule* botSchedule)
{
    if (!botRequirement || !botSchedule)
        return false;
    botSchedule->parameter1 = 0;
    if (botRequirement->needTeam == TEAM_ALLIANCE)
        botSchedule->parameter1 = 1;
    else if (botRequirement->needTeam == TEAM_HORDE)
        botSchedule->parameter1 = 2;
    else
        return false;
    std::vector<uint32> matchClasses;
    botSchedule->parameter2 = 0;
    if (botRequirement->needRole == lfg::LfgRoles::PLAYER_ROLE_TANK)
    {
        matchClasses.push_back(1);
#ifndef INCOMPLETE_BOT
        matchClasses.push_back(2);
#endif
        //matchClasses.push_back(6);
    }
    else if (botRequirement->needRole == lfg::LfgRoles::PLAYER_ROLE_HEALER)
    {
        matchClasses.push_back(5);
#ifndef INCOMPLETE_BOT
        matchClasses.push_back(2);
        matchClasses.push_back(7);
        matchClasses.push_back(11);
#endif
    }
    else if (botRequirement->needRole == lfg::LfgRoles::PLAYER_ROLE_DAMAGE)
    {
#ifndef INCOMPLETE_BOT
        matchClasses.push_back(3);
        matchClasses.push_back(4);
        matchClasses.push_back(8);
#endif
        matchClasses.push_back(9);
    }
    if (matchClasses.empty())
        return false;
    botSchedule->parameter2 = matchClasses[urand(0, matchClasses.size() - 1)];
    return true;
}

uint32 PlayerBotMgr::GetScheduleTalentByLFGRequirement(lfg::LfgRoles roles, uint32 botCls)
{
    uint32 talentType = 3;
    switch (botCls)
    {
    case 1:
        if (roles == lfg::LfgRoles::PLAYER_ROLE_TANK)
            talentType = 2;
        else
            talentType = urand(0, 1);
        break;
    case 2:
        if (roles == lfg::LfgRoles::PLAYER_ROLE_TANK)
            talentType = 1;
        else if (roles == lfg::LfgRoles::PLAYER_ROLE_HEALER)
            talentType = 0;
        else
            talentType = 2;
        break;
    case 6:
        if (roles == lfg::LfgRoles::PLAYER_ROLE_TANK)
            talentType = 1;
        else
        {
            if (urand(0, 1) == 0)
                talentType = 0;
            else
                talentType = 2;
        }
        break;
    case 5:
        if (roles == lfg::LfgRoles::PLAYER_ROLE_DAMAGE)
            talentType = 2;
        else
            talentType = urand(0, 1);
        break;
    case 7:
        if (roles == lfg::LfgRoles::PLAYER_ROLE_HEALER)
            talentType = 2;
        else
            talentType = urand(0, 1);
        break;
    case 11:
        if (roles == lfg::LfgRoles::PLAYER_ROLE_HEALER)
            talentType = 2;
        else
            talentType = urand(0, 1);
        break;
    }
    return talentType;
}

lfg::LfgRoles PlayerBotMgr::GetPlayerBotCurrentLFGRoles(Player* player)
{
    if (!player)
        return lfg::LfgRoles::PLAYER_ROLE_NONE;
    uint32 talentType = player->FindTalentType();
    switch (player->getClass())
    {
    case 1:
        if (talentType == 2)
            return lfg::LfgRoles::PLAYER_ROLE_TANK;
        else
            return lfg::LfgRoles::PLAYER_ROLE_DAMAGE;
        break;
    case 2:
        if (talentType == 0)
            return lfg::LfgRoles::PLAYER_ROLE_HEALER;
        else if (talentType == 1)
            return lfg::LfgRoles::PLAYER_ROLE_TANK;
        else
            return lfg::LfgRoles::PLAYER_ROLE_DAMAGE;
        break;
    case 6:
        if (talentType == 1)
            return lfg::LfgRoles::PLAYER_ROLE_TANK;
        else
            return lfg::LfgRoles::PLAYER_ROLE_DAMAGE;
        break;
    case 3:
    case 4:
    case 8:
    case 9:
        return lfg::LfgRoles::PLAYER_ROLE_DAMAGE;
        break;
    case 5:
        if (talentType == 2)
            return lfg::LfgRoles::PLAYER_ROLE_DAMAGE;
        else
            return lfg::LfgRoles::PLAYER_ROLE_HEALER;
        break;
    case 7:
        if (talentType == 2)
            return lfg::LfgRoles::PLAYER_ROLE_HEALER;
        else
            return lfg::LfgRoles::PLAYER_ROLE_DAMAGE;
        break;
    case 11:
        if (talentType == 2)
            return lfg::LfgRoles::PLAYER_ROLE_HEALER;
        else
            return lfg::LfgRoles::PLAYER_ROLE_DAMAGE;
        break;
    default:
        return lfg::LfgRoles::PLAYER_ROLE_DAMAGE;
    }
    return lfg::LfgRoles::PLAYER_ROLE_DAMAGE;
}

ObjectGuid PlayerBotMgr::GetNoArenaMatchCharacter(TeamId team, uint32 arenaType, Classes cls, std::vector<ObjectGuid>& fliters)
{
    if (team != TEAM_ALLIANCE && team != TEAM_HORDE)
        return ObjectGuid::Empty;
    if (arenaType != 2 && arenaType != 3 && arenaType != 5)
        return ObjectGuid::Empty;
    if (m_idPlayerBotBase.empty())
        return ObjectGuid::Empty;
    std::vector<PlayerBotBaseInfo*> allBotBaseInfos;
    for (std::map<uint32, PlayerBotBaseInfo*>::iterator itInfo = m_idPlayerBotBase.begin();
        itInfo != m_idPlayerBotBase.end();
        itInfo++)
        allBotBaseInfos.push_back(itInfo->second);
    for (uint32 i = allBotBaseInfos.size() - 1; i >= 0; --i)
    {
        PlayerBotBaseInfo* pInfo = allBotBaseInfos[i];
        uint32 id = pInfo->GetCharIDByNoArenaType((team == TEAM_ALLIANCE) ? true : false, cls, arenaType, fliters);
        if (id == 0)
            continue;
        bool exist = false;
        for (ObjectGuid& guid : fliters)
        {
            if (guid.GetCounter() == id)
            {
                exist = true;
                break;
            }
        }
        if (!exist)
            return ObjectGuid::Create<HighGuid::Player>(id);
    }

    //for (std::map<uint32, PlayerBotBaseInfo*>::iterator itInfo = m_idPlayerBotBase.begin();
    //	itInfo != m_idPlayerBotBase.end();
    //	itInfo++)
    //{
    //	PlayerBotBaseInfo* pInfo = itInfo->second;
    //	uint32 id = pInfo->GetCharIDByNoArenaType((team == TEAM_ALLIANCE) ? true : false, cls, arenaType, fliters);
    //	if (id == 0)
    //		continue;
    //	bool exist = false;
    //	for (ObjectGuid& guid : fliters)
    //	{
    //		if (guid.GetCounter() == id)
    //		{
    //			exist = true;
    //			break;
    //		}
    //	}
    //	if (!exist)
    //		return ObjectGuid(uint64(id));
    //}
    return ObjectGuid::Empty;
}

std::string PlayerBotMgr::GetNameANDClassesText(ObjectGuid& guid)
{
    for (std::map<uint32, PlayerBotBaseInfo*>::iterator itInfo = m_idPlayerBotBase.begin();
        itInfo != m_idPlayerBotBase.end();
        itInfo++)
    {
        PlayerBotBaseInfo* pInfo = itInfo->second;
        std::string text = pInfo->GetCharNameANDClassesText(guid);
        if (!text.empty())
            return text;
    }
    return "";
}

bool PlayerBotMgr::CanReadyArenaByArenaTeamID(uint32 arenaTeamId)
{

    return true;
}

void PlayerBotMgr::QueryBattlegroundRequirement()
{
    for (BattleGroundTypes::iterator itType = m_BGTypes.begin(); itType != m_BGTypes.end(); itType++)
    {
        BattlegroundTypeId bgTypeID = *itType;
        Battleground* bg_template = sBattlegroundMgr->GetBattlegroundTemplate(bgTypeID);
        if (!bg_template)
            continue;
        BGFreeSlotQueueContainer& bgFreeSlotQueues = sBattlegroundMgr->GetBGFreeSlotQueueStore(bgTypeID);
        for (BGFreeSlotQueueContainer::iterator itr = bgFreeSlotQueues.begin(); itr != bgFreeSlotQueues.end(); itr++)
        {
            Battleground* bg = *itr;
            if (!bg->ExistRealPlayer())
                continue;
            uint32 minLV = bg->GetMinLevel();
            uint32 maxLV = bg->GetMaxLevel();
            if (!bg->isRated() && bg->GetStatus() > STATUS_WAIT_QUEUE && bg->GetStatus() < STATUS_WAIT_LEAVE)
            {
                if (bg->GetFreeSlotsForTeam(Team::ALLIANCE) > 0 && bg->GetFreeSlotsForTeam(Team::ALLIANCE) >= bg->GetFreeSlotsForTeam(Team::HORDE))
                    AddNewPlayerBotToBG(TeamId::TEAM_ALLIANCE, minLV, maxLV, bgTypeID);
                else if (bg->GetFreeSlotsForTeam(Team::HORDE) > 0)
                    AddNewPlayerBotToBG(TeamId::TEAM_HORDE, minLV, maxLV, bgTypeID);
                else
                    continue;
                return;
            }
        }

        BattlegroundQueueTypeId bgQueueTypeID = BattlegroundMgr::BGQueueTypeId(BattlegroundTypeId(bgTypeID), 0);
        BattlegroundQueue& bgQueue = sBattlegroundMgr->GetBattlegroundQueue(bgQueueTypeID);
        for (uint32 j = BattlegroundBracketId::BG_BRACKET_ID_FIRST; j <= BattlegroundBracketId::BG_BRACKET_ID_LAST; j++)
        {
            BattlegroundBracketId bracket = BattlegroundBracketId(j);
            PVPDifficultyEntry const* bracketEntry = sDB2Manager.GetBattlegroundBracketById(bg_template->GetMapId(), bracket);
            if (!bracketEntry)
                continue;
            if (!bgQueue.ExistRealPlayer(bracketEntry))
                continue;
            int32 needAlliancePlayerCount = 0;
            int32 needHordePlayerCount = 0;
            if (bgQueue.QueryNeedPlayerCount(bgTypeID, bracket, 0, needAlliancePlayerCount, needHordePlayerCount))
            {
                if (needAlliancePlayerCount > 0 && needAlliancePlayerCount >= needHordePlayerCount)
                    AddNewPlayerBotToBG(TeamId::TEAM_ALLIANCE, bracketEntry->MinLevel, bracketEntry->MaxLevel, bgTypeID);
                else if (needHordePlayerCount > 0)
                    AddNewPlayerBotToBG(TeamId::TEAM_HORDE, bracketEntry->MinLevel, bracketEntry->MaxLevel, bgTypeID);
                else
                    continue;
                return;
            }
        }
    }
}

void PlayerBotMgr::QueryRatedArenaRequirement()
{
    if (m_ArenaSearchTick > 0)
    {
        --m_ArenaSearchTick;
        return;
    }
    Battleground* bg_template = sBattlegroundMgr->GetBattlegroundTemplate(BattlegroundTypeId::BATTLEGROUND_AA);
    if (!bg_template)
        return;
    PVPDifficultyEntry const* bracketEntry = FindBGBracketEntry(bg_template, 80);
    if (!bracketEntry)
        return;

    uint32 arenaType[3] = { 2, 3, 5 };
    for (uint32 i = 0; i < 3; i++)
    {
        BattlegroundQueueTypeId bgQueueTypeID = BattlegroundMgr::BGQueueTypeId(BattlegroundTypeId(BattlegroundTypeId::BATTLEGROUND_AA), arenaType[i]);
        BattlegroundQueue& bgQueue = sBattlegroundMgr->GetBattlegroundQueue(bgQueueTypeID);
        if (!bgQueue.ExistRealPlayer(bracketEntry, true))
        {
            bgQueue.AllPlayerBotLeaveQueueFromRatedArena(bracketEntry->GetBracketId());
            continue;
        }
        uint32 allianceArenaTeamID = 0;
        uint32 hordeArenaTeamID = 0;
        GroupQueueInfo* allianceGroupInfo = bgQueue.GetFirstRealPlayerGroupInfo(bracketEntry->GetBracketId(), BattlegroundQueueGroupTypes::BG_QUEUE_PREMADE_ALLIANCE);
        GroupQueueInfo* hordeGroupInfo = bgQueue.GetFirstRealPlayerGroupInfo(bracketEntry->GetBracketId(), BattlegroundQueueGroupTypes::BG_QUEUE_PREMADE_HORDE);
        if (!allianceGroupInfo && !hordeGroupInfo)
            continue;
        //if (allianceGroupInfo && hordeGroupInfo)
            //{
            //allianceArenaTeamID = allianceGroupInfo->ArenaTeamId;
            //hordeArenaTeamID = hordeGroupInfo->ArenaTeamId;
        //}
        /*else if (allianceGroupInfo && !BotUtility::DownBotArenaTeam)
        {
            allianceGroupID = allianceGroupInfo->GroupId;
            hordeGroupID = hordeGroupInfo->GroupId;
            if (hordeGroupID == 0)
                continue;
            AddTeamBotToRatedArena(hordeGroupID);
        }
        else if (hordeGroupInfo && !BotUtility::DownBotArenaTeam)
        {
            hordeGroupID = hordeGroupInfo->GroupId;
            allianceGroupID = sArenaTeamMgr->SearchEnemyArenaTeam(hordeGroupID, ALLIANCE);
            if (allianceGroupID == 0)
                continue;
            AddTeamBotToRatedArena(allianceGroupID);
        }*/
        else
            continue;
        m_ArenaSearchTick = 14;
        break;
    }
}

void PlayerBotMgr::QueryNonRatedArenaRequirement()
{
    Battleground* bg_template = sBattlegroundMgr->GetBattlegroundTemplate(BattlegroundTypeId::BATTLEGROUND_AA);
    if (!bg_template)
        return;
    PVPDifficultyEntry const* bracketEntry = FindBGBracketEntry(bg_template, 110);
    if (!bracketEntry)
        return;
    BGFreeSlotQueueContainer& bgFreeSlotQueues = sBattlegroundMgr->GetBGFreeSlotQueueStore(BattlegroundTypeId::BATTLEGROUND_AA);
    for (BGFreeSlotQueueContainer::iterator itr = bgFreeSlotQueues.begin(); itr != bgFreeSlotQueues.end(); itr++)
    {
        Battleground* bg = *itr;
        if (!bg->ExistRealPlayer())
            continue;
        if (bg->GetStatus() > STATUS_WAIT_QUEUE && bg->GetStatus() < STATUS_WAIT_LEAVE)
        {
            if (bg->GetFreeSlotsForTeam(Team::ALLIANCE) > 0)
                AddNewPlayerBotToAA(TeamId::TEAM_ALLIANCE, BattlegroundTypeId::BATTLEGROUND_AA, bracketEntry->RangeIndex, bg->GetMaxPlayers() / 2);
            else if (bg->GetFreeSlotsForTeam(Team::HORDE) > 0)
                AddNewPlayerBotToAA(TeamId::TEAM_HORDE, BattlegroundTypeId::BATTLEGROUND_AA, bracketEntry->RangeIndex, bg->GetMaxPlayers() / 2);
            else
                continue;
            return;
        }
    }

    uint32 arenaType[3] = { 2, 3, 5 };
    for (uint32 i = 0; i < 3; i++)
    {
        BattlegroundQueueTypeId bgQueueTypeID = BattlegroundMgr::BGQueueTypeId(BattlegroundTypeId(BattlegroundTypeId::BATTLEGROUND_AA), arenaType[i]);
        BattlegroundQueue& bgQueue = sBattlegroundMgr->GetBattlegroundQueue(bgQueueTypeID);
        if (!bgQueue.ExistRealPlayer(bracketEntry, false))
            continue;
        int32 needAlliancePlayerCount = 0;
        int32 needHordePlayerCount = 0;
        if (bgQueue.QueryNeedPlayerCount(BattlegroundTypeId::BATTLEGROUND_AA, bracketEntry->GetBracketId(), arenaType[i], needAlliancePlayerCount, needHordePlayerCount))
        {
            if (needAlliancePlayerCount > 0 && needAlliancePlayerCount >= needHordePlayerCount)
                AddNewPlayerBotToAA(TeamId::TEAM_ALLIANCE, BattlegroundTypeId::BATTLEGROUND_AA, bracketEntry->RangeIndex, arenaType[i]);
            else if (needHordePlayerCount > 0)
                AddNewPlayerBotToAA(TeamId::TEAM_HORDE, BattlegroundTypeId::BATTLEGROUND_AA, bracketEntry->RangeIndex, arenaType[i]);
            else
                continue;
            return;
        }
    }
}

void PlayerBotMgr::OnlinePlayerBotByGUIDQueue()
{
    while (!m_DelayOnlineBots.empty())
    {
        ObjectGuid& guid = m_DelayOnlineBots.front();
        m_DelayOnlineBots.pop();
        if (AddNewPlayerBotByGUID(guid))
            return;
    }
}

bool PlayerBotMgr::ExistUnBGPlayerBot()
{
    const SessionMap& allSession = sWorld->GetAllSessions();
    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {
        if (!itSession->second->IsBotSession())
            continue;
        PlayerBotSession* pSession = dynamic_cast<PlayerBotSession*>((WorldSession*)itSession->second);
        if (!pSession)
            continue;
        if (pSession->PlayerLoading() || pSession->IsAccountBotSession())
            continue;
        Player* player = pSession->GetPlayer();
        if (!player || !player->IsInWorld())
            continue;
        if (player->InBattleground() || player->InBattlegroundQueue() || player->isUsingLfg() || player->GetGroup())
            continue;
        if (player->HasAura(26013))
            continue;
        if (!pSession->HasSchedules())
            continue;
        return true;
    }
    return false;
}

PVPDifficultyEntry const* PlayerBotMgr::FindBGBracketEntry(Battleground* bg_template, uint32 level)
{
    if (!bg_template)
        return NULL;
    for (uint32 j = BattlegroundBracketId::BG_BRACKET_ID_FIRST; j <= BattlegroundBracketId::BG_BRACKET_ID_LAST; j++)
    {
        BattlegroundBracketId bracket = BattlegroundBracketId(j);
        PVPDifficultyEntry const* bracketEntry = sDB2Manager.GetBattlegroundBracketById(bg_template->GetMapId(), bracket);
        if (!bracketEntry)
            continue;
        if (bracketEntry->MinLevel <= level && bracketEntry->MaxLevel >= level)
            return bracketEntry;
    }
    return NULL;
}

uint32 PlayerBotMgr::GetOnlineBotCount(TeamId team, bool hasReal)
{
    uint32 onlineCount = 0;
    const SessionMap& allSession = sWorld->GetAllSessions();
    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {
        if (itSession->second->IsBotSession())
        {
            PlayerBotSession* pSession = dynamic_cast<PlayerBotSession*>((WorldSession*)itSession->second);
            if (!pSession)
                continue;
            if (pSession->PlayerLoading())
            {
                ++onlineCount;
                continue;
            }
            Player* player = pSession->GetPlayer();
            if (!player || !player->IsInWorld())
                continue;
            if (team != TEAM_NEUTRAL)
            {
                if (player->GetTeamId() != team)
                    continue;
            }
            ++onlineCount;
        }
        else if (hasReal)
        {
            WorldSession* pSession = itSession->second;
            if (pSession->PlayerLoading())
                continue;
            Player* player = pSession->GetPlayer();
            if (!player || !player->IsInWorld())
                continue;
            if (team != TEAM_NEUTRAL)
            {
                if (player->GetTeamId() != team)
                    continue;
            }
            ++onlineCount;
        }
    }
    return onlineCount;
}


uint32 PlayerBotMgr::GetOnlineBotCount2(TeamId team, bool hasReal)
{
    uint32 onlineCount = 0;
    const SessionMap& allSession = sWorld->GetAllSessions();
    for (SessionMap::const_iterator itSession = allSession.begin(); itSession != allSession.end(); itSession++)
    {
        if (itSession->second->IsBotSession())
        {
            PlayerBotSession* pSession = dynamic_cast<PlayerBotSession*>((WorldSession*)itSession->second);
            if (!pSession)
                continue;
            if (pSession->PlayerLoading())
            {
                //++onlineCount;
                continue;
            }
            Player* player = pSession->GetPlayer();
            if (!player || !player->IsInWorld())
                continue;

            if (!player->InBattleground() && !player->InBattlegroundQueue())
                continue;

            if (team != TEAM_NEUTRAL)
            {
                if (player->GetTeamId() != team)
                    continue;
            }
            ++onlineCount;
        }
        else if (hasReal)
        {
            WorldSession* pSession = itSession->second;
            if (pSession->PlayerLoading())
                continue;
            Player* player = pSession->GetPlayer();
            if (!player || !player->IsInWorld())
                continue;

            if (!player->InBattleground() && !player->InBattlegroundQueue())
                continue;

            if (team != TEAM_NEUTRAL)
            {
                if (player->GetTeamId() != team)
                    continue;
            }
            ++onlineCount;
        }
    }
    return onlineCount;
}

bool PlayerBotMgr::IsRecruitTemplate(Player* player)
{
    if (!player || !player->IsPlayerBot() || !player->GetSession())
        return false;
    return GetPlayerBotAccountInfo(player->GetSession()->GetAccountId()) != nullptr;
}

uint32 PlayerBotMgr::GetRecruitPartyLimit(Player const* recruiter) const
{
    if (!recruiter)
        return MAX_GROUP_SIZE;

    auto bracket = [](uint32 maxPlayers) -> uint32
    {
        if (maxPlayers <= 10)
            return 10;
        if (maxPlayers <= 20)
            return 20;
        return 25;
    };

    Map const* map = recruiter->GetMap();
    if (map && map->IsRaid())
    {
        MapDifficultyEntry const* mapDiff = sDB2Manager.GetMapDifficultyData(map->GetId(), map->GetDifficultyID());
        if (mapDiff && mapDiff->MaxPlayers > 0)
            return bracket(mapDiff->MaxPlayers);
    }

    if (Group const* group = recruiter->GetGroup())
    {
        if (group->isRaidGroup())
        {
            switch (recruiter->GetRaidDifficultyID())
            {
            case DIFFICULTY_10_N:
            case DIFFICULTY_10_HC:
                return 10;
            case DIFFICULTY_MYTHIC_RAID:
                return 20;
            case DIFFICULTY_25_N:
            case DIFFICULTY_25_HC:
            case DIFFICULTY_LFR:
            case DIFFICULTY_LFR_NEW:
            case DIFFICULTY_NORMAL_RAID:
            case DIFFICULTY_HEROIC_RAID:
                return 25;
            default:
                break;
            }

            switch (recruiter->GetLegacyRaidDifficultyID())
            {
            case DIFFICULTY_10_N:
            case DIFFICULTY_10_HC:
                return 10;
            case DIFFICULTY_25_N:
            case DIFFICULTY_25_HC:
                return 25;
            default:
                return 10;
            }
        }
    }

    return MAX_GROUP_SIZE;
}

uint32 PlayerBotMgr::CountRecruiterClones(ObjectGuid recruiterGuid) const
{
    uint32 count = 0;
    for (BotCloneRecord const& record : m_cloneRecords)
    {
        if (!record.release && record.recruiterGuid == recruiterGuid)
            ++count;
    }
    return count;
}

bool PlayerBotMgr::RecruiterHasTemplate(ObjectGuid recruiterGuid, ObjectGuid templateGuid) const
{
    for (BotCloneRecord const& record : m_cloneRecords)
    {
        if (!record.release && record.recruiterGuid == recruiterGuid && record.templateGuid == templateGuid)
            return true;
    }
    return false;
}

PlayerBotBaseInfo* PlayerBotMgr::GetCloneAccountInfo(uint32 accountId)
{
    std::map<uint32, PlayerBotBaseInfo*>::iterator it = m_cloneAccounts.find(accountId);
    if (it == m_cloneAccounts.end())
        return nullptr;
    return it->second;
}

void PlayerBotMgr::LoadCloneAccounts()
{
    QueryResult result = LoginDatabase.Query("SELECT id, username, sha_pass_hash, battlenet_account FROM account WHERE username LIKE 'PBOTCOPY%'");
    if (!result)
        return;

    do
    {
        Field* fields = result->Fetch();
        uint32 id = fields[0].GetUInt32();
        std::string username = fields[1].GetString();
        std::string pass = fields[2].GetString();
        uint32 bnetId = fields[3].GetUInt32();
        if (m_cloneAccounts.find(id) == m_cloneAccounts.end())
        {
            PlayerBotBaseInfo* info = new PlayerBotBaseInfo(id, username.c_str(), pass, false, bnetId);
            m_cloneAccounts[id] = info;
        }

        std::string lower = boost::algorithm::to_lower_copy(username);
        if (lower.size() > 8 && lower.compare(0, 8, "pbotcopy") == 0)
        {
            uint32 index = uint32(atoi(lower.c_str() + 8));
            if (index > m_nextCloneIndex)
                m_nextCloneIndex = index;
        }
    } while (result->NextRow());
}

bool PlayerBotMgr::CreateOneCloneAccount()
{
    uint32 index = m_nextCloneIndex + 1;
    std::string userName = boost::algorithm::to_upper_copy(std::string("pbotcopy") + std::to_string(index));
    std::string password = userName;
    std::string bnetEmail = userName + "@BOTACCOUNTS";

    AccountOpResult accRes = sAccountMgr->CreateAccount(userName, password);
    if (accRes != AccountOpResult::AOR_OK && accRes != AccountOpResult::AOR_NAME_ALREADY_EXIST)
        return false;

    QueryResult accResQr = LoginDatabase.PQuery("SELECT id, username, sha_pass_hash FROM account WHERE username='%s'", userName.c_str());
    if (!accResQr)
        return false;

    Field* accF = accResQr->Fetch();
    uint32 accountId = accF[0].GetUInt32();
    std::string accName = accF[1].GetString();
    std::string accHash = accF[2].GetString();

    AccountOpResult bnetRes = Battlenet::AccountMgr::CreateBattlenetAccount(bnetEmail, password, false, nullptr);
    if (bnetRes != AccountOpResult::AOR_OK && bnetRes != AccountOpResult::AOR_NAME_ALREADY_EXIST)
        return false;

    QueryResult bnQr = LoginDatabase.PQuery("SELECT id FROM battlenet_accounts WHERE email='%s'", bnetEmail.c_str());
    if (!bnQr)
        return false;

    uint32 battlenetId = bnQr->Fetch()[0].GetUInt32();
    uint32 bnIndex = 1;
    if (QueryResult idxQr = LoginDatabase.PQuery("SELECT COALESCE(MAX(battlenet_index), 0) FROM account WHERE battlenet_account=%u", battlenetId))
        bnIndex = idxQr->Fetch()[0].GetUInt32() + 1;

    LoginDatabase.PExecute("UPDATE account SET battlenet_account=%u, battlenet_index=%u WHERE id=%u", battlenetId, bnIndex, accountId);

    if (m_cloneAccounts.find(accountId) == m_cloneAccounts.end())
    {
        PlayerBotBaseInfo* info = new PlayerBotBaseInfo(accountId, accName.c_str(), accHash, false, battlenetId);
        m_cloneAccounts[accountId] = info;
    }

    m_nextCloneIndex = index;
    return true;
}

PlayerBotBaseInfo* PlayerBotMgr::AcquireCloneAccount()
{
    for (std::map<uint32, PlayerBotBaseInfo*>::iterator it = m_cloneAccounts.begin(); it != m_cloneAccounts.end(); ++it)
    {
        bool used = false;
        for (BotCloneRecord const& record : m_cloneRecords)
        {
            if (record.accountId == it->first)
            {
                used = true;
                break;
            }
        }
        if (!used)
            return it->second;
    }

    if (m_cloneAccounts.size() >= 48)
        return nullptr;
    if (!CreateOneCloneAccount())
        return nullptr;
    return AcquireCloneAccount();
}

std::string PlayerBotMgr::MakeCloneName(std::string const& templateName)
{
    std::string root = templateName;
    if (root.size() > 8)
        root.resize(8);

    for (uint32 i = 1; i < 100; ++i)
    {
        std::string candidate = root + std::to_string(i);
        if (candidate.size() > 12)
            break;
        if (ObjectMgr::CheckPlayerName(candidate, LOCALE_enUS, true) != RESPONSE_SUCCESS)
            continue;

        PreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_CHECK_NAME);
        stmt->setString(0, candidate);
        if (!CharacterDatabase.Query(stmt))
            return candidate;
    }

    std::string fallback = RandomName();
    if (!fallback.empty())
        return fallback;
    return "Copy" + std::to_string(urand(1000, 9999));
}

WorldPacket PlayerBotMgr::BuildCloneCreateData(Player* templateBot, std::string const& name)
{
    WorldPacket data(CMSG_CREATE_CHARACTER);
    data.WriteBits(name.length(), 6);
    data.WriteBit(false);
    data.FlushBits();

    data << uint8(templateBot->getRace());
    data << uint8(templateBot->getClass());
    data << uint8(templateBot->GetByteValue(PLAYER_BYTES_3, PLAYER_BYTES_3_OFFSET_GENDER));
    data << uint8(templateBot->GetByteValue(PLAYER_BYTES, PLAYER_BYTES_OFFSET_SKIN_ID));
    data << uint8(templateBot->GetByteValue(PLAYER_BYTES, PLAYER_BYTES_OFFSET_FACE_ID));
    data << uint8(templateBot->GetByteValue(PLAYER_BYTES, PLAYER_BYTES_OFFSET_HAIR_STYLE_ID));
    data << uint8(templateBot->GetByteValue(PLAYER_BYTES, PLAYER_BYTES_OFFSET_HAIR_COLOR_ID));
    data << uint8(templateBot->GetByteValue(PLAYER_BYTES_2, PLAYER_BYTES_2_OFFSET_FACIAL_STYLE));
    data << uint8(0);

    data << uint8(0);
    data << uint8(0);
    data << uint8(0);
    data.WriteString(name);
    return data;
}

PlayerBotCharBaseInfo* PlayerBotMgr::FindCloneCharacter(PlayerBotBaseInfo* info, Player* templateBot)
{
    if (!info || !templateBot)
        return nullptr;

    uint16 gender = templateBot->GetByteValue(PLAYER_BYTES_3, PLAYER_BYTES_3_OFFSET_GENDER);
    std::string root = templateBot->GetName();
    if (root.size() > 8)
        root.resize(8);
    for (PlayerBotBaseInfo::CharInfoMap::iterator it = info->characters.begin(); it != info->characters.end(); ++it)
    {
        PlayerBotCharBaseInfo& character = it->second;
        if (character.race != templateBot->getRace() || character.profession != templateBot->getClass() || character.gender != gender)
            continue;
        if (character.name.size() < root.size() || character.name.compare(0, root.size(), root) != 0)
            continue;
        if (character.name.size() > root.size())
        {
            char suffix = character.name[root.size()];
            if (suffix < '0' || suffix > '9')
                continue;
        }
        return &character;
    }
    return nullptr;
}

void PlayerBotMgr::LoginCloneCharacter(PlayerBotBaseInfo* info, uint64 guidLow)
{
    if (!info)
        return;

    WorldSession* session = sWorld->FindSession(info->id);
    if (!session || session->PlayerLoading() || session->GetPlayer())
        return;

    WorldPacket packet(CMSG_PLAYER_LOGIN);
    WorldPackets::Character::PlayerLogin cmd(std::move(packet));
    cmd.Guid = ObjectGuid::Create<HighGuid::Player>(guidLow);
    cmd.FarClip = 0.0f;
    session->AddLegitCharacter(cmd.Guid);
    session->HandlePlayerLoginOpcode(cmd);
    session->HandleContinuePlayerLogin();
}

bool PlayerBotMgr::TryRecruitClone(Player* recruiter, Player* templateBot)
{
    if (!recruiter || !templateBot || recruiter->IsPlayerBot() || !IsRecruitTemplate(templateBot))
        return false;
    if (!recruiter->IsInWorld() || recruiter->GetTeamId() != templateBot->GetTeamId())
    {
        recruiter->GetSession()->SendNotification("%s cannot join your faction.", templateBot->GetName().c_str());
        return false;
    }
    if (RecruiterHasTemplate(recruiter->GetGUID(), templateBot->GetGUID()))
    {
        recruiter->GetSession()->SendNotification("You already have a copy of %s.", templateBot->GetName().c_str());
        return false;
    }

    uint32 limit = GetRecruitPartyLimit(recruiter);
    uint32 members = recruiter->GetGroup() ? recruiter->GetGroup()->GetMembersCount() : 1;
    uint32 pending = 0;
    for (BotCloneRecord const& existing : m_cloneRecords)
    {
        if (!existing.release && !existing.active && existing.recruiterGuid == recruiter->GetGUID())
            ++pending;
    }
    if (members + pending >= limit)
    {
        recruiter->GetSession()->SendNotification("Your group is full (%u).", limit);
        return false;
    }

    PlayerBotBaseInfo* account = AcquireCloneAccount();
    if (!account)
    {
        recruiter->GetSession()->SendNotification("No free copies are available.");
        return false;
    }

    BotCloneRecord record;
    record.accountId = account->id;
    record.templateGuid = templateBot->GetGUID();
    record.recruiterGuid = recruiter->GetGUID();
    record.level = recruiter->getLevel() > 0 ? recruiter->getLevel() : 1;
    m_cloneRecords.push_back(record);
    recruiter->GetSession()->SendNotification("%s is joining your group.", templateBot->GetName().c_str());
    return true;
}

void PlayerBotMgr::ReleaseCloneRecord(BotCloneRecord& record)
{
    record.release = true;
    record.loggingIn = false;
    record.active = false;

    WorldSession* session = sWorld->FindSession(record.accountId);
    if (!session || session->PlayerLoading() || session->isLogingOut())
        return;

    Player* bot = session->GetPlayer();
    if (!bot)
        return;

    if (bot->GetGroup())
        bot->RemoveFromGroup();
    session->LogoutPlayer(false);
}

void PlayerBotMgr::FinishCloneJoin(Player* clone)
{
    LegionForge::SetCrashBreadcrumb("PlayerBotMgr::FinishCloneJoin");
    if (!clone || !clone->GetSession())
        return;

    for (BotCloneRecord& record : m_cloneRecords)
    {
        if (record.accountId != clone->GetSession()->GetAccountId() || record.release || record.active)
            continue;

        Player* recruiter = ObjectAccessor::FindConnectedPlayer(record.recruiterGuid);
        if (!recruiter || !recruiter->IsInWorld())
            return;

        bool otherCopy = false;
        for (BotCloneRecord const& other : m_cloneRecords)
        {
            if (!other.release && other.accountId != record.accountId && other.recruiterGuid == record.recruiterGuid && other.templateGuid == record.templateGuid)
            {
                otherCopy = true;
                break;
            }
        }
        if (otherCopy)
        {
            ReleaseCloneRecord(record);
            return;
        }

        uint32 limit = GetRecruitPartyLimit(recruiter);
        Group* group = recruiter->GetGroup();
        uint32 members = group ? group->GetMembersCount() : 1;
        uint32 pendingOthers = 0;
        for (BotCloneRecord const& other : m_cloneRecords)
        {
            if (!other.release && other.recruiterGuid == record.recruiterGuid && other.accountId != record.accountId && !other.active)
                ++pendingOthers;
        }
        if (members + pendingOthers >= limit)
        {
            recruiter->GetSession()->SendNotification("Your group is full (%u).", limit);
            ReleaseCloneRecord(record);
            return;
        }

        if (!group)
        {
            group = new Group();
            if (!group->Create(recruiter))
            {
                delete group;
                ReleaseCloneRecord(record);
                return;
            }
            sGroupMgr->AddGroup(group);
        }

        if (!group->isRaidGroup() && limit > MAX_GROUP_SIZE && (group->IsFull() || group->GetMembersCount() + 1 > MAX_GROUP_SIZE))
            group->ConvertToRaid();

        if (group->IsFull() || !group->AddMember(clone))
        {
            recruiter->GetSession()->SendNotification("Your group is full (%u).", limit);
            ReleaseCloneRecord(record);
            return;
        }

        clone->CombatStop(true);
        clone->TeleportTo(recruiter->GetMapId(), recruiter->GetPositionX(), recruiter->GetPositionY(), recruiter->GetPositionZ(), recruiter->GetOrientation());
        if (clone->IsBeingTeleportedNear())
        {
            WorldPacket opcode(CMSG_MOVE_TELEPORT_ACK);
            WorldPackets::Movement::MoveTeleportAck ack(std::move(opcode));
            ack.MoverGUID = clone->GetGUID();
            clone->GetSession()->HandleMoveTeleportAck(ack);
        }
        else if (clone->IsBeingTeleportedFar())
            clone->GetSession()->HandleMoveWorldportAck();
        SwitchPlayerBotAI(clone, PlayerBotAIType::PBAIT_GROUP, true);
        record.active = true;
        record.loggingIn = false;
        return;
    }
}

void PlayerBotMgr::UpdateCloneRecruits()
{
    for (BotCloneRecord& record : m_cloneRecords)
    {
        PlayerBotBaseInfo* info = GetCloneAccountInfo(record.accountId);
        if (!info)
        {
            record.release = true;
            continue;
        }

        WorldSession* session = sWorld->FindSession(info->id);
        Player* recruiter = ObjectAccessor::FindConnectedPlayer(record.recruiterGuid);

        if (record.release)
        {
            if (session && (session->PlayerLoading() || session->isLogingOut()))
                continue;
            if (session && session->GetPlayer())
            {
                if (session->GetPlayer()->GetGroup())
                    session->GetPlayer()->RemoveFromGroup();
                session->LogoutPlayer(false);
            }
            continue;
        }

        ++record.ticks;
        if (!record.active && record.ticks > 60)
        {
            if (recruiter && recruiter->GetSession())
                recruiter->GetSession()->SendNotification("The copy did not arrive.");
            ReleaseCloneRecord(record);
            continue;
        }

        if (record.active)
        {
            Player* clone = session ? session->GetPlayer() : nullptr;
            if (!recruiter)
            {
                ReleaseCloneRecord(record);
                continue;
            }
            if (!recruiter->IsInWorld() || !clone || !clone->IsInWorld())
                continue;

            Group* group = clone->GetGroup();
            if (!group || !group->IsMember(recruiter->GetGUID()))
            {
                ReleaseCloneRecord(record);
                continue;
            }

            if (clone->GetMapId() != recruiter->GetMapId() && !clone->IsBeingTeleported())
            {
                clone->CombatStop(true);
                clone->TeleportTo(recruiter->GetMapId(), recruiter->GetPositionX(), recruiter->GetPositionY(), recruiter->GetPositionZ(), recruiter->GetOrientation());
                if (clone->IsBeingTeleportedFar())
                    clone->GetSession()->HandleMoveWorldportAck();
            }
            continue;
        }

        if (!recruiter)
        {
            ReleaseCloneRecord(record);
            continue;
        }
        if (!recruiter->IsInWorld())
            continue;

        Player* templateBot = ObjectAccessor::FindConnectedPlayer(record.templateGuid);
        if (!templateBot)
        {
            ReleaseCloneRecord(record);
            continue;
        }

        if (!session)
        {
            UpPlayerBotSessionByBaseInfo(info, false);
            continue;
        }
        if (session->PlayerLoading())
            continue;
        if (session->GetPlayer())
        {
            FinishCloneJoin(session->GetPlayer());
            continue;
        }

        PlayerBotCharBaseInfo* character = nullptr;
        if (!record.cloneName.empty())
        {
            for (PlayerBotBaseInfo::CharInfoMap::iterator it = info->characters.begin(); it != info->characters.end(); ++it)
            {
                if (it->second.name == record.cloneName)
                {
                    character = &it->second;
                    break;
                }
            }
        }
        if (!character)
        {
            if (!info->needCreateBots.empty())
                continue;
            if (record.createAttempts >= 3)
            {
                if (recruiter->GetSession())
                    recruiter->GetSession()->SendNotification("%s could not be copied.", templateBot->GetName().c_str());
                ReleaseCloneRecord(record);
                continue;
            }
            ++record.createAttempts;
            record.cloneName = RandomName();
            if (record.cloneName.empty())
            {
                if (recruiter->GetSession())
                    recruiter->GetSession()->SendNotification("%s could not be copied.", templateBot->GetName().c_str());
                ReleaseCloneRecord(record);
                continue;
            }
            info->needCreateBots.push(BuildCloneCreateData(templateBot, record.cloneName));
            if (!CreateQueuedPlayerBotForSession(info, session))
            {
                record.cloneName.clear();
                continue;
            }
            for (PlayerBotBaseInfo::CharInfoMap::iterator it = info->characters.begin(); it != info->characters.end(); ++it)
            {
                if (it->second.name == record.cloneName)
                {
                    character = &it->second;
                    break;
                }
            }
            if (!character)
                continue;
        }

        record.loggingIn = true;
        LoginCloneCharacter(info, character->guid);
    }

    m_cloneRecords.erase(std::remove_if(m_cloneRecords.begin(), m_cloneRecords.end(), [](BotCloneRecord const& record)
    {
        if (!record.release)
            return false;
        WorldSession* session = sWorld->FindSession(record.accountId);
        return !session || (!session->PlayerLoading() && !session->isLogingOut() && !session->GetPlayer());
    }), m_cloneRecords.end());
}

void PlayerBotMgr::Update()
{
    UpdateCloneRecruits();

    static uint8 startupLoginAttempts = 0;
    if (startupLoginAttempts < 30)
    {
        ++startupLoginAttempts;
        AllPlayerBotRandomLogin("");
    }

    OnlinePlayerBotByGUIDQueue();

    //if (!ExistUnBGPlayerBot())
    QueryBattlegroundRequirement();
#ifndef INCOMPLETE_BOT
    //sArenaTeamMgr->CheckPlayerBotArenaTeam();
    QueryRatedArenaRequirement();
    QueryNonRatedArenaRequirement();
    if (m_LFGSearchTick > 1)
    {
        m_LFGSearchTick = 0;
        if (lfg::LFGBotRequirement* pbotReq = sLFGMgr->SearchLFGBotRequirement())
        {
            AddNewPlayerBotToLFG(pbotReq);
            delete pbotReq;
        }
    }
    else
        ++m_LFGSearchTick;
#endif

    std::list<std::map<uint32, std::list<UnitAI*> >::iterator > delITer;
    uint32 currentTick = getMSTime();
    for (std::map<uint32, std::list<UnitAI*> >::iterator itDelayAi = m_DelayDestroyAIs.begin();
        itDelayAi != m_DelayDestroyAIs.end();
        itDelayAi++)
    {
        uint32 delayTick = itDelayAi->first;
        if (delayTick + 5000 >= currentTick)
        {
            for (std::list<UnitAI*>::iterator itAI = itDelayAi->second.begin();
                itAI != itDelayAi->second.end();
                itAI++)
            {
                UnitAI* pAI = (*itAI);
                if (pAI)
                    delete pAI;
            }
            itDelayAi->second.clear();
            delITer.push_back(itDelayAi);
        }
    }
    for (std::list<std::map<uint32, std::list<UnitAI*> >::iterator >::iterator itDel = delITer.begin();
        itDel != delITer.end();
        itDel++)
    {
        m_DelayDestroyAIs.erase(*itDel);
    }
}
