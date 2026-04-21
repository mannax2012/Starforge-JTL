/*
				Copyright <SWGEmu>
		See file COPYING for copying conditions.*/

#ifndef FORCECHAINHEAL1COMMAND_H_
#define FORCECHAINHEAL1COMMAND_H_

#include "ForceHealQueueCommand.h"
#include "server/zone/Zone.h"
#include "server/zone/CloseObjectsVector.h"
#include "server/zone/managers/collision/CollisionManager.h"
#include "server/zone/objects/group/GroupObject.h"

class ForceChainHeal1Command : public ForceHealQueueCommand {
public:
	ForceChainHeal1Command(const String& name, ZoneProcessServer* server)
		: ForceHealQueueCommand(name, server) {
		allowedTarget = TARGET_SELF | TARGET_OTHER;
		range = 32;
		chainToAmount = 1;
	}

	int doQueueCommand(CreatureObject* creature, const uint64& target, const UnicodeString& arguments) const override {
		if (creature == nullptr || !creature->isPlayerCreature())
			return GENERALERROR;

		if (!checkInvalidLocomotions(creature))
			return INVALIDLOCOMOTION;

		int comResult = doCommonJediSelfChecks(creature);

		if (comResult != SUCCESS)
			return comResult;

		const int maxChainTargets = chainToAmount > 0 ? chainToAmount : 1;
		int healedTargets = 0;
		int lastResult = GENERALERROR;
		bool attemptedHeal = false;

		Vector<uint64> visitedTargets;

		ManagedReference<CreatureObject*> chainSource = creature;
		ManagedReference<GroupObject*> group = creature->getGroup();
		ManagedReference<CreatureObject*> nextTarget = getSelectedChainTarget(creature, target, visitedTargets);

		if (nextTarget == creature && !needsChainHeal(creature)) {
			visitedTargets.add(creature->getObjectID());
			nextTarget = nullptr;
		} else if (nextTarget == nullptr) {
			visitedTargets.add(creature->getObjectID());

			if (needsChainHeal(creature))
				nextTarget = creature;
		} else if (nextTarget != creature) {
			visitedTargets.add(creature->getObjectID());
		}

		if (nextTarget == nullptr)
			nextTarget = findNextChainTarget(creature, chainSource, group, visitedTargets);

		while (nextTarget != nullptr && healedTargets < maxChainTargets) {
			ManagedReference<CreatureObject*> healTarget = nextTarget;
			visitedTargets.add(healTarget->getObjectID());

			Locker locker(healTarget, creature);

			if (healTarget != creature && !isValidChainTarget(creature, chainSource, healTarget, nullptr)) {
				locker.release();
				nextTarget = findNextChainTarget(creature, chainSource, group, visitedTargets);
				continue;
			}

			attemptedHeal = true;
			lastResult = runCommand(creature, healTarget);

			if (lastResult != SUCCESS)
				break;

			healedTargets++;
			chainSource = healTarget;
			playChainHealTargetEffect(creature, healTarget);

			locker.release();

			nextTarget = findNextChainTarget(creature, chainSource, group, visitedTargets);
		}

		if (healedTargets > 0)
			return SUCCESS;

		if (!attemptedHeal && lastResult == GENERALERROR)
			creature->sendSystemMessage("@jedi_spam:no_damage_heal_other");

		return lastResult;
	}

private:
	void playChainHealTargetEffect(CreatureObject* healer, CreatureObject* healTarget) const {
		if (healer == nullptr || healTarget == nullptr || healer == healTarget)
			return;

		healTarget->playEffect(clientEffect, "");
	}

	ManagedReference<CreatureObject*> getSelectedChainTarget(CreatureObject* healer, const uint64& target, const Vector<uint64>& visitedTargets) const {
		if (healer == nullptr || target == 0)
			return nullptr;

		if (target == healer->getObjectID())
			return healer;

		ManagedReference<SceneObject*> sceneTarget = server->getZoneServer()->getObject(target);

		if (sceneTarget == nullptr || !sceneTarget->isCreatureObject())
			return nullptr;

		ManagedReference<CreatureObject*> targetCreature = sceneTarget.castTo<CreatureObject*>();

		if (targetCreature == nullptr)
			return nullptr;

		if (!isValidChainTarget(healer, healer, targetCreature, &visitedTargets))
			return nullptr;

		return targetCreature;
	}

	ManagedReference<CreatureObject*> findNextChainTarget(CreatureObject* healer, CreatureObject* fromTarget, GroupObject* group, const Vector<uint64>& visitedTargets) const {
		if (healer == nullptr || fromTarget == nullptr)
			return nullptr;

		ManagedReference<CreatureObject*> bestTarget = findNextGroupTarget(healer, fromTarget, group, visitedTargets);

		if (bestTarget != nullptr)
			return bestTarget;

		return findNextFriendlyTarget(healer, fromTarget, visitedTargets);
	}

	ManagedReference<CreatureObject*> findNextGroupTarget(CreatureObject* healer, CreatureObject* fromTarget, GroupObject* group, const Vector<uint64>& visitedTargets) const {
		if (healer == nullptr || fromTarget == nullptr || group == nullptr)
			return nullptr;

		ManagedReference<CreatureObject*> bestTarget = nullptr;
		float bestDistSq = range > 0 ? (float)range * (float)range : 0;

		for (int i = 0; i < group->getGroupSize(); ++i) {
			ManagedReference<CreatureObject*> member = group->getGroupMember(i);

			if (!isValidChainTarget(healer, fromTarget, member, &visitedTargets))
				continue;

			float distSq = fromTarget->getWorldPosition().squaredDistanceTo(member->getWorldPosition());

			if (bestTarget == nullptr || distSq < bestDistSq) {
				bestDistSq = distSq;
				bestTarget = member;
			}
		}

		return bestTarget;
	}

	ManagedReference<CreatureObject*> findNextFriendlyTarget(CreatureObject* healer, CreatureObject* fromTarget, const Vector<uint64>& visitedTargets) const {
		Zone* zone = healer->getZone();

		if (zone == nullptr)
			return nullptr;

		SortedVector<TreeEntry*> closeObjects;
		CloseObjectsVector* vec = (CloseObjectsVector*)fromTarget->getCloseObjects();

		if (vec != nullptr) {
			closeObjects.removeAll(vec->size(), 10);
			vec->safeCopyReceiversTo(closeObjects, CloseObjectsVector::CREOTYPE);
		} else {
			Vector3 pos = fromTarget->getWorldPosition();
			zone->getInRangeObjects(pos.getX(), pos.getZ(), pos.getY(), range, &closeObjects, true);
		}

		ManagedReference<CreatureObject*> bestTarget = nullptr;
		float bestDistSq = range > 0 ? (float)range * (float)range : 0;

		for (int i = 0; i < closeObjects.size(); ++i) {
			SceneObject* object = static_cast<SceneObject*>(closeObjects.get(i));

			if (object == nullptr || !object->isCreatureObject())
				continue;

			ManagedReference<CreatureObject*> targetCreature = object->asCreatureObject();

			if (!isValidChainTarget(healer, fromTarget, targetCreature, &visitedTargets))
				continue;

			float distSq = fromTarget->getWorldPosition().squaredDistanceTo(targetCreature->getWorldPosition());

			if (bestTarget == nullptr || distSq < bestDistSq) {
				bestDistSq = distSq;
				bestTarget = targetCreature;
			}
		}

		return bestTarget;
	}

	bool isValidChainTarget(CreatureObject* healer, CreatureObject* fromTarget, CreatureObject* targetCreature, const Vector<uint64>* visitedTargets) const {
		if (healer == nullptr || fromTarget == nullptr || targetCreature == nullptr)
			return false;

		if (targetCreature == healer)
			return false;

		if (visitedTargets != nullptr) {
			for (int i = 0; i < visitedTargets->size(); ++i) {
				if (visitedTargets->get(i) == targetCreature->getObjectID())
					return false;
			}
		}

		if ((!targetCreature->isPlayerCreature() && !targetCreature->isPet()) || targetCreature->isDroidObject() || targetCreature->isWalkerSpecies())
			return false;

		if (targetCreature->isDead() || targetCreature->isAttackableBy(healer))
			return false;

		if (targetCreature->getZone() != healer->getZone())
			return false;

		if (range > 0 && !targetCreature->isInRange(fromTarget, range))
			return false;

		if (checkForArenaDuel(targetCreature))
			return false;

		if (!targetCreature->isHealableBy(healer))
			return false;

		if (!CollisionManager::checkLineOfSight(fromTarget, targetCreature))
			return false;

		if (!playerEntryCheck(healer, targetCreature))
			return false;

		return needsChainHeal(targetCreature);
	}

	bool needsChainHeal(CreatureObject* targetCreature) const {
		if (targetCreature == nullptr)
			return false;

		for (int i = 0; i < 3; ++i) {
			if (attributesToHeal & (1 << i)) {
				uint8 attrib = i * 3;
				int maxHam = targetCreature->getMaxHAM(attrib) - targetCreature->getWounds(attrib);

				if (targetCreature->getHAM(attrib) < maxHam)
					return true;
			}

			if (woundAttributesToHeal & (1 << i)) {
				for (int j = 0; j < 3; ++j) {
					uint8 attrib = (i * 3) + j;

					if (targetCreature->getWounds(attrib) > 0)
						return true;
				}
			}
		}

		if (healBattleFatigue != 0 && targetCreature->getShockWounds() > 0)
			return true;

		for (int i = 12; i <= 15; ++i) {
			int state = (1 << i);

			if ((statesToHeal & state) && targetCreature->hasState(state))
				return true;
		}

		if (healBleedingCost > 0 && targetCreature->isBleeding())
			return true;

		if (healPoisonCost > 0 && targetCreature->isPoisoned())
			return true;

		if (healDiseaseCost > 0 && targetCreature->isDiseased())
			return true;

		if (healFireCost > 0 && targetCreature->isOnFire())
			return true;

		return false;
	}
};

#endif // FORCECHAINHEAL1COMMAND_H_
