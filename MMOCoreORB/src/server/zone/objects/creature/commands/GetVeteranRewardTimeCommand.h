/*
				Copyright <SWGEmu>
		See file COPYING for copying conditions.*/

#ifndef GETVETERANREWARDTIMECOMMAND_H_
#define GETVETERANREWARDTIMECOMMAND_H_

#include "conf/ConfigManager.h"

class GetVeteranRewardTimeCommand : public QueueCommand {
public:
	GetVeteranRewardTimeCommand(const String& name, ZoneProcessServer* server) : QueueCommand(name, server) {
	}

	int doQueueCommand(CreatureObject* player, const uint64& target, const UnicodeString& arguments) const {
		if (!checkStateMask(player))
			return INVALIDSTATE;

		if (!checkInvalidLocomotions(player))
			return INVALIDLOCOMOTION;

		if (!player->isPlayerCreature())
			return GENERALERROR;

		auto zoneServer = player->getZoneServer();

		if (zoneServer == nullptr)
			return GENERALERROR;

		auto ghost = player->getPlayerObject();

		if (ghost == nullptr)
			return GENERALERROR;

		auto playerManager = zoneServer->getPlayerManager();

		if (playerManager == nullptr)
			return GENERALERROR;

		// Get account
		ManagedReference<Account*> account = ghost->getAccount();

		if (account == nullptr)
			return GENERALERROR;

		Locker alocker(account);

		// Send message with current account age
		StringIdChatParameter timeActiveMsg;
		timeActiveMsg.setStringId("veteran", "self_time_active"); // You have %DI days logged for veteran rewards.
		timeActiveMsg.setDI(account->getAgeInDays());
		player->sendSystemMessage(timeActiveMsg);

		StringBuffer buff;

		// Check if player is eligible for a reward
		int eligibleMilestone = playerManager->getEligibleMilestone(ghost, account);

		if (eligibleMilestone > -1) {
			StringIdChatParameter timeMsg("veteran", "new_reward"); // "You are eligible for the %DI day veteran reward! Use the /claimVeteranReward command to get your reward."
			timeMsg.setDI(eligibleMilestone);

			player->sendSystemMessage(timeMsg);

			// Call out the yacht now that it sits on its own 30-day tier.
			if (eligibleMilestone == 30 && ConfigManager::instance()->isJtlEnabled()) {
				player->sendSystemMessage("You are eligible for the 30-day Jump to Lightspeed veteran reward, the Sorosuub Luxury Yacht.");
			}
		} else {
			player->sendSystemMessage("@veteran:not_eligible"); // You are not currently eligible for a veteran reward.

			// Check next milestone
			int nextMilestone = playerManager->getFirstIneligibleMilestone(ghost, account);
			buff << "You will be eligible for the " << String::valueOf(nextMilestone) << "-day reward in ";
			buff << String::valueOf(nextMilestone - account->getAgeInDays()) << " days";
			player->sendSystemMessage(buff.toString());
		}

		// Send character played time
		player->sendSystemMessage(ghost->getPlayedTimeString(true));

		return SUCCESS;
	}
};

#endif // GETVETERANREWARDTIMECOMMAND_H_
