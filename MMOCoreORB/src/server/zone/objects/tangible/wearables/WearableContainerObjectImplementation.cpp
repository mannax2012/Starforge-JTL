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

namespace {
VectorMap<String, int> collectWearableMods(const VectorMap<String, int>& wearableSkillMods, const VectorMap<String, int>* templateSkillMods) {
	VectorMap<String, int> allMods;
	allMods.setAllowOverwriteInsertPlan();
	allMods.setNullValue(0);

	for (int i = 0; i < wearableSkillMods.size(); ++i) {
		const auto& entry = wearableSkillMods.elementAt(i);
		allMods.put(entry.getKey(), allMods.get(entry.getKey()) + entry.getValue());
	}

	if (templateSkillMods != nullptr) {
		for (int i = 0; i < templateSkillMods->size(); ++i) {
			const auto& entry = templateSkillMods->elementAt(i);
			allMods.put(entry.getKey(), allMods.get(entry.getKey()) + entry.getValue());
		}
	}

	return allMods;
}
}

void WearableContainerObjectImplementation::initializeTransientMembers() {
	ContainerImplementation::initializeTransientMembers();
	setLoggingName("WearableContainerObject");
}

void WearableContainerObjectImplementation::fillAttributeList(AttributeListMessage* alm, CreatureObject* object) {
	TangibleObjectImplementation::fillAttributeList(alm, object);

	auto allMods = collectWearableMods(wearableSkillMods, getTemplateSkillMods());

	for (int i = 0; i < allMods.size(); ++i) {
		String key = allMods.elementAt(i).getKey();
		String statname = "cat_skill_mod_bonus.@stat_n:" + key;
		int value = allMods.get(key);

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

	auto allMods = collectWearableMods(wearableSkillMods, getTemplateSkillMods());

	for (int i = 0; i < allMods.size(); ++i) {
		String name = allMods.elementAt(i).getKey();
		int value = allMods.get(name);

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

	auto allMods = collectWearableMods(wearableSkillMods, getTemplateSkillMods());

	for (int i = 0; i < allMods.size(); ++i) {
		String name = allMods.elementAt(i).getKey();
		int value = allMods.get(name);

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
