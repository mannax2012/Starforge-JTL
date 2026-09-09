death_watch_siege_captain = Creature:new {
	objectName = "",
	customName = "Varek Voss (Death Watch Siege Captain)",
	socialGroup = "death_watch",
	mobType = MOB_NPC,
	faction = "",
	level = 336,
	chanceHit = 30,
	damageMin = 2270,
	damageMax = 4250,
	baseXp = 28549,
	baseHAM = 410000,
	baseHAMmax = 501000,
	armor = 3,
	resists = {80,80,90,80,45,45,90,70,-1},
	meatType = "",
	meatAmount = 0,
	hideType = "",
	hideAmount = 0,
	boneType = "",
	boneAmount = 0,
	milk = 0,
	tamingChance = 0,
	ferocity = 0,
	pvpBitmask = AGGRESSIVE + ATTACKABLE + ENEMY,
	creatureBitmask = KILLER,
	optionsBitmask = AIENABLED,
	diet = HERBIVORE,
	scale = 1.15,

	templates = {"object/mobile/dressed_death_watch_gold.iff"},
	lootGroups = {
		-- Standard DWB rewards, plus independent material and schematic rolls.
		{
			groups = {
				{group = "death_watch_bunker_commoners", chance = 6500000},
				{group = "death_watch_bunker_lieutenants", chance = 3500000}
			},
			lootChance = 10000000
		},
		{
			groups = {{group = "death_watch_bunker_ingredient_binary", chance = 10000000}},
			lootChance = 3500000
		},
		{
			groups = {{group = "death_watch_bunker_ingredient_protective", chance = 10000000}},
			lootChance = 3500000
		},
		{
			groups = {{group = "mando_armor_loot", chance = 10000000}},
			lootChance = 2500000
		}
	},

	-- Primary and secondary weapon should be different types (rifle/carbine, carbine/pistol, rifle/unarmed, etc)
	-- Unarmed should be put on secondary unless the mobile doesn't use weapons, in which case "unarmed" should be put primary and "none" as secondary
	primaryWeapon = "dark_trooper_weapons",
	secondaryWeapon = "none",
	conversationTemplate = "",
	thrownWeapon = "thrown_weapons",

	-- primaryAttacks and secondaryAttacks should be separate skill groups specific to the weapon type listed in primaryWeapon and secondaryWeapon
	-- Use merge() to merge groups in creatureskills.lua together. If a weapon is set to "none", set the attacks variable to empty brackets
	primaryAttacks = merge(riflemanmaster,fencermaster,marksmanmaster,brawlermaster),
	secondaryAttacks = { }
}

CreatureTemplates:addCreatureTemplate(death_watch_siege_captain, "death_watch_siege_captain")
