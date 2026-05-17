#include "engine/engine.h"

#include "server/zone/objects/creature/buffs/PlayerVehicleBuff.h"

#include "server/zone/objects/creature/CreatureObject.h"

#include "server/zone/managers/creature/PetManager.h"
#include "server/zone/ZoneServer.h"



void PlayerVehicleBuffImplementation::applyAllModifiers() {

	if (!modsApplied) {
		applyAttributeModifiers();
		applySkillModifiers();
		applyStates();
		modsApplied = true;

		updateRiderSpeeds();
	}
}

void PlayerVehicleBuffImplementation::removeAllModifiers() {

	if (modsApplied) {
		removeAttributeModifiers();
		removeSkillModifiers();
		removeStates();
		modsApplied = false;

		updateRiderSpeeds();
	}
}

void PlayerVehicleBuffImplementation::activate(bool applyModifiers) {
		BuffImplementation::activate(applyModifiers);
		//Send start message to mount rider
		if (!startMessage.isEmpty()) {

			ManagedReference<CreatureObject*> rider = creature.get()->getSlottedObject("rider").castTo<CreatureObject*>();

			if(rider != nullptr) {
				rider->sendSystemMessage(startMessage);
			}
		}

}

void PlayerVehicleBuffImplementation::deactivate(bool removeModifiers) {
		BuffImplementation::deactivate(removeModifiers);
		//Send end message to mount rider
		if (!endMessage.isEmpty()) {

			ManagedReference<CreatureObject*> rider = creature.get()->getSlottedObject("rider").castTo<CreatureObject*>();

			if(rider != nullptr) {
				rider->sendSystemMessage(endMessage);
			}
		}

}

void PlayerVehicleBuffImplementation::updateRiderSpeeds() {
	ManagedReference<CreatureObject*> vehicle = creature.get();

	if (vehicle == nullptr) {
		return;
	}

	Core::getTaskManager()->executeTask([vehicle] () {
		if (vehicle == nullptr) {
			return;
		}

		Locker lock(vehicle);

		// get vehicle speed
		float newSpeed = vehicle->getRunSpeed();
		float newAccel = vehicle->getAccelerationMultiplierMod();
		float newTurn = vehicle->getTurnScale();

		// get animal mount speeds
		if (vehicle->isMount()) {
			PetManager* petManager = vehicle->getZoneServer()->getPetManager();

			if (petManager != nullptr) {
				newSpeed = petManager->getMountedRunSpeed(vehicle);
			}
		}

		// add speed multiplier mod for existing buffs
		if (vehicle->getSpeedMultiplierMod() != 0) {
			newSpeed *= vehicle->getSpeedMultiplierMod();
		}

		// Update Vehicles Speed
		vehicle->setRunSpeed(newSpeed);

		ManagedReference<CreatureObject*> rider = vehicle->getSlottedObject("rider").castTo<CreatureObject*>();

		if (rider == nullptr || !rider->isRidingMount()) {
			return;
		}

		Locker rideClock(rider, vehicle);

		// Force Sensitive SkillMods
		if (vehicle->isVehicleObject()) {
			newAccel += rider->getSkillMod("force_vehicle_speed");
			newTurn += rider->getSkillMod("force_vehicle_control");
		}

		rider->setSpeedMultiplierMod(newSpeed / 10, true, true);
		rider->setTurnScale(newTurn, true);
		rider->setAccelerationMultiplierMod(newAccel, true);
		rider->updateSpeedAndAccelerationMods();
		rider->updateRunSpeed();
		rider->updateToDatabase();
	}, "UpdateRiderSpeedsLambda");
}
