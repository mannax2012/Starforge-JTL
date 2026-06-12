tusken_princeling = Creature:new {
	customName = "Tusken Princeling",
	socialGroup = "tusken_raider",
	faction = "tusken_raider",
	mobType = MOB_NPC,
	level = 153,
	chanceHit = 8.5,
	damageMin = 895,
	damageMax = 1500,
	baseXp = 14504,
	baseHAM = 81000,
	baseHAMmax = 99000,
	armor = 2,
	resists = {160,165,120,180,75,130,135,160,-1},
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
	creatureBitmask = PACK + KILLER + STALKER,
	optionsBitmask = AIENABLED,
	diet = HERBIVORE,

	templates = {"object/mobile/tusken_raider.iff"},
	scale = 1.2,
	lootGroups = {
		{
			groups = {
				{group = "tusken_raider_tier_4", chance = 10000000}
			}
		}
	},

	primaryWeapon = "tusken_ranged",
	secondaryWeapon = "tusken_melee",
	conversationTemplate = "",

	primaryAttacks = merge(marksmanmaster,riflemanmaster),
	secondaryAttacks = merge(brawlermaster,fencermaster)
}

CreatureTemplates:addCreatureTemplate(tusken_princeling, "tusken_princeling")
