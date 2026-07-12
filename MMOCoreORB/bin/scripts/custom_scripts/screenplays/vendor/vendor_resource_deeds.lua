--[[
Created on: 04/20, 2026
Author: Codex
]]--
ResourceDeedsVendorLogic = ScreenPlay:new {
	scriptName = "ResourceDeedsVendorLogic",
	currencies = {
		{currency = "credits"},
		{currency = "experience", name = "Starforge Currency", experience =  "starforge_currency"},
	},

	merchandise_resource_deeds = {
		{name = "Small Resource Deed", template = "object/tangible/veteran_reward/resource_small.iff", cost = {0, 10000}},
		{name = "Medium Resource Deed", template = "object/tangible/veteran_reward/resource_medium.iff", cost = {0, 50000}},
	},
}

registerScreenPlay("ResourceDeedsVendorLogic", false)

function ResourceDeedsVendorLogic:getUsingObjectFromSui(pSui)
	if (pSui == nil) then
		return nil
	end

	return LuaSuiBox(pSui):getUsingObject()
end

function ResourceDeedsVendorLogic:openSUIResourceDeeds(pCreatureObject, pUsingObject)
	local sui = SuiListBox.new(self.scriptName, "defaultCallbackResourceDeeds")

	if (pUsingObject == nil) then
		sui.setTargetNetworkId(0)
	else
		sui.setTargetNetworkId(SceneObject(pUsingObject):getObjectID())
	end

	sui.setForceCloseDistance(16)
	sui.setTitle("Resource Deeds")
	sui.setPrompt("Please select which resource deed you want to buy.")

	for i = 1, #self.merchandise_resource_deeds, 1 do
		local merchString = self:getMerchandiseStringResourceDeeds(i)
		sui.add(merchString, "")
	end

	sui.sendTo(pCreatureObject)
end

function ResourceDeedsVendorLogic:defaultCallbackResourceDeeds(pPlayer, pSui, eventIndex, args)
	local cancelPressed = (eventIndex == 1)
	local pUsingObject = self:getUsingObjectFromSui(pSui)

	if (cancelPressed) then
		return
	end

	if (args == "-1") then
		CreatureObject(pPlayer):sendSystemMessage("No option was selected, please try again.")
		self:openSUIResourceDeeds(pPlayer, pUsingObject)
		return
	end

	local selectedOption = tonumber(args) + 1

	self:buyItemResourceDeeds(pPlayer, selectedOption)
	self:openSUIResourceDeeds(pPlayer, pUsingObject)
end

function ResourceDeedsVendorLogic:buyItemResourceDeeds(pPlayer, itemSelected)
	local merch = self.merchandise_resource_deeds[itemSelected]
	local pInventory = CreatureObject(pPlayer):getSlottedObject("inventory")
	local pGhost = CreatureObject(pPlayer):getPlayerObject()

	if (pGhost == nil) then
		return
	end

	if (SceneObject(pInventory):isContainerFullRecursive()) then
		CreatureObject(pPlayer):sendSystemMessage("You do not have enough inventory space.")
		return
	end

	if (not self:hasEnoughCurrencyResourceDeeds(pPlayer, itemSelected)) then
		CreatureObject(pPlayer):sendSystemMessage("You can't afford the selected item.")
		return
	end

	for i = 1, #merch.cost do
		local currency = self.currencies[i].currency
		local currencyName = self.currencies[i].name
		local experienceName = self.currencies[i].experience
		local cost = merch.cost[i]

		if (cost ~= 0) then
			if (currency == "credits") then
				if (cost <= CreatureObject(pPlayer):getCashCredits()) then
					CreatureObject(pPlayer):subtractCashCredits(cost)
				else
					cost = cost - CreatureObject(pPlayer):getCashCredits()
					CreatureObject(pPlayer):subtractCashCredits(CreatureObject(pPlayer):getCashCredits())
					CreatureObject(pPlayer):setBankCredits(CreatureObject(pPlayer):getBankCredits() - cost)
				end
			end

			if (currency == "experience") then
				CreatureObject(pPlayer):awardExperience(experienceName, cost * -1, true)
			end

			if (currency == "faction") then
				PlayerObject(pGhost):decreaseFactionStanding(currencyName, cost)
			end
		end
	end

	local pItem = giveItem(pInventory, merch.template, -1)

	if (pItem ~= nil) then
		SceneObject(pItem):setCustomObjectName(merch.name)
	end

	CreatureObject(pPlayer):sendSystemMessage("You have purchased " .. merch.name)
end

function ResourceDeedsVendorLogic:getMerchandiseStringResourceDeeds(num)
	local merch = self.merchandise_resource_deeds[num]
	local merchString = merch.name .. " ("

	for i = 1, #merch.cost do
		local currency = self.currencies[i].currency
		local currencyName = self.currencies[i].name

		if (merch.cost[i] > 0) then
			if (currency == "credits") then
				merchString = merchString .. merch.cost[i] .. " Credits"
			end

			if (currency == "experience") then
				merchString = merchString .. merch.cost[i] .. " " .. currencyName
			end

			if (currency == "faction") then
				merchString = merchString .. merch.cost[i] .. " " .. currencyName:gsub("^%l", string.upper) .. " faction"
			end

			merchString = merchString .. ", "
		end
	end

	merchString = merchString .. ")"
	return merchString:gsub(", %)", ")")
end

function ResourceDeedsVendorLogic:hasEnoughCurrencyResourceDeeds(pPlayer, num)
	local pGhost = CreatureObject(pPlayer):getPlayerObject()

	if (pGhost == nil) then
		return false
	end

	local merch = self.merchandise_resource_deeds[num]

	for i = 1, #merch.cost do
		local currency = self.currencies[i].currency
		local currencyName = self.currencies[i].name
		local cost = merch.cost[i]

		if (cost > 0) then
			if (currency == "credits") then
				if (CreatureObject(pPlayer):getCashCredits() + CreatureObject(pPlayer):getBankCredits() < cost) then
					return false
				end
			end

			if (currency == "experience") then
				if (PlayerObject(pGhost):getExperience(self.currencies[i].experience) < cost) then
					return false
				end
			end

			if (currency == "faction") then
				if (PlayerObject(pGhost):getFactionStanding(currencyName) < cost) then
					return false
				end
			end
		end
	end

	return true
end
