/*
 * VehicleControlDeviceImplementation.cpp
 *
 *  Created on: 10/04/2010
 *      Author: victor
 */

#include "server/zone/objects/intangible/VehicleControlDevice.h"
#include "server/zone/objects/intangible/VehicleControlObserver.h"
#include "server/zone/objects/creature/CreatureObject.h"
#include "server/zone/objects/creature/VehicleObject.h"
#include "server/zone/objects/creature/events/VehicleDecayTask.h"
#include "server/zone/packets/scene/AttributeListMessage.h"
#include "server/zone/ZoneServer.h"
#include "server/zone/Zone.h"
#include "tasks/CallMountTask.h"
#include "server/zone/objects/region/CityRegion.h"
#include "server/zone/objects/player/sessions/TradeSession.h"
#include "server/zone/managers/player/PlayerManager.h"
#include "server/zone/objects/player/PlayerObject.h"

namespace {
String getDebugTemplateName(SceneObject* object) {
	if (object == nullptr) {
		return "null-object";
	}

	auto objectTemplate = object->getObjectTemplate();

	if (objectTemplate == nullptr) {
		return "unknown-template";
	}

	return objectTemplate->getFullTemplateString();
}

String getDebugDisplayName(SceneObject* object) {
	if (object == nullptr) {
		return "null-object";
	}

	if (object->isCreatureObject()) {
		auto creature = object->asCreatureObject();

		if (creature != nullptr) {
			return creature->getDisplayedName();
		}
	}

	return getDebugTemplateName(object);
}

void detachVehicleRider(VehicleObject* vehicle, bool notifyClient) {
	if (vehicle == nullptr) {
		return;
	}

	ManagedReference<CreatureObject*> rider = vehicle->getLinkedCreature().get();

	if (rider == nullptr) {
		return;
	}

	Locker riderLocker(rider, vehicle);

	if (rider->getParent().get() != vehicle && !rider->isRidingMount()) {
		return;
	}

	Vector3 cachedWorldPosition = rider->getWorldPosition();
	vehicle->error() << "VehicleControlDeviceImplementation::detachVehicleRider -- riderOID=" << rider->getObjectID()
		<< " riderName=" << getDebugDisplayName(rider)
		<< " riderTemplate=" << getDebugTemplateName(rider)
		<< " vehicleOID=" << vehicle->getObjectID()
		<< " vehicleName=" << getDebugDisplayName(vehicle)
		<< " vehicleTemplate=" << getDebugTemplateName(vehicle)
		<< " riderParentID=" << rider->getParentID()
		<< " vehicleParentID=" << vehicle->getParentID();

	if (vehicle->hasState(CreatureState::MOUNTEDCREATURE)) {
		vehicle->clearState(CreatureState::MOUNTEDCREATURE, notifyClient);
	}

	if (rider->isRidingMount()) {
		rider->clearState(CreatureState::RIDINGMOUNT, notifyClient);
	}

	if (rider->getParent().get() == vehicle) {
		rider->setParent(nullptr);
	}

	rider->setPosition(cachedWorldPosition.getX(), cachedWorldPosition.getZ(), cachedWorldPosition.getY());

	auto ghost = rider->getPlayerObject();

	if (ghost != nullptr) {
		ghost->setSavedParentID(0);
	}
}

bool reconcileVehicleState(VehicleControlDevice* device, CreatureObject* owner, bool notifyClient) {
	if (device == nullptr)
		return false;

	ManagedReference<TangibleObject*> controlledObject = device->getControlledObject();

	if (controlledObject == nullptr)
		return false;

	ManagedReference<VehicleObject*> vehicle = cast<VehicleObject*>(controlledObject.get());

	if (vehicle != nullptr) {
		Locker vehicleLocker(vehicle, device);

		if (owner != nullptr && vehicle->getLinkedCreature() != owner) {
			vehicle->setCreatureLink(owner, notifyClient);
		}

		if (vehicle->getControlDevice() != device) {
			vehicle->setControlDevice(device);
		}

		if (!vehicle->isInQuadTree() && device->getStatus() != 0) {
			device->error() << "VehicleControlDeviceImplementation::reconcileVehicleState recovering persisted vehicle -- deviceOID=" << device->getObjectID()
				<< " deviceTemplate=" << getDebugTemplateName(device)
				<< " ownerOID=" << (owner != nullptr ? owner->getObjectID() : 0)
				<< " ownerName=" << (owner != nullptr ? owner->getDisplayedName() : String("null-owner"))
				<< " vehicleOID=" << vehicle->getObjectID()
				<< " vehicleName=" << getDebugDisplayName(vehicle)
				<< " vehicleTemplate=" << getDebugTemplateName(vehicle)
				<< " vehicleParentID=" << vehicle->getParentID();
			// Recovery may encounter a persisted vehicle that still has a rider attached.
			// Detach the rider before the vehicle is removed from world state.
			detachVehicleRider(vehicle, notifyClient);
		}
	}

	if (controlledObject->isInQuadTree()) {
		if (device->getStatus() == 0) {
			device->updateStatus(1, notifyClient);
		}

		return false;
	}

	if (device->getStatus() == 0) {
		return false;
	}

	Locker objectLocker(controlledObject, device);

	Reference<Task*> decayTask = controlledObject->getPendingTask("decay");

	if (decayTask != nullptr) {
		decayTask->cancel();
		controlledObject->removePendingTask("decay");
	}

	controlledObject->destroyObjectFromWorld(true);

	if (controlledObject->isCreatureObject()) {
		cast<CreatureObject*>(controlledObject.get())->setCreatureLink(nullptr, notifyClient);
	}

	device->updateStatus(0, notifyClient);

	return true;
}
}

void VehicleControlDeviceImplementation::notifyLoadFromDatabase() {
	ControlDeviceImplementation::notifyLoadFromDatabase();

	ManagedReference<CreatureObject*> owner = cast<CreatureObject*>(getRootParent());
	const bool recovered = reconcileVehicleState(_this.getReferenceUnsafeStaticCast(), owner, false);

	if (recovered && owner != nullptr) {
		owner->sendSystemMessage("A vehicle left deployed during shutdown was recovered to your datapad.");
	}
}

void VehicleControlDeviceImplementation::generateObject(CreatureObject* player) {
	if (player->isDead() || player->isIncapacitated())
		return;

	if (!isASubChildOf(player))
		return;

	if (player->getParent() != nullptr || player->isInCombat()) {
		player->sendSystemMessage("@pet/pet_menu:cant_call_vehicle"); // You can only unpack vehicles while Outside and not in Combat.
		return;
	}

	ManagedReference<TangibleObject*> controlledObject = this->controlledObject.get();

	if (controlledObject == nullptr) {
		return;
	}

	reconcileVehicleState(_this.getReferenceUnsafeStaticCast(), player, true);
	controlledObject = this->controlledObject.get();

	if (controlledObject == nullptr || controlledObject->getLocalZone() != nullptr) {
		return;
	}

	auto ghost = player->getPlayerObject();

	if (ghost == nullptr) {
		return;
	}

	auto zoneServer = player->getZoneServer();

	if (zoneServer == nullptr) {
		return;
	}

	ManagedReference<TradeSession*> tradeContainer = player->getActiveSession(SessionFacadeType::TRADE).castTo<TradeSession*>();

	if (tradeContainer != nullptr) {
		auto playerManager = zoneServer->getPlayerManager();

		if (playerManager != nullptr) {
			playerManager->handleAbortTradeMessage(player);
		}
	}

	if (player->getPendingTask("call_mount") != nullptr) {
		StringIdChatParameter waitTime("pet/pet_menu", "call_delay_finish_vehicle");
		AtomicTime nextExecution;
		Core::getTaskManager()->getNextExecutionTime(player->getPendingTask("call_mount"), nextExecution);
		int timeLeft = (nextExecution.getMiliTime() / 1000) - System::getTime();
		waitTime.setDI(timeLeft);

		player->sendSystemMessage(waitTime);
		return;
	}

	ManagedReference<SceneObject*> datapad = player->getSlottedObject("datapad");

	if (datapad == nullptr) {
		return;
	}

	int currentlySpawned = 0;

	for (int i = 0; i < datapad->getContainerObjectsSize(); ++i) {
		ManagedReference<SceneObject*> object = datapad->getContainerObject(i);

		if (object->isVehicleControlDevice()) {
			VehicleControlDevice* device = cast<VehicleControlDevice*>(object.get());

			ManagedReference<SceneObject*> vehicle = device->getControlledObject();

			if (vehicle != nullptr && vehicle->isInQuadTree()) {
				if (++currentlySpawned > 2)
					player->sendSystemMessage("@pet/pet_menu:has_max_vehicle");

				return;
			}
		}
	}

	if (player->getCurrentCamp() == nullptr && player->getCityRegion() == nullptr && !ghost->isPrivileged()) {
		Reference<CallMountTask*> callMount = new CallMountTask(_this.getReferenceUnsafeStaticCast(), player, "call_mount");

		StringIdChatParameter message("pet/pet_menu", "call_vehicle_delay");
		message.setDI(3);
		player->sendSystemMessage(message);

		player->addPendingTask("call_mount", callMount, 3 * 1000);

		if (vehicleControlObserver == nullptr) {
			vehicleControlObserver = new VehicleControlObserver(_this.getReferenceUnsafeStaticCast());
			vehicleControlObserver->deploy();
		}

		player->registerObserver(ObserverEventType::STARTCOMBAT, vehicleControlObserver);

	} else {
		Locker clocker(controlledObject, player);
		spawnObject(player);
	}
}

void VehicleControlDeviceImplementation::spawnObject(CreatureObject* player) {
	ZoneServer* zoneServer = getZoneServer();

	ManagedReference<TangibleObject*> controlledObject = this->controlledObject.get();

	if (controlledObject == nullptr)
		return;

	if (!isASubChildOf(player))
		return;

	if (player->getParent() != nullptr || player->isInCombat()) {
		player->sendSystemMessage("@pet/pet_menu:cant_call_vehicle"); // You can only unpack vehicles while Outside and not in Combat.
		return;
	}

	auto zone = player->getZone();

	if (zone == nullptr || !zone->isGroundZone()) {
		return;
	}

	ManagedReference<TradeSession*> tradeContainer = player->getActiveSession(SessionFacadeType::TRADE).castTo<TradeSession*>();

	if (tradeContainer != nullptr) {
		server->getZoneServer()->getPlayerManager()->handleAbortTradeMessage(player);
	}

	Vector3 playerWorld = player->getWorldPosition();

	controlledObject->initializePosition(playerWorld.getX(), playerWorld.getZ(), playerWorld.getY());
	ManagedReference<CreatureObject*> vehicle = nullptr;

	if (controlledObject->isCreatureObject()) {
		vehicle = cast<CreatureObject*>(controlledObject.get());
		vehicle->setCreatureLink(player);
		vehicle->setControlDevice(_this.getReferenceUnsafeStaticCast());
	}

	zone->transferObject(controlledObject, -1, true);

	Reference<VehicleDecayTask*> decayTask = new VehicleDecayTask(controlledObject);

	if (decayTask != nullptr) {
		decayTask->execute();
	}

	if (vehicle != nullptr && controlledObject->getServerObjectCRC() == 0x32F87A54) { // Jetpack
		controlledObject->setCustomizationVariable("/private/index_hover_height", 40, true);				  // Illusion of flying.
		player->executeObjectControllerAction(STRING_HASHCODE("mount"), controlledObject->getObjectID(), ""); // Auto mount.
	}

	updateStatus(1);

	if (vehicleControlObserver != nullptr) {
		player->dropObserver(ObserverEventType::STARTCOMBAT, vehicleControlObserver);
	}
}

void VehicleControlDeviceImplementation::cancelSpawnObject(CreatureObject* player) {
	Reference<Task*> mountTask = player->getPendingTask("call_mount");
	if (mountTask) {
		mountTask->cancel();
		player->removePendingTask("call_mount");
	}

	if (vehicleControlObserver != nullptr)
		player->dropObserver(ObserverEventType::STARTCOMBAT, vehicleControlObserver);
}

void VehicleControlDeviceImplementation::storeObject(CreatureObject* player, bool force) {
	const bool recovered = reconcileVehicleState(_this.getReferenceUnsafeStaticCast(), player, true);
	ManagedReference<TangibleObject*> controlledObject = this->controlledObject.get();

	if (controlledObject == nullptr)
		return;

	if (recovered && !controlledObject->isInQuadTree())
		return;

	/*if (!controlledObject->isInQuadTree())
		return;*/

	if (!force && (player->isInCombat() || player->isDead()))
		return;

	if (player->isRidingMount() && player->getParent() == controlledObject) {
		if (!force && !player->checkCooldownRecovery("mount_dismount"))
			return;

		player->executeObjectControllerAction(STRING_HASHCODE("dismount"));

		if (player->isRidingMount())
			return;
	}

	Locker crossLocker(controlledObject, player);

	Reference<Task*> decayTask = controlledObject->getPendingTask("decay");

	if (decayTask != nullptr) {
		decayTask->cancel();
		controlledObject->removePendingTask("decay");
	}

	controlledObject->destroyObjectFromWorld(true);

	if (controlledObject->isCreatureObject())
		(cast<CreatureObject*>(controlledObject.get()))->setCreatureLink(nullptr);

	crossLocker.release();

	Locker deviceLocker(_this.getReferenceUnsafeStaticCast(), player);

	updateStatus(0);

	ManagedReference<VehicleObject*> vehicle = cast<VehicleObject*>(controlledObject.get());

	if (vehicle != nullptr && vehicle->isRentalVehicle() && vehicle->getRentalUses() <= 0) {
		destroyObjectFromWorld(true);
		destroyObjectFromDatabase(true);

		StringIdChatParameter param;
		param.setStringId("pet/pet_menu", "uses_complete");
		player->sendSystemMessage(param.toString());

		return;
	}
}

void VehicleControlDeviceImplementation::destroyObjectFromDatabase(bool destroyContainedObjects) {
	ManagedReference<TangibleObject*> controlledObject = this->controlledObject.get();

	if (controlledObject != nullptr) {
		Locker locker(controlledObject);

		ManagedReference<CreatureObject*> object = controlledObject->getSlottedObject("rider").castTo<CreatureObject*>();

		if (object != nullptr) {
			Locker clocker(object, controlledObject);

			object->executeObjectControllerAction(STRING_HASHCODE("dismount"));

			object = controlledObject->getSlottedObject("rider").castTo<CreatureObject*>();

			if (object != nullptr) {
				controlledObject->removeObject(object, nullptr, true);

				Zone* zone = getZone();

				if (zone != nullptr)
					zone->transferObject(object, -1, true);
			}
		}

		controlledObject->destroyObjectFromDatabase(true);
	}

	IntangibleObjectImplementation::destroyObjectFromDatabase(destroyContainedObjects);
}

int VehicleControlDeviceImplementation::canBeDestroyed(CreatureObject* player) {
	ManagedReference<TangibleObject*> controlledObject = this->controlledObject.get();

	if (controlledObject != nullptr) {
		if (controlledObject->isInQuadTree())
			return 1;
	}

	return IntangibleObjectImplementation::canBeDestroyed(player);
}

bool VehicleControlDeviceImplementation::canBeTradedTo(CreatureObject* player, CreatureObject* receiver, int numberInTrade) {
	ManagedReference<SceneObject*> datapad = receiver->getSlottedObject("datapad");

	if (datapad == nullptr)
		return false;

	ManagedReference<PlayerManager*> playerManager = player->getZoneServer()->getPlayerManager();

	int vehiclesInDatapad = numberInTrade;
	int maxStoredVehicles = playerManager->getBaseStoredVehicles();

	for (int i = 0; i < datapad->getContainerObjectsSize(); i++) {
		Reference<SceneObject*> obj = datapad->getContainerObject(i).castTo<SceneObject*>();

		if (obj != nullptr && obj->isVehicleControlDevice()) {
			vehiclesInDatapad++;
		}
	}

	if (vehiclesInDatapad >= maxStoredVehicles) {
		player->sendSystemMessage("That person has too many vehicles in their datapad");
		receiver->sendSystemMessage("@pet/pet_menu:has_max_vehicle"); // You already have the maximum number of vehicles that you can own.
		return false;
	}

	return true;
}

void VehicleControlDeviceImplementation::fillAttributeList(AttributeListMessage* alm, CreatureObject* object) {
	SceneObjectImplementation::fillAttributeList(alm, object);

	if (this->controlledObject == nullptr)
		return;

	ManagedReference<VehicleObject*> vehicle = this->controlledObject.get().castTo<VehicleObject*>();
	if (vehicle == nullptr)
		return;

	StringBuffer conditionString;
	conditionString << "\t" << vehicle->getMaxCondition() - vehicle->getConditionDamage() << "/" << vehicle->getMaxCondition();
	alm->insertAttribute("cat_vehicle_stats.hit_points", conditionString);
	alm->insertAttribute("cat_vehicle_stats.vehicle_speed", vehicle->getRunSpeed());
	alm->insertAttribute("cat_vehicle_stats.vehicle_acceleration", vehicle->getAccelerationMultiplierMod() * 10.f);
	alm->insertAttribute("cat_vehicle_stats.vehicle_handling", vehicle->getTurnScale() * 75.f);

	int armorRating = vehicle->getArmor();
	if (armorRating == 0)
		alm->insertAttribute("cat_vehicle_stats.armorrating","@obj_attr_n:armor_pierce_none");
	else if (armorRating == 1)
		alm->insertAttribute("cat_vehicle_stats.armorrating","@obj_attr_n:armor_pierce_light");
	else if (armorRating == 2)
		alm->insertAttribute("cat_vehicle_stats.armorrating","@obj_attr_n:armor_pierce_medium");
	else if (armorRating == 3)
		alm->insertAttribute("cat_vehicle_stats.armorrating","@obj_attr_n:armor_pierce_heavy");

	// Add resists
	StringBuffer kin;
	kin << vehicle->getKinetic() << "%";
	alm->insertAttribute("cat_armor_special_protection.armor_eff_kinetic", kin.toString());

	StringBuffer ene;
	ene << vehicle->getEnergy() << "%";
	alm->insertAttribute("cat_armor_effectiveness.armor_eff_energy", ene.toString());

	StringBuffer bla;
	bla << vehicle->getBlast() << "%";
	alm->insertAttribute("cat_armor_effectiveness.armor_eff_blast", bla.toString());

	StringBuffer stu;
	stu << vehicle->getStun() << "%";
	alm->insertAttribute("cat_armor_effectiveness.armor_eff_stun", stu.toString());

	StringBuffer lig;
	lig << vehicle->getLightSaber() << "%";
	alm->insertAttribute("cat_armor_effectiveness.armor_eff_restraint", lig.toString());

	StringBuffer hea;
	hea << vehicle->getHeat() << "%";
	alm->insertAttribute("cat_armor_effectiveness.armor_eff_elemental_heat", hea.toString());

	StringBuffer col;
	col << vehicle->getCold() << "%";
	alm->insertAttribute("cat_armor_effectiveness.armor_eff_elemental_cold", col.toString());

	StringBuffer aci;
	aci << vehicle->getAcid() << "%";
	alm->insertAttribute("cat_armor_effectiveness.armor_eff_elemental_acid", aci.toString());

	StringBuffer ele;
	ele << vehicle->getElectricity() << "%";
	alm->insertAttribute("cat_armor_effectiveness.armor_eff_elemental_electrical", ele.toString());

	if (vehicle->getPaintCount() > 0) {
		alm->insertAttribute("customization_cnt", vehicle->getPaintCount());
	}
}
