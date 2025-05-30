/*
 * HarvesterObjectImplementation.cpp
 *
 *  Created on: 10/06/2010
 *      Author: victor
 */

#include "server/zone/objects/installation/harvester/HarvesterObject.h"
#include "server/zone/packets/harvester/HarvesterObjectMessage7.h"
#include "server/zone/objects/resource/ResourceContainer.h"
#include "server/zone/packets/object/ObjectMenuResponse.h"
#include "server/zone/packets/harvester/ResourceHarvesterActivatePageMessage.h"


void HarvesterObjectImplementation::fillObjectMenuResponse(ObjectMenuResponse* menuResponse, CreatureObject* player) {
	if (!isOnAdminList(player))
		return;

	InstallationObjectImplementation::fillObjectMenuResponse(menuResponse, player);

	menuResponse->addRadialMenuItemToRadialID(118, 78, 3, "@harvester:manage"); //Operate Machinery
}

void HarvesterObjectImplementation::synchronizedUIListen(CreatureObject* player, int value) {
	if (!player->isPlayerCreature() || !isOnAdminList(player) || getZone() == nullptr)
		return;

	addOperator(player);

	updateInstallationWork();

	HarvesterObjectMessage7* msg = new HarvesterObjectMessage7(_this.getReferenceUnsafeStaticCast());
	player->sendMessage(msg);

	/// Have to send the spawns of items no in shift, or the dont show
	/// up in the hopper when you look.
	for (int i = 0; i < resourceHopper.size(); ++i) {
		ResourceContainer* container = resourceHopper.get(i);

		if (container != nullptr) {
			container->sendTo(player, true);
		}
	}

	activateUiSync();
}

void HarvesterObjectImplementation::updateOperators() {
	HarvesterObjectMessage7* msg = new HarvesterObjectMessage7(_this.getReferenceUnsafeStaticCast());
	broadcastToOperators(msg);
}

void HarvesterObjectImplementation::synchronizedUIStopListen(CreatureObject* player, int value) {
	if (!player->isPlayerCreature())
		return;

	removeOperator(player);
}

int HarvesterObjectImplementation::handleObjectMenuSelect(CreatureObject* player, byte selectedID) {
	if (!isOnAdminList(player))
		return 1;

	switch (selectedID) {
	case 78: {
		ResourceHarvesterActivatePageMessage* rhapm = new ResourceHarvesterActivatePageMessage(getObjectID());
		player->sendMessage(rhapm);
		break;
	}
	case 77:
		handleStructureAddEnergy(player);
		break;

	default:
		return InstallationObjectImplementation::handleObjectMenuSelect(player, selectedID);
	}

	return 0;
}

String HarvesterObjectImplementation::getRedeedMessage() {
	if (isActive())
		return "destroy_deactivate_first";

	if (getHopperSize() > 0)
		return "destroy_empty_hopper";

	return "";
}

void HarvesterObjectImplementation::fillAttributeList(AttributeListMessage* alm,
		CreatureObject* object) {
	InstallationObjectImplementation::fillAttributeList(alm, object);

InstallationObject* installation = cast<InstallationObject*>(_this.get().get());

installation->updateStructureStatus();
bool isOperational = installation->isActive();
float hopperFilledPercent = 0.0f;
int remainingMaint = installation->getSurplusMaintenance();
int remainingPower = installation->getSurplusPower();
float secsRemainingPower = 0.f;
float secsRemainingMaint = 0.f;
float percentRemaining = 100.0f;
float basePowerRate = installation->getBasePowerRate();
float baseMaintRate = installation->getMaintenanceRate();
String currentSpawn = installation->getCurrentSpawnName();
String hopperAmount = String::valueOf((int)installation->getHopperSize());
String hopperAmountMax = String::valueOf((int)installation->getHopperSizeMax());
String hopperPercentString = "0%";
String hopperString = hopperAmount + " / " + hopperAmountMax + " (" + hopperPercentString + ")";
String statusString = "OFFLINE";
String powerTimeRemaining = "0";
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

if((installation->getSurplusPower() > 0) && (basePowerRate != 0)){
	secsRemainingPower = ((float)installation->getSurplusPower() / (float)basePowerRate)*3600;
	powerTimeRemaining = getTimeString((uint32)secsRemainingPower);
}

if((installation->getSurplusMaintenance() > 0) && (baseMaintRate != 0)){
	secsRemainingMaint = ((float)installation->getSurplusMaintenance() / (float)baseMaintRate)*3600;
	maintTimeRemaining = getTimeString((uint32)secsRemainingMaint);
}


alm->insertAttribute("@starforge_n:installation_status", statusString);
alm->insertAttribute("@starforge_n:harvester_harvesting", currentSpawn);

if (object != nullptr && isOnAdminList(object)){
alm->insertAttribute("@starforge_n:installation_hopper_amount", hopperString);
alm->insertAttribute("@starforge_n:installation_percent_power", powerTimeRemaining);
alm->insertAttribute("@starforge_n:installation_maintenance_time", maintTimeRemaining);
}

if(isSelfPowered()){
	alm->insertAttribute("@veteran_new:harvester_examine_title", "@veteran_new:harvester_examine_text");
}

}
