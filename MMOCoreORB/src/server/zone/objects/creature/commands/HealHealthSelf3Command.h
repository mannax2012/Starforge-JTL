/*
				Copyright <SWGEmu>
		See file COPYING for copying conditions.*/

#ifndef HEALHEALTHSELF3COMMAND_H_
#define HEALHEALTHSELF3COMMAND_H_

#include "server/zone/objects/scene/SceneObject.h"
#include "ForceHealQueueCommand.h"

class HealHealthSelf3Command : public ForceHealQueueCommand {
public:
	HealHealthSelf3Command(const String& name, ZoneProcessServer* server) : ForceHealQueueCommand(name, server) {}
};

#endif //HEALHEALTHSELF3COMMAND_H_
