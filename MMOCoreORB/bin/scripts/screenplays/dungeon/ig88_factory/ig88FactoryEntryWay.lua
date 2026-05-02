ig88FactoryEntryWay = ScreenPlay:new {
	numberOfActs = 1,
	screenplayName = "ig88FactoryEntryWay"
}

registerScreenPlay("ig88FactoryEntryWay", true)

function ig88FactoryEntryWay:start()
	if not isZoneEnabled("lok") then
		return
	end

	self:spawnSceneObjects()
end

function ig88FactoryEntryWay:spawnSceneObjects()
	local x = 426.5
	local y = 5151.7
	local z = getWorldFloor(x, y, "lok") + 1
	local pTerminal = spawnSceneObject("lok", "object/tangible/dungeon/keypad_terminal.iff", x, z, y, 0, math.rad(180))

	if pTerminal ~= nil then
		SceneObject(pTerminal):setCustomObjectName("Nym's Factory Compound [Instance]")
		SceneObject(pTerminal):setObjectMenuComponent("ig88FactoryEntryMenuComponent")
	end
end
