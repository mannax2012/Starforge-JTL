/*
				Copyright <SWGEmu>
		See file COPYING for copying conditions. */

#ifndef HEALOTHER1COMMAND_H_
#define HEALOTHER1COMMAND_H_

#include "server/zone/objects/scene/SceneObject.h"
#include "server/zone/packets/object/CombatAction.h"
#include "ForceHealQueueCommand.h"

class HealOther1Command : public ForceHealQueueCommand {
public:
	HealOther1Command(const String& name, ZoneProcessServer* server)
		: ForceHealQueueCommand(name, server) {
	}
};

#endif /* HEALOTHER1COMMAND_H_ */
