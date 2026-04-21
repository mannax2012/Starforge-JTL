exarKunEntryWay = ScreenPlay:new {
	numberOfActs = 1,
	screenplayName = "exarKunEntryWay"
}

registerScreenPlay("exarKunEntryWay", true)

function exarKunEntryWay:start()
	if not isZoneEnabled("yavin4") then
		return
	end

	self:spawnSceneObjects()
end

function exarKunEntryWay:spawnSceneObjects()
	spawnSceneObject("yavin4", "object/static/structure/general/poi_temple_ancient_ruined.iff", 5026, 73, 5562, 0, math.rad(-90))

	local pTerminal = spawnSceneObject("yavin4", "object/tangible/item/yavin4_exar_kun_entry.iff", 5078.5, 73.7, 5537.6, 0, math.rad(84))

	if pTerminal ~= nil then
		SceneObject(pTerminal):setCustomObjectName("Exar Kun's Tomb [Instance]")
		SceneObject(pTerminal):setObjectMenuComponent("exarKunEntryMenuComponent")
	end
end
