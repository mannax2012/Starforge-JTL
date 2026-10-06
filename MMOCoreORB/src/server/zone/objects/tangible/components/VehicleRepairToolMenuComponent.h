/*
 * VehicleRepairToolMenuComponent.h
 */

#ifndef VEHICLEREPAIRTOOLMENUCOMPONENT_H_
#define VEHICLEREPAIRTOOLMENUCOMPONENT_H_

#include "TangibleObjectMenuComponent.h"

class VehicleRepairToolMenuComponent : public TangibleObjectMenuComponent {
public:
	void fillObjectMenuResponse(SceneObject* sceneObject, ObjectMenuResponse* menuResponse, CreatureObject* player) const override;

	int handleObjectMenuSelect(SceneObject* sceneObject, CreatureObject* player, byte selectedID) const override;
};

#endif /* VEHICLEREPAIRTOOLMENUCOMPONENT_H_ */
