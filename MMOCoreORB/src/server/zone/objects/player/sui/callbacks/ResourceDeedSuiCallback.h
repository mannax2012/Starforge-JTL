/*
 * ResourceDeedSuiCallback.h
 *
 *  Created on: Aug 17, 2011
 *      Author: crush
 */

#ifndef RESOURCEDEEDSUICALLBACK_H_
#define RESOURCEDEEDSUICALLBACK_H_

#include "server/zone/objects/player/sui/SuiCallback.h"


class ResourceDeedSuiCallback : public SuiCallback {
	String nodeName;

	int getDeedQuantity(ResourceDeed* deed) const {
		if (deed == nullptr) {
			return ResourceManager::RESOURCE_DEED_QUANTITY;
		}

		const auto templateObject = deed->getObjectTemplate();

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

public:
	ResourceDeedSuiCallback(ZoneServer* serv, const String& name) : SuiCallback(serv) {
		nodeName = name;
	}

	void run(CreatureObject* creature, SuiBox* sui, uint32 eventIndex, Vector<UnicodeString>* args) {
		bool cancelPressed = (eventIndex == 1);

		if (!sui->isListBox() || cancelPressed)
			return;

		SuiListBox* listBox = cast<SuiListBox*>( sui);

		ManagedReference<SceneObject*> obj = sui->getUsingObject().get();

		if (obj == nullptr)
			return;

		ResourceDeed* deed = cast<ResourceDeed*>( obj.get());

		if (deed == nullptr)
			return;

		ManagedReference<SceneObject*> inventory = creature->getSlottedObject("inventory");

		if (inventory == nullptr || !deed->isASubChildOf(inventory)) //No longer in inventory.
			return;

		ManagedReference<PlayerObject*> ghost = creature->getPlayerObject();

		if (ghost == nullptr)
			return;

		bool backPressed = false;
		int index = -1;

		try {
			backPressed = Bool::valueOf(args->get(0).toString());
			index = Integer::valueOf(args->get(1).toString());
		} catch (Exception& e) {
			creature->error("Invalid parameters passed to ResourceDeedSuiCallback.");
			return;
		}

		ManagedReference<ResourceManager*> resourceManager = creature->getZoneServer()->getResourceManager();

		if (backPressed) {
			if(nodeName == "Resources" || nodeName == "Resource")
				return;

			listBox->setPromptTitle("@veteran:resource_title");
			listBox->setPromptText("@veteran:choose_class");

			listBox->removeAllMenuItems();

			nodeName = resourceManager->addParentNodeToListBox(listBox, nodeName);

		} else if(cancelPressed)
			return;
		else {

			ManagedReference<ResourceSpawn*> spawn = resourceManager->getResourceSpawn(nodeName);

			//They chose the resource, eat the deed and give them what they want...fuck it.
			if (spawn != nullptr) {
				int quantity = getDeedQuantity(deed);

				Locker clocker(deed, creature);
				deed->destroyDeed();
				clocker.release();

				resourceManager->givePlayerResource(creature, nodeName, quantity);

				return;
			}

			if(index >= 0 && index < listBox->getMenuSize()) {
				nodeName = listBox->getMenuItemName(index);

				listBox->removeAllMenuItems();

				spawn = resourceManager->getResourceSpawn(nodeName); //Check again, this means they are looking at stats.
				if (spawn != nullptr) {
					spawn->addStatsToDeedListBox(listBox);
				} else {
					resourceManager->addNodeToListBox(listBox, nodeName);
				}
			}
		}

		ghost->addSuiBox(listBox);
		creature->sendMessage(listBox->generateMessage());
	}
};

#endif /* RESOURCEDEEDSUICALLBACK_H_ */
