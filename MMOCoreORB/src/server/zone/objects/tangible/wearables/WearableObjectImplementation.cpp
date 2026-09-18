/*
 * WearableObjectImplementation.cpp
 *
 *  Created on: 02/08/2009
 *      Author: victor
 */

#include "server/zone/objects/tangible/wearables/WearableObject.h"
#include "server/zone/objects/creature/CreatureObject.h"
#include "server/zone/objects/manufactureschematic/craftingvalues/CraftingValues.h"
#include "server/zone/objects/manufactureschematic/ManufactureSchematic.h"
#include "server/zone/objects/draftschematic/DraftSchematic.h"
#include "server/zone/objects/tangible/attachment/Attachment.h"
#include "server/zone/managers/skill/SkillModManager.h"
#include "server/zone/objects/tangible/wearables/ModSortingHelper.h"
#include "server/zone/objects/transaction/TransactionLog.h"

namespace {
// Add exact crafted object template paths here to guarantee 1-4 sockets.
// Other wearables continue to use the normal skill-based socket roll.
const char* const guaranteedSocketTemplates[] = {
	"object/tangible/wearables/armor/mandalorian/armor_mandalorian_belt.iff",
	"object/tangible/wearables/armor/mandalorian/armor_mandalorian_bicep_l.iff",
	"object/tangible/wearables/armor/mandalorian/armor_mandalorian_bicep_r.iff",
	"object/tangible/wearables/armor/mandalorian/armor_mandalorian_bracer_l.iff",
	"object/tangible/wearables/armor/mandalorian/armor_mandalorian_bracer_r.iff",
	"object/tangible/wearables/armor/mandalorian/armor_mandalorian_chest_plate.iff",
	"object/tangible/wearables/armor/mandalorian/armor_mandalorian_gloves.iff",
	"object/tangible/wearables/armor/mandalorian/armor_mandalorian_helmet.iff",
	"object/tangible/wearables/armor/mandalorian/armor_mandalorian_leggings.iff",
	"object/tangible/wearables/armor/mandalorian/armor_mandalorian_shoes.iff",
};

bool guaranteesSockets(const String& templateName) {
	for (const char* guaranteedTemplate : guaranteedSocketTemplates) {
		if (templateName == guaranteedTemplate)
			return true;
	}

	return false;
}

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

void WearableObjectImplementation::initializeTransientMembers() {
	TangibleObjectImplementation::initializeTransientMembers();

	// Wearable has too many attachments on it for the allowed socket count
	while (usedSocketCount > socketCount && wearableSkillMods.size() > 0) {
		wearableSkillMods.removeElementAt(wearableSkillMods.size() - 1);

		usedSocketCount--;
	}
}

void WearableObjectImplementation::fillAttributeList(AttributeListMessage* alm, CreatureObject* object) {
	TangibleObjectImplementation::fillAttributeList(alm, object);

	auto allMods = collectWearableMods(wearableSkillMods, getTemplateSkillMods());

	for (int i = 0; i < allMods.size(); ++i) {
		String key = allMods.elementAt(i).getKey();
		String statname = "cat_skill_mod_bonus.@stat_n:" + key;
		int value = allMods.get(key);

		if (value > 0)
			alm->insertAttribute(statname, value);
	}

	//Anti Decay Kit
	if (hasAntiDecayKit() && !isArmorObject()){
		alm->insertAttribute("@veteran_new:antidecay_examine_title", "@veteran_new:antidecay_examine_text");
	}

}

void WearableObjectImplementation::updateCraftingValues(CraftingValues* values, bool initialUpdate) {
	/*
	 * Values available:	Range:
	 * sockets				0-0(novice artisan) (Don't use)
	 * hitpoints			1000-1000 (Don't Use)
	 */
	if (initialUpdate) {
		if(values->hasExperimentalAttribute("sockets") && values->getCurrentValue("sockets") >= 0)
			generateSockets(values);
	}
}

void WearableObjectImplementation::generateSockets(CraftingValues* craftingValues) {
	if (socketsGenerated) {
		return;
	}

	if (guaranteesSockets(getObjectTemplate()->getFullTemplateString())) {
		usedSocketCount = 0;
		socketCount = System::random(MAXSOCKETS - 1) + 1;
		socketsGenerated = true;
		return;
	}

	int skill = 0;
	int luck = 0;

	if (craftingValues != nullptr) {
		ManagedReference<ManufactureSchematic*> manuSchematic = craftingValues->getManufactureSchematic();

		if (manuSchematic != nullptr) {
			ManagedReference<DraftSchematic*> draftSchematic = manuSchematic->getDraftSchematic();
			ManagedReference<CreatureObject*> player = manuSchematic->getCrafter().get();

			if (player != nullptr && draftSchematic != nullptr) {
				String assemblySkill = draftSchematic->getAssemblySkill();

				skill = player->getSkillMod(assemblySkill);

				if (MIN_SOCKET_MOD > skill)
					return;

				luck = System::random(player->getSkillMod("luck") + player->getSkillMod("force_luck"));
			}
		}
	}

	skill -= MIN_SOCKET_MOD;
	int bonusMod = 65 - skill;

	if (bonusMod <= 0) {
		bonusMod = 0;
	} else {
		bonusMod = System::random(bonusMod);
	}

	int skillAdjust = skill + System::random(luck) + bonusMod;
	int maxMod = 65 + System::random(skill);

	float randomSkill = System::random(skillAdjust) * 10;
	float roll = randomSkill / (400.f + maxMod);

	float generatedCount = roll * MAXSOCKETS;

	if (generatedCount > MAXSOCKETS)
		generatedCount = MAXSOCKETS;
	else if (generatedCount > 3 && generatedCount <= 3.75f)
		generatedCount = floor(generatedCount);

	usedSocketCount = 0;
	socketCount = (int)generatedCount;

	socketsGenerated = true;

	return;
}

void WearableObjectImplementation::applyAttachment(CreatureObject* player, Attachment* attachment) {
	if (attachment == nullptr || !isASubChildOf(player)) {
		return;
	}

	if (getRemainingSockets() < 1 || wearableSkillMods.size() > 5) {
		return;
	}

	if (isEquipped()) {
		removeSkillModsFrom(player);
	}

	Locker clocker(attachment, player);

	SortedVector<ModSortingHelper> sortedMods;
	VectorMap<String, int>* skillModifiers = attachment->getSkillMods();

	for (int i = 0; i < skillModifiers->size(); i++) {
		auto key = skillModifiers->elementAt(i).getKey();
		auto value = skillModifiers->elementAt(i).getValue();

		sortedMods.put(ModSortingHelper(key, value));
	}

	// Select the next mod in the SEA, sorted high-to-low. If that skill mod is already on the
	// wearable, with higher or equal value, don't apply and continue. Break once one mod
	// is applied.
	for (int i = 0; i < sortedMods.size(); i++) {
		String modName = sortedMods.elementAt(i).getKey();
		int modValue = sortedMods.elementAt(i).getValue();

		int existingValue = -26;

		if (wearableSkillMods.contains(modName)) {
			existingValue = wearableSkillMods.get(modName);
		}

		if (modValue > existingValue) {
			wearableSkillMods.put(modName, modValue);
			break;
		}
	}

	usedSocketCount++;
	addMagicBit(true);

	TransactionLog trx(player, asSceneObject(), attachment, TrxCode::APPLYATTACHMENT);

	if (trx.isVerbose()) {
		// Force a synchronous export because the object will be deleted before we can export it!
		trx.addRelatedObject(attachment, true);
		trx.setExportRelatedObjects(true);
		trx.exportRelated();
	}

	trx.addState("subjectSkillModMap", sortedMods);
	trx.addState("dstSkillModMap", wearableSkillMods);

	attachment->destroyObjectFromWorld(true);
	attachment->destroyObjectFromDatabase(true);

	if (isEquipped()) {
		applySkillModsTo(player);
	}
}

void WearableObjectImplementation::applySkillModsTo(CreatureObject* creature) const {
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

void WearableObjectImplementation::removeSkillModsFrom(CreatureObject* creature) {
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

bool WearableObjectImplementation::isEquipped() {
	ManagedReference<SceneObject*> parent = getParent().get();
	if (parent != nullptr && parent->isPlayerCreature())
		return true;

	return false;
}

String WearableObjectImplementation::repairAttempt(int repairChance) {
	String message = "@error_message:";

	if(repairChance < 25) {
		message += "sys_repair_failed";
		setMaxCondition(1, true);
		setConditionDamage(0, true);
	} else if(repairChance < 50) {
		message += "sys_repair_imperfect";
		setMaxCondition(getMaxCondition() * .65f, true);
		setConditionDamage(0, true);
	} else if(repairChance < 75) {
		setMaxCondition(getMaxCondition() * .80f, true);
		setConditionDamage(0, true);
		message += "sys_repair_slight";
	} else {
		setMaxCondition(getMaxCondition() * .95f, true);
		setConditionDamage(0, true);
		message += "sys_repair_perfect";
	}

	return message;
}
