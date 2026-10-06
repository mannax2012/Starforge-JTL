/*
 * SEAToolMenuComponent.h
 */

#ifndef SEATOOLMENUCOMPONENT_H_
#define SEATOOLMENUCOMPONENT_H_

#include "TangibleObjectMenuComponent.h"

class SEAToolMenuComponent : public TangibleObjectMenuComponent {
public:
	void fillObjectMenuResponse(SceneObject* sceneObject, ObjectMenuResponse* menuResponse, CreatureObject* player) const override;

	int handleObjectMenuSelect(SceneObject* sceneObject, CreatureObject* player, byte selectedID) const override;
};

#endif /* SEATOOLMENUCOMPONENT_H_ */
