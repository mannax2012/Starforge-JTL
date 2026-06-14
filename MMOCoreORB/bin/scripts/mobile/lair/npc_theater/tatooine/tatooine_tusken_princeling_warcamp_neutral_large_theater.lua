tatooine_tusken_princeling_warcamp_neutral_large_theater = Lair:new {
	mobiles = {
		{"tusken_berserker",2},
		{"tusken_blood_champion",2},
		{"tusken_elite_guard",2},
		{"tusken_carnage_champion",1},
		{"tusken_witch_doctor",1},
	},
	bossMobiles = {
		{"tusken_princeling",1},
	},
	spawnLimit = 12,
	buildingsVeryEasy = {"object/building/poi/anywhere_misc_camp_small_1.iff","object/building/poi/anywhere_misc_camp_small_1.iff"},
	buildingsEasy = {"object/building/poi/anywhere_misc_camp_small_1.iff","object/building/poi/anywhere_misc_camp_small_1.iff"},
	buildingsMedium = {"object/building/poi/anywhere_misc_camp_small_1.iff","object/building/poi/anywhere_misc_camp_small_1.iff"},
	buildingsHard = {"object/building/poi/anywhere_misc_camp_small_1.iff","object/building/poi/anywhere_misc_camp_small_1.iff"},
	buildingsVeryHard = {"object/building/poi/anywhere_misc_camp_small_1.iff","object/building/poi/anywhere_misc_camp_small_1.iff"},
	missionBuilding = "object/tangible/lair/base/objective_power_transformer.iff",
	mobType = "npc",
	buildingType = "theater"
}

addLairTemplate("tatooine_tusken_princeling_warcamp_neutral_large_theater", tatooine_tusken_princeling_warcamp_neutral_large_theater)
