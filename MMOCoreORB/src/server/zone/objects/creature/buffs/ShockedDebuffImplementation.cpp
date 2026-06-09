#include "ShockedDebuffTickEvent.h"
#include "server/zone/objects/creature/buffs/ShockedDebuff.h"
#include "server/zone/objects/creature/buffs/BuffCRC.h"
#include "server/zone/packets/object/StopClientEffectObjectByLabelMessage.h"
#include "server/zone/ZoneServer.h"
#include "engine/core/TaskManager.h"

namespace {
	void stopForceRunClientEffect(CreatureObject* creature) {
		if (creature == nullptr)
			return;

		static const char* labels[] = {
			"",
			"force_run",
			"clienteffect/pl_force_run_self.cef",
			"pl_force_run_self.cef",
			"pl_force_run_self",
			"force_run_self"
		};

		for (const char* label : labels) {
			// Send directly to the owner first in case the local client is the one
			// missing the stop, then fan out to nearby observers.
			creature->sendMessage(new StopClientEffectObjectByLabelMessage(creature, label));
			creature->broadcastMessage(new StopClientEffectObjectByLabelMessage(creature, label), false);
		}
	}

	void logShockTickForceRunTrace(CreatureObject* victim, uint64 attackerID, int tickCount, const String& phase, bool removed1, bool removed2, bool removed3) {
		if (victim == nullptr)
			return;

		float shockTimeLeft = 0.f;
		ManagedReference<Buff*> shockBuff = victim->getBuff(STRING_HASHCODE("bountyhuntershockdart_shocked"));

		if (shockBuff != nullptr)
			shockTimeLeft = shockBuff->getTimeLeft();

		StringBuffer msg;
		msg << "[ForceRunTrace] phase=" << phase
			<< " tick=" << tickCount
			<< " attackerOid=" << attackerID
			<< " victim=" << victim->getDisplayedName()
			<< " victimOid=" << victim->getObjectID()
			<< " removed1=" << removed1
			<< " removed2=" << removed2
			<< " removed3=" << removed3
			<< " has1=" << victim->hasBuff(BuffCRC::JEDI_FORCE_RUN_1)
			<< " has2=" << victim->hasBuff(BuffCRC::JEDI_FORCE_RUN_2)
			<< " has3=" << victim->hasBuff(BuffCRC::JEDI_FORCE_RUN_3)
			<< " speedMulti=" << victim->getSpeedMultiplierMod()
			<< " accelMulti=" << victim->getAccelerationMultiplierMod()
			<< " shockTimeLeft=" << shockTimeLeft;

		victim->info(msg.toString(), true);
	}

	void applyShockTickDamage(CreatureObject* victim, uint64 attackerID, uint8 attribute, int strength) {
		if (victim == nullptr || strength <= 0 || victim->isIncapacitated())
			return;

		int attr = victim->getHAM(attribute);

		if (attr <= 1)
			return;

		int damage = strength;

		if (attr < damage)
			damage = attr - 1;

		if (damage <= 0)
			return;

		auto zoneServer = victim->getZoneServer();

		if (zoneServer == nullptr)
			return;

		ManagedReference<CreatureObject*> attacker = zoneServer->getObject(attackerID).castTo<CreatureObject*>();

		if (attacker == nullptr)
			attacker = victim;

		Reference<CreatureObject*> attackerRef = attacker;
		Reference<CreatureObject*> victimRef = victim;

		Core::getTaskManager()->executeTask([victimRef, attackerRef, attribute, damage] () {
			Locker locker(victimRef);
			Locker crossLocker(attackerRef, victimRef);

			victimRef->inflictDamage(attackerRef, attribute, damage, false, "dotDMG", true, false);

			if (victimRef->hasAttackDelay())
				victimRef->removeAttackDelay();
		}, "ShockTickDamageLambda");
	}
}

void ShockedDebuffImplementation::initializeTransientMembers() {
	BuffImplementation::initializeTransientMembers();
}

void ShockedDebuffImplementation::activate(bool applyModifiers) {
	if (creature.get() == nullptr)
		return;

	Locker locker(creature.get());
	Locker lockerX(_this.getReferenceUnsafeStaticCast(), creature.get());

	if (tickCount == 0) {
		BuffImplementation::activate(false);
	}

	if (!creature.get()->isDead() && !creature.get()->isIncapacitated()) {
		uint32 snareCRC = Long::hashCode(CreatureState::IMMOBILIZED);

		if (creature.get()->hasBuff(snareCRC))
			creature.get()->renewBuff(snareCRC, snareDuration, true);
		else
			creature.get()->setSnaredState(snareDuration);

		creature.get()->playEffect("clienteffect/ig88_droideka_electrify.cef", "");

		applyShockTickDamage(creature.get(), attackerID, damageAttribute, tickDamage);

		if (stripForceRun) {
			bool removedForceRun = false;
			bool removed1 = false;
			bool removed2 = false;
			bool removed3 = false;
			logShockTickForceRunTrace(creature.get(), attackerID, tickCount, "shock_tick_before_stop", removed1, removed2, removed3);
			stopForceRunClientEffect(creature.get());

			if (creature.get()->hasBuff(BuffCRC::JEDI_FORCE_RUN_1)) {
				creature.get()->removeBuff(BuffCRC::JEDI_FORCE_RUN_1);
				removedForceRun = true;
				removed1 = true;
			}

			if (creature.get()->hasBuff(BuffCRC::JEDI_FORCE_RUN_2)) {
				creature.get()->removeBuff(BuffCRC::JEDI_FORCE_RUN_2);
				removedForceRun = true;
				removed2 = true;
			}

			if (creature.get()->hasBuff(BuffCRC::JEDI_FORCE_RUN_3)) {
				creature.get()->removeBuff(BuffCRC::JEDI_FORCE_RUN_3);
				removedForceRun = true;
				removed3 = true;
			}

			logShockTickForceRunTrace(creature.get(), attackerID, tickCount, "shock_tick_after_remove", removed1, removed2, removed3);
		}
	}

	++tickCount;

	if (getTimeLeft() > SHOCK_TICK_SECONDS) {
		Reference<ShockedDebuffTickEvent*> shockCheck = creature.get()->getPendingTask("shockDartTick").castTo<ShockedDebuffTickEvent*>();

		if (shockCheck == nullptr) {
			shockBuffEvent = new ShockedDebuffTickEvent(creature.get(), _this.getReferenceUnsafeStaticCast());
			creature.get()->addPendingTask("shockDartTick", shockBuffEvent, SHOCK_TICK_SECONDS * 1000);
		} else {
			shockCheck->reschedule(SHOCK_TICK_SECONDS * 1000);
		}
	}
}

void ShockedDebuffImplementation::deactivate(bool removeModifiers) {
	BuffImplementation::deactivate(false);
}

void ShockedDebuffImplementation::clearBuffEvent() {
	if (creature.get() == nullptr)
		return;

	Locker locker(creature.get());
	Locker lockerX(_this.getReferenceUnsafeStaticCast(), creature.get());

	if (shockBuffEvent != nullptr) {
		creature.get()->removePendingTask("shockDartTick");

		if (shockBuffEvent->isScheduled())
			shockBuffEvent->cancel();
	}

	BuffImplementation::clearBuffEvent();
}
