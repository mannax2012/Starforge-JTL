/*
 * RecruitCITYNPC.h
 *
 *  Created on: Apr. 26 2012
 *      Author: TragD
 */

#ifndef RECRUITCITYNPCCALLBACK_H_
#define RECRUITCITYNPCCALLBACK_H_

#include "server/zone/objects/player/sui/SuiCallback.h"
#include "server/zone/Zone.h"
#include "server/zone/managers/creature/CreatureManager.h"
#include "server/zone/managers/city/CityManager.h"

class RecruitCityNPCSuiCallback : public SuiCallback {
public:
	RecruitCityNPCSuiCallback(ZoneServer* server)
		: SuiCallback(server) {
	}

	void run(CreatureObject* player, SuiBox* suiBox, uint32 eventIndex, Vector<UnicodeString>* args) {
		bool cancelPressed = (eventIndex == 1);

		if (cancelPressed)
			return;

		if (args->size() < 1)
			return;

		if (player->getParent() != nullptr)
			return;

		ManagedReference<CityRegion*> city = player->getCityRegion().get();
		CityManager* cityManager = player->getZoneServer()->getCityManager();
		if (city == nullptr || cityManager == nullptr)
			return;

		if (!city->isMayor(player->getObjectID()))
			return;

		if (!cityManager->canSupportMoreTrainers(city)) {
					player->sendSystemMessage("@city/city:no_more_trainers"); // Your city can't support any more trainers at its current rank!
					return;
		}

		Zone* zone = player->getZone();

		PlayerObject* ghost = player->getPlayerObject();
		if (ghost == nullptr)
			return;

		if (!ghost->hasAbility("recruitcitynpc"))
			return;

		int option = Integer::valueOf(args->get(0).toString());

		String cityNPCTemplatePath = "";

		switch (option) {

		case 0: cityNPCTemplatePath = "junk_dealer";
				break;

		case 1: cityNPCTemplatePath = "informant_npc_lvl_1";
				break;

		case 2: cityNPCTemplatePath = "informant_npc_lvl_2";
				break;

		case 3: cityNPCTemplatePath = "informant_npc_lvl_3";

		}

		if (cityNPCTemplatePath != "") {
			Locker clocker(city, player);

			if(city->getCityTreasury() < 1000) {
				StringIdChatParameter msg;
				msg.setStringId("@city/city:action_no_money");
				msg.setDI(1000);
				player->sendSystemMessage(msg); //"The city treasury must have %DI credits in order to perform that action.");
				return;

			}

			if(player->isSwimming() || player->isIncapacitated() || player->isDead()) {
				return;
			}

			CreatureObject* cityNPC = zone->getCreatureManager()->spawnCreature(cityNPCTemplatePath.hashCode(),0,player->getWorldPositionX(),player->getWorldPositionZ(),player->getWorldPositionY(),0,true);

			if (cityNPC == nullptr) {
				player->sendSystemMessage("@city/city:st_fail"); // Failed to create the skill trainer for some reason. Try again.
				return;
			}

			cityNPC->rotate(player->getDirectionAngle());
			city->subtractFromCityTreasury(1000);
			city->addSkillTrainer(cityNPC);

			if (!city->isRegistered()) {
				zone->unregisterObjectWithPlanetaryMap(cityNPC);
			}
		}
	}
};

#endif /* RECRUITCITYNPCCALLBACK_H_ */
