#include "ShockedDebuffTickEvent.h"
#include "server/zone/objects/creature/buffs/ShockedDebuff.h"
#include "server/zone/objects/creature/buffs/BuffCRC.h"

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

		if (stripForceRun) {
			creature.get()->removeBuff(BuffCRC::JEDI_FORCE_RUN_1);
			creature.get()->removeBuff(BuffCRC::JEDI_FORCE_RUN_2);
			creature.get()->removeBuff(BuffCRC::JEDI_FORCE_RUN_3);
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
