-- Drop group for the chest item itself.
bio_tukata_deed = {
	description = "",
	minimumLevel = 0,
	maximumLevel = 0,
	lootItems = {
		{itemTemplate = "tukata_deed_schematic", weight = 10000000}
	}
}

addLootGroupTemplate("bio_tukata_deed", bio_tukata_deed)
