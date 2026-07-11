-- Drop group for the chest item itself.
lewt_chest_rare_drop = {
	description = "",
	minimumLevel = 0,
	maximumLevel = 0,
	lootItems = {
		{itemTemplate = "rare_lewt_chest", weight = 10000000}
	}
}

addLootGroupTemplate("lewt_chest_rare_drop", lewt_chest_rare_drop)
