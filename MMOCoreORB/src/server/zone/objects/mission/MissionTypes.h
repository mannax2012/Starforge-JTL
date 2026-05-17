#ifndef MISSIONTYPES_H_
#define MISSIONTYPES_H_


namespace MissionTypes {
	enum {
		DESTROY = 0x74EF9BE3, // generic
		BOUNTY = 0x2904F372, // bounty
		BOUNTY_NPC = 0xD437ABCA, // npc_bounty
		BOUNTY_PLAYER = 0x928A585B, // player_bounty
		DELIVER = 0xE5C27EC6, // generic
		CRAFTING = 0xE5F6DC59, // artisan
		ESCORT = 0x682B871E, // ???
		ESCORT2ME = 0x58F59884, // ???
		ESCORTTOCREATOR = 0x5E4C7163, // ???
		HUNTING = 0x906999A2, // scout
		MUSICIAN = 0x4AD93196, // entertainer
		DANCER = 0xF067B37, // entertainer
		RECON = 0x34F4C2E4, // scout
		SURVEY = 0x19C9FAC1 // artisan
	};

	inline bool isBountyType(unsigned int missionType) {
		return missionType == BOUNTY || missionType == BOUNTY_NPC || missionType == BOUNTY_PLAYER;
	}

	inline bool isPlayerBountyType(unsigned int missionType) {
		return missionType == BOUNTY_PLAYER;
	}

	inline bool isNpcBountyType(unsigned int missionType) {
		return missionType == BOUNTY || missionType == BOUNTY_NPC;
	}
}

#endif
