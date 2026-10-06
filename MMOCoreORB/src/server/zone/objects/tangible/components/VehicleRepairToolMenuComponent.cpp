/*
 * VehicleRepairToolMenuComponent.cpp
 */

#include "VehicleRepairToolMenuComponent.h"

#include "server/zone/ZoneServer.h"
#include "server/zone/managers/radial/RadialOptions.h"
#include "server/zone/objects/creature/CreatureObject.h"
#include "server/zone/objects/creature/VehicleObject.h"
#include "server/zone/objects/intangible/VehicleControlDevice.h"
#include "server/zone/objects/player/PlayerObject.h"
#include "server/zone/objects/player/sui/SuiCallback.h"
#include "server/zone/objects/player/sui/listbox/SuiListBox.h"
#include "server/zone/objects/player/sui/messagebox/SuiMessageBox.h"
#include "server/zone/objects/tangible/TangibleObject.h"
#include "server/zone/objects/tangible/tool/repair/RepairTool.h"
#include "server/zone/packets/object/ObjectMenuResponse.h"

namespace {
enum VehicleRepairMenuPhase {
	VEHICLE_LIST,
	REPAIR_CONFIRM
};

const String VEHICLE_REPAIR_KIT_TEMPLATE = "object/tangible/item/vehicle_repair_kit.iff";

const char* const mechanicSkills[] = {
	"crafting_mechanic_novice",
	"crafting_mechanic_landspeeder_01", "crafting_mechanic_landspeeder_02", "crafting_mechanic_landspeeder_03", "crafting_mechanic_landspeeder_04",
	"crafting_mechanic_speederbike_01", "crafting_mechanic_speederbike_02", "crafting_mechanic_speederbike_03", "crafting_mechanic_speederbike_04",
	"crafting_mechanic_modules_01", "crafting_mechanic_modules_02", "crafting_mechanic_modules_03", "crafting_mechanic_modules_04",
	"crafting_mechanic_techniques_01", "crafting_mechanic_techniques_02", "crafting_mechanic_techniques_03", "crafting_mechanic_techniques_04",
	"crafting_mechanic_master"
};

int getMechanicBoxes(CreatureObject* player) {
	if (player == nullptr)
		return 0;

	int boxes = 0;

	for (int i = 0; i < static_cast<int>(sizeof(mechanicSkills) / sizeof(mechanicSkills[0])); ++i) {
		if (player->hasSkill(mechanicSkills[i]))
			boxes++;
	}

	return boxes;
}

int getMechanicRepairChance(CreatureObject* player, bool disabled) {
	const int baseChance = disabled ? 25 : 50;
	const int maximumSkillBonus = disabled ? 25 : 50;
	const int maximumBoxes = 18;
	int boxes = Math::max(0, Math::min(maximumBoxes, getMechanicBoxes(player)));

	// A disabled vehicle receives half the mechanic bonus of a standard repair.
	return baseChance + ((maximumSkillBonus * boxes) + (maximumBoxes / 2)) / maximumBoxes;
}

float getRepairKitQuality(TangibleObject* kit) {
	if (kit == nullptr || !kit->isRepairTool())
		return 1.f;

	RepairTool* repairTool = cast<RepairTool*>(kit);
	return Math::max(1.f, Math::min(100.f, repairTool->getQuality()));
}

int getRepairKitBonus(TangibleObject* kit) {
	// Quality 1 adds nothing; quality 100 adds 25 percentage points.
	return static_cast<int>(((getRepairKitQuality(kit) - 1.f) * 25.f / 99.f) + 0.5f);
}

int getRemainingCondition(VehicleObject* vehicle) {
	if (vehicle == nullptr)
		return 0;

	return Math::max(0, vehicle->getMaxCondition() - vehicle->getConditionDamage());
}

bool isDisabledVehicle(VehicleObject* vehicle) {
	return vehicle == nullptr || vehicle->isDisabled() || getRemainingCondition(vehicle) <= 0;
}

int getRepairChance(CreatureObject* player, VehicleObject* vehicle, TangibleObject* kit) {
	int baseChance = getMechanicRepairChance(player, isDisabledVehicle(vehicle));
	return Math::min(100, baseChance + getRepairKitBonus(kit));
}

int getConditionPercent(VehicleObject* vehicle) {
	if (vehicle == nullptr || isDisabledVehicle(vehicle) || vehicle->getMaxCondition() <= 0)
		return 0;

	return Math::min(100, (getRemainingCondition(vehicle) * 100 + vehicle->getMaxCondition() / 2) / vehicle->getMaxCondition());
}

bool validateTool(ZoneServer* server, CreatureObject* player, uint64 toolID) {
	if (server == nullptr || player == nullptr)
		return false;

	ManagedReference<SceneObject*> tool = server->getObject(toolID);
	return tool != nullptr && tool->isTangibleObject() && tool->isASubChildOf(player);
}

VehicleObject* getOwnedVehicle(CreatureObject* player, uint64 vehicleID) {
	if (player == nullptr)
		return nullptr;

	ManagedReference<SceneObject*> datapad = player->getSlottedObject("datapad");

	if (datapad == nullptr)
		return nullptr;

	for (int i = 0; i < datapad->getContainerObjectsSize(); ++i) {
		ManagedReference<VehicleControlDevice*> device = datapad->getContainerObject(i).castTo<VehicleControlDevice*>();

		if (device == nullptr)
			continue;

		VehicleObject* vehicle = cast<VehicleObject*>(device->getControlledObject());

		if (vehicle != nullptr && vehicle->getObjectID() == vehicleID)
			return vehicle;
	}

	return nullptr;
}

TangibleObject* findRepairKit(SceneObject* container) {
	if (container == nullptr)
		return nullptr;

	for (int i = 0; i < container->getContainerObjectsSize(); ++i) {
		SceneObject* object = container->getContainerObject(i);

		if (object == nullptr)
			continue;

		if (object->isTangibleObject() && object->getServerObjectCRC() == VEHICLE_REPAIR_KIT_TEMPLATE.hashCode()) {
			TangibleObject* kit = cast<TangibleObject*>(object);

			if (kit != nullptr && kit->getUseCount() > 0)
				return kit;
		}

		if (object->isContainerObject()) {
			TangibleObject* nestedKit = findRepairKit(object);

			if (nestedKit != nullptr)
				return nestedKit;
		}
	}

	return nullptr;
}

int countRepairKitUses(SceneObject* container) {
	if (container == nullptr)
		return 0;

	int uses = 0;

	for (int i = 0; i < container->getContainerObjectsSize(); ++i) {
		SceneObject* object = container->getContainerObject(i);

		if (object == nullptr)
			continue;

		if (object->isTangibleObject() && object->getServerObjectCRC() == VEHICLE_REPAIR_KIT_TEMPLATE.hashCode()) {
			TangibleObject* kit = cast<TangibleObject*>(object);

			if (kit != nullptr)
				uses += Math::max(0, kit->getUseCount());
		}

		if (object->isContainerObject())
			uses += countRepairKitUses(object);
	}

	return uses;
}

void showVehicleMenu(CreatureObject* player, uint64 toolID);
void showRepairConfirmation(CreatureObject* player, uint64 toolID, uint64 vehicleID);
void attemptVehicleRepair(CreatureObject* player, uint64 toolID, uint64 vehicleID, uint64 repairKitID);

class VehicleRepairToolSuiCallback : public SuiCallback {
private:
	int phase;
	uint64 toolID;
	uint64 vehicleID;
	uint64 repairKitID;

public:
	VehicleRepairToolSuiCallback(ZoneServer* server, int menuPhase, uint64 toolObjectID, uint64 selectedVehicleID = 0, uint64 selectedRepairKitID = 0)
		: SuiCallback(server), phase(menuPhase), toolID(toolObjectID), vehicleID(selectedVehicleID), repairKitID(selectedRepairKitID) {
	}

	void run(CreatureObject* player, SuiBox* suiBox, uint32 eventIndex, Vector<UnicodeString>* args) override {
		if (player == nullptr || suiBox == nullptr || eventIndex == 1)
			return;

		if (!validateTool(server, player, toolID)) {
			player->sendSystemMessage("The vehicle restoration tool must remain in your inventory.");
			return;
		}

		if (phase == REPAIR_CONFIRM) {
			if (suiBox->isMessageBox())
				attemptVehicleRepair(player, toolID, vehicleID, repairKitID);

			return;
		}

		if (!suiBox->isListBox() || args == nullptr || args->size() == 0)
			return;

		SuiListBox* listBox = cast<SuiListBox*>(suiBox);
		int index = Integer::valueOf(args->get(0).toString());

		if (index < 0 || index >= listBox->getMenuSize())
			return;

		showRepairConfirmation(player, toolID, listBox->getMenuObjectID(index));
	}
};

void showVehicleMenu(CreatureObject* player, uint64 toolID) {
	ZoneServer* zoneServer = player == nullptr ? nullptr : player->getZoneServer();
	ManagedReference<PlayerObject*> ghost = player == nullptr ? nullptr : player->getPlayerObject();
	ManagedReference<SceneObject*> datapad = player == nullptr ? nullptr : player->getSlottedObject("datapad");
	ManagedReference<SceneObject*> inventory = player == nullptr ? nullptr : player->getSlottedObject("inventory");

	if (zoneServer == nullptr || ghost == nullptr || datapad == nullptr || inventory == nullptr || !validateTool(zoneServer, player, toolID))
		return;

	ManagedReference<SuiListBox*> menu = new SuiListBox(player, SuiWindowType::NONE, SuiListBox::HANDLETWOBUTTON);
	StringBuffer prompt;
	prompt << "Select a vehicle to inspect or restore.\n"
		<< "Mechanic progress: " << getMechanicBoxes(player) << "/18"
		<< "   Repair kits: " << countRepairKitUses(inventory);
	menu->setUsingObject(zoneServer->getObject(toolID));
	menu->setPromptTitle("Vehicle Restoration Tool");
	menu->setPromptText(prompt.toString());
	menu->setCancelButton(true, "@cancel");
	menu->setOkButton(true, "@ok");

	int vehicleCount = 0;

	for (int i = 0; i < datapad->getContainerObjectsSize(); ++i) {
		ManagedReference<VehicleControlDevice*> device = datapad->getContainerObject(i).castTo<VehicleControlDevice*>();
		VehicleObject* vehicle = device == nullptr ? nullptr : cast<VehicleObject*>(device->getControlledObject());

		if (vehicle == nullptr)
			continue;

		StringBuffer label;
		label << vehicle->getDisplayedName() << " - " << getConditionPercent(vehicle) << " (percent)";

		if (isDisabledVehicle(vehicle))
			label << " (Disabled)";

		menu->addMenuItem(label.toString(), vehicle->getObjectID());
		vehicleCount++;
	}

	if (vehicleCount == 0) {
		player->sendSystemMessage("No vehicles were found in your datapad.");
		return;
	}

	menu->setCallback(new VehicleRepairToolSuiCallback(zoneServer, VEHICLE_LIST, toolID));
	ghost->addSuiBox(menu);
	player->sendMessage(menu->generateMessage());
}

void showRepairConfirmation(CreatureObject* player, uint64 toolID, uint64 vehicleID) {
	ZoneServer* zoneServer = player == nullptr ? nullptr : player->getZoneServer();
	ManagedReference<PlayerObject*> ghost = player == nullptr ? nullptr : player->getPlayerObject();
	ManagedReference<SceneObject*> inventory = player == nullptr ? nullptr : player->getSlottedObject("inventory");
	ManagedReference<VehicleObject*> vehicle = getOwnedVehicle(player, vehicleID);

	if (zoneServer == nullptr || ghost == nullptr || inventory == nullptr || vehicle == nullptr || !validateTool(zoneServer, player, toolID)) {
		if (player != nullptr)
			player->sendSystemMessage("That vehicle is no longer available in your datapad.");
		return;
	}

	bool disabled = isDisabledVehicle(vehicle);
	ManagedReference<TangibleObject*> repairKit = findRepairKit(inventory);
	int baseChance = getMechanicRepairChance(player, disabled);
	int qualityBonus = getRepairKitBonus(repairKit);
	int chance = getRepairChance(player, vehicle, repairKit);
	int currentCondition = getRemainingCondition(vehicle);
	int maximumCondition = vehicle->getMaxCondition();
	int kitUses = countRepairKitUses(inventory);

	StringBuffer details;
	details << vehicle->getDisplayedName() << "\n\n"
		<< "Current health: " << currentCondition << " / " << maximumCondition
			<< " - " << getConditionPercent(vehicle) << " (percent)\n"
		<< "Status: " << (disabled ? "Disabled" : "Operational") << "\n"
		<< "Repair kit uses available: " << kitUses << "\n";

	if (repairKit != nullptr)
		details << "Next kit quality: " << Math::getPrecision(getRepairKitQuality(repairKit), 1) << " / 100\n";
	else
		details << "Next kit quality: no kit available\n";

	details << "Chance with mechanic skill: " << baseChance << " (percent)\n"
		<< "Kit bonus: " << qualityBonus << " (percent)\n"
		<< "Success chance: " << chance << " (percent)\n\n";

	if (currentCondition >= maximumCondition && !disabled) {
		details << "This vehicle is already at full health. No kit will be consumed.";
	} else if (disabled) {
		details << "Success restores the vehicle to full health, re-enables it, and reduces maximum health by 5 (percent).\n"
				<< "Failure leaves it disabled and reduces maximum health by 10 (percent).";
	} else {
		details << "Success restores the vehicle to full health.\n"
				<< "Failure reduces maximum health by 10 (percent).";
	}

	ManagedReference<SuiMessageBox*> confirmation = new SuiMessageBox(player, SuiWindowType::NONE);
	confirmation->setPromptTitle("Confirm Vehicle Restoration");
	confirmation->setPromptText(details.toString());
	confirmation->setCancelButton(true, "@cancel");
	confirmation->setOkButton(true, "@ok");
	confirmation->setCallback(new VehicleRepairToolSuiCallback(zoneServer, REPAIR_CONFIRM, toolID, vehicleID,
		repairKit == nullptr ? 0 : repairKit->getObjectID()));
	ghost->addSuiBox(confirmation);
	player->sendMessage(confirmation->generateMessage());
}

void attemptVehicleRepair(CreatureObject* player, uint64 toolID, uint64 vehicleID, uint64 repairKitID) {
	ZoneServer* zoneServer = player == nullptr ? nullptr : player->getZoneServer();
	ManagedReference<SceneObject*> inventory = player == nullptr ? nullptr : player->getSlottedObject("inventory");
	ManagedReference<VehicleObject*> vehicle = getOwnedVehicle(player, vehicleID);
	ManagedReference<TangibleObject*> repairKit = zoneServer == nullptr ? nullptr : zoneServer->getObject(repairKitID).castTo<TangibleObject*>();

	if (zoneServer == nullptr || inventory == nullptr || vehicle == nullptr || !validateTool(zoneServer, player, toolID)) {
		if (player != nullptr)
			player->sendSystemMessage("The vehicle restoration attempt was cancelled because the tool or vehicle is no longer available.");
		return;
	}

	if (repairKit == nullptr) {
		player->sendSystemMessage("You need a vehicle repair kit in your inventory to make an attempt.");
		return;
	}

	Locker vehicleLocker(vehicle, player);
	Locker kitLocker(repairKit, vehicle);

	if (getOwnedVehicle(player, vehicleID) != vehicle.get() || !repairKit->isASubChildOf(player) ||
		repairKit->getServerObjectCRC() != VEHICLE_REPAIR_KIT_TEMPLATE.hashCode() || repairKit->getUseCount() < 1) {
		player->sendSystemMessage("The vehicle restoration attempt was cancelled because its inputs changed.");
		return;
	}

	bool disabled = isDisabledVehicle(vehicle);
	int currentCondition = getRemainingCondition(vehicle);
	int oldMaximum = vehicle->getMaxCondition();

	if (oldMaximum <= 1) {
		player->sendSystemMessage("This vehicle has too little structural integrity remaining to restore.");
		return;
	}

	if (!disabled && currentCondition >= oldMaximum) {
		player->sendSystemMessage("That vehicle is already at full health. No repair kit was consumed.");
		return;
	}

	int successChance = getRepairChance(player, vehicle, repairKit);
	bool success = System::random(99) < successChance;

	if (success) {
		int repairedMaximum = disabled ? Math::max(2, (oldMaximum * 95) / 100) : oldMaximum;
		vehicle->setMaxCondition(repairedMaximum, true);
		vehicle->setConditionDamage(0, true);
		vehicle->setDisabled(false);
	} else {
		int reducedMaximum = Math::max(1, (oldMaximum * 90) / 100);
		vehicle->setMaxCondition(reducedMaximum, true);

		if (disabled || vehicle->getConditionDamage() >= reducedMaximum) {
			vehicle->setConditionDamage(reducedMaximum, true);
			vehicle->setDisabled(true);
		}
	}

	repairKit->decreaseUseCount(1, true);

	StringBuffer result;

	if (success) {
		result << "Vehicle restoration succeeded at " << successChance << " (percent) chance. "
			<< vehicle->getDisplayedName() << " is at full health";

		if (disabled)
			result << " and has been re-enabled with 5 (percent) reduced maximum health";

		result << ". One vehicle repair kit was consumed.";
	} else {
		result << "Vehicle restoration failed at " << successChance << " (percent) chance. "
			<< vehicle->getDisplayedName() << " lost 10 (percent) maximum health. One vehicle repair kit was consumed.";
	}

	player->sendSystemMessage(result.toString());
	kitLocker.release();
	vehicleLocker.release();
	showVehicleMenu(player, toolID);
}
}

void VehicleRepairToolMenuComponent::fillObjectMenuResponse(SceneObject* sceneObject, ObjectMenuResponse* menuResponse, CreatureObject* player) const {
	if (sceneObject == nullptr || menuResponse == nullptr || player == nullptr)
		return;

	if (sceneObject->isASubChildOf(player))
		menuResponse->addRadialMenuItem(RadialOptions::ITEM_USE, 3, "@ui_radial:item_use");

	TangibleObjectMenuComponent::fillObjectMenuResponse(sceneObject, menuResponse, player);
}

int VehicleRepairToolMenuComponent::handleObjectMenuSelect(SceneObject* sceneObject, CreatureObject* player, byte selectedID) const {
	if (sceneObject == nullptr || player == nullptr)
		return 0;

	if (selectedID != RadialOptions::ITEM_USE)
		return TangibleObjectMenuComponent::handleObjectMenuSelect(sceneObject, player, selectedID);

	if (!sceneObject->isTangibleObject() || !sceneObject->isASubChildOf(player))
		return 0;

	showVehicleMenu(player, sceneObject->getObjectID());
	return 0;
}
