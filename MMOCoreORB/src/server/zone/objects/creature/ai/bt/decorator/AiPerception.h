#ifndef AIPERCEPTION_H_
#define AIPERCEPTION_H_

#include "server/zone/objects/creature/ai/AiAgent.h"
#include "server/zone/managers/collision/CollisionManager.h"
#include "templates/params/creature/CreaturePosture.h"
#include "templates/params/creature/CreatureState.h"
#include "templates/params/creature/ObjectFlag.h"

#include <cmath>

namespace server {
namespace zone {
namespace objects {
namespace creature {
namespace ai {
namespace bt {
namespace decorator {
namespace detail {

inline bool canPerceiveTarget(AiAgent* agent, CreatureObject* target) {
	if (agent == nullptr || target == nullptr) {
		return false;
	}

	SceneObject* agentParent = agent->getParent().get();
	SceneObject* targetParent = target->getParent().get();
	bool sharedParent = agentParent != nullptr && targetParent != nullptr && agentParent->getObjectID() == targetParent->getObjectID();

	float aggroRadius = agent->getAggroRadius();

	if (aggroRadius <= 0.f) {
		aggroRadius = AiAgent::DEFAULTAGGRORADIUS;
	}

	float visionRadius = aggroRadius;
	float hearingRadius = Math::max(6.f, aggroRadius * 0.55f);
	float fovDegrees = 170.f;

	const uint32 creatureFlags = agent->getCreatureBitmask();
	const uint32 pvpFlags = agent->getPvpStatusBitmask();

	if ((pvpFlags & ObjectFlag::AGGRESSIVE) || (creatureFlags & ObjectFlag::STALKER) || (creatureFlags & ObjectFlag::KILLER)) {
		visionRadius = Math::min(96.f, aggroRadius * 1.2f);
		hearingRadius = Math::min(72.f, aggroRadius * 0.75f);
		fovDegrees = 220.f;
	}

	if (agent->hasState(CreatureState::BLINDED)) {
		visionRadius *= 0.4f;
		fovDegrees = 300.f;
	}

	if (target->getPosture() == CreaturePosture::PRONE) {
		hearingRadius *= 0.5f;
	} else if (target->getPosture() == CreaturePosture::CROUCHED) {
		hearingRadius *= 0.75f;
	}

	const bool hasLineOfSight = sharedParent || CollisionManager::checkLineOfSight(agent, target);

	if (!hasLineOfSight) {
		return false;
	}

	if (agent->isInRange(target, hearingRadius)) {
		return true;
	}

	if (!agent->isInRange(target, visionRadius)) {
		return false;
	}

	Vector3 source = agent->getWorldPosition();
	Vector3 targetPos = target->getWorldPosition();

	float dx = targetPos.getX() - source.getX();
	float dy = targetPos.getY() - source.getY();
	float facingAngle = atan2(dy, dx);
	facingAngle = M_PI / 2 - facingAngle;

	if (facingAngle < 0) {
		float wrap = M_PI + facingAngle;
		facingAngle = M_PI + wrap;
	}

	float angleDiff = fabs(facingAngle - agent->getDirection()->getRadians());

	if (angleDiff > M_PI) {
		angleDiff = (2 * M_PI) - angleDiff;
	}

	return angleDiff <= Math::deg2rad(fovDegrees * 0.5f);
}

}
}
}
}
}
}
}
}

#endif // AIPERCEPTION_H_
