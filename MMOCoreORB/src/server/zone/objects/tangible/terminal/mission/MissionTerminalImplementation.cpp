/*
 * MissionTerminalImplementation.cpp
 *
 *  Created on: 03/05/11
 *      Author: polonel
 */

#include "server/zone/objects/tangible/terminal/mission/MissionTerminal.h"
#include "server/zone/objects/creature/CreatureObject.h"
#include "server/zone/packets/object/ObjectMenuResponse.h"
#include "server/zone/objects/region/CityRegion.h"
#include "server/zone/managers/city/CityManager.h"
#include "server/zone/managers/city/CityRemoveAmenityTask.h"
#include "server/zone/objects/player/sessions/SlicingSession.h"
#include "server/zone/managers/director/DirectorManager.h"
#include "server/zone/managers/player/PlayerManager.h"
#include "server/zone/objects/group/GroupObject.h"
#include "server/zone/objects/player/PlayerObject.h"
#include "server/zone/objects/player/sui/SuiCallback.h"
#include "server/zone/objects/player/sui/listbox/SuiListBox.h"

namespace {
constexpr byte MISSION_DIRECTION_MENU_ID = 113;
constexpr byte MISSION_DIFFICULTY_MENU_ID = 114;
constexpr int MISSION_DIFFICULTY_BRACKET_SIZE = 10;
constexpr const char* MISSION_DIFFICULTY_CHOICE_SCREENPLAY = "mission_difficulty_choice";
constexpr const char* MISSION_DIFFICULTY_CHOICE_VARIABLE = "levelBracketMax";

bool supportsDirectionalMissionSelection(const String& terminalType) {
	return terminalType == "general" || terminalType == "imperial" || terminalType == "rebel";
}

bool supportsMissionDifficultySelection(const String& terminalType) {
	return terminalType == "general" || terminalType == "imperial" || terminalType == "rebel" || terminalType == "scout";
}

bool shouldIncludeFactionPetsForMissionDifficulty(const String& terminalType) {
	return terminalType == "imperial" || terminalType == "rebel" || ConfigManager::instance()->includeFactionPetsForMissionDifficulty();
}

int getMissionTerminalCombatLevel(CreatureObject* player, const String& terminalType) {
	if (player == nullptr) {
		return 1;
	}

	int combatLevel = player->getZoneServer()->getPlayerManager()->calculatePlayerLevel(player);

	if (player->isGrouped()) {
		Reference<GroupObject*> group = player->getGroup();

		if (group != nullptr) {
			Locker locker(group);
			combatLevel = group->getGroupLevel(shouldIncludeFactionPetsForMissionDifficulty(terminalType));
		}
	}

	return Math::max(1, combatLevel);
}

int getMissionDifficultyBracketMax(int combatLevel) {
	combatLevel = Math::max(1, combatLevel);

	return ((combatLevel - 1) / MISSION_DIFFICULTY_BRACKET_SIZE + 1) * MISSION_DIFFICULTY_BRACKET_SIZE;
}

int getMissionDifficultyBracketMin(int bracketMax) {
	return Math::max(1, bracketMax - MISSION_DIFFICULTY_BRACKET_SIZE + 1);
}

String getMissionDifficultyBracketLabel(int bracketMax) {
	return String::valueOf(getMissionDifficultyBracketMin(bracketMax)) + "-" + String::valueOf(bracketMax);
}

class MissionDifficultySelectionSuiCallback : public SuiCallback {
	String terminalType;

public:
	MissionDifficultySelectionSuiCallback(ZoneServer* server, const String& terminal)
		: SuiCallback(server), terminalType(terminal) {
	}

	void run(CreatureObject* player, SuiBox* suiBox, uint32 eventIndex, Vector<UnicodeString>* args) {
		if (player == nullptr || !suiBox->isListBox() || eventIndex == 1 || args == nullptr || args->size() <= 0) {
			return;
		}

		PlayerObject* ghost = player->getPlayerObject();

		if (ghost == nullptr) {
			return;
		}

		SuiListBox* listBox = cast<SuiListBox*>(suiBox);
		int index = Integer::valueOf(args->get(0).toString());

		if (index < 0 || index >= listBox->getMenuSize()) {
			player->sendSystemMessage("No mission difficulty range was selected.");
			return;
		}

		int currentBracketMax = getMissionDifficultyBracketMax(getMissionTerminalCombatLevel(player, terminalType));

		if (index == 0) {
			ghost->deleteScreenPlayData(MISSION_DIFFICULTY_CHOICE_SCREENPLAY, MISSION_DIFFICULTY_CHOICE_VARIABLE);
			player->sendSystemMessage("Mission difficulty has been reset to your current combat range.");
			return;
		}

		int selectedBracketMax = currentBracketMax - (index * MISSION_DIFFICULTY_BRACKET_SIZE);

		if (selectedBracketMax < MISSION_DIFFICULTY_BRACKET_SIZE) {
			ghost->deleteScreenPlayData(MISSION_DIFFICULTY_CHOICE_SCREENPLAY, MISSION_DIFFICULTY_CHOICE_VARIABLE);
			player->sendSystemMessage("That mission difficulty range is no longer available.");
			return;
		}

		ghost->setScreenPlayData(MISSION_DIFFICULTY_CHOICE_SCREENPLAY, MISSION_DIFFICULTY_CHOICE_VARIABLE, String::valueOf(selectedBracketMax));
		player->sendSystemMessage("Mission difficulty has been lowered to the " + getMissionDifficultyBracketLabel(selectedBracketMax) + " bracket. Refresh the terminal to view missions in that range.");
	}
};
}

void MissionTerminalImplementation::fillObjectMenuResponse(ObjectMenuResponse* menuResponse, CreatureObject* player) {
	TerminalImplementation::fillObjectMenuResponse(menuResponse, player);

	ManagedReference<CityRegion*> city = player->getCityRegion().get();

	if (city != nullptr && city->isMayor(player->getObjectID()) && getParent().get() == nullptr) {

		menuResponse->addRadialMenuItem(72, 3, "@city/city:mt_remove"); // Remove

		menuResponse->addRadialMenuItem(73, 3, "@city/city:align"); // Align
		menuResponse->addRadialMenuItemToRadialID(73, 74, 3, "@city/city:north"); // North
		menuResponse->addRadialMenuItemToRadialID(73, 75, 3, "@city/city:east"); // East
		menuResponse->addRadialMenuItemToRadialID(73, 76, 3, "@city/city:south"); // South
		menuResponse->addRadialMenuItemToRadialID(73, 77, 3, "@city/city:west"); // West
	}
	if (supportsDirectionalMissionSelection(terminalType)) {
		menuResponse->addRadialMenuItem(MISSION_DIRECTION_MENU_ID, 3, "Choose Mission Direction");
	}

	if (supportsMissionDifficultySelection(terminalType)) {
		menuResponse->addRadialMenuItem(MISSION_DIFFICULTY_MENU_ID, 3, "Choose Mission Difficulty");
	}
}

int MissionTerminalImplementation::handleObjectMenuSelect(CreatureObject* player, byte selectedID) {
	ManagedReference<CityRegion*> city = player->getCityRegion().get();

	if (selectedID == 69 && player->hasSkill("combat_smuggler_slicing_01")) {
		if (isBountyTerminal())
			return 0;

		if (city != nullptr && !city->isClientRegion() && city->isBanned(player->getObjectID())) {
			player->sendSystemMessage("@city/city:banned_services"); // You are banned from using this city's services.
			return 0;
		}

		if (player->containsActiveSession(SessionFacadeType::SLICING)) {
			player->sendSystemMessage("@slicing/slicing:already_slicing");
			return 0;
		}

		if (!player->checkCooldownRecovery("slicing.terminal")) {
			StringIdChatParameter message;
			message.setStringId("@slicing/slicing:not_yet"); // You will be able to hack the network again in %DI seconds.
			message.setDI(player->getCooldownTime("slicing.terminal")->getTime() - Time().getTime());
			player->sendSystemMessage(message);
			return 0;
		}

		//Create Session
		ManagedReference<SlicingSession*> session = new SlicingSession(player);
		session->initalizeSlicingMenu(player, _this.getReferenceUnsafeStaticCast());

		return 0;

	} else if (selectedID == 72) {

		if (city != nullptr && city->isMayor(player->getObjectID())) {
			CityRemoveAmenityTask* task = new CityRemoveAmenityTask(_this.getReferenceUnsafeStaticCast(), city);
			task->execute();

			player->sendSystemMessage("@city/city:mt_removed"); // The object has been removed from the city.
		}

		return 0;
	}
	else if (selectedID == MISSION_DIRECTION_MENU_ID) {

		Lua* lua = DirectorManager::instance()->getLuaInstance();

		Reference<LuaFunction*> mission_direction_choice = lua->createFunction("mission_direction_choice", "openWindow", 0);
		*mission_direction_choice << player;

		mission_direction_choice->callFunction();
		return 0;

	} else if (selectedID == MISSION_DIFFICULTY_MENU_ID) {
		PlayerObject* ghost = player->getPlayerObject();

		if (ghost == nullptr) {
			return 0;
		}

		int currentBracketMax = getMissionDifficultyBracketMax(getMissionTerminalCombatLevel(player, terminalType));

		if (currentBracketMax <= MISSION_DIFFICULTY_BRACKET_SIZE) {
			ghost->deleteScreenPlayData(MISSION_DIFFICULTY_CHOICE_SCREENPLAY, MISSION_DIFFICULTY_CHOICE_VARIABLE);
			player->sendSystemMessage("Your current combat range is already the lowest available mission bracket.");
			return 0;
		}

		ManagedReference<SuiListBox*> box = new SuiListBox(player, 0);
		box->setCallback(new MissionDifficultySelectionSuiCallback(getZoneServer(), terminalType));
		box->setPromptTitle("Mission Difficulty Selection");

		String promptText = "Use this menu to lower combat mission offerings to a fixed level bracket.\n\nCurrent combat range: " + getMissionDifficultyBracketLabel(currentBracketMax) + "\n";
		String selectedBracket = ghost->getScreenPlayData(MISSION_DIFFICULTY_CHOICE_SCREENPLAY, MISSION_DIFFICULTY_CHOICE_VARIABLE);

		if (!selectedBracket.isEmpty()) {
			int selectedBracketMax = Integer::valueOf(selectedBracket);

			if (selectedBracketMax >= MISSION_DIFFICULTY_BRACKET_SIZE && selectedBracketMax < currentBracketMax) {
				promptText += "Active lower range: " + getMissionDifficultyBracketLabel(selectedBracketMax) + "\n";
			} else {
				ghost->deleteScreenPlayData(MISSION_DIFFICULTY_CHOICE_SCREENPLAY, MISSION_DIFFICULTY_CHOICE_VARIABLE);
			}
		}

		promptText += "\nChoose Current Range to restore normal mission difficulty. Only lower brackets are listed below.";
		box->setPromptText(promptText);

		box->addMenuItem("Current Range (" + getMissionDifficultyBracketLabel(currentBracketMax) + ")");

		for (int bracketMax = currentBracketMax - MISSION_DIFFICULTY_BRACKET_SIZE; bracketMax >= MISSION_DIFFICULTY_BRACKET_SIZE; bracketMax -= MISSION_DIFFICULTY_BRACKET_SIZE) {
			box->addMenuItem(getMissionDifficultyBracketLabel(bracketMax));
		}

		ghost->addSuiBox(box);
		player->sendMessage(box->generateMessage());
		return 0;

	} else if (selectedID == 74 || selectedID == 75 || selectedID == 76 || selectedID == 77) {

		CityManager* cityManager = getZoneServer()->getCityManager();
		cityManager->alignAmenity(city, player, _this.getReferenceUnsafeStaticCast(), selectedID - 74);

		return 0;
	}

	return TangibleObjectImplementation::handleObjectMenuSelect(player, selectedID);
}

String MissionTerminalImplementation::getTerminalName() {
	String name = "@terminal_name:terminal_mission";

	if (terminalType == "artisan" || terminalType == "entertainer" || terminalType == "bounty" || terminalType == "imperial" || terminalType == "rebel" || terminalType == "scout")
		name = name + "_" + terminalType;

	return name;
}
