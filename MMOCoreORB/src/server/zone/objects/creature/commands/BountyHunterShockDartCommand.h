/*
				Copyright <SWGEmu>
		See file COPYING for copying conditions.*/

#ifndef BOUNTYHUNTERSHOCKDARTCOMMAND_H_
#define BOUNTYHUNTERSHOCKDARTCOMMAND_H_

#include "QueueCommand.h"
#include "server/zone/managers/collision/CollisionManager.h"
#include "server/zone/objects/creature/buffs/BuffCRC.h"
#include "server/zone/objects/creature/buffs/ShockedDebuff.h"
#include "server/zone/packets/object/StopClientEffectObjectByLabelMessage.h"
#include "server/zone/objects/player/PlayerObject.h"
#include "server/zone/objects/tangible/TangibleObject.h"
#include "templates/params/creature/CreatureAttribute.h"

class BountyHunterShockDartCommand : public QueueCommand {
	void stopForceRunClientEffect(CreatureObject* creature) const {
		if (creature == nullptr)
			return;

		// Force run is played with an empty aux string, so test the raw stop packet
		// with both empty and basename-style labels in addition to our older guesses.
		static const char* labels[] = {
			"",
			"force_run",
			"clienteffect/pl_force_run_self.cef",
			"pl_force_run_self.cef",
			"pl_force_run_self",
			"force_run_self"
		};

		for (const char* label : labels) {
			// The stale trail only matters on the target's own client, so send the
			// stop packet directly to that session and broadcast it to observers separately.
			creature->sendMessage(new StopClientEffectObjectByLabelMessage(creature, label));
			creature->broadcastMessage(new StopClientEffectObjectByLabelMessage(creature, label), false);
		}
	}

	void logShockForceRunTrace(CreatureObject* attacker, CreatureObject* target, const String& phase, bool removed1, bool removed2, bool removed3) const {
		if (target == nullptr)
			return;

		StringBuffer msg;
		msg << "[ForceRunTrace] phase=" << phase
			<< " attacker=" << (attacker != nullptr ? attacker->getDisplayedName() : "null")
			<< " attackerOid=" << (attacker != nullptr ? attacker->getObjectID() : 0)
			<< " target=" << target->getDisplayedName()
			<< " targetOid=" << target->getObjectID()
			<< " removed1=" << removed1
			<< " removed2=" << removed2
			<< " removed3=" << removed3
			<< " has1=" << target->hasBuff(BuffCRC::JEDI_FORCE_RUN_1)
			<< " has2=" << target->hasBuff(BuffCRC::JEDI_FORCE_RUN_2)
			<< " has3=" << target->hasBuff(BuffCRC::JEDI_FORCE_RUN_3)
			<< " speedMulti=" << target->getSpeedMultiplierMod()
			<< " accelMulti=" << target->getAccelerationMultiplierMod();

		target->info(msg.toString(), true);
	}

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

	int getShockTickDamage(CreatureObject* targetCreature, TangibleObject* dart) const {
		if (targetCreature == nullptr)
			return 1;

		// Start by draining a quarter of the victim's current max action pool on each tick.
		int maxAction = targetCreature->getMaxHAM(CreatureAttribute::ACTION);
		int tickDamage = Math::max(1, (int)ceil(maxAction * 0.25f));

		if (dart == nullptr)
			return tickDamage;

		return tickDamage;
	}

	uint8 getShockDamageAttribute() const {
		// Shock is more of an endurance/mobility disruption than a lethal poison.
		return CreatureAttribute::ACTION;
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
		const int shockTickDamage = getShockTickDamage(targetCreature, dart);
		const bool stripForceRun = targetCreature->isPlayerCreature() && targetCreature->getPlayerObject() != nullptr
			&& targetCreature->getPlayerObject()->isJedi();

		if (stripForceRun) {
			bool removedForceRun = false;
			bool removed1 = false;
			bool removed2 = false;
			bool removed3 = false;
			logShockForceRunTrace(creature, targetCreature, "shock_hit_before_stop", removed1, removed2, removed3);
			stopForceRunClientEffect(targetCreature);

			if (targetCreature->hasBuff(BuffCRC::JEDI_FORCE_RUN_3)) {
				targetCreature->removeBuff(BuffCRC::JEDI_FORCE_RUN_3);
				removedForceRun = true;
				removed3 = true;
			}

			if (targetCreature->hasBuff(BuffCRC::JEDI_FORCE_RUN_2)) {
				targetCreature->removeBuff(BuffCRC::JEDI_FORCE_RUN_2);
				removedForceRun = true;
				removed2 = true;
			}

			if (targetCreature->hasBuff(BuffCRC::JEDI_FORCE_RUN_1)) {
				targetCreature->removeBuff(BuffCRC::JEDI_FORCE_RUN_1);
				removedForceRun = true;
				removed1 = true;
			}

			logShockForceRunTrace(creature, targetCreature, "shock_hit_after_remove", removed1, removed2, removed3);
		}

		// Reapplying the same buff CRC replaces the existing shocked debuff, so the dart can
		// be fired into the same target again to refresh the effect.
		ManagedReference<Buff*> shockedDebuff = new ShockedDebuff(targetCreature, STRING_HASHCODE("bountyhuntershockdart_shocked"),
			shockDurationSeconds, getShockSnareSeconds(), stripForceRun, creature->getObjectID(), shockTickDamage, getShockDamageAttribute());

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
