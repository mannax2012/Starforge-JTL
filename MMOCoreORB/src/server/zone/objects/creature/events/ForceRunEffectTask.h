/*
				Copyright <SWGEmu>
		See file COPYING for copying conditions.*/

#ifndef FORCERUNEFFECTTASK_H_
#define FORCERUNEFFECTTASK_H_

#include "server/zone/objects/creature/CreatureObject.h"
#include "server/zone/objects/creature/buffs/BuffCRC.h"

class ForceRunEffectTask : public Task {
	ManagedWeakReference<CreatureObject*> creature;
	String clientEffect;

public:
	static const uint64 REPLAY_DELAY_MS = 2000;

	static const char* getPendingTaskName() {
		return "forceRunEffect";
	}

	ForceRunEffectTask(CreatureObject* creo, const String& effect) : Task() {
		creature = creo;
		clientEffect = effect;
	}

	static bool hasActiveForceRun(CreatureObject* creo) {
		return creo != nullptr && (creo->hasBuff(BuffCRC::JEDI_FORCE_RUN_1)
			|| creo->hasBuff(BuffCRC::JEDI_FORCE_RUN_2)
			|| creo->hasBuff(BuffCRC::JEDI_FORCE_RUN_3));
	}

	void run() {
		ManagedReference<CreatureObject*> strongCreature = creature.get();

		if (strongCreature == nullptr)
			return;

		Locker locker(strongCreature);

		if (!hasActiveForceRun(strongCreature) || strongCreature->isDead() || strongCreature->isIncapacitated()) {
			strongCreature->removePendingTask(getPendingTaskName());
			return;
		}

		strongCreature->playEffect(clientEffect, "");
		reschedule(REPLAY_DELAY_MS);
	}
};

#endif /* FORCERUNEFFECTTASK_H_ */
