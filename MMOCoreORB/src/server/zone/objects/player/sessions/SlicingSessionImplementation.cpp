/*
 * SlicingSessionImplementation.cpp
 *
 *  Created on: Mar 5, 2011
 *      Author: polonel
 */

#include "server/zone/objects/player/sessions/SlicingSession.h"
#include "server/zone/objects/player/sui/SuiWindowType.h"
#include "server/zone/objects/player/sui/listbox/SuiListBox.h"
#include "server/zone/objects/tangible/tool/smuggler/SlicingTool.h"
#include "server/zone/objects/player/PlayerObject.h"
#include "server/zone/managers/player/PlayerManager.h"
#include "server/zone/managers/loot/LootManager.h"
#include "server/zone/managers/gcw/GCWManager.h"
#include "server/zone/managers/gcw/tasks/SecuritySliceTask.h"
#include "server/zone/objects/tangible/Container.h"
#include "server/zone/objects/tangible/RelockLootContainerEvent.h"
#include "server/zone/objects/tangible/weapon/WeaponObject.h"
#include "server/zone/objects/tangible/wearables/ArmorObject.h"
#include "server/zone/objects/tangible/terminal/mission/MissionTerminal.h"
#include "server/zone/objects/tangible/tool/smuggler/PrecisionLaserKnife.h"
#include "server/zone/objects/tangible/powerup/PowerupObject.h"

#include "server/zone/objects/player/sessions/sui/SlicingSessionSuiCallback.h"

#include "server/zone/ZoneServer.h"

#include "server/zone/Zone.h"
#include "server/zone/objects/scene/SceneObjectType.h"
#include "system/lang.h"
#include "system/util/HashTable.h"

namespace {
	enum SliceTypeSelection : byte {
		SLICE_SELECTION_PRIMARY = 0,
		SLICE_SELECTION_SECONDARY = 1,
		SLICE_SELECTION_TERTIARY = 2,
		SLICE_SELECTION_UNSET = 0xFF
	};

	class SliceSelectionMap : public HashTable<uint64, byte> {
		int hash(uint64 const& key) {
			return Long::hashCode((long long) key);
		}

	public:
		SliceSelectionMap() : HashTable<uint64, byte>(32) {
			setNullValue(SLICE_SELECTION_UNSET);
		}
	};

	Mutex sliceSelectionMutex;
	SliceSelectionMap sliceSelections;

	inline uint64 getSliceSelectionKey(SlicingSessionImplementation* session) {
		return reinterpret_cast<uint64>(session);
	}

	byte getSliceSelection(SlicingSessionImplementation* session) {
		Locker locker(&sliceSelectionMutex);
		return sliceSelections.get(getSliceSelectionKey(session));
	}

	void setSliceSelection(SlicingSessionImplementation* session, byte selection) {
		Locker locker(&sliceSelectionMutex);
		sliceSelections.put(getSliceSelectionKey(session), selection);
	}

	void clearSliceSelection(SlicingSessionImplementation* session) {
		Locker locker(&sliceSelectionMutex);
		sliceSelections.remove(getSliceSelectionKey(session));
	}

	bool needsSliceTypeSelection(TangibleObject* tangibleObject) {
		return tangibleObject != nullptr && (tangibleObject->isWeaponObject() || tangibleObject->isArmorObject());
	}

	String getSliceSelectionPrompt(TangibleObject* tangibleObject) {
		if (tangibleObject != nullptr && tangibleObject->isWeaponObject())
			return "Select the weapon slice to attempt.";

		return "Select the armor slice to attempt.";
	}

	String getPrimarySliceSelectionLabel(TangibleObject* tangibleObject) {
		if (tangibleObject != nullptr && tangibleObject->isWeaponObject())
			return "Increase damage";

		return "Improve resistance";
	}

	String getSecondarySliceSelectionLabel(TangibleObject* tangibleObject) {
		if (tangibleObject != nullptr && tangibleObject->isWeaponObject())
			return "Improve speed";

		return "Increase condition";
	}

	String getTertiarySliceSelectionLabel(TangibleObject* tangibleObject) {
		if (tangibleObject != nullptr && tangibleObject->isWeaponObject())
			return "Increase condition";

		return "";
	}

	bool isValidSliceSelection(TangibleObject* tangibleObject, byte selection) {
		if (tangibleObject == nullptr)
			return false;

		if (tangibleObject->isWeaponObject())
			return selection <= SLICE_SELECTION_TERTIARY;

		if (tangibleObject->isArmorObject())
			return selection <= SLICE_SELECTION_SECONDARY;

		return false;
	}

	void applyConditionSlice(TangibleObject* tangibleObject, uint8 percent) {
		int oldMaxCondition = tangibleObject->getMaxCondition();
		float oldConditionDamage = tangibleObject->getConditionDamage();
		int newMaxCondition = oldMaxCondition + Math::max(1, (oldMaxCondition * percent) / 100);

		tangibleObject->setMaxCondition(newMaxCondition);

		if (oldMaxCondition > 0 && oldConditionDamage > 0) {
			float conditionRatio = oldConditionDamage / oldMaxCondition;
			float scaledConditionDamage = Math::max(oldConditionDamage, conditionRatio * newMaxCondition);
			tangibleObject->setConditionDamage(scaledConditionDamage);
		}
	}
}

int SlicingSessionImplementation::initializeSession() {
	firstCable = System::random(1);
	nodeCable = 0;

	cableBlue = false;
	cableRed = false;

	usedNode = false;
	usedClamp = false;

	relockEvent = nullptr;

	baseSlice = false;
	keypadSlice = false;
	clearSliceSelection(this);

	return 0;
}

void SlicingSessionImplementation::initalizeSlicingMenu(CreatureObject* pl, TangibleObject* obj) {
	player = pl;
	tangibleObject = obj;

	ManagedReference<CreatureObject*> player = pl;
	ManagedReference<TangibleObject*> tangibleObject = obj;

	if (player == nullptr || tangibleObject == nullptr)
		return;

	if (!tangibleObject->isSliceable() && !isBaseSlice() && !isKeypadSlice())
		return;

	if (tangibleObject->containsActiveSession(SessionFacadeType::SLICING)) {
		player->sendSystemMessage("@slicing/slicing:slicing_underway");
		return;
	}

	if (!hasPrecisionLaserKnife(false)) { // do not remove the item on inital window
		player->sendSystemMessage("@slicing/slicing:no_knife");
		return;
	}

	//bugfix 814,819
	ManagedReference<SceneObject*> inventory = player->getSlottedObject("inventory");
	if (inventory == nullptr)
		return;

	if(!isBaseSlice() && !isKeypadSlice()){
		if (!inventory->hasObjectInContainer(tangibleObject->getObjectID()) && tangibleObject->getGameObjectType() != SceneObjectType::STATICLOOTCONTAINER
				&& tangibleObject->getGameObjectType() != SceneObjectType::MISSIONTERMINAL ) {
			player->sendSystemMessage("The object must be in your inventory in order to perform the slice.");
			return;
		}

		if (tangibleObject->isWeaponObject() && !hasWeaponUpgradeKit()) {
			player->sendSystemMessage("@slicing/slicing:no_weapon_kit");
			return;
		}

		if (tangibleObject->isArmorObject() && !hasArmorUpgradeKit()) {
			player->sendSystemMessage("@slicing/slicing:no_armor_kit");
			return;
		}
	}

	slicingSuiBox = new SuiListBox(player, SuiWindowType::SLICING_MENU, 2);
	slicingSuiBox->setCallback(new SlicingSessionSuiCallback(player->getZoneServer()));

	if (tangibleObject->getGameObjectType() == SceneObjectType::PLAYERLOOTCRATE)
		// Don't close the window when we remove PlayerLootContainer from the player's inventory.
		slicingSuiBox->setForceCloseDisabled();

	slicingSuiBox->setPromptTitle("@slicing/slicing:title");
	slicingSuiBox->setUsingObject(tangibleObject);
	slicingSuiBox->setCancelButton(true, "@cancel");

	if (needsSliceTypeSelection(tangibleObject)) {
		slicingSuiBox->setPromptText(getSliceSelectionPrompt(tangibleObject));
		slicingSuiBox->addMenuItem(getPrimarySliceSelectionLabel(tangibleObject), SLICE_SELECTION_PRIMARY);
		slicingSuiBox->addMenuItem(getSecondarySliceSelectionLabel(tangibleObject), SLICE_SELECTION_SECONDARY);

		if (tangibleObject->isWeaponObject())
			slicingSuiBox->addMenuItem(getTertiarySliceSelectionLabel(tangibleObject), SLICE_SELECTION_TERTIARY);

		player->getPlayerObject()->addSuiBox(slicingSuiBox);
		player->sendMessage(slicingSuiBox->generateMessage());
	} else {
		generateSliceMenu(slicingSuiBox);
	}

	player->addActiveSession(SessionFacadeType::SLICING, _this.getReferenceUnsafeStaticCast());
	tangibleObject->addActiveSession(SessionFacadeType::SLICING, _this.getReferenceUnsafeStaticCast());
}

void SlicingSessionImplementation::generateSliceMenu(SuiListBox* suiBox) {
	ManagedReference<CreatureObject*> player = this->player.get();
	ManagedReference<TangibleObject*> tangibleObject = this->tangibleObject.get();

	if (player == nullptr || tangibleObject == nullptr)
		return;

	uint8 progress = getProgress();
	suiBox->removeAllMenuItems();

	StringBuffer prompt;
	prompt << "@slicing/slicing:";
	prompt << getPrefix(tangibleObject);

	if (progress == 0) {
		if (usedClamp)
			prompt << "clamp_" << firstCable;
		else if (usedNode)
			prompt << "analyze_" << nodeCable;
		else
			prompt << progress;

		suiBox->addMenuItem("@slicing/slicing:blue_cable", 0);
		suiBox->addMenuItem("@slicing/slicing:red_cable", 1);

		if (!usedClamp && !usedNode) {
			suiBox->addMenuItem("@slicing/slicing:use_clamp", 2);
			suiBox->addMenuItem("@slicing/slicing:use_analyzer", 3);
		}

	} else if (progress == 1) {
		prompt << progress;

		suiBox->addMenuItem((cableBlue) ? "@slicing/slicing:blue_cable_cut" : "@slicing/slicing:blue_cable", 0);
		suiBox->addMenuItem((cableRed) ? "@slicing/slicing:red_cable_cut" : "@slicing/slicing:red_cable", 1);
	}

	suiBox->setPromptText(prompt.toString());
	player->getPlayerObject()->addSuiBox(suiBox);
	player->sendMessage(suiBox->generateMessage());

}

void SlicingSessionImplementation::handleMenuSelect(CreatureObject* pl, byte menuID, SuiListBox* suiBox) {
	ManagedReference<CreatureObject*> player = this->player.get();
	ManagedReference<TangibleObject*> tangibleObject = this->tangibleObject.get();

	if (tangibleObject == nullptr || player == nullptr || player != pl)
		return;

	ManagedReference<SceneObject*> inventory = player->getSlottedObject("inventory");
	if (inventory == nullptr)
		return;

	if(!isBaseSlice() && !isKeypadSlice() && tangibleObject->getGameObjectType() != SceneObjectType::STATICLOOTCONTAINER && tangibleObject->getGameObjectType() != SceneObjectType::MISSIONTERMINAL){
		if (!inventory->hasObjectInContainer(tangibleObject->getObjectID())) {
			player->sendSystemMessage("The object must be in your inventory in order to perform the slice.");
			return;
		}
	}

	if (needsSliceTypeSelection(tangibleObject) && getSliceSelection(this) == SLICE_SELECTION_UNSET) {
		if (!isValidSliceSelection(tangibleObject, menuID)) {
			cancelSession();
			return;
		}

		setSliceSelection(this, menuID);
		generateSliceMenu(suiBox);
		return;
	}

	uint8 progress = getProgress();

	if (progress == 0) {
		switch(menuID) {
		case 0: {
			if (hasPrecisionLaserKnife()) {
				if (firstCable != 0)
					handleSliceFailed(); // Handle failed slice attempt
				else
					cableBlue = true;
			} else
				player->sendSystemMessage("@slicing/slicing:no_knife");
			break;
		}
		case 1: {
			if (hasPrecisionLaserKnife()) {
				if (firstCable != 1)
					handleSliceFailed(); // Handle failed slice attempt
				else
					cableRed = true;
			} else
				player->sendSystemMessage("@slicing/slicing:no_knife");
			break;
		}
		case 2:
			handleUseClamp(); // Handle Use of Molecular Clamp
			break;

		case 3: {
			handleUseFlowAnalyzer(); // Handle Use of Flow Analyzer
			break;
		}
		default:
			cancelSession();
			break;
		}
	} else {
		if (hasPrecisionLaserKnife()) {
			if (firstCable != menuID)
				handleSlice(suiBox); // Handle Successful Slice
			else
				handleSliceFailed(); // Handle failed slice attempt //bugfix 820
			return;
		} else
			player->sendSystemMessage("@slicing/slicing:no_knife");
	}

	generateSliceMenu(suiBox);

}

void SlicingSessionImplementation::endSlicing() {
	ManagedReference<CreatureObject*> player = this->player.get();
	ManagedReference<TangibleObject*> tangibleObject = this->tangibleObject.get();

	if (player == nullptr || tangibleObject == nullptr) {
		cancelSession();
		return;
	}

	if (tangibleObject->isMissionTerminal())
		player->addCooldown("slicing.terminal", (2 * (60 * 1000))); // 2min Cooldown

	cancelSession();

}

int SlicingSessionImplementation::getSlicingSkill(CreatureObject* slicer) {

	String skill0 = "combat_smuggler_novice";
	String skill1 = "combat_smuggler_slicing_01";
	String skill2 = "combat_smuggler_slicing_02";
	String skill3 = "combat_smuggler_slicing_03";
	String skill4 = "combat_smuggler_slicing_04";
	String skill5 = "combat_smuggler_master";

	if (slicer->hasSkill(skill5))
		return 5;
	else if (slicer->hasSkill(skill4))
		return 4;
	else if (slicer->hasSkill(skill3))
		return 3;
	else if (slicer->hasSkill(skill2))
		return 2;
	else if (slicer->hasSkill(skill1))
		return 1;
	else if (slicer->hasSkill(skill0))
		return 0;

	return -1;

}

bool SlicingSessionImplementation::hasPrecisionLaserKnife(bool removeItem) {
	ManagedReference<CreatureObject*> player = this->player.get();

	if (player == nullptr)
		return 0;

	ManagedReference<SceneObject*> inventory = player->getSlottedObject("inventory");

	if (inventory == nullptr)
		return false;

	Locker inventoryLocker(inventory);

	for (int i = 0; i < inventory->getContainerObjectsSize(); ++i) {
		ManagedReference<SceneObject*> sceno = inventory->getContainerObject(i);

		uint32 objType = sceno->getGameObjectType();

		if (objType == SceneObjectType::LASERKNIFE) {
			PrecisionLaserKnife* knife = sceno.castTo<PrecisionLaserKnife*>();

			if (knife != nullptr) {
				if (removeItem) {
					Locker locker(knife);
					knife->useCharge(player);
				}
				return 1;
			}
		}
	}

	return 0;
}

bool SlicingSessionImplementation::hasWeaponUpgradeKit() {
	ManagedReference<CreatureObject*> player = this->player.get();

	if (player == nullptr)
		return false;

	ManagedReference<SceneObject*> inventory = player->getSlottedObject("inventory");

	if (inventory == nullptr)
		return false;

	for (int i = 0; i < inventory->getContainerObjectsSize(); ++i) {
		ManagedReference<SceneObject*> sceno = inventory->getContainerObject(i);

		uint32 objType = sceno->getGameObjectType();

		if (objType == SceneObjectType::WEAPONUPGRADEKIT) {
			Locker locker(sceno);
			sceno->destroyObjectFromWorld(true);
			sceno->destroyObjectFromDatabase(true);
			return true;
		}
	}

	return false;
}

bool SlicingSessionImplementation::hasArmorUpgradeKit() {
	ManagedReference<CreatureObject*> player = this->player.get();

	if (player == nullptr)
		return false;

	ManagedReference<SceneObject*> inventory = player->getSlottedObject("inventory");

	if (inventory == nullptr)
		return false;

	for (int i = 0; i < inventory->getContainerObjectsSize(); ++i) {
		ManagedReference<SceneObject*> sceno = inventory->getContainerObject(i);

		uint32 objType = sceno->getGameObjectType();

		if (objType == SceneObjectType::ARMORUPGRADEKIT) {
			Locker locker(sceno);
			sceno->destroyObjectFromWorld(true);
			sceno->destroyObjectFromDatabase(true);
			return true;
		}
	}

	return false;
}

void SlicingSessionImplementation::useClampFromInventory(SlicingTool* clamp) {
	ManagedReference<CreatureObject*> player = this->player.get();

	if (clamp == nullptr || clamp->getGameObjectType() != SceneObjectType::MOLECULARCLAMP)
		return;

	ManagedReference<SceneObject*> inventory = player->getSlottedObject("inventory");

	Locker locker(clamp);

	//inventory->removeObject(clamp, true);
	clamp->destroyObjectFromWorld(true);
	clamp->destroyObjectFromDatabase(true);
	player->sendSystemMessage("@slicing/slicing:used_clamp");
	usedClamp = true;

	//if (player->hasSuiBox(slicingSuiBox->getBoxID()))
	//	player->closeSuiWindowType(SuiWindowType::SLICING_MENU);
}

void SlicingSessionImplementation::handleUseClamp() {
	ManagedReference<CreatureObject*> player = this->player.get();

	if (player == nullptr)
		return;

	ManagedReference<SceneObject*> inventory = player->getSlottedObject("inventory");

	Locker inventoryLocker(inventory);

	for (int i = 0; i < inventory->getContainerObjectsSize(); ++i) {
		ManagedReference<SceneObject*> sceno = inventory->getContainerObject(i);

		uint32 objType = sceno->getGameObjectType();

		if (objType == SceneObjectType::MOLECULARCLAMP) {
			Locker locker(sceno);
			sceno->destroyObjectFromWorld(true);
			sceno->destroyObjectFromDatabase(true);

			player->sendSystemMessage("@slicing/slicing:used_clamp");
			usedClamp = true;
			return;
		}
	}

	player->sendSystemMessage("@slicing/slicing:no_clamp");
}

void SlicingSessionImplementation::handleUseFlowAnalyzer() {
	ManagedReference<CreatureObject*> player = this->player.get();

	if (player == nullptr)
		return;

	ManagedReference<SceneObject*> inventory = player->getSlottedObject("inventory");

	Locker inventoryLocker(inventory);

	for (int i = 0; i < inventory->getContainerObjectsSize(); ++i) {
		ManagedReference<SceneObject*> sceno = inventory->getContainerObject(i);

		uint32 objType = sceno->getGameObjectType();

		if (objType == SceneObjectType::FLOWANALYZER) {
			SlicingTool* node = cast<SlicingTool*>(sceno.get());

			if (node == nullptr)
				continue;

			nodeCable = node->calculateSuccessRate();

			if (nodeCable) // PASSED
				nodeCable = firstCable;
			else if (nodeCable == firstCable) { // Failed but the cables are Correct
				if (firstCable)
					nodeCable = 0; // Failed - Make the Cable incorrect
			}

			Locker locker(sceno);
			sceno->destroyObjectFromWorld(true);
			sceno->destroyObjectFromDatabase(true);

			player->sendSystemMessage("@slicing/slicing:used_node");
			usedNode = true;
			return;
		}
	}

	player->sendSystemMessage("@slicing/slicing:no_node");
}

void SlicingSessionImplementation::handleSlice(SuiListBox* suiBox) {
	ManagedReference<CreatureObject*> player = this->player.get();
	ManagedReference<TangibleObject*> tangibleObject = this->tangibleObject.get();

	if (player == nullptr || tangibleObject == nullptr)
		return;

	Locker locker(player);
	Locker clocker(tangibleObject, player);

	PlayerManager* playerManager = player->getZoneServer()->getPlayerManager();

	suiBox->removeAllMenuItems();
	suiBox->setCancelButton(false,"@cancel");

	StringBuffer prompt;
	prompt << "@slicing/slicing:";
	prompt << getPrefix(tangibleObject) + "examine";
	suiBox->setPromptText(prompt.toString());

	player->getPlayerObject()->addSuiBox(suiBox);
	player->sendMessage(suiBox->generateMessage());

	if (tangibleObject->isContainerObject() || tangibleObject->getGameObjectType() == SceneObjectType::PLAYERLOOTCRATE) {
		handleContainerSlice();
		playerManager->awardExperience(player, "slicing", 250, true); // Container Slice XP
	} else if (tangibleObject->isMissionTerminal()) {
		MissionTerminal* term = cast<MissionTerminal*>( tangibleObject.get());
		playerManager->awardExperience(player, "slicing", 100, true); // Terminal Slice XP
		term->addSlicer(player);
		player->sendSystemMessage("@slicing/slicing:terminal_success");
	} else if (tangibleObject->isWeaponObject()) {
		handleWeaponSlice();
		playerManager->awardExperience(player, "slicing", 250, true); // Weapon Slice XP
	} else if (tangibleObject->isArmorObject()) {
		handleArmorSlice();
		playerManager->awardExperience(player, "slicing", 250, true); // Armor Slice XP
	} else if ( isBaseSlice()){
		playerManager->awardExperience(player,"slicing", 1000, true); // Base slicing

		Zone* zone = player->getZone();

		if (zone != nullptr){
			GCWManager* gcwMan = zone->getGCWManager();

			if (gcwMan != nullptr){
				SecuritySliceTask* task = new SecuritySliceTask(gcwMan, tangibleObject.get(), player);
				task->execute();
			}
		}

	}

	tangibleObject->notifyObservers(ObserverEventType::SLICED, player, 1);

	endSlicing();

}

void SlicingSessionImplementation::handleWeaponSlice() {
	ManagedReference<CreatureObject*> player = this->player.get();
	ManagedReference<TangibleObject*> tangibleObject = this->tangibleObject.get();

	if (player == nullptr || tangibleObject == nullptr || !tangibleObject->isWeaponObject())
		return;

	int sliceSkill = getSlicingSkill(player);
	uint8 min = 0;
	uint8 max = 0;

	switch (sliceSkill) {
	case 5:
		min += 5;
		max += 5;
	case 4:
		min += 5;
		max += 5;
	case 3:
	case 2:
		min += 10;
		max += 25;
		break;
	default:
		return;

	}

	uint8 percentage = System::random(max - min) + min;
	uint8 sliceType = getSliceSelection(this);

	if (sliceType == SLICE_SELECTION_UNSET)
		sliceType = System::random(2);

	switch (sliceType) {
	case 0:
		handleSliceDamage(percentage);
		break;
	case 1:
		handleSliceSpeed(percentage);
		break;
	case 2: {
		WeaponObject* weap = cast<WeaponObject*>(tangibleObject.get());

		if (weap == nullptr)
			return;

		Locker locker(weap);

		if (weap->hasPowerup())
			this->detachPowerUp(player, weap);

		applyConditionSlice(weap, percentage);
		weap->setSliced(true);

		StringBuffer message;
		message << "Weapon condition increased by " << percentage << "%.";
		player->sendSystemMessage(message.toString());
		break;
	}
	}
}

void SlicingSessionImplementation::detachPowerUp(CreatureObject* player, WeaponObject* weap) {
	ManagedReference<PowerupObject*> pup = weap->removePowerup();
	if (pup == nullptr)
		return;

	Locker locker(pup);

	pup->destroyObjectFromWorld(true);
	pup->destroyObjectFromDatabase(true);

	locker.release();

	StringIdChatParameter message("powerup", "prose_remove_powerup"); //You detach your powerup from %TT.
	message.setTT(weap->getDisplayedName());
	player->sendSystemMessage(message);

}

void SlicingSessionImplementation::handleSliceDamage(uint8 percent) {
	ManagedReference<CreatureObject*> player = this->player.get();
	ManagedReference<TangibleObject*> tangibleObject = this->tangibleObject.get();

	if (tangibleObject == nullptr || player == nullptr || !tangibleObject->isWeaponObject())
		return;

	WeaponObject* weap = cast<WeaponObject*>(tangibleObject.get());

	Locker locker(weap);

	if (weap->hasPowerup())
		this->detachPowerUp(player, weap);

	weap->setDamageSlice(percent / 100.f);
	weap->setSliced(true);

	StringIdChatParameter params;
	params.setDI(percent);
	params.setStringId("@slicing/slicing:dam_mod");

	player->sendSystemMessage(params);

}

void SlicingSessionImplementation::handleSliceSpeed(uint8 percent) {
	ManagedReference<CreatureObject*> player = this->player.get();
	ManagedReference<TangibleObject*> tangibleObject = this->tangibleObject.get();

	if (tangibleObject == nullptr || player == nullptr || !tangibleObject->isWeaponObject())
		return;

	WeaponObject* weap = cast<WeaponObject*>(tangibleObject.get());

	Locker locker(weap);

	if (weap->hasPowerup())
		this->detachPowerUp(player, weap);

	weap->setSpeedSlice(percent / 100.f);
	weap->setSliced(true);

	StringIdChatParameter params;
	params.setDI(percent);
	params.setStringId("@slicing/slicing:spd_mod");

	player->sendSystemMessage(params);
}

void SlicingSessionImplementation::handleArmorSlice() {
	ManagedReference<CreatureObject*> player = this->player.get();
	ManagedReference<TangibleObject*> tangibleObject = this->tangibleObject.get();

	if (tangibleObject == nullptr || player == nullptr)
		return;

	uint8 sliceType = getSliceSelection(this);
	int sliceSkill = getSlicingSkill(player);
	uint8 min = 0;
	uint8 max = 0;

	if (sliceType == SLICE_SELECTION_UNSET)
		sliceType = System::random(1);

	switch (sliceSkill) {
	case 5:
		min += (sliceType == 0) ? 6 : 5;
		max += 5;
	case 4:
		min += (sliceType == 0) ? 0 : 10;
		max += 10;
	case 3:
		min += 5;
		max += (sliceType == 0) ? 20 : 30;
		break;
	default:
		return;
	}

	uint8 percent = System::random(max - min) + min;

	switch (sliceType) {
	case 0:
		handleSliceEffectiveness(percent);
		break;
	case 1:
		handleSliceEncumbrance(percent);
		break;
	}
}

void SlicingSessionImplementation::handleSliceEncumbrance(uint8 percent) {
	ManagedReference<CreatureObject*> player = this->player.get();
	ManagedReference<TangibleObject*> tangibleObject = this->tangibleObject.get();

	if (tangibleObject == nullptr || player == nullptr || !tangibleObject->isArmorObject())
		return;

	ArmorObject* armor = cast<ArmorObject*>(tangibleObject.get());

	Locker locker(armor);

	applyConditionSlice(armor, percent);
	armor->setSliced(true);

	StringBuffer message;
	message << "Armor condition increased by " << percent << "%.";
	player->sendSystemMessage(message.toString());
}

void SlicingSessionImplementation::handleSliceEffectiveness(uint8 percent) {
	ManagedReference<CreatureObject*> player = this->player.get();
	ManagedReference<TangibleObject*> tangibleObject = this->tangibleObject.get();

	if (tangibleObject == nullptr || player == nullptr || !tangibleObject->isArmorObject())
		return;

	ArmorObject* armor = cast<ArmorObject*>(tangibleObject.get());

	Locker locker(armor);

	armor->setEffectivenessSlice(percent / 100.f);
	armor->setSliced(true);

	StringIdChatParameter params;
	params.setDI(percent);
	params.setStringId("@slicing/slicing:eff_mod");

	player->sendSystemMessage(params);
}

void SlicingSessionImplementation::handleContainerSlice() {
	ManagedReference<CreatureObject*> player = this->player.get();
	ManagedReference<TangibleObject*> tangibleObject = this->tangibleObject.get();

	if (tangibleObject == nullptr || player == nullptr)
		return;

	ManagedReference<SceneObject*> inventory = player->getSlottedObject("inventory");

	if (inventory == nullptr)
		return;

	Locker inventoryLocker(inventory);

	LootManager* lootManager = player->getZoneServer()->getLootManager();

	if (tangibleObject->getGameObjectType() == SceneObjectType::PLAYERLOOTCRATE) {
		String unlockedContainerTemplate = "object/tangible/container/loot/loot_crate.iff";

		String lockedContainerTemplate = tangibleObject->getObjectTemplate() != nullptr ? tangibleObject->getObjectTemplate()->getFullTemplateString() : "";
		//player->info(true) << "SlicingSession: lockedContainerTemplate = " << lockedContainerTemplate << endl;

		if (tangibleObject->getObjectTemplate() != nullptr && lockedContainerTemplate == "object/tangible/loot/misc/briefcase_s01.iff")
			unlockedContainerTemplate = "object/tangible/container/loot/loot_briefcase.iff";

		//player->info(true) << "SlicingSession: unlockedContainerTemplate = " << unlockedContainerTemplate << endl;

		Reference<SceneObject*> containerSceno = player->getZoneServer()->createObject(unlockedContainerTemplate.hashCode(), 1);

		if (containerSceno == nullptr) {
			player->info(true) << "SlicingSession: failed to create unlocked container template = " << unlockedContainerTemplate << endl;
			return;
		}

		String replacementTemplate = containerSceno->getObjectTemplate() != nullptr ? containerSceno->getObjectTemplate()->getFullTemplateString() : "<null>";

		player->info(true) << "SlicingSession: created replacement class = " << containerSceno->_getClassName()
				<< ", type = " << containerSceno->getGameObjectType()
				<< ", template = " << replacementTemplate << endl;

		Locker clocker(containerSceno, player);

		Container* container = dynamic_cast<Container*>(containerSceno.get());

		if (container == nullptr) {
			player->info(true) << "SlicingSession: replacement is not a Container; original item was preserved." << endl;
			containerSceno->destroyObjectFromDatabase(true);
			return;
		}

		player->info(true) << "SlicingSession: replacement container volume = " << container->getContainerVolumeLimit() << endl;

		TransactionLog trx(TrxCode::SLICECONTAINER, player, container);

		if (System::random(10) != 4) {
			lootManager->createLoot(trx, container, "looted_container");
		}

		if (!inventory->transferObject(container, -1)) {
			player->info(true) << "SlicingSession: failed to transfer replacement into inventory; original item was preserved." << endl;
			container->destroyObjectFromWorld(true);
			container->destroyObjectFromDatabase(true);
			return;
		}

		if (!inventory->hasObjectInContainer(container->getObjectID())) {
			player->info(true) << "SlicingSession: replacement transfer did not place object in inventory; original item was preserved." << endl;
			container->destroyObjectFromWorld(true);
			container->destroyObjectFromDatabase(true);
			return;
		}

		container->sendTo(player, true);

		trx.commit();

		if (inventory->hasObjectInContainer(tangibleObject->getObjectID())) {
			//inventory->removeObject(tangibleObject, true);
			tangibleObject->destroyObjectFromWorld(true);
		}

		tangibleObject->destroyObjectFromDatabase(true);

	} else if (tangibleObject->isContainerObject()) {

		Container* container = dynamic_cast<Container*>(tangibleObject.get());
        if (container == nullptr)
			return;

		container->setSliced(true);
		container->setLockedStatus(false);

		if(!container->isRelocking())
		{
			relockEvent = new RelockLootContainerEvent(container);
			relockEvent->schedule(container->getLockTime());
		}
	} else
		return;

	player->sendSystemMessage("@slicing/slicing:container_success");
}

void SlicingSessionImplementation::handleSliceFailed() {
	ManagedReference<CreatureObject*> player = this->player.get();
	ManagedReference<TangibleObject*> tangibleObject = this->tangibleObject.get();

	if (tangibleObject == nullptr || player == nullptr)
			return;

	if (tangibleObject->isMissionTerminal())
		player->sendSystemMessage("@slicing/slicing:terminal_fail");
	else if (tangibleObject->isWeaponObject())
		player->sendSystemMessage("@slicing/slicing:fail_weapon");
	else if (tangibleObject->isArmorObject())
		player->sendSystemMessage("@slicing/slicing:fail_armor");
	else if (tangibleObject->isContainerObject() || tangibleObject->getGameObjectType() == SceneObjectType::PLAYERLOOTCRATE)
		player->sendSystemMessage("@slicing/slicing:container_fail");
	else if (isBaseSlice())
		player->sendSystemMessage("@slicing/slicing:hq_security_fail"); // Unable to sucessfully slice the terminal, you realize that the only away
	else if (isKeypadSlice())
		player->sendSystemMessage("@slicing/slicing:keypad_fail"); // Unable to successfully slice the keypad, you realize that the only way to reset it is to carefully repair what damage you have done.
	else
		player->sendSystemMessage("Your attempt to slice the object has failed.");

	if (tangibleObject->isContainerObject()) {

		ManagedReference<Container*> container = tangibleObject.castTo<Container*>();
        Locker clocker(container, player);

		if (!container)
			return;

        container->setSliced(true);
		if (!container->isRelocking())
		{
			relockEvent = new RelockLootContainerEvent(container);
			relockEvent->schedule(container->getLockTime()); // This will reactivate the 'broken' lock. (1 Hour)
		}

	} else if (isBaseSlice()){

		Zone* zone = player->getZone();
		if (zone != nullptr) {
			GCWManager* gcwMan = zone->getGCWManager();
			if(gcwMan != nullptr)
				gcwMan->failSecuritySlice(tangibleObject.get());

		}
	} else if (!tangibleObject->isMissionTerminal() && !isKeypadSlice()) {
		tangibleObject->setSliced(true);
	}

	tangibleObject->notifyObservers(ObserverEventType::SLICED, player, 0);
	endSlicing();

}
int SlicingSessionImplementation::cancelSession() {
	ManagedReference<CreatureObject*> player = this->player.get();
	ManagedReference<TangibleObject*> tangibleObject = this->tangibleObject.get();
	clearSliceSelection(this);
	if (player != nullptr) {
		player->dropActiveSession(SessionFacadeType::SLICING);
		player->getPlayerObject()->removeSuiBoxType(SuiWindowType::SLICING_MENU);
	}
	if (tangibleObject != nullptr)
		tangibleObject->dropActiveSession(SessionFacadeType::SLICING);
	clearSession();
	return 0;
}
