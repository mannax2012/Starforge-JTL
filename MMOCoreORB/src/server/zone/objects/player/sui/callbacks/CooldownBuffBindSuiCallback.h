/*
 * CooldownBuffBindSuiCallback.h
 *
 *  Created on: 5/1/2026
 */

#ifndef COOLDOWNBUFFBINDSUICALLBACK_H_
#define COOLDOWNBUFFBINDSUICALLBACK_H_

#include "server/zone/objects/player/sui/SuiCallback.h"
#include "server/zone/objects/tangible/components/CooldownBuffObjectMenuComponent.h"

class CooldownBuffBindSuiCallback : public SuiCallback {
public:
	CooldownBuffBindSuiCallback(ZoneServer* server)
		: SuiCallback(server) {
	}

	void run(CreatureObject* player, SuiBox* suiBox, uint32 eventIndex, Vector<UnicodeString>* args) {
		bool cancelPressed = (eventIndex == 1);

		if (!suiBox->isMessageBox() || player == nullptr || cancelPressed)
			return;

		if (player->isDead() || player->isIncapacitated())
			return;

		ManagedReference<SceneObject*> sceneObject = suiBox->getUsingObject().get();
		if (sceneObject == nullptr)
			return;

		CooldownBuffObjectMenuComponent::applyBuff(sceneObject, player);
	}
};

#endif /* COOLDOWNBUFFBINDSUICALLBACK_H_ */
