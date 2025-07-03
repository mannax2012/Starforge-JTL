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
	ManagedReference<CreatureObject*> rider = vehicle->getSlottedObject("rider").castTo<CreatureObject*>();

	if (rider == nullptr) // Our rider is gone
		return;

	Core::getTaskManager()->executeTask([=] () {
		Locker riderLock(rider);
		Locker crossLock(vehicle, rider);

		if (!rider->isRidingMount()) // dismount will reset the player's speed for us, do nothing
			return;

		// Speed hack buffer
		SpeedMultiplierModChanges* changeBuffer = rider->getSpeedMultiplierModChanges();
		const int bufferSize = changeBuffer->size();

		// Drop old change off the buffer
		if (bufferSize > 5) {
			changeBuffer->remove(0);
		}

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
		if(vehicle->getSpeedMultiplierMod() != 0){
			newSpeed *= vehicle->getSpeedMultiplierMod();
		}else{
			rider->sendSystemMessage("Debug - vehicle->getSpeedMultiplierMod(): " + String::valueOf(vehicle->getSpeedMultiplierMod()));
		}

		// Force Sensitive SkillMods
		if (vehicle->isVehicleObject()) {
			newAccel += rider->getSkillMod("force_vehicle_speed");
			newTurn += rider->getSkillMod("force_vehicle_control");
		}

		// Add a fake "skillmod" change
		changeBuffer->add(SpeedModChange(newSpeed / 10));

		// Update riders speed to match mount speed
		rider->setSpeedMultiplierMod(vehicle->getRunSpeed() / 10);
		rider->setRunSpeed(newSpeed);
		rider->setTurnScale(newTurn, true);
		rider->setAccelerationMultiplierMod(newAccel, true);
		rider->sendSystemMessage("Debug - newSpeed: " + String::valueOf(newSpeed));
		rider->updateToDatabase();
	}, "UpdateRiderSpeedsLambda");
}
