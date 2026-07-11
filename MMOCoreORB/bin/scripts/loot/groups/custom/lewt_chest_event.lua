-- Temporary event chest table. Reuse rare rewards until event-specific rewards are finalized.
lewt_chest_event = {
	description = "",
	minimumLevel = 0,
	maximumLevel = 0,
	lootItems = {
		{itemTemplate = "lewt_chest_common", weight = 2500000},
		{itemTemplate = "krayt_dragon_tissue_uncommon", weight = 2500000},
		{itemTemplate = "all_saber_schematics", weight = 2000000},
		{itemTemplate = "lance_trando_pike_schematic", weight = 1500000},
		{itemTemplate = "baton_gaderiffi_elite_schematic", weight = 1500000}
	}
}

addLootGroupTemplate("lewt_chest_event", lewt_chest_event)
