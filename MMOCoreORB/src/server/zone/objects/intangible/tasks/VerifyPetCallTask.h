#ifndef VERIFYPETCALLTASK_H_
#define VERIFYPETCALLTASK_H_

#include "server/zone/objects/creature/CreatureObject.h"
#include "server/zone/objects/creature/ai/AiAgent.h"
#include "server/zone/objects/intangible/PetControlDevice.h"
#include "server/zone/objects/player/PlayerObject.h"
#include "server/zone/managers/creature/PetManager.h"
#include <system/lang/StringBuffer.h>

class VerifyPetCallTask : public Task, public Logger {
	ManagedWeakReference<CreatureObject*> playerRef;
	ManagedWeakReference<AiAgent*> petRef;
	ManagedWeakReference<PetControlDevice*> deviceRef;
	float expectedHomeX = 0.f;
	float expectedHomeZ = 0.f;
	float expectedHomeY = 0.f;
	uint64 expectedCellID = 0;

public:
	VerifyPetCallTask(CreatureObject* player, AiAgent* pet, PetControlDevice* device, float x, float z, float y, CellObject* cell)
			: playerRef(player), petRef(pet), deviceRef(device), expectedHomeX(x), expectedHomeZ(z), expectedHomeY(y) {
		expectedCellID = cell != nullptr ? cell->getObjectID() : 0;
		setLoggingName("VerifyPetCallTask");
	}

	void run() {
		ManagedReference<CreatureObject*> player = playerRef.get();
		ManagedReference<AiAgent*> pet = petRef.get();
		ManagedReference<PetControlDevice*> device = deviceRef.get();

		if (player == nullptr || pet == nullptr || device == nullptr) {
			return;
		}

		Locker locker(player);
		Locker clocker(pet, player);
		Locker dlocker(device, pet);

		if (player->isDead() || player->isInCombat() || pet->isDead() || pet->isInCombat()) {
			return;
		}

		if (device->getStatus() != 1 || device->getLastCommand() != PetManager::FOLLOW) {
			return;
		}

		if (pet->getLinkedCreature().get() != player) {
			return;
		}

		ManagedReference<PlayerObject*> ghost = player->getPlayerObject();

		if (ghost == nullptr || !ghost->hasActivePet(pet)) {
			return;
		}

		ManagedReference<SceneObject*> follow = pet->getFollowObject().get();
		unsigned int movementState = pet->getMovementState();

		if (follow.get() == player && movementState == AiAgent::FOLLOWING) {
			return;
		}

		PatrolPoint* home = pet->getHomeLocation();
		uint64 followID = follow != nullptr ? follow->getObjectID() : 0;
		uint64 homeCellID = (home != nullptr && home->getCell() != nullptr) ? home->getCell()->getObjectID() : 0;
		String zoneName = player->getZone() != nullptr ? player->getZone()->getZoneName() : "unknown";

		StringBuffer report;
		report << "PETCALL-VERIFY"
			   << " pet=" << pet->getObjectID()
			   << " dev=" << device->getObjectID()
			   << " owner=" << player->getObjectID()
			   << " state=" << movementState
			   << " follow=" << followID
			   << " last=" << device->getLastCommand()
			   << " status=" << device->getStatus()
			   << " zone=" << zoneName
			   << " homeX=" << (home != nullptr ? home->getPositionX() : 0.f)
			   << " homeZ=" << (home != nullptr ? home->getPositionZ() : 0.f)
			   << " homeY=" << (home != nullptr ? home->getPositionY() : 0.f)
			   << " homeCell=" << homeCellID
			   << " expX=" << expectedHomeX
			   << " expZ=" << expectedHomeZ
			   << " expY=" << expectedHomeY
			   << " expCell=" << expectedCellID;

		warning() << report.toString();

		StringBuffer message;
		message << "Pet call verification failed. Please send this to staff: " << report.toString();
		player->sendSystemMessage(message.toString());
	}
};

#endif /* VERIFYPETCALLTASK_H_ */
