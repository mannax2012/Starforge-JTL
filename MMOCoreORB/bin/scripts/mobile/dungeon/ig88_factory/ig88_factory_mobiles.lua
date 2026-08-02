local ig88FactoryStandardLoot = {
	{
		groups = {
			{ group = "weapons_all", chance = 2000000 },
			{ group = "junk", chance = 3000000 },
			{ group = "clothing_attachments", chance = 1500000 },
			{ group = "armor_attachments", chance = 1500000 },
			{ group = "droid_servo_motor", chance = 1000000 },
			{ group = "fragmented_targeting_computer", chance = 1000000 },
		},
		lootChance = 4200000,
	},
}

local ig88FactoryBonusLoot = {
	{
		groups = {
			{group = "lewt_chest_common_drop",  		chance = 1000000},
			{group = "lewt_chest_rare_drop",    		chance = 1000000},
			{group = "droid_servo_motor",    	chance = 4000000},
			{ group = "fragmented_targeting_computer", chance = 4000000 },		
		},
		lootChance = 10000,
	},
}

local ig88FactoryBossLoot = {
	{
		groups = {
			{ group = "power_crystals", chance = 2000000 },
			{ group = "weapons_all", chance = 2000000 },
			{ group = "clothing_attachments", chance = 1500000 },
			{ group = "armor_attachments", chance = 1500000 },
			{ group = "droid_servo_motor", chance = 1500000 },
			{ group = "fragmented_targeting_computer", chance = 1500000 },
		},
		lootChance = 10000000,
	},
	{
		groups = {
			{ group = "lewt_chest_common_drop", chance = 2000000 },
			{ group = "clothing_attachments", chance = 1500000 },
			{ group = "armor_attachments", chance = 1500000 },
			{ group = "droid_servo_motor", chance = 2000000 },
			{ group = "resource_deed_boss", chance = 1000000 },
			{ group = "lewt_chest_rare_drop", chance = 1000000 },
			{ group = "fragmented_targeting_computer", chance = 200000 },
		},
		lootChance = 10000000,
	},
	{
		groups = {
			{group = "ig88_buff_head", chance = 10000000},
		},
		lootChance = 100000,
	},
}

ig88_factory_mouse_droid = Creature:new {
	customName = "@mob/creature_names:mouse_droid",
	socialGroup = "ig88factory",
	faction = "ig88factory",
	mobType = MOB_DROID,
	level = 10,
	chanceHit = 0.3,
	damageMin = 1,
	damageMax = 1,
	baseXp = 100,
	baseHAM = 8000,
	baseHAMmax = 10000,
	armor = 0,
	resists = {0,0,0,0,0,0,0,-1,-1},
	meatType = "",
	meatAmount = 0,
	hideType = "",
	hideAmount = 0,
	boneType = "",
	boneAmount = 0,
	milk = 0,
	tamingChance = 0,
	ferocity = 0,
	pvpBitmask = NONE,
	creatureBitmask = NONE,
	optionsBitmask = AIENABLED,
	diet = NONE,

	templates = {"object/mobile/mouse_droid.iff"},
	lootGroups = {},
	primaryWeapon = "unarmed",
	secondaryWeapon = "none",
	conversationTemplate = "",
	primaryAttacks = {},
	secondaryAttacks = {}
}

CreatureTemplates:addCreatureTemplate(ig88_factory_mouse_droid, "ig88_factory_mouse_droid")

ig88_factory_bomb_droid = Creature:new {
	customName = "Bomb Mouse Droid",
	socialGroup = "ig88factory",
	faction = "ig88factory",
	mobType = MOB_DROID,
	level = 120,
	chanceHit = 1.5,
	damageMin = 1,
	damageMax = 1,
	baseXp = 1200,
	baseHAM = 30000,
	baseHAMmax = 36000,
	armor = 1,
	resists = {40,40,50,50,50,25,25,25,-1},
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
	creatureBitmask = PACK,
	optionsBitmask = AIENABLED,
	diet = NONE,

	templates = {"object/mobile/mouse_droid.iff"},
	lootGroups = {},
	primaryWeapon = "unarmed",
	secondaryWeapon = "none",
	conversationTemplate = "",
	primaryAttacks = {},
	secondaryAttacks = {}
}

CreatureTemplates:addCreatureTemplate(ig88_factory_bomb_droid, "ig88_factory_bomb_droid")

ig88_factory_battle_droid = Creature:new {
	customName = "Factory Battle Droid",
	socialGroup = "ig88factory",
	faction = "ig88factory",
	mobType = MOB_ANDROID,
	level = 230,
	chanceHit = 4.0,
	damageMin = 935,
	damageMax = 1485,
	baseXp = 12000,
	baseHAM = 104000,
	baseHAMmax = 136000,
	armor = 2,
	resists = {70,70,90,70,80,20,35,70,-1},
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
	creatureBitmask = PACK + KILLER + NOINTIMIDATE,
	optionsBitmask = AIENABLED,
	diet = NONE,
	scale = 1.15,

	templates = {
		"object/mobile/death_watch_battle_droid.iff",
		"object/mobile/death_watch_battle_droid_02.iff",
		"object/mobile/death_watch_battle_droid_03.iff"
	},
		lootGroups = {
		ig88FactoryStandardLoot[1],		
	},
	primaryWeapon = "battle_droid_weapons",
	secondaryWeapon = "unarmed",
	conversationTemplate = "",
	primaryAttacks = merge(pistoleermaster, carbineermaster, marksmanmaster),
	secondaryAttacks = {}
}

CreatureTemplates:addCreatureTemplate(ig88_factory_battle_droid, "ig88_factory_battle_droid")

ig88_factory_droideka = Creature:new {
	customName = "Factory Droideka",
	socialGroup = "ig88factory",
	faction = "ig88factory",
	mobType = MOB_DROID,
	level = 260,
	chanceHit = 10.0,
	damageMin = 1485,
	damageMax = 2090,
	baseXp = 18000,
	baseHAM = 300000,
	baseHAMmax = 380000,
	armor = 2,
	resists = {85,95,95,80,85,45,55,70,-1},
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
	creatureBitmask = PACK + KILLER + NOINTIMIDATE,
	optionsBitmask = AIENABLED,
	diet = NONE,

	templates = {"object/mobile/droideka.iff"},
		lootGroups = {
		ig88FactoryStandardLoot[1],	
	},
	defaultAttack = "attack",
	defaultWeapon = "object/weapon/ranged/droid/droid_droideka_ranged.iff"
}

CreatureTemplates:addCreatureTemplate(ig88_factory_droideka, "ig88_factory_droideka")

ig88_factory_flame_droid = Creature:new {
	customName = "Heavy Flamethrower Battle Droid",
	socialGroup = "ig88factory",
	faction = "ig88factory",
	mobType = MOB_DROID,
	level = 335,
	chanceHit = 14.0,
	damageMin = 1870,
	damageMax = 2860,
	baseXp = 22000,
	baseHAM = 480000,
	baseHAMmax = 600000,
	armor = 2,
	resists = {90,95,100,90,90,45,55,85,-1},
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
	creatureBitmask = PACK + KILLER + NOINTIMIDATE,
	optionsBitmask = AIENABLED,
	diet = NONE,
	scale = 1.7,

	templates = {
		"object/mobile/death_watch_s_battle_droid.iff",
		"object/mobile/death_watch_s_battle_droid_02.iff",
		"object/mobile/death_watch_s_battle_droid_03.iff"
	},
	lootGroups = {
		ig88FactoryStandardLoot[1],
		ig88FactoryBossLoot[1],
		ig88FactoryBonusLoot[1],			
	},
	primaryWeapon = "commando_ranged",
	secondaryWeapon = "battle_droid_weapons",
	conversationTemplate = "",
	primaryAttacks = merge(commandomaster, marksmanmaster),
	secondaryAttacks = merge(carbineermaster, pistoleermaster)
}

CreatureTemplates:addCreatureTemplate(ig88_factory_flame_droid, "ig88_factory_flame_droid")

ig88_factory_ig88 = Creature:new {
	customName = "@mob/creature_names:ig_88",
	socialGroup = "ig88factory",
	faction = "ig88factory",
	mobType = MOB_DROID,
	level = 420,
	chanceHit = 18.0,
	damageMin = 2420,
	damageMax = 3740,
	baseXp = 26000,
	baseHAM = 840000,
	baseHAMmax = 1000000,
	armor = 3,
	resists = {90,95,95,90,90,70,70,85,-1},
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
	creatureBitmask = PACK + KILLER + NOINTIMIDATE,
	optionsBitmask = AIENABLED,
	diet = NONE,
	scale = 1.35,

	templates = {"object/mobile/ig_88.iff"},
	lootGroups = {
		ig88FactoryStandardLoot[1],
		ig88FactoryBossLoot[1],
		ig88FactoryBossLoot[2],
		ig88FactoryBossLoot[3],
		ig88FactoryBonusLoot[1],			
	},
	primaryWeapon = "general_carbine",
	secondaryWeapon = "general_pistol",
	conversationTemplate = "",
	primaryAttacks = merge(bountyhuntermaster, marksmanmaster, carbineermaster),
	secondaryAttacks = merge(bountyhuntermaster, marksmanmaster, pistoleermaster)
}

CreatureTemplates:addCreatureTemplate(ig88_factory_ig88, "ig88_factory_ig88")
