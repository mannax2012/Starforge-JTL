/*
 * ResourceDeedImplementation.cpp
 *
 *  Created on: Sep 8, 2010
 *      Author: elvaron
 */

#include "server/zone/objects/tangible/deed/resource/ResourceDeed.h"
#include "server/zone/managers/resource/ResourceManager.h"
#include "server/zone/objects/creature/CreatureObject.h"
#include "server/zone/objects/player/sui/callbacks/ResourceDeedSuiCallback.h"

#include "server/zone/packets/object/ObjectMenuResponse.h"
#include "server/zone/packets/scene/AttributeListMessage.h"

namespace {
int getResourceDeedQuantity(SharedObjectTemplate* templateObject) {
	if (templateObject == nullptr) {
		return ResourceManager::RESOURCE_DEED_QUANTITY;
	}

	const String& templateName = templateObject->getTemplateFileName();
	const String& fullTemplateName = templateObject->getFullTemplateString();

	if (templateName == "resource_small" || fullTemplateName == "object/tangible/veteran_reward/resource_small.iff") {
		return 10000;
	}

	if (templateName == "resource_medium" || fullTemplateName == "object/tangible/veteran_reward/resource_medium.iff") {
		return 50000;
	}

	if (templateName == "resource_large" || fullTemplateName == "object/tangible/veteran_reward/resource_large.iff") {
		return 250000;
	}

	return ResourceManager::RESOURCE_DEED_QUANTITY;
}
}

void ResourceDeedImplementation::initializeTransientMembers() {
	DeedImplementation::initializeTransientMembers();

	setLoggingName("ResourceDeed");
}

void ResourceDeedImplementation::updateCraftingValues(CraftingValues* values, bool firstUpdate) {
}

void ResourceDeedImplementation::fillObjectMenuResponse(ObjectMenuResponse* menuResponse, CreatureObject* player) {
	DeedImplementation::fillObjectMenuResponse(menuResponse, player);

	menuResponse->addRadialMenuItem(20, 3, "@ui_radial:item_use"); //use
}

void ResourceDeedImplementation::fillAttributeList(AttributeListMessage* alm, CreatureObject* object) {
	DeedImplementation::fillAttributeList(alm, object);

	alm->insertAttribute("deed_value", getResourceDeedQuantity(getObjectTemplate()));
}

int ResourceDeedImplementation::handleObjectMenuSelect(CreatureObject* player, byte selectedID) {
	if (selectedID != 20) // not use object
		return 1;

	if (player != nullptr)
		useObject(player);

	return 0;
}

int ResourceDeedImplementation::useObject(CreatureObject* creature) {
	if (creature == nullptr)
		return 0;

	if (!isASubChildOf(creature))
		return 0;

	ManagedReference<PlayerObject*> ghost = creature->getPlayerObject();

	if (ghost == nullptr || ghost->hasSuiBoxWindowType(SuiWindowType::FREE_RESOURCE)) {
		//ghost->closeSuiWindowType(SuiWindowType::FREE_RESOURCE);
		ghost->removeSuiBoxType(SuiWindowType::FREE_RESOURCE);

		return 0;
	}

	ManagedReference<ResourceManager*> resourceManager = server->getZoneServer()->getResourceManager();

	ManagedReference<SuiListBox*> sui = new SuiListBox(creature, SuiWindowType::FREE_RESOURCE);
	sui->setUsingObject(_this.getReferenceUnsafeStaticCast());
	sui->setCallback(new ResourceDeedSuiCallback(server->getZoneServer(), "Resource"));
	sui->setPromptTitle("@veteran:resource_title"); //Resources
	sui->setPromptText("@veteran:choose_class"); //Choose resource class
	sui->setOtherButton(true, "@back");
	sui->setCancelButton(true, "@cancel");
	sui->setOkButton(true, "@ok");

	resourceManager->addNodeToListBox(sui, "resource");

	ghost->addSuiBox(sui);
	creature->sendMessage(sui->generateMessage());

	return 1;
}

void ResourceDeedImplementation::destroyDeed() {
	if (parent.get() != nullptr) {
		destroyObjectFromWorld(true);
	}

	if (isPersistent())
		destroyObjectFromDatabase(true);

	generated = true;
}
