ig88FactoryEntryMenuComponent = { }

function ig88FactoryEntryMenuComponent:fillObjectMenuResponse(pSceneObject, pMenuResponse, pPlayer)
	local response = LuaObjectMenuResponse(pMenuResponse)
	response:addRadialMenuItem(20, 3, "Enter the IG-88 Factory Arena [Instance]")
end

function ig88FactoryEntryMenuComponent:handleObjectMenuSelect(pSceneObject, pPlayer, selectedID)
	if selectedID ~= 20 then
		return 0
	end

	if pPlayer == nil or pSceneObject == nil then
		return 0
	end

	if CreatureObject(pPlayer):isInCombat() or CreatureObject(pPlayer):isIncapacitated() or CreatureObject(pPlayer):isDead() then
		CreatureObject(pPlayer):sendSystemMessage("You cannot enter while in combat, incapacitated, or dead.")
		return 0
	end

	if not CreatureObject(pPlayer):isInRangeWithObject(pSceneObject, 6) then
		return 0
	end

	if CreatureObject(pPlayer):isRidingMount() then
		CreatureObject(pPlayer):sendSystemMessage("You cannot use this object while riding a mount.")
		return 0
	end

	createEvent(1000, "ig88FactoryArena", "activate", pPlayer, "")
	return 0
end

ig88FactoryExitMenuComponent = { }

function ig88FactoryExitMenuComponent:fillObjectMenuResponse(pSceneObject, pMenuResponse, pPlayer)
	local response = LuaObjectMenuResponse(pMenuResponse)
	response:addRadialMenuItem(20, 3, "Exit Zone")
end

function ig88FactoryExitMenuComponent:handleObjectMenuSelect(pSceneObject, pPlayer, selectedID)
	if selectedID ~= 20 then
		return 0
	end

	if pPlayer == nil or pSceneObject == nil then
		return 0
	end

	if not CreatureObject(pPlayer):isInRangeWithObject(pSceneObject, 6) then
		return 0
	end

	createEvent(1, "ig88FactoryArena", "sendExitSui", pPlayer, "")
	return 0
end

ig88FactoryTriggerMenuComponent = { }

function ig88FactoryTriggerMenuComponent:fillObjectMenuResponse(pSceneObject, pMenuResponse, pPlayer)
	if pSceneObject == nil or pMenuResponse == nil or pPlayer == nil then
		return
	end

	local response = LuaObjectMenuResponse(pMenuResponse)
	response:addRadialMenuItem(20, 3, "Kick")
end

function ig88FactoryTriggerMenuComponent:handleObjectMenuSelect(pSceneObject, pPlayer, selectedID)
	if selectedID ~= 20 then
		return 0
	end

	if pSceneObject == nil or pPlayer == nil then
		return 0
	end

	if not CreatureObject(pPlayer):isInRangeWithObject(pSceneObject, 6) then
		return 0
	end

	ig88FactoryArena:kickTriggerDroid(pSceneObject, pPlayer)
	return 0
end
