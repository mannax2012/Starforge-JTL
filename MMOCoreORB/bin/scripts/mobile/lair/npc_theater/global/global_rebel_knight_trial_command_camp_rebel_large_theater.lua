global_rebel_knight_trial_command_camp_rebel_large_theater = Lair:new {
	mobiles = {
		{"rebel_high_general", 2},
		{"rebel_surface_marshal", 2},
		{"rebel_general", 2},
		{"rebel_commando", 4},
		{"rebel_trooper", 3}
	},
	spawnLimit = 15,
	buildingsVeryEasy = {"object/building/poi/anywhere_rebel_base_large_1.iff"},
	buildingsEasy = {"object/building/poi/anywhere_rebel_base_large_1.iff"},
	buildingsMedium = {"object/building/poi/anywhere_rebel_base_large_1.iff"},
	buildingsHard = {"object/building/poi/anywhere_rebel_base_large_1.iff"},
	buildingsVeryHard = {"object/building/poi/anywhere_rebel_base_large_1.iff"},
	missionBuilding = "object/tangible/lair/base/objective_banner_rebel.iff",
	mobType = "npc",
	buildingType = "theater",
	faction = "rebel"
}

addLairTemplate("global_rebel_knight_trial_command_camp_rebel_large_theater", global_rebel_knight_trial_command_camp_rebel_large_theater)
