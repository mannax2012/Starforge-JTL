/*
				Copyright <SWGEmu>
		See file COPYING for copying conditions. */

#ifndef AVOIDINCAPACITATIONCOMMAND_H_
#define AVOIDINCAPACITATIONCOMMAND_H_

#include "JediQueueCommand.h"

class AvoidIncapacitationCommand : public JediQueueCommand {
public:

	AvoidIncapacitationCommand(const String& name, ZoneProcessServer* server)
: JediQueueCommand(name, server) {
		 buffCRC = BuffCRC::JEDI_AVOID_INCAPACITATION;
		 skillMods.put("avoid_incapacitation", 50);
	}

	int doQueueCommand(CreatureObject* creature, const uint64& target, const UnicodeString& arguments) const {
		int res = doCommonJediSelfChecks(creature);

		if (res != SUCCESS)
			return res;

		if (creature->hasBuff(buffCRC))
			return NOSTACKJEDIBUFF;

		if (!checkCooldown(creature))
			return GENERALERROR;

		return doBuff(creature);
	}

};

#endif //AVOIDINCAPACITATIONCOMMAND_H_
