/*
 * GeneratorObjectImplementation.cpp
 *
 *  Created on: 15/06/2010
 *      Author: victor
 */

#include "server/zone/objects/installation/generator/GeneratorObject.h"
#include "server/zone/packets/harvester/HarvesterObjectMessage7.h"
#include "server/zone/packets/object/ObjectMenuResponse.h"
#include "server/zone/packets/harvester/ResourceHarvesterActivatePageMessage.h"

void GeneratorObjectImplementation::fillObjectMenuResponse(ObjectMenuResponse* menuResponse, CreatureObject* player) {
	if (!isOnAdminList(player))
		return;

	InstallationObjectImplementation::fillObjectMenuResponse(menuResponse, player);

	menuResponse->addRadialMenuItemToRadialID(118, 78, 3, "@harvester:manage"); //Operate Machinery
}

void GeneratorObjectImplementation::synchronizedUIListen(CreatureObject* player, int value) {
	if (!player->isPlayerCreature() || !isOnAdminList(player) || getZone() == nullptr)
		return;

	addOperator(player);

	updateInstallationWork();

	HarvesterObjectMessage7* msg = new HarvesterObjectMessage7(_this.getReferenceUnsafeStaticCast());
	player->sendMessage(msg);

	activateUiSync();
}

void GeneratorObjectImplementation::synchronizedUIStopListen(CreatureObject* player, int value) {
	if (!player->isPlayerCreature())
		return;

	removeOperator(player);
}

int GeneratorObjectImplementation::handleObjectMenuSelect(CreatureObject* player, byte selectedID) {
	if (!isOnAdminList(player))
		return 1;

	switch (selectedID) {

	case 78: {
		ResourceHarvesterActivatePageMessage* rhapm = new ResourceHarvesterActivatePageMessage(getObjectID());
		player->sendMessage(rhapm);
		break;
	}

	default:
		return InstallationObjectImplementation::handleObjectMenuSelect(player, selectedID);
	}

	return 0;
}

String GeneratorObjectImplementation::getRedeedMessage() {
	if (isActive())
		return "destroy_deactivate_first";

	if (getHopperSize() > 0)
		return "destroy_empty_hopper";

	return "";
}

void GeneratorObjectImplementation::fillAttributeList(AttributeListMessage* alm, CreatureObject* object) {
	InstallationObjectImplementation::fillAttributeList(alm, object);

		InstallationObject* installation = cast<InstallationObject*>(_this.get().get());

		installation->updateStructureStatus();
		bool isOperational = installation->isActive();
		float hopperFilledPercent = 0.0f;
		int remainingMaint = installation->getSurplusMaintenance();
		float secsRemainingMaint = 0.f;
		float percentRemaining = 100.0f;
		float baseMaintRate = installation->getMaintenanceRate();
		String currentSpawn = installation->getCurrentSpawnName();
		String hopperAmount = String::valueOf((int)installation->getHopperSize());
		String hopperAmountMax = String::valueOf((int)installation->getHopperSizeMax());
		String hopperPercentString = "0%";
		String hopperString = hopperAmount + " / " + hopperAmountMax + " (" + hopperPercentString + ")";
		String statusString = "OFFLINE";
		String maintTimeRemaining = "0";

		if (hopperAmount.isEmpty())
			hopperAmount = "hopperAmount: Empty";

		if (installation->getHopperSize() > 0.0f) {
				hopperFilledPercent = Math::getPrecision((installation->getHopperSize() / installation->getHopperSizeMax()) * 100.0f, 2);  // round % to two decimal places
				hopperPercentString = String::valueOf((float)hopperFilledPercent) + "%";
				hopperString = hopperAmount + " / " + hopperAmountMax + " (" + hopperPercentString + ")";
			}

		if (isOperational){
			statusString = "ONLINE";
		}else{
			statusString = "OFFLINE";
		}

		if((installation->getSurplusMaintenance() > 0) && (baseMaintRate != 0)){
			secsRemainingMaint = ((float)installation->getSurplusMaintenance() / (float)baseMaintRate)*3600;
			maintTimeRemaining = getTimeString((uint32)secsRemainingMaint);
		}


		alm->insertAttribute("@starforge_n:installation_status", statusString);
		alm->insertAttribute("@starforge_n:harvester_harvesting", currentSpawn);

		if (object != nullptr && isOnAdminList(object)){
		alm->insertAttribute("@starforge_n:installation_hopper_amount", hopperString);
		alm->insertAttribute("@starforge_n:installation_maintenance_time", maintTimeRemaining);
		}

}