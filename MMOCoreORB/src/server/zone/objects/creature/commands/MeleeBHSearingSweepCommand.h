/*
				Copyright <SWGEmu>
		See file COPYING for copying conditions.*/

#ifndef MELEEBHSEARINGSWEEPCOMMAND_H_
#define MELEEBHSEARINGSWEEPCOMMAND_H_

#include "CombatQueueCommand.h"

class MeleeBHSearingSweepCommand : public CombatQueueCommand {
public:

	MeleeBHSearingSweepCommand(const String& name, ZoneProcessServer* server)
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

#endif //MELEEBHSEARINGSWEEPCOMMAND_H_
