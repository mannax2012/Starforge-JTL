/*
				Copyright <SWGEmu>
		See file COPYING for copying conditions.*/

#ifndef BOUNTYHUNTERSHOCKDARTCOMMAND_H_
#define BOUNTYHUNTERSHOCKDARTCOMMAND_H_

#include "QueueCommand.h"
#include "server/zone/managers/collision/CollisionManager.h"
#include "server/zone/objects/creature/buffs/BuffCRC.h"
#include "server/zone/objects/creature/buffs/ShockedDebuff.h"
#include "server/zone/objects/tangible/TangibleObject.h"

class BountyHunterShockDartCommand : public QueueCommand {
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

	int getShockDurationSeconds(TangibleObject* dart) const {
		// Default shock duration until the crafted dart data exists. Keep the clamp in place for
		// future item-driven bonuses so the command can't exceed the intended ceiling.
		int durationSeconds = 15;

		if (dart == nullptr)
			return durationSeconds;

		if (durationSeconds > 30)
			durationSeconds = 30;

		return durationSeconds;
	}

	int getShockSnareSeconds() const {
		return 5;
	}

	float getMaxRange() const {
		return 32.f;
	}

public:
	BountyHunterShockDartCommand(const String& name, ZoneProcessServer* server)
		: QueueCommand(name, server) {
	}

	int doQueueCommand(CreatureObject* creature, const uint64& target, const UnicodeString& arguments) const {
		if (!checkStateMask(creature))
			return INVALIDSTATE;

		if (!checkInvalidLocomotions(creature))
			return INVALIDLOCOMOTION;

		ManagedReference<CreatureObject*> targetCreature = server->getZoneServer()->getObject(target).castTo<CreatureObject*>();

		if (targetCreature == nullptr || targetCreature == creature || targetCreature->isDead() || targetCreature->isIncapacitated())
			return INVALIDTARGET;

		if (!checkDistance(creature, targetCreature, getMaxRange()))
			return TOOFAR;

		if (!CollisionManager::checkLineOfSight(creature, targetCreature)) {
			creature->sendSystemMessage("@cbt_spam:los_fail");
			return GENERALERROR;
		}

		if (!playerEntryCheck(creature, targetCreature))
			return GENERALERROR;

		Locker crossLocker(targetCreature, creature);

		if (!targetCreature->isAttackableBy(creature))
			return INVALIDTARGET;

		TangibleObject* dart = findRequiredItem(creature, "bh_shock_dart");

		if (dart == nullptr) {
			creature->sendSystemMessage("You need a Bounty Hunter Shock Dart to use Shock Dart.");
			return GENERALERROR;
		}

		const int shockDurationSeconds = getShockDurationSeconds(dart);
		const bool stripForceRun = targetCreature->isPlayerCreature() && targetCreature->getPlayerObject() != nullptr
			&& targetCreature->getPlayerObject()->isJedi();

		// Reapplying the same buff CRC replaces the existing shocked debuff, so the dart can
		// be fired into the same target again to refresh the effect.
		ManagedReference<Buff*> shockedDebuff = new ShockedDebuff(targetCreature, STRING_HASHCODE("bountyhuntershockdart_shocked"),
			shockDurationSeconds, getShockSnareSeconds(), stripForceRun);

		Locker debuffLocker(shockedDebuff, targetCreature);
		targetCreature->addBuff(shockedDebuff);

		Locker dartLocker(dart);
		consumeRequiredItem(dart);

		creature->doAnimation("fire_1_special_single");

		checkForTef(creature, targetCreature);

		return SUCCESS;
	}
};

#endif //BOUNTYHUNTERSHOCKDARTCOMMAND_H_
