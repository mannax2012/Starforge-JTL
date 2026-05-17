/*
 * WearableContainerObjectImplementation.cpp
 *
 *  Created on: Oct 27, 2012
 *      Author: loshult
 */

#include "server/zone/objects/tangible/wearables/WearableContainerObject.h"
#include "server/zone/objects/creature/CreatureObject.h"
#include "server/zone/managers/skill/SkillModManager.h"
#include "server/zone/packets/scene/AttributeListMessage.h"
#include "server/zone/objects/manufactureschematic/craftingvalues/CraftingValues.h"


void WearableContainerObjectImplementation::initializeTransientMembers() {
	ContainerImplementation::initializeTransientMembers();
	setLoggingName("WearableContainerObject");
}

void WearableContainerObjectImplementation::fillAttributeList(AttributeListMessage* alm, CreatureObject* object) {
	TangibleObjectImplementation::fillAttributeList(alm, object);

	for(int i = 0; i < wearableSkillMods.size(); ++i) {
		String key = wearableSkillMods.elementAt(i).getKey();
		String statname = "cat_skill_mod_bonus.@stat_n:" + key;
		int value = wearableSkillMods.get(key);

		if (value > 0)
			alm->insertAttribute(statname, value);
	}
}

void WearableContainerObjectImplementation::updateCraftingValues(CraftingValues* values, bool initialUpdate) {
	if (initialUpdate) {
		if (values->hasExperimentalAttribute("sockets") && values->getCurrentValue("sockets") >= 0)
			generateSockets(values);
	}
}

void WearableContainerObjectImplementation::generateSockets(CraftingValues* craftingValues) {
	(void) craftingValues;

	// Wearable containers (for example backpacks) should never roll sockets.
	socketCount = 0;
	usedSocketCount = 0;
	socketsGenerated = false;
}

void WearableContainerObjectImplementation::applySkillModsTo(CreatureObject* creature) const {
	if (creature == nullptr) {
		return;
	}

	for (int i = 0; i < wearableSkillMods.size(); ++i) {
		String name = wearableSkillMods.elementAt(i).getKey();
		int value = wearableSkillMods.get(name);

		if (!SkillModManager::instance()->isWearableModDisabled(name))
		{
			creature->addSkillMod(SkillModManager::WEARABLE, name, value, true);
			creature->updateSpeedAndAccelerationMods();
		}
	}

	SkillModManager::instance()->verifyWearableSkillMods(creature);
}

void WearableContainerObjectImplementation::removeSkillModsFrom(CreatureObject* creature) {
	if (creature == nullptr) {
		return;
	}

	for (int i = 0; i < wearableSkillMods.size(); ++i) {
		String name = wearableSkillMods.elementAt(i).getKey();
		int value = wearableSkillMods.get(name);

		if (!SkillModManager::instance()->isWearableModDisabled(name))
		{
			creature->removeSkillMod(SkillModManager::WEARABLE, name, value, true);
			creature->updateSpeedAndAccelerationMods();
		}
	}

	SkillModManager::instance()->verifyWearableSkillMods(creature);
}

bool WearableContainerObjectImplementation::isEquipped() {
	ManagedReference<SceneObject*> parent = getParent().get();
	if (parent != nullptr && parent->isPlayerCreature())
		return true;

	return false;
}
