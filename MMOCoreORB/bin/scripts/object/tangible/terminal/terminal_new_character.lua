--NOTES ABOUT CHARACTER BUILDER TERMINAL ITEM LIST FORMAT
---------------------------------------------------------
--The item list is an infinitely deep node tree system.
--To create a sub menu, use the following format:
--"Name of the sub menu", {Menu items contained in brackets}
--To create an item that is selectable, use the following format (within brackets of a submenu):
--"Name of the item", "Path to the server or client template."
--Be sure to pay attention to commas.

object_tangible_terminal_terminal_new_character = object_tangible_terminal_shared_terminal_new_character:new {
	gameObjectType = 16400,

	maxCondition = 0,

	templateType = CHARACTERBUILDERTERMINAL,

	itemList = {
		"Enhance Character", "enhance_character_new",
		"Learn Skills",
		{
				"Novice Artisan", "crafting_artisan_novice",
				"Novice Brawler", "combat_brawler_novice",
				"Novice Entertainer", "social_entertainer_novice",
				"Novice Marksman", "combat_marksman_novice",
				"Novice Medic", "science_medic_novice",
				"Novice Politician", "social_politician_novice",
				"Novice Scout", "outdoors_scout_novice",

				"Learn Languages", "language",
		},
		"Items",
		{
			"Armor",
			{
				"Humanoid Armor",
				{
					"Composite Armor",
					{
					"Composite Left Bicep", "object/tangible/wearables/armor/composite/armor_composite_bicep_l.iff",
					"Composite Right Bicep", "object/tangible/wearables/armor/composite/armor_composite_bicep_r.iff",
					"Composite Boots", "object/tangible/wearables/armor/composite/armor_composite_boots.iff",
					"Composite Left Bracer", "object/tangible/wearables/armor/composite/armor_composite_bracer_l.iff",
					"Composite Right Bracer", "object/tangible/wearables/armor/composite/armor_composite_bracer_r.iff",
					"Composite Chest Plate", "object/tangible/wearables/armor/composite/armor_composite_chest_plate.iff",
					"Composite Gloves", "object/tangible/wearables/armor/composite/armor_composite_gloves.iff",
					"Composite Helmet", "object/tangible/wearables/armor/composite/armor_composite_helmet.iff",
					"Composite Leggings", "object/tangible/wearables/armor/composite/armor_composite_leggings.iff"
					},
				},
				"Ithorian Armor",
				{
					"Ithorian Sentinel",
					{
						"Ithorian Sentinel Left Bicep", "object/tangible/wearables/armor/ithorian_sentinel/ith_armor_s03_bicep_l.iff",
						"Ithorian Sentinel Right Bicep", "object/tangible/wearables/armor/ithorian_sentinel/ith_armor_s03_bicep_r.iff",
						"Ithorian Sentinel Boots", "object/tangible/wearables/armor/ithorian_sentinel/ith_armor_s03_boots.iff",
						"Ithorian Sentinel Left Bracer", "object/tangible/wearables/armor/ithorian_sentinel/ith_armor_s03_bracer_l.iff",
						"Ithorian Sentinel Right Bracer", "object/tangible/wearables/armor/ithorian_sentinel/ith_armor_s03_bracer_r.iff",
						"Ithorian Sentinel Chest Plate", "object/tangible/wearables/armor/ithorian_sentinel/ith_armor_s03_chest_plate.iff",
						"Ithorian Sentinel Gloves", "object/tangible/wearables/armor/ithorian_sentinel/ith_armor_s03_gloves.iff",
						"Ithorian Sentinel Helmet", "object/tangible/wearables/armor/ithorian_sentinel/ith_armor_s03_helmet.iff",
						"Ithorian Sentinel Leggings", "object/tangible/wearables/armor/ithorian_sentinel/ith_armor_s03_leggings.iff"
					}
				},
				"Wookiee Armor",
				{
					"Kashyyykian Hunting",
					{
						"Kashyyykian Hunting Left Bracer", "object/tangible/wearables/armor/kashyyykian_hunting/armor_kashyyykian_hunting_bracer_l.iff",
						"Kashyyykian Hunting Right Bracer", "object/tangible/wearables/armor/kashyyykian_hunting/armor_kashyyykian_hunting_bracer_r.iff",
						"Kashyyykian Hunting Chest Plate", "object/tangible/wearables/armor/kashyyykian_hunting/armor_kashyyykian_hunting_chest_plate.iff",
						"Kashyyykian Hunting Leggings", "object/tangible/wearables/armor/kashyyykian_hunting/armor_kashyyykian_hunting_leggings.iff"
					}
				},
			},
			"Deeds",
			{
				"Vehicle Deeds",
				{
					"Speederbike", "object/tangible/deed/vehicle_deed/speederbike_deed.iff",
				},
			},

			"Tools",
			{
				"Crafting Tools",
				{
					"Clothing and Armor Crafting Tool", "object/tangible/crafting/station/clothing_tool.iff",
					"Food and Chemical Crafting Tool", "object/tangible/crafting/station/food_tool.iff",
					"Generic Crafting Tool", "object/tangible/crafting/station/generic_tool.iff",
					"Lightsaber Crafting Toolkit", "object/tangible/crafting/station/jedi_tool.iff",
					"Starship Crafting Tool", "object/tangible/crafting/station/space_tool.iff",
					"Structure and Furniture Crafting Tool", "object/tangible/crafting/station/structure_tool.iff",
					"Weapon, Droid, and General Item Crafting Tool", "object/tangible/crafting/station/weapon_tool.iff"
				},
				"Crafting Stations",
				{
					"Clothing Crafting Station", "object/tangible/crafting/station/clothing_station.iff",
					"Food Crafting Station", "object/tangible/crafting/station/food_station.iff",
					"Starship Crafting Station", "object/tangible/crafting/station/space_station.iff",
					"Structure Crafting Station", "object/tangible/crafting/station/structure_station.iff",
					"Weapon Crafting Station", "object/tangible/crafting/station/weapon_station.iff"
				},
				"Survey Tools",
				{
					"Gas Survey Tool", "object/tangible/survey_tool/survey_tool_gas.iff",
					--"Inorganic Survey Tool", "oobject/tangible/survey_tool/survey_tool_inorganic.iff",
					"Chemical Survey Tool", "object/tangible/survey_tool/survey_tool_liquid.iff",
					"Flora Survey Tool", "object/tangible/survey_tool/survey_tool_lumber.iff",
					"Mineral Survey Tool", "object/tangible/survey_tool/survey_tool_mineral.iff",
					"Moisture Survey Tool", "object/tangible/survey_tool/survey_tool_moisture.iff",
					--"Organic Survey Tool", "object/tangible/survey_tool/survey_tool_organic.iff",
					"Solar Survey Tool", "object/tangible/survey_tool/survey_tool_solar.iff",
					"Wind Survey Tool", "object/tangible/survey_tool/survey_tool_wind.iff"
				}
			},

			"Weapons",
			{
				"Carbines",
				{
							"CDEF Carbine", "object/weapon/ranged/carbine/carbine_cdef.iff",
							"DH17 Carbine", "object/weapon/ranged/carbine/carbine_dh17.iff",
				},
				"One-handed",
				{
							"Sword", "object/weapon/melee/sword/sword_01.iff",
							"Curved Sword", "object/weapon/melee/sword/sword_02.iff"
				},
				"Pistols",
				{
							"CDEF Pistol", "object/weapon/ranged/pistol/pistol_cdef.iff",
							"D18 Pistol", "object/weapon/ranged/pistol/pistol_d18.iff"
				},
				"Polearms",
				{
							"Lance", "object/weapon/melee/polearm/lance_controllerfp.iff",
							"Vibro Lance", "object/weapon/melee/polearm/lance_vibrolance.iff"
				},
				"Rifles",
				{
							"Bowcaster", "object/weapon/ranged/rifle/rifle_bowcaster.iff",
							"CDEF Rifle", "object/weapon/ranged/rifle/rifle_cdef.iff",
							"DLT20 Rifle", "object/weapon/ranged/rifle/rifle_dlt20.iff"

				},
				"Two-handed",
				{
						"Two-handed Curved Sword", "object/weapon/melee/2h_sword/2h_sword_katana.iff",
						"Power Hammer", "object/weapon/melee/2h_sword/2h_sword_maul.iff"

				},
				"Unarmed",
				{
					"Vibro Knuckler", "object/weapon/melee/special/vibroknuckler.iff"
				}
			},
		
		}
	}
}
ObjectTemplates:addTemplate(object_tangible_terminal_terminal_new_character, "object/tangible/terminal/terminal_new_character.iff")
