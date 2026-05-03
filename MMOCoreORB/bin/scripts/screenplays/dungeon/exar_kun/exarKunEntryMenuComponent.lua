exarKunEntryMenuComponent = { }

function exarKunEntryMenuComponent:fillObjectMenuResponse(pSceneObject, pMenuResponse, pPlayer)
	local response = LuaObjectMenuResponse(pMenuResponse)
	response:addRadialMenuItem(20, 3, "Enter Exar Kun's Tomb [Instance]")
end

function exarKunEntryMenuComponent:handleObjectMenuSelect(pSceneObject, pPlayer, selectedID)
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

	createEvent(1, "exarKun", "sendStartSui", pPlayer, "")
	return 0
end

exarKunExitMenuComponent = { }

function exarKunExitMenuComponent:fillObjectMenuResponse(pSceneObject, pMenuResponse, pPlayer)
	local response = LuaObjectMenuResponse(pMenuResponse)
	response:addRadialMenuItem(20, 3, "Exit Zone")
end

function exarKunExitMenuComponent:handleObjectMenuSelect(pSceneObject, pPlayer, selectedID)
	if selectedID ~= 20 then
		return 0
	end

	if pPlayer == nil or pSceneObject == nil then
		return 0
	end

	if not CreatureObject(pPlayer):isInRangeWithObject(pSceneObject, 6) then
		return 0
	end

	createEvent(1, "exarKun", "sendExitSui", pPlayer, "")
	return 0
end
