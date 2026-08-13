global_imperial_knight_trial_officer_camp_imperial_large_theater = Lair:new {
	mobiles = {
		{"storm_commando", 5},
		{"stormtrooper", 5}
	},
	bossMobiles = {{"elite_novatrooper_commander", 2}},
	spawnLimit = 15,
	buildingsVeryEasy = {"object/building/poi/anywhere_imperial_base_large_1.iff"},
	buildingsEasy = {"object/building/poi/anywhere_imperial_base_large_1.iff"},
	buildingsMedium = {"object/building/poi/anywhere_imperial_base_large_1.iff"},
	buildingsHard = {"object/building/poi/anywhere_imperial_base_large_1.iff"},
	buildingsVeryHard = {"object/building/poi/anywhere_imperial_base_large_1.iff"},
	missionBuilding = "object/tangible/lair/base/objective_banner_imperial.iff",
	mobType = "npc",
	buildingType = "theater",
	faction = "imperial"
}

addLairTemplate("global_imperial_knight_trial_officer_camp_imperial_large_theater", global_imperial_knight_trial_officer_camp_imperial_large_theater)
