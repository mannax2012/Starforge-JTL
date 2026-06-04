/*
				Copyright <SWGEmu>
		See file COPYING for copying conditions.*/

#include "engine/engine.h"

#include "server/zone/objects/creature/buffs/CenterOfBeingBuff.h"
#include "server/zone/objects/creature/buffs/CenterOfBeingBuffDurationEvent.h"

void CenterOfBeingBuffImplementation::activate(bool applyModifiers) {
	debug() << "activating center of being buff with crc " << hex << buffCRC;

	try {
		if (applyModifiers)
			applyAllModifiers();

		scheduleBuffEvent();

		timeApplied.updateToCurrentTime();

		ManagedReference<CreatureObject*> creo = creature.get();
		if (creo->isPlayerCreature())
			sendTo(creo);

		if (!startMessage.isEmpty())
			creo->sendSystemMessage(startMessage);

		if (!startFlyFile.isEmpty())
			creo->showFlyText(startFlyFile, startFlyAux, startFlyRed, startFlyGreen, startFlyBlue);

		if (!startSpam.isEmpty())
			creo->sendStateCombatSpam(startSpam.getFile(), startSpam.getStringID(), spamColor, 0, broadcastSpam);

	} catch (const Exception& e) {
		error(e.getMessage());
		e.printStackTrace();
	}
}

void CenterOfBeingBuffImplementation::loadBuffDurationEvent(CreatureObject* creo) {
	if (nextExecutionTime.getTime() - time(0) > buffDuration) {
		error("Buff timer was f'ed in the a!  Serialized Time:" + String::valueOf((int)(nextExecutionTime.getTime() - time(0))) + " Duration: " + String::valueOf(buffDuration));
		nextExecutionTime = Time((uint32)(time(0) + (int)buffDuration));
	}

	if (nextExecutionTime.isPast()) {
		buffEvent = new CenterOfBeingBuffDurationEvent(creo, _this.getReferenceUnsafeStaticCast());
		buffEvent->execute();
	} else {
		buffEvent = new CenterOfBeingBuffDurationEvent(creo, _this.getReferenceUnsafeStaticCast());
		buffEvent->schedule(nextExecutionTime);
	}
}

void CenterOfBeingBuffImplementation::scheduleBuffEvent() {
	buffEvent = new CenterOfBeingBuffDurationEvent(creature.get(), _this.getReferenceUnsafeStaticCast());
	buffEvent->schedule((int)(buffDuration * 1000));

	AtomicTime time;
	Core::getTaskManager()->getNextExecutionTime(buffEvent, time);
	nextExecutionTime = time.getTimeObject();
}
