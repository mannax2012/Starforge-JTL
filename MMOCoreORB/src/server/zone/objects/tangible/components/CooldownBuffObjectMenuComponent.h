/*
 * CooldownBuffObjectMenuComponent.h
 *
 *  Created on: 5/1/2026
 */

#ifndef COOLDOWNBUFFOBJECTMENUCOMPONENT_H_
#define COOLDOWNBUFFOBJECTMENUCOMPONENT_H_

#include "TangibleObjectMenuComponent.h"

class CooldownBuffObjectMenuComponent : public TangibleObjectMenuComponent {
public:
	virtual void fillObjectMenuResponse(SceneObject* sceneObject, ObjectMenuResponse* menuResponse, CreatureObject* player) const;
	virtual int handleObjectMenuSelect(SceneObject* sceneObject, CreatureObject* player, byte selectedID) const;

	static int applyBuff(SceneObject* sceneObject, CreatureObject* player);
	static String getCooldownKey(SceneObject* sceneObject);
	static String getActiveBuffKey(SceneObject* sceneObject);
	static String formatTime(uint64 milliseconds);
	static String getOwnerIdKey();
	static String getOwnerNameKey();
};

#endif /* COOLDOWNBUFFOBJECTMENUCOMPONENT_H_ */
