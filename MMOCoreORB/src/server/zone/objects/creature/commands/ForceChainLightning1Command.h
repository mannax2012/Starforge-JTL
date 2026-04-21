/*
				Copyright <SWGEmu>
		See file COPYING for copying conditions.*/

#ifndef FORCECHAINLIGHTNING1COMMAND_H_
#define FORCECHAINLIGHTNING1COMMAND_H_

#include "ForcePowersQueueCommand.h"
#include "server/zone/Zone.h"
#include "server/zone/CloseObjectsVector.h"
#include "server/zone/managers/collision/CollisionManager.h"

class ForceChainLightning1Command : public ForcePowersQueueCommand {
	static const int MAX_CHAIN_BOUNCES = 3;
	static const int CHAIN_ANIMATION_DELAY_MS = 250;

	// Bounce damage is applied through combat, but the visible chain uses the same
	// target-to-target animation path Force Intimidate uses.
	static bool& inChainBounce() {
		static thread_local bool flag = false;
		return flag;
	}

public:
	ForceChainLightning1Command(const String& name, ZoneProcessServer* server)
		: ForcePowersQueueCommand(name, server) {
	}

	String getAnimation(TangibleObject* attacker, TangibleObject* defender, WeaponObject* weapon, uint8 hitLocation, int damage) const override {
		if (inChainBounce())
			return String("chainlightning_bounce_noanim");
		return ForcePowersQueueCommand::getAnimation(attacker, defender, weapon, hitLocation, damage);
	}

	int doQueueCommand(CreatureObject* creature, const uint64& target, const UnicodeString& arguments) const override {
		if (!checkStateMask(creature))
			return INVALIDSTATE;

		if (!checkInvalidLocomotions(creature))
			return INVALIDLOCOMOTION;

		if (isWearingArmor(creature))
			return NOJEDIARMOR;

		// Primary hit — force cost deducted here, CombatAction broadcast normally
		// (player → primary target) with the real animation.
		int result = doCombatAction(creature, target);
		if (result != SUCCESS)
			return result;

		ManagedReference<SceneObject*> primaryScene = server->getZoneServer()->getObject(target);
		if (primaryScene == nullptr || !primaryScene->isTangibleObject())
			return SUCCESS;

		Vector<uint64> hitTargets;
		hitTargets.add(creature->getObjectID());
		hitTargets.add(target);

		ManagedReference<TangibleObject*> currentTarget = cast<TangibleObject*>(primaryScene.get());
		CombatManager* combatManager = CombatManager::instance();
		Vector<ManagedReference<TangibleObject*>> bounceTargets;

		// Bounce damage goes through the normal combat action path. The default
		// combat visuals are suppressed so the Force Intimidate chain animation can
		// draw target-to-target links after all bounce targets are known.
		inChainBounce() = true;

		for (int bounce = 0; bounce < MAX_CHAIN_BOUNCES && currentTarget != nullptr; ++bounce) {
			ManagedReference<TangibleObject*> nextTarget = findNextChainTarget(creature, currentTarget, hitTargets);
			if (nextTarget == nullptr)
				break;

			hitTargets.add(nextTarget->getObjectID());
			bounceTargets.add(nextTarget);

			try {
				combatManager->doCombatAction(creature, creature->getWeapon(), nextTarget,
					CreatureAttackData(arguments, this, nextTarget->getObjectID()));
			} catch (Exception& e) {
				creature->error("unreported exception caught in ForceChainLightning1Command chain bounce");
			}

			currentTarget = nextTarget;
		}

		inChainBounce() = false;

		if (bounceTargets.size() > 0)
			scheduleChainAnimation(cast<TangibleObject*>(primaryScene.get()), bounceTargets);

		return SUCCESS;
	}

private:
	void scheduleChainAnimation(TangibleObject* firstTarget, const Vector<ManagedReference<TangibleObject*>>& bounceTargets) const {
		CreatureObject* firstCreature = firstTarget != nullptr ? firstTarget->asCreatureObject() : nullptr;

		if (firstCreature == nullptr)
			return;

		Reference<CreatureObject*> firstRef = firstCreature;
		Vector<ManagedReference<TangibleObject*>> targets = bounceTargets;

		Core::getTaskManager()->scheduleTask([firstRef, targets] () mutable {
			CreatureObject* source = firstRef.get();

			for (int i = 0; i < targets.size(); ++i) {
				if (source == nullptr)
					return;

				TangibleObject* target = targets.get(i).get();
				CreatureObject* targetCreature = target != nullptr ? target->asCreatureObject() : nullptr;

				if (targetCreature == nullptr || source == targetCreature)
					continue;

				Locker locker(source);
				source->doCombatAnimation(targetCreature, STRING_HASHCODE("force_chain_lightning1"), 0x01, 0xFF);
				locker.release();

				source = targetCreature;
			}
		}, "ForceChainLightningChainAnimation", CHAIN_ANIMATION_DELAY_MS);
	}

	ManagedReference<TangibleObject*> findNextChainTarget(CreatureObject* attacker, TangibleObject* fromTarget, const Vector<uint64>& hitTargets) const {
		Zone* zone = attacker->getZone();
		if (zone == nullptr)
			return nullptr;

		CloseObjectsVector* vec = (CloseObjectsVector*)fromTarget->getCloseObjects();
		SortedVector<TreeEntry*> closeObjects;

		if (vec != nullptr) {
			closeObjects.removeAll(vec->size(), 10);
			vec->safeCopyTo(closeObjects);
		} else {
			Vector3 pos = fromTarget->getWorldPosition();
			zone->getInRangeObjects(pos.getX(), 0, pos.getY(), areaRange + 32, &closeObjects, true);
		}

		ManagedReference<TangibleObject*> bestTarget = nullptr;
		float bestDistSq = (float)areaRange * (float)areaRange;

		for (int i = 0; i < closeObjects.size(); ++i) {
			SceneObject* obj = static_cast<SceneObject*>(closeObjects.get(i));
			if (obj == nullptr)
				continue;

			TangibleObject* tano = obj->asTangibleObject();
			if (tano == nullptr || !tano->isAttackableBy(attacker))
				continue;

			bool alreadyHit = false;
			for (int j = 0; j < hitTargets.size(); ++j) {
				if (hitTargets.get(j) == tano->getObjectID()) {
					alreadyHit = true;
					break;
				}
			}
			if (alreadyHit)
				continue;

			CreatureObject* creo = tano->asCreatureObject();
			if (creo != nullptr && (creo->isFeigningDeath() || creo->isIncapacitated()))
				continue;

			float distSq = fromTarget->getWorldPosition().squaredDistanceTo(tano->getWorldPosition());
			if (distSq > bestDistSq)
				continue;

			if (!CollisionManager::checkLineOfSight(tano, fromTarget))
				continue;

			bestDistSq = distSq;
			bestTarget = tano;
		}

		return bestTarget;
	}
};

#endif // FORCECHAINLIGHTNING1COMMAND_H_
