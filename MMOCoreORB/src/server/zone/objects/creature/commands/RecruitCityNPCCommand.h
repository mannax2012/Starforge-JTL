/*
				Copyright <SWGEmu>
		See file COPYING for copying conditions.*/

#ifndef RECRUITCITYNPCCOMMAND_H_
#define RECRUITCITYNPCCOMMAND_H_

#include "server/zone/objects/player/sui/listbox/SuiListBox.h"
#include "server/zone/objects/creature/commands/sui/RecruitCityNPCSuiCallback.h"

class RecruitCityNPCCommand : public QueueCommand {
public:

	RecruitCityNPCCommand(const String& name, ZoneProcessServer* server)
		: QueueCommand(name, server) {

	}

	int doQueueCommand(CreatureObject* creature, const uint64& target, const UnicodeString& arguments) const {

		if (!checkStateMask(creature))
			return INVALIDSTATE;

		if (!checkInvalidLocomotions(creature))
			return INVALIDLOCOMOTION;

		PlayerObject* ghost = creature->getPlayerObject();
		if (ghost == nullptr)
			return GENERALERROR;

		if (!ghost->hasAbility("recruitcitynpc"))
			return GENERALERROR;

		if (creature->isIncapacitated() || creature->isDead())
			return GENERALERROR;

		ManagedReference<CityRegion*> city = creature->getCityRegion().get();
		if (city == nullptr)
			return GENERALERROR;

		if (!city->isMayor(creature->getObjectID()))
			return GENERALERROR;

		ManagedReference<SuiListBox*> suicityNPCType = new SuiListBox(creature, SuiWindowType::RECRUIT_CITY_NPC, 0);
		suicityNPCType->setCallback(new RecruitCityNPCSuiCallback(server->getZoneServer()));

		suicityNPCType->setPromptTitle("@starforge_n:citynpc_n"); // Recruit City NPC
		suicityNPCType->setPromptText("@starforge_n:citynpc_d");

		suicityNPCType->addMenuItem("@starforge_n:citynpc_junkdealer", 0);
		suicityNPCType->addMenuItem("@starforge_n:citynpc_spynet_one", 1);
		suicityNPCType->addMenuItem("@starforge_n:citynpc_spynet_two", 2);
		suicityNPCType->addMenuItem("@starforge_n:citynpc_spynet_three", 3);

		ghost->addSuiBox(suicityNPCType);
		creature->sendMessage(suicityNPCType->generateMessage());

		return SUCCESS;
	}

};

#endif //RECRUITCITYNPCCOMMAND_H_
