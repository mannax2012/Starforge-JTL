/*
				Copyright <SWGEmu>
		See file COPYING for copying conditions.*/

#ifndef MELEEBHCROSSCHECKCOMMAND_H_
#define MELEEBHCROSSCHECKCOMMAND_H_

#include "CombatQueueCommand.h"

class MeleeBHCrossCheckCommand : public CombatQueueCommand {
public:

	MeleeBHCrossCheckCommand(const String& name, ZoneProcessServer* server)
		: CombatQueueCommand(name, server) {
	}

	int doQueueCommand(CreatureObject* creature, const uint64& target, const UnicodeString& arguments) const {

		if (!checkStateMask(creature))
			return INVALIDSTATE;

		if (!checkInvalidLocomotions(creature))
			return INVALIDLOCOMOTION;

		return doCombatAction(creature, target);
	}

};

#endif //MELEEBHCROSSCHECKCOMMAND_H_
