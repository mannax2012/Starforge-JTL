junkDealerAllInOneConvoTemplate = ConvoTemplate:new {
	initialScreen = "ask_for_loot",
	templateType = "Lua",
	luaClassHandler = "JunkDealerAllInOneConvoHandler",
	screens = {}
}

-- The generic dealer dialogue also supplies the collectible-kit conversation.
ask_for_loot = ConvoScreen:new {
	id = "ask_for_loot",
	leftDialog = "@conversation/junk_dealer_generic:s_bef51e38",
	stopConversation = "false",
	options = {}
}
junkDealerAllInOneConvoTemplate:addScreen(ask_for_loot);

start_sale = ConvoScreen:new {
	id = "start_sale",
	leftDialog = "@conversation/junk_dealer_generic:s_84a67771",
	stopConversation = "true",
	options = {}
}
junkDealerAllInOneConvoTemplate:addScreen(start_sale);

no_loot = ConvoScreen:new {
	id = "no_loot",
	leftDialog = "@conversation/junk_dealer_generic:s_4bd9d15e",
	stopConversation = "true",
	options = {}
}
junkDealerAllInOneConvoTemplate:addScreen(no_loot);

inventor = ConvoScreen:new {
	id = "inventor",
	leftDialog = "@conversation/junk_dealer_generic:s_d9e6b751",
	stopConversation = "false",
	options = {
		{"@conversation/junk_dealer_generic:s_6d53d062", "shipment"},
	}
}
junkDealerAllInOneConvoTemplate:addScreen(inventor);

shipment = ConvoScreen:new {
	id = "shipment",
	leftDialog = "@conversation/junk_dealer_generic:s_e29f48dc",
	stopConversation = "false",
	options = {
		{"@conversation/junk_dealer_generic:s_324b9b0f", "adventerous"},
	}
}
junkDealerAllInOneConvoTemplate:addScreen(shipment);

adventerous = ConvoScreen:new {
	id = "adventerous",
	leftDialog = "@conversation/junk_dealer_generic:s_12fe83a6",
	stopConversation = "false",
	options = {
		{"@conversation/junk_dealer_generic:s_e1a103e5", "want_them_gone"},
	}
}
junkDealerAllInOneConvoTemplate:addScreen(adventerous);

want_them_gone = ConvoScreen:new {
	id = "want_them_gone",
	leftDialog = "@conversation/junk_dealer_generic:s_4d65752",
	stopConversation = "false",
	options = {
		{"@conversation/junk_dealer_generic:s_d347bee3", "kit_types"},
		{"@conversation/junk_dealer_generic:s_b60b73f8", "not_taking_one"},
	}
}
junkDealerAllInOneConvoTemplate:addScreen(want_them_gone);

not_taking_one = ConvoScreen:new {
	id = "not_taking_one",
	leftDialog = "@conversation/junk_dealer_generic:s_3633b5a5",
	stopConversation = "true",
	options = {}
}
junkDealerAllInOneConvoTemplate:addScreen(not_taking_one);

kit_types = ConvoScreen:new {
	id = "kit_types",
	leftDialog = "@conversation/junk_dealer_generic:s_3fc7eb45",
	stopConversation = "false",
	options = {
		{"@conversation/junk_dealer_generic:s_ee977dee", "give_orange"},
		{"@conversation/junk_dealer_generic:s_8f39769", "give_blue"},
		{"@conversation/junk_dealer_generic:s_fe657cdd", "give_gong"},
		{"@conversation/junk_dealer_generic:s_9ede4b84", "give_table"},
		{"@conversation/junk_dealer_generic:s_87c5851b", "give_sculpture"},
	}
}
junkDealerAllInOneConvoTemplate:addScreen(kit_types);

give_orange = ConvoScreen:new {
	id = "give_orange",
	leftDialog = "@conversation/junk_dealer_generic:s_14efaaa2",
	stopConversation = "true",
	options = {}
}
junkDealerAllInOneConvoTemplate:addScreen(give_orange);

give_blue = ConvoScreen:new {
	id = "give_blue",
	leftDialog = "@conversation/junk_dealer_generic:s_14efaaa2",
	stopConversation = "true",
	options = {}
}
junkDealerAllInOneConvoTemplate:addScreen(give_blue);

give_gong = ConvoScreen:new {
	id = "give_gong",
	leftDialog = "@conversation/junk_dealer_generic:s_14efaaa2",
	stopConversation = "true",
	options = {}
}
junkDealerAllInOneConvoTemplate:addScreen(give_gong);

give_table = ConvoScreen:new {
	id = "give_table",
	leftDialog = "@conversation/junk_dealer_generic:s_14efaaa2",
	stopConversation = "true",
	options = {}
}
junkDealerAllInOneConvoTemplate:addScreen(give_table);

give_sculpture = ConvoScreen:new {
	id = "give_sculpture",
	leftDialog = "@conversation/junk_dealer_generic:s_14efaaa2",
	stopConversation = "true",
	options = {}
}
junkDealerAllInOneConvoTemplate:addScreen(give_sculpture);

addConversationTemplate("junkDealerAllInOneConvoTemplate", junkDealerAllInOneConvoTemplate);
