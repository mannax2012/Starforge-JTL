/*
				Copyright <SWGEmu>
		See file COPYING for copying conditions. */

#ifndef HEALOTHER2COMMAND_H_
#define HEALOTHER2COMMAND_H_

#include "server/zone/objects/scene/SceneObject.h"
#include "server/zone/packets/object/CombatAction.h"
#include "ForceHealQueueCommand.h"

class HealOther2Command : public ForceHealQueueCommand {
public:
	HealOther2Command(const String& name, ZoneProcessServer* server)
		: ForceHealQueueCommand(name, server) {
	}
};

#endif /* HEALAOTHER2COMMAND_H_ */
