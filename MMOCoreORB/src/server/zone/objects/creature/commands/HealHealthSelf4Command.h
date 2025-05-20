/*
				Copyright <SWGEmu>
		See file COPYING for copying conditions.*/

#ifndef HEALHEALTHSELF4COMMAND_H_
#define HEALHEALTHSELF4COMMAND_H_

#include "server/zone/objects/scene/SceneObject.h"
#include "ForceHealQueueCommand.h"

class HealHealthSelf4Command : public ForceHealQueueCommand {
public:
	HealHealthSelf4Command(const String& name, ZoneProcessServer* server) : ForceHealQueueCommand(name, server) {}
};

#endif //HEALHEALTHSELF4COMMAND_H_
