exarKunTrashSpawns = {
	{ "exar_kun_cultist", 43.3, 0, -48.1, 116, "r3" },
	{ "exar_kun_cultist", 51.5, 0, -53.8, -37, "r3" },
	{ "exar_kun_cultist", 50.7, 0, -46.1, -140, "r3" },
	{ "exar_kun_cultist", 59.1, 0, -20.4, -174, "r3" },
	{ "exar_kun_cultist", 56.7, 0, -20.2, -171, "r3" },
	{ "exar_kun_cultist", 52.2, 0, -21.0, 176, "r3" },
	{ "exar_kun_cultist", 38.6, -0.1, -1.4, 101, "r3" },
	{ "exar_kun_cultist", 41.1, -0.2, 1.9, 117, "r3" },
	{ "exar_kun_cultist", 44.6, -0.4, 4.5, 150, "r3" },
	{ "exar_kun_cultist", -38.1, 0, 11.1, -172, "r5" },
	{ "exar_kun_cultist", -31.9, 0, 11.8, -174, "r5" },
	{ "exar_kun_cultist", -34.7, 0, 12.5, -179, "r5" },
	{ "exar_kun_cultist", -22.4, -0.2, 40.9, 144, "r5" },
	{ "exar_kun_cultist", -16.3, 0, 39.7, -125, "r5" },
	{ "exar_kun_cultist", -15.5, 0, 35.3, -51, "r5" },
	{ "exar_kun_cultist", 7.7, 0.3, 50, 141, "r6" },
	{ "exar_kun_cultist", 23.3, 0.3, 49.7, -113, "r6" },
	{ "exar_kun_cultist", 16.7, 0.3, 39.9, -4, "r6" },
}

exarKunBossSpawns = {
	[1] = { "exar_kun_open_hand", -12.2, -0.1, -47.9, 171, "r2" },
	[2] = { "exar_kun_minder", -1.9, 0.1, -2.7, 85, "r4" },
	[3] = { "exar_kun_caretaker", 18.1, 0.1, -2.0, -90, "r4" },
	[4] = { "exar_kun_fist_of_hate", 15.6, 0.0, 92.8, 178, "r7" },
	[5] = { "exar_kun", 15.8, 4.7, 106.9, 179, "r7" },
}

exarKunBarricadeSpawns = {
	{ template = "object/tangible/door/exar_kun_door_s1.iff", x = -11.7, z = 0.2, y = -95.0, heading = 90, cell = "r1" },
	{ template = "object/tangible/door/exar_kun_door_s1.iff", x = 28.0, z = 0.0, y = -62.7, heading = 134, cell = "r3" },
	{ template = "object/tangible/door/exar_kun_door_s1.iff", x = 38.2, z = 0.0, y = -1.3, heading = 0, cell = "r3" },
	{ template = "object/tangible/door/exar_kun_door_s1.iff", x = -24.1, z = -0.3, y = -20.1, heading = -175, cell = "r5" },
	{ template = "object/tangible/door/exar_kun_door_s1.iff", x = 2.5, z = -0.2, y = 45.1, heading = -1, cell = "r6" },
	{ template = "object/tangible/door/exar_kun_door_s1.iff", x = 15.5, z = 0.0, y = 55.5, heading = 90, cell = "r7" },
}

exarKunInitialBarricades = { 2, 3, 4, 5, 6 }

exarKunBarricadeUnlocks = {
	[1] = { 1, 2, 3 },
	[3] = { 4, 5, 6 },
}

exarKunBossFourGuards = {
	{ "exar_kun_cultist", 33.2, -0.1, 71.4, -90, "r7" },
	{ "exar_kun_cultist", 33.2, -0.1, 75.4, -90, "r7" },
	{ "exar_kun_cultist", 33.2, -0.1, 79.4, -90, "r7" },
	{ "exar_kun_cultist", 33.2, -0.1, 83.4, -90, "r7" },
	{ "exar_kun_cultist", 33.2, -0.1, 87.4, -90, "r7" },
	{ "exar_kun_cultist", -3.0, -0.1, 71.4, 90, "r7" },
	{ "exar_kun_cultist", -3.0, -0.1, 75.4, 90, "r7" },
	{ "exar_kun_cultist", -3.0, -0.1, 79.4, 90, "r7" },
	{ "exar_kun_cultist", -3.0, -0.1, 83.4, 90, "r7" },
	{ "exar_kun_cultist", -3.0, -0.1, 87.4, 90, "r7" },
}

exarKunBossPhases = {
	[1] = {
		{ percent = 99, text = "You come seeking the wisdom of the master? Very well. There is much to learn. I will show you!", effect = "clienteffect/space_command/shp_shocked_01.cef" },
		{ percent = 75, text = "We have barely begun to probe the depths of the knowledge in this place.", effect = "clienteffect/combat_pt_electricalfield.cef" },
		{ percent = 50, text = "Before the master, I was a simple scientist. Do you not appreciate the gifts he bestows?", effect = "clienteffect/pl_force_resist_states_self.cef", spawns = {
			{ "exar_kun_cultist", 5.3, -0.1, -46.5, -147, "r2" },
			{ "exar_kun_cultist", -28.4, -0.1, -46.4, 130, "r2" },
			{ "exar_kun_cultist", -32.2, -0.1, -51.9, 109, "r2" },
			{ "exar_kun_cultist", 9.2, -0.1, -51.8, -121, "r2" },
			{ "exar_kun_cultist", 9.1, -0.1, -77.7, -55, "r2" },
			{ "exar_kun_cultist", 5.3, -0.1, -82.3, -37, "r2" },
			{ "exar_kun_cultist", -28.4, -0.1, -82.7, 40, "r2" },
			{ "exar_kun_cultist", -32.3, -0.1, -77.2, 59, "r2" },
		} },
		{ percent = 25, text = "You do not understand, all this can be yours too if you just devote yourselves to him!", effect = "clienteffect/pl_force_resist_bleeding_self.cef" },
		{ percent = 10, text = "You had the chance to learn, now your only choice is death at the hand of the master.", effect = "clienteffect/pl_storm_lord_special.cef" },
	},
	[2] = {
		{ percent = 99, text = "I will test the mettle of your will against the metal of my blade, for the glory of the master!", effect = "clienteffect/space_command/shp_shocked_01.cef" },
		{ percent = 75, text = "You are all weak, and as the master says... The weak deserve their fate!", spawns = {
			{ "exar_kun_cultist", 8.3, 0.1, -13.2, 0, "r4" },
			{ "exar_kun_cultist", 8.3, 0.1, 8.2, 180, "r4" },
		} },
		{ percent = 50, text = "Why do you persist? You can't possibly believe you will win?", effect = "clienteffect/pl_storm_lord_special.cef" },
		{ percent = 25, text = "This is impossible, I serve the master in all things.", effect = "clienteffect/combat_pt_electricalfield.cef", spawns = {
			{ "exar_kun_cultist", 8.3, 0.1, -13.2, 0, "r4" },
			{ "exar_kun_cultist", 8.3, 0.1, 8.2, 180, "r4" },
		} },
		{ percent = 10, text = "Perhaps you were not as weak as I thought. I deserve to die for failing the master." },
	},
	[3] = {
		{ percent = 99, text = "Execute them!", spawns = { { "exar_kun_warrior_f", -1.7, 0.1, 10.1, 128, "r4" } } },
		{ percent = 75, text = "You are unworthy of the gifts of the master.", spawns = { { "exar_kun_warrior", -2.0, 0.1, -16.0, 43, "r4" } } },
		{ percent = 50, text = "Execute them!", spawns = { { "exar_kun_warrior_f", -1.7, 0.1, 10.1, 128, "r4" } } },
		{ percent = 25, text = "I will not fail the Master. His power is undeniable!", effect = "clienteffect/pl_storm_lord_special.cef" },
		{ percent = 10, text = "Master, I could not stop them..." },
	},
	[4] = {
		{ percent = 99, text = "You stand before the Master, defiantly. Pity for you to come so far only to die.", effect = "clienteffect/pl_storm_lord_special.cef", spawns = { { "exar_kun_cultist", 15.5, 0.0, 59, 0, "r7" } } },
		{ percent = 75, text = "There is no way out for you but to embrace death.", spawns = { { "exar_kun_cultist", 15.5, 0.0, 59, 0, "r7" } } },
		{ percent = 50, text = "It will be over soon, give in to the inevitable!", spawns = { { "exar_kun_cultist", 15.5, 0.0, 59, 0, "r7" } } },
		{ percent = 25, text = "Don't you see? He can not be destroyed. He will purge you from this life like insects!", effect = "clienteffect/combat_pt_electricalfield.cef" },
		{ percent = 10, text = "Exar Kun... lives.... he will destroy you all!" },
	},
	[5] = {
		{ percent = 99, text = "If you kneel before me now, I will end your life painlessly. Refuse and there will be no end to your torment.", effect = "clienteffect/mustafar/som_dark_jedi_laugh.cef" },
		{ percent = 75, text = "Time to make this more interesting...", effect = "clienteffect/pl_storm_lord_special.cef", spawns = exarKunBossFourGuards },
		{ percent = 50, text = "Your defiance only feeds the darkness.", effect = "clienteffect/mustafar/som_dark_jedi_laugh.cef", spawns = exarKunBossFourGuards },
		{ percent = 25, text = "How you must hate me. I can feel your anger.", effect = "clienteffect/mustafar/som_dark_jedi_laugh.cef", spawns = exarKunBossFourGuards },
		{ percent = 10, text = "My spirit will live forever! Forever!", effect = "clienteffect/combat_pt_electricalfield.cef" },
	},
}
