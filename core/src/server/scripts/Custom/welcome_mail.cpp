/*
 * One welcome letter for each new character.
 */

#include "DatabaseEnv.h"
#include "Mail.h"
#include "Player.h"
#include "ScriptMgr.h"

class player_welcome_mail : public PlayerScript
{
public:
    player_welcome_mail() : PlayerScript("player_welcome_mail") { }

    void OnCreate(Player* player) override
    {
        if (!player)
            return;

        std::string body =
            "Hello, and welcome to the Legion server.$B$B"
            "I'm n0social. I'm getting World of Warcraft: Legion 7.3.5 into working condition so people can play it again.$B$B"
            "Play it with friends on a server of your own, test what's here, or build on it. "
            "The project is at https://github.com/n0social/project_legion. "
            "Fork it, and if you find a fix for a bug, tell me there.";

        // Creature 9500100 is named n0social. Creature mail shows that name.
        // A player sender of 0 has no name, so the client falls back to another letter.
        SQLTransaction trans = CharacterDatabase.BeginTransaction();
        MailDraft("Welcome to Legion", body)
            .SendMailTo(trans, MailReceiver(player), MailSender(MAIL_CREATURE, 9500100));
        CharacterDatabase.CommitTransaction(trans);
    }
};

void AddSC_player_welcome_mail()
{
    new player_welcome_mail();
}
