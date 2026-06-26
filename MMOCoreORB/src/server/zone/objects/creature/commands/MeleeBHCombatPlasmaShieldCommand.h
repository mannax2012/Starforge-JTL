/*
				Copyright <SWGEmu>
		See file COPYING for copying conditions.*/

#ifndef MELEEBHCOMBATPLASMASHIELDCOMMAND_H_
#define MELEEBHCOMBATPLASMASHIELDCOMMAND_H_

#include "QueueCommand.h"
#include "server/zone/objects/creature/buffs/Buff.h"
#include "server/zone/objects/creature/buffs/PrivateSkillMultiplierBuff.h"
#include "server/zone/objects/tangible/TangibleObject.h"

class MeleeBHCombatPlasmaShieldCommand : public QueueCommand {
	bool matchesRequiredItem(SceneObject* item, const String& templateToken) const {
		if (item == nullptr)
			return false;

		TangibleObject* tangible = item->asTangibleObject();

		if (tangible == nullptr || tangible->getObjectTemplate() == nullptr)
			return false;

		return tangible->getObjectTemplate()->getTemplateFileName().contains(templateToken);
	}

	TangibleObject* findRequiredItemInContainer(SceneObject* container, const String& templateToken) const {
		if (container == nullptr)
			return nullptr;

		for (int i = 0; i < container->getContainerObjectsSize(); ++i) {
			SceneObject* item = container->getContainerObject(i);

			if (matchesRequiredItem(item, templateToken))
				return item->asTangibleObject();

			TangibleObject* nestedItem = findRequiredItemInContainer(item, templateToken);

			if (nestedItem != nullptr)
				return nestedItem;
		}

		return nullptr;
	}

	TangibleObject* findRequiredItem(CreatureObject* creature, const String& templateToken) const {
		if (creature == nullptr)
			return nullptr;

		SceneObject* inventory = creature->getSlottedObject("inventory");

		return findRequiredItemInContainer(inventory, templateToken);
	}

	void consumeRequiredItem(TangibleObject* item) const {
		if (item == nullptr)
			return;

		if (item->getUseCount() > 1) {
			item->decreaseUseCount();
			return;
		}

		// GM-created test items can have a zero use count, so destroy them as a single-use fallback.
		item->destroyObjectFromWorld(true);
		item->destroyObjectFromDatabase(true);
	}

public:
	MeleeBHCombatPlasmaShieldCommand(const String& name, ZoneProcessServer* server)
		: QueueCommand(name, server) {
	}

	int doQueueCommand(CreatureObject* creature, const uint64& target, const UnicodeString& arguments) const {
		if (!checkStateMask(creature))
			return INVALIDSTATE;

		if (!checkInvalidLocomotions(creature))
			return INVALIDLOCOMOTION;

		if (!creature->isPlayerCreature())
			return GENERALERROR;

		if (creature->hasBuff(name.hashCode())) {
			creature->sendSystemMessage("Combat Plasma Shield is already active.");
			return GENERALERROR;
		}

		if (!checkCooldown(creature))
			return GENERALERROR;

		TangibleObject* battery = findRequiredItem(creature, "bh_shield_battery");

		if (battery == nullptr) {
			creature->sendSystemMessage("You need a Bounty Hunter Shield Battery to use Combat Plasma Shield.");
			return GENERALERROR;
		}

		const int durationSeconds = 30;

		ManagedReference<PrivateSkillMultiplierBuff*> reductionBuff = new PrivateSkillMultiplierBuff(creature, STRING_HASHCODE("meleebhcombatplasmashield_reduction"), durationSeconds, BuffType::SKILL);

		Locker reductionLocker(reductionBuff);
		reductionBuff->setSkillModifier("private_damage_divisor", 25);
		reductionLocker.release();

		ManagedReference<Buff*> shieldBuff = new Buff(creature, name.hashCode(), durationSeconds, BuffType::SKILL);

		Locker shieldLocker(shieldBuff);
		shieldBuff->addSecondaryBuffCRC(reductionBuff->getBuffCRC());
		shieldLocker.release();

		creature->addBuff(reductionBuff);
		creature->addBuff(shieldBuff);
		creature->playEffect("clienteffect/cyssc_grnshield.cef", "");

		Locker batteryLocker(battery);
		consumeRequiredItem(battery);

		return SUCCESS;
	}
};

#endif //MELEEBHCOMBATPLASMASHIELDCOMMAND_H_
