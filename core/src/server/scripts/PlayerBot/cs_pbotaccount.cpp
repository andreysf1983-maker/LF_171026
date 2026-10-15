/*


 */

#include "PlayerBotMgr.h"
#include "Chat.h"
#include "ScriptMgr.h"
#include "World.h"
#include "RBAC.h"

static bool HandlePBotLogoutAllCommand(ChatHandler* /*handler*/, char const* /*args*/)
{
    sPlayerBotMgr->AllPlayerBotLogout();
    return true;
}

static bool HandlePBotLoginClassesCommand(ChatHandler* /*handler*/, char const* args)
{
    if (!*args)
        return false;
    char* clsStr = strtok((char*)args, " ");
    char* numStr = strtok(nullptr, " ");
    if (!clsStr)
        return false;
    uint32 prof = uint32(atoi(clsStr));
    uint32 count = numStr ? uint32(atoi(numStr)) : 1;
    sPlayerBotMgr->AddNewPlayerBotByClass(count, Classes(prof));
    return true;
}

static bool HandlePBotLoginAllCommand(ChatHandler* /*handler*/, char const* /*args*/)
{
    sPlayerBotMgr->AllPlayerBotRandomLogin();
    return true;
}

static bool HandlePBotCreateCommand(ChatHandler* /*handler*/, char const* /*args*/)
{
    sPlayerBotMgr->SupplementPlayerBot();
    return true;
}

static bool HandlePBotResetLVCommand(ChatHandler* /*handler*/, char const* args)
{
    if (!*args)
        return false;
    char* lvStr = strtok((char*)args, " ");
    char* lmNumStr = strtok(nullptr, " ");
    char* blNumStr = strtok(nullptr, " ");
    if (!lvStr)
        return false;

    uint32 level = uint32(atoi(lvStr));
    uint32 lmNum = lmNumStr ? uint32(atoi(lmNumStr)) : 300;
    uint32 blNum = blNumStr ? uint32(atoi(blNumStr)) : 300;
    if (level == 0)
        return false;
    if (level > 110)
        level = 110;

    SessionMap const sessions = sWorld->GetAllSessions();
    for (SessionMap::const_iterator itSession = sessions.begin(); itSession != sessions.end(); ++itSession)
    {
        Player* player = itSession->second->GetPlayer();
        if (!player || uint32(player->getLevel()) == level)
            continue;
        if (player->GetTeamId() == TEAM_ALLIANCE && lmNum > 0)
        {
            if (player->ResetPlayerToLevel(level))
                --lmNum;
        }
        else if (player->GetTeamId() == TEAM_HORDE && blNum > 0)
        {
            if (player->ResetPlayerToLevel(level))
                --blNum;
        }
        if (lmNum == 0 && blNum == 0)
            break;
    }
    return true;
}

static bool HandlePBotLoginAccountCommand(ChatHandler* /*handler*/, char const* args)
{
    if (!*args)
        return false;
    char* minAccStr = strtok((char*)args, " ");
    char* maxAccStr = strtok(nullptr, " ");
    char* accIndexStr = strtok(nullptr, " ");
    if (!minAccStr || !maxAccStr || !accIndexStr)
        return false;
    uint32 minAcc = uint32(atoi(minAccStr));
    uint32 maxAcc = uint32(atoi(maxAccStr));
    if (maxAcc < minAcc)
        maxAcc = minAcc;
    uint32 accIndex = uint32(atoi(accIndexStr));
    sPlayerBotMgr->AllPlayerBotLogout();
    for (uint32 acc = minAcc; acc <= maxAcc; ++acc)
    {
        if (!sPlayerBotMgr->LoginBotByAccountIndex(acc, accIndex))
        {
            char text[128] = { 0 };
            snprintf(text, 127, "Login bot error. acc %u, index %u.", acc, accIndex);
            sWorld->SendGlobalText(text, nullptr);
        }
    }
    return true;
}

class pbotaccount_commandscript : public CommandScript
{
public:
    pbotaccount_commandscript() : CommandScript("pbotaccount_commandscript") { }

    std::vector<ChatCommand> GetCommands() const override
    {
        static std::vector<ChatCommand> pbotaccCommandTable =
        {
            { "resetlevel", rbac::RBAC_PERM_COMMAND_SERVER_DEBUG, true, &HandlePBotResetLVCommand, "" },
            { "logoutall", rbac::RBAC_PERM_COMMAND_SERVER_DEBUG, true, &HandlePBotLogoutAllCommand, "" },
            { "loginall", rbac::RBAC_PERM_COMMAND_SERVER_DEBUG, true, &HandlePBotLoginAllCommand, "" },
            { "botcreate", rbac::RBAC_PERM_COMMAND_SERVER_DEBUG, true, &HandlePBotCreateCommand, "" },
            { "loginclasses", rbac::RBAC_PERM_COMMAND_SERVER_DEBUG, true, &HandlePBotLoginClassesCommand, "" },
            { "loginacc", rbac::RBAC_PERM_COMMAND_SERVER_DEBUG, true, &HandlePBotLoginAccountCommand, "" },
        };

        static std::vector<ChatCommand> commandTable =
        {
            { "pbotacc", rbac::RBAC_PERM_COMMAND_SERVER_DEBUG, false, nullptr, "", pbotaccCommandTable },
        };

        return commandTable;
    }
};

void AddSC_pbotaccount_commandscript()
{
    new pbotaccount_commandscript();
}
