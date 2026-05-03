local ObjectManager = require("managers.object.object_manager")

local ig88FactoryDoorSpawns = {
	west = {-20, 0, -23, 2},
	east = {20, 0, -23, 2},
	northEast = {20, 0, 44, -170},
	northWest = {-20, 0, 44, -170}
}

local ig88FactoryArenaCenter = {0, 0, 10}
local ig88FactoryBossSpawn = {0, 0, 43, -170}
local ig88FactoryBossPatrolRight = {13, 0, 17, -170}
local ig88FactoryBossPatrolLeft = {-13, 0, 17, -170}
local ig88FactoryBossPatrolCenter = {0, 0, 17, -170}

local ig88FactoryClockwiseRoute = {
	{ig88FactoryBossPatrolLeft[1], ig88FactoryBossPatrolLeft[2], ig88FactoryBossPatrolLeft[3]}
}

local ig88FactoryCounterClockwiseRoute = {
	{ig88FactoryBossPatrolRight[1], ig88FactoryBossPatrolRight[2], ig88FactoryBossPatrolRight[3]}
}

ig88FactoryArena = ScreenPlay:new {
	numberOfActs = 1,
	screenplayName = "ig88FactoryArena",
	instanceZone = "ig88factoryarena",
	fallbackInstanceZone = "tutorial",
	returnZone = "lok",
	maxGroupSize = 10,
	durationSeconds = 60 * 60,
	buildingTemplate = "object/building/heroic/ig88_factory_arena.iff",
	exitTerminalTemplate = "object/tangible/dungeon/keypad_terminal.iff",
	instanceTerrainMinCoordinate = -8192,
	instanceTerrainMaxCoordinate = 8192,
	instanceMinCoordinate = 5200,
	instanceMaxCoordinate = 7600,
	instancePlacementClearRadius = 250,
	instancePlacementGridSize = 250,
	instancePlacementAttempts = 40,
	entryCellPreferences = {1, 2},
	arenaCellPreferences = {2, 1},
	entryX = 0,
	entryZ = 0,
	entryY = -42,
	exitTerminalX = 0,
	exitTerminalZ = 0,
	exitTerminalY = -22,
	exitTerminalHeading = 0,
	triggerX = ig88FactoryArenaCenter[1],
	triggerZ = ig88FactoryArenaCenter[2],
	triggerY = ig88FactoryArenaCenter[3],
	returnX = 426.5,
	returnY = 5151.5,
	bombDroidRadius = 12,
	bombDroidMinDamage = 2200,
	bombDroidMaxDamage = 3200,
	bombDroidFallbackDetonationMs = 20 * 1000,
	flameZoneRadius = 8,
	flameZoneMinDamage = 2800,
	flameZoneMaxDamage = 4200,
	ig88ShieldThresholds = {75, 50, 25},
}

registerScreenPlay("ig88FactoryArena", true)

function ig88FactoryArena:start()
end

function ig88FactoryArena:getAvailableInstanceZone()
	if isZoneEnabled(self.instanceZone) then
		return self.instanceZone
	end

	if self.fallbackInstanceZone ~= nil and self.fallbackInstanceZone ~= "" and isZoneEnabled(self.fallbackInstanceZone) then
		return self.fallbackInstanceZone
	end

	return ""
end

function ig88FactoryArena:getInstanceZoneForInstance(instanceID)
	if instanceID ~= nil and instanceID ~= 0 then
		local zoneName = readStringData(self:getKey(instanceID, "zone"))

		if zoneName ~= nil and zoneName ~= "" then
			return zoneName
		end
	end

	return self:getAvailableInstanceZone()
end

function ig88FactoryArena:isManagedInstanceZone(zoneName)
	if zoneName == nil or zoneName == "" then
		return false
	end

	return zoneName == self.instanceZone or zoneName == self.fallbackInstanceZone
end

function ig88FactoryArena:sendStartSui(pPlayer)
	if pPlayer == nil then
		return
	end

	local sui = SuiMessageBox.new("ig88FactoryArena", "startSuiCallback")
	sui.setTitle("IG-88 Factory Arena [Instance]")
	sui.setPrompt("You are about to start an IG-88 Factory Arena [Instance]. This will create a new instance for your group and send travel invitations to the other group members. Continue?")
	sui.setOkButtonText("Start")
	sui.setCancelButtonText("Cancel")

	local pageId = sui.sendTo(pPlayer)
	createEvent(30 * 1000, "ig88FactoryArena", "closeStartSui", pPlayer, pageId)
end

function ig88FactoryArena:startSuiCallback(pPlayer, pSui, eventIndex, args, ...)
	if pPlayer == nil then
		return
	end

	if eventIndex == 1 then
		CreatureObject(pPlayer):sendSystemMessage("You decide not to start the IG-88 Factory Arena [Instance].")
		return
	end

	createEvent(1, "ig88FactoryArena", "activate", pPlayer, "")
end

function ig88FactoryArena:closeStartSui(pPlayer, pageId)
	if pPlayer == nil then
		return
	end

	local pGhost = CreatureObject(pPlayer):getPlayerObject()

	if pGhost ~= nil then
		PlayerObject(pGhost):removeSuiBox(pageId)
	end
end

function ig88FactoryArena:activate(pPlayer)
	if pPlayer == nil then
		return false
	end

	local instanceZone = self:getAvailableInstanceZone()

	if not isZoneEnabled(self.returnZone) or instanceZone == "" then
		CreatureObject(pPlayer):sendSystemMessage("The IG-88 Factory Arena [Instance] is currently unavailable.")
		return false
	end

	if instanceZone ~= self.instanceZone then
		CreatureObject(pPlayer):sendSystemMessage("Preferred instance zone '" .. self.instanceZone .. "' is unavailable. Using tutorial fallback.")
	end

	if CreatureObject(pPlayer):isRidingMount() then
		CreatureObject(pPlayer):sendSystemMessage("You fail to enter the instance because you are riding a mount.")
		return false
	end

	if not CreatureObject(pPlayer):isGrouped() then
		CreatureObject(pPlayer):sendSystemMessage("You must be in a group to start the IG-88 Factory Arena [Instance].")
		return false
	end

	if CreatureObject(pPlayer):getGroupSize() > self.maxGroupSize then
		CreatureObject(pPlayer):sendSystemMessage("Your group is too large. IG-88 Factory Arena allows a maximum of 8 players.")
		return false
	end

	local playerInstanceID = self:getPlayerInstance(pPlayer)

	if playerInstanceID ~= 0 then
		CreatureObject(pPlayer):sendSystemMessage("You are already assigned to an IG-88 Factory Arena [Instance].")
		return false
	end

	local groupID = CreatureObject(pPlayer):getGroupID()
	local groupInstanceID = self:getGroupInstance(groupID)

	if groupInstanceID ~= 0 then
		self:transportPlayerToInstance(pPlayer, groupInstanceID)
		CreatureObject(pPlayer):sendSystemMessage("You enter your group's active IG-88 Factory Arena [Instance].")
		return true
	end

	local pBuilding = self:createInstanceBuilding(instanceZone)

	if pBuilding == nil then
		CreatureObject(pPlayer):sendSystemMessage("Unable to create the IG-88 Factory Arena [Instance]. Please try again later.")
		return false
	end

	local instanceID = SceneObject(pBuilding):getObjectID()
	self:reserveInstancePlacement(instanceID, instanceZone, SceneObject(pBuilding):getWorldPositionX(), SceneObject(pBuilding):getWorldPositionY())

	writeData(self:getKey(instanceID, "active"), 1)
	writeData(self:getKey(instanceID, "leaderID"), SceneObject(pPlayer):getObjectID())
	writeData(self:getKey(instanceID, "groupID"), groupID)
	writeData(self:getKey(instanceID, "startTime"), os.time())
	writeStringData(self:getKey(instanceID, "zone"), instanceZone)
	writeData(self:getGroupKey(groupID), instanceID)

	createObserver(EXITEDBUILDING, "ig88FactoryArena", "onExitedInstance", pBuilding)
	self:logActivationStep(instanceID, "instance building created; queuing finishActivation")
	createEvent(250, "ig88FactoryArena", "finishActivation", pPlayer, tostring(instanceID))

	createEvent(5 * 60 * 1000, "ig88FactoryArena", "checkInstanceTimer", pBuilding, "")
	return true
end

function ig88FactoryArena:finishActivation(pPlayer, eventData)
	local instanceID = tonumber(eventData)

	if instanceID == nil or instanceID == 0 then
		if pPlayer ~= nil then
			CreatureObject(pPlayer):sendSystemMessage("Unable to finish creating the IG-88 Factory Arena [Instance].")
		end

		return
	end

	if pPlayer == nil then
		self:logActivationStep(instanceID, "finishActivation aborted: missing player reference")
		local pBuilding = getSceneObject(instanceID)

		if pBuilding ~= nil then
			self:resetInstance(pBuilding)
		else
			self:cleanupInstanceData(instanceID)
		end

		return
	end

	if readData(self:getKey(instanceID, "active")) ~= 1 then
		CreatureObject(pPlayer):sendSystemMessage("That IG-88 Factory Arena [Instance] is no longer available.")
		return
	end

	local pBuilding = getSceneObject(instanceID)

	if pBuilding == nil then
		CreatureObject(pPlayer):sendSystemMessage("Unable to find the IG-88 Factory Arena [Instance] building.")
		self:logActivationStep(instanceID, "finishActivation aborted: missing building")
		self:cleanupInstanceData(instanceID)
		return
	end

	local entryCellID = self:getEntryCellID(instanceID)
	self:logActivationStep(instanceID, "finishActivation resolved entry cell " .. entryCellID)

	if entryCellID == 0 then
		CreatureObject(pPlayer):sendSystemMessage("Unable to find the IG-88 Factory Arena [Instance] entry cell.")
		self:logActivationStep(instanceID, "finishActivation aborted: entry cell lookup returned 0")
		self:resetInstance(pBuilding)
		return
	end

	self:spawnExitTerminal(instanceID)

	if not self:transportPlayerToInstance(pPlayer, instanceID) then
		CreatureObject(pPlayer):sendSystemMessage("Unable to enter the IG-88 Factory Arena [Instance].")
		self:logActivationStep(instanceID, "finishActivation aborted: transportPlayerToInstance failed")
		self:resetInstance(pBuilding)
		return
	end

	self:inviteGroupMembers(pPlayer, instanceID)
	self:spawnInitialEncounter(instanceID)
	self:sendInstanceMessage(instanceID, "Instance started: kick the mouse droid in the arena center to begin the factory defense.")
	self:logActivationStep(instanceID, "finishActivation complete")
end

function ig88FactoryArena:getPlacementGridCoordinate(value)
	return math.floor(value / self.instancePlacementGridSize)
end

function ig88FactoryArena:getPlacementReservationKey(instanceZone, gridX, gridY)
	return self.screenplayName .. ":placement:" .. instanceZone .. ":" .. gridX .. ":" .. gridY
end

function ig88FactoryArena:isPlacementAvailable(instanceZone, x, y)
	local gridX = self:getPlacementGridCoordinate(x)
	local gridY = self:getPlacementGridCoordinate(y)
	local cellRadius = math.ceil(self.instancePlacementClearRadius / self.instancePlacementGridSize)
	local minDistanceSquared = self.instancePlacementClearRadius * self.instancePlacementClearRadius

	for checkX = gridX - cellRadius, gridX + cellRadius, 1 do
		for checkY = gridY - cellRadius, gridY + cellRadius, 1 do
			local reservationKey = self:getPlacementReservationKey(instanceZone, checkX, checkY)
			local reservedInstanceID = readData(reservationKey)

			if reservedInstanceID ~= 0 then
				if getSceneObject(reservedInstanceID) == nil or readData(self:getKey(reservedInstanceID, "active")) ~= 1 then
					deleteData(reservationKey)
				else
					local reservedX = readData(self:getKey(reservedInstanceID, "spawnX"))
					local reservedY = readData(self:getKey(reservedInstanceID, "spawnY"))
					local deltaX = x - reservedX
					local deltaY = y - reservedY

					if (deltaX * deltaX) + (deltaY * deltaY) < minDistanceSquared then
						return false
					end
				end
			end
		end
	end

	return true
end

function ig88FactoryArena:findAvailableInstanceLocation(instanceZone)
	for attempt = 1, self.instancePlacementAttempts, 1 do
		local x = getRandomNumber(self.instanceMinCoordinate, self.instanceMaxCoordinate)
		local y = getRandomNumber(self.instanceMinCoordinate, self.instanceMaxCoordinate)

		if self:isPlacementAvailable(instanceZone, x, y) then
			return x, y
		end
	end

	return nil, nil
end

function ig88FactoryArena:reserveInstancePlacement(instanceID, instanceZone, x, y)
	local gridX = self:getPlacementGridCoordinate(x)
	local gridY = self:getPlacementGridCoordinate(y)

	writeData(self:getKey(instanceID, "spawnX"), x)
	writeData(self:getKey(instanceID, "spawnY"), y)
	writeData(self:getKey(instanceID, "spawnGridX"), gridX)
	writeData(self:getKey(instanceID, "spawnGridY"), gridY)
	writeData(self:getPlacementReservationKey(instanceZone, gridX, gridY), instanceID)
end

function ig88FactoryArena:releaseInstancePlacement(instanceID)
	local instanceZone = readStringData(self:getKey(instanceID, "zone"))
	local gridX = readData(self:getKey(instanceID, "spawnGridX"))
	local gridY = readData(self:getKey(instanceID, "spawnGridY"))

	if instanceZone ~= nil and instanceZone ~= "" then
		deleteData(self:getPlacementReservationKey(instanceZone, gridX, gridY))
	end

	deleteData(self:getKey(instanceID, "spawnX"))
	deleteData(self:getKey(instanceID, "spawnY"))
	deleteData(self:getKey(instanceID, "spawnGridX"))
	deleteData(self:getKey(instanceID, "spawnGridY"))
end

function ig88FactoryArena:createInstanceBuilding(instanceZone)
	local x, y = self:findAvailableInstanceLocation(instanceZone)

	if x == nil or y == nil then
		printLuaError("ig88FactoryArena: unable to find an open instance location in zone " .. instanceZone)
		return nil
	end

	local pBuilding = spawnSceneObject(instanceZone, self.buildingTemplate, x, 0, y, 0, 0)

	if pBuilding == nil then
		return nil
	end

	SceneObject(pBuilding):setCustomObjectName("IG-88 Factory Arena")
	return pBuilding
end

function ig88FactoryArena:spawnExitTerminal(instanceID)
	local cellID = self:getEntryCellID(instanceID)

	if cellID == 0 then
		printLuaError("ig88FactoryArena: unable to resolve exit cell for instance " .. instanceID)
		return nil
	end

	local pTerminal = self:spawnTrackedSceneObject(instanceID, self.exitTerminalTemplate, self.exitTerminalX, self.exitTerminalZ, self.exitTerminalY, self.exitTerminalHeading, cellID)

	if pTerminal == nil then
		printLuaError("ig88FactoryArena: unable to spawn exit terminal for instance " .. instanceID)
		return nil
	end

	SceneObject(pTerminal):setCustomObjectName("Exit IG-88 Factory Arena [Instance]")
	SceneObject(pTerminal):setObjectMenuComponent("ig88FactoryExitMenuComponent")
	writeData(SceneObject(pTerminal):getObjectID() .. ":ig88FactoryArenaInstance", instanceID)
	writeData(self:getKey(instanceID, "exitTerminalID"), SceneObject(pTerminal):getObjectID())
	return pTerminal
end

function ig88FactoryArena:inviteGroupMembers(pLeader, instanceID)
	local groupSize = CreatureObject(pLeader):getGroupSize()

	for i = 0, groupSize - 1, 1 do
		local pMember = CreatureObject(pLeader):getGroupMember(i)

		if pMember ~= nil and pMember ~= pLeader and not SceneObject(pMember):isAiAgent() then
			self:sendAuthorizationSui(pMember, pLeader, instanceID)
		end
	end
end

function ig88FactoryArena:sendAuthorizationSui(pPlayer, pLeader, instanceID)
	if pPlayer == nil then
		return
	end

	writeData(SceneObject(pPlayer):getObjectID() .. ":ig88FactoryPendingInstance", instanceID)

	local sui = SuiMessageBox.new("ig88FactoryArena", "authorizationSuiCallback")
	sui.setTitle("IG-88 Factory Arena [Instance]")
	sui.setPrompt(CreatureObject(pLeader):getFirstName() .. " has started an IG-88 Factory Arena [Instance]. Do you want to enter?")
	sui.setOkButtonText("Yes")
	sui.setCancelButtonText("No")

	local pageId = sui.sendTo(pPlayer)
	createEvent(30 * 1000, "ig88FactoryArena", "closeAuthorizationSui", pPlayer, pageId)
end

function ig88FactoryArena:closeAuthorizationSui(pPlayer, pageId)
	if pPlayer == nil then
		return
	end

	local pGhost = CreatureObject(pPlayer):getPlayerObject()

	if pGhost ~= nil then
		PlayerObject(pGhost):removeSuiBox(pageId)
	end
end

function ig88FactoryArena:authorizationSuiCallback(pPlayer, pSui, eventIndex, args, ...)
	if pPlayer == nil then
		return
	end

	local playerID = SceneObject(pPlayer):getObjectID()
	local instanceID = readData(playerID .. ":ig88FactoryPendingInstance")
	deleteData(playerID .. ":ig88FactoryPendingInstance")

	if eventIndex == 1 then
		CreatureObject(pPlayer):sendSystemMessage("You decline to enter the IG-88 Factory Arena [Instance].")
		return
	end

	if instanceID == 0 or readData(self:getKey(instanceID, "active")) ~= 1 then
		CreatureObject(pPlayer):sendSystemMessage("That IG-88 Factory Arena [Instance] is no longer available.")
		return
	end

	if not self:canJoinInstance(pPlayer, instanceID) then
		CreatureObject(pPlayer):sendSystemMessage("You are no longer in the group assigned to that IG-88 Factory Arena [Instance].")
		return
	end

	if self:getPlayerInstance(pPlayer) ~= 0 then
		CreatureObject(pPlayer):sendSystemMessage("You are already assigned to an IG-88 Factory Arena [Instance].")
		return
	end

	if CreatureObject(pPlayer):isRidingMount() then
		CreatureObject(pPlayer):sendSystemMessage("You fail to enter the instance because you are riding a mount.")
		return
	end

	self:transportPlayerToInstance(pPlayer, instanceID)
end

function ig88FactoryArena:sendExitSui(pPlayer)
	if pPlayer == nil then
		return
	end

	local instanceID = self:getPlayerInstance(pPlayer)

	if instanceID == 0 then
		CreatureObject(pPlayer):sendSystemMessage("You are not currently inside an IG-88 Factory Arena [Instance].")
		return
	end

	local sui = SuiMessageBox.new("ig88FactoryArena", "exitInstanceSuiCallback")
	sui.setTitle("Exit IG-88 Factory Arena [Instance]")
	sui.setPrompt("Leave the IG-88 Factory Arena [Instance] and return to Lok?")
	sui.setOkButtonText("Exit")
	sui.setCancelButtonText("Stay")
	sui.sendTo(pPlayer)
end

function ig88FactoryArena:exitInstanceSuiCallback(pPlayer, pSui, eventIndex, args, ...)
	if pPlayer == nil then
		return
	end

	if eventIndex == 1 then
		CreatureObject(pPlayer):sendSystemMessage("You remain inside the IG-88 Factory Arena [Instance].")
		return
	end

	local instanceID = self:getPlayerInstance(pPlayer)

	if instanceID == 0 then
		CreatureObject(pPlayer):sendSystemMessage("That IG-88 Factory Arena [Instance] is no longer available.")
		return
	end

	self:ejectPlayer(pPlayer, "You leave the IG-88 Factory Arena [Instance].")
end

function ig88FactoryArena:transportPlayerToInstance(pPlayer, instanceID)
	local cellID = self:getEntryCellID(instanceID)
	local instanceZone = self:getInstanceZoneForInstance(instanceID)

	if cellID == 0 or instanceZone == "" then
		self:logActivationStep(instanceID, "transportPlayerToInstance failed validation zone=" .. instanceZone .. " cell=" .. cellID)
		CreatureObject(pPlayer):sendSystemMessage("Unable to find the IG-88 Factory Arena [Instance] entry cell.")
		return false
	end

	self:logActivationStep(instanceID, "transportPlayerToInstance switching player " .. SceneObject(pPlayer):getObjectID() .. " to " .. instanceZone .. " cell " .. cellID)
	writeData(SceneObject(pPlayer):getObjectID() .. ":ig88FactoryInstance", instanceID)
	writeData(self:getKey(instanceID, "member:" .. SceneObject(pPlayer):getObjectID()), 1)
	deleteData(SceneObject(pPlayer):getObjectID() .. ":ig88FactoryPendingInstance")
	dropObserver(LOGGEDIN, "ig88FactoryArena", "onPlayerLoggedIn", pPlayer)
	createObserver(LOGGEDIN, "ig88FactoryArena", "onPlayerLoggedIn", pPlayer, 1)
	SceneObject(pPlayer):switchZone(instanceZone, self.entryX, self.entryZ, self.entryY, cellID)
	return true
end

function ig88FactoryArena:onPlayerLoggedIn(pPlayer)
	if pPlayer == nil then
		return 0
	end

	createEvent(5 * 1000, "ig88FactoryArena", "recoverPlayerAfterLogin", pPlayer, "")
	return 0
end

function ig88FactoryArena:recoverPlayerAfterLogin(pPlayer)
	if pPlayer == nil then
		return
	end

	local playerID = SceneObject(pPlayer):getObjectID()
	local instanceID = readData(playerID .. ":ig88FactoryInstance")

	if instanceID ~= 0 then
		if getSceneObject(instanceID) == nil or readData(self:getKey(instanceID, "active")) ~= 1 then
			self:ejectPlayer(pPlayer, "Your IG-88 Factory Arena [Instance] was closed while the server was offline.")
		end

		return
	end

	if not self:isManagedInstanceZone(SceneObject(pPlayer):getZoneName()) then
		return
	end

	local x = SceneObject(pPlayer):getWorldPositionX()
	local y = SceneObject(pPlayer):getWorldPositionY()
	local parentID = SceneObject(pPlayer):getParentID()

	if x < self.instanceTerrainMinCoordinate or x > self.instanceTerrainMaxCoordinate or y < self.instanceTerrainMinCoordinate or y > self.instanceTerrainMaxCoordinate or self:isInInstanceCoordinateRange(x, y) or (parentID ~= 0 and getSceneObject(parentID) == nil) then
		self:ejectPlayer(pPlayer, "Your previous IG-88 Factory Arena [Instance] is no longer active.")
	end
end

function ig88FactoryArena:isInInstanceCoordinateRange(x, y)
	return x >= self.instanceMinCoordinate and x <= self.instanceMaxCoordinate and y >= self.instanceMinCoordinate and y <= self.instanceMaxCoordinate
end

function ig88FactoryArena:spawnInitialEncounter(instanceID)
	self:spawnTriggerDroid(instanceID)
end

function ig88FactoryArena:spawnTriggerDroid(instanceID)
	local cellID = self:getArenaCellID(instanceID)

	if cellID == 0 then
		return nil
	end

	local pTrigger = self:spawnEncounterMobile(instanceID, "ig88_factory_mouse_droid", self.triggerX, self.triggerZ, self.triggerY, 0, "trigger", 0, cellID)

	if pTrigger ~= nil then
		SceneObject(pTrigger):setCustomObjectName("Defective Mouse Droid")
		SceneObject(pTrigger):setObjectMenuComponent("ig88FactoryTriggerMenuComponent")
		writeData(SceneObject(pTrigger):getObjectID() .. ":ig88FactoryTriggerInstance", instanceID)
	end

	return pTrigger
end

function ig88FactoryArena:kickTriggerDroid(pTrigger, pPlayer)
	if pTrigger == nil or pPlayer == nil then
		return 0
	end

	if not SceneObject(pPlayer):isPlayerCreature() then
		return 0
	end

	local triggerID = SceneObject(pTrigger):getObjectID()

	if readData(triggerID .. ":ig88FactoryResolved") == 1 then
		return 0
	end

	CreatureObject(pPlayer):sendSystemMessage("You kick the defective mouse droid. Factory alarms begin to scream.")
	SceneObject(pTrigger):playEffect("clienteffect/combat_grenade_proton.cef", "")
	deleteData(triggerID .. ":ig88FactoryTriggerInstance")
	self:resolveEncounterMobByID(triggerID)
	SceneObject(pTrigger):destroyObjectFromWorld()
	return 0
end

function ig88FactoryArena:startEncounter(instanceID)
	if readData(self:getKey(instanceID, "started")) == 1 then
		return
	end

	writeData(self:getKey(instanceID, "started"), 1)
	self:sendInstanceMessage(instanceID, "Factory alarms blare as the first defense wave deploys.")
	self:spawnPhaseOne(instanceID)
end

function ig88FactoryArena:spawnPhaseOne(instanceID)
	writeData(self:getKey(instanceID, "phase"), 1)
	local cellID = self:getArenaCellID(instanceID)
	local total = 0

	for _, doorData in pairs(ig88FactoryDoorSpawns) do
		local x = doorData[1]
		local z = doorData[2]
		local y = doorData[3]
		local heading = doorData[4]

		local pBattleOne = self:spawnEncounterMobile(instanceID, "ig88_factory_battle_droid", x, z, y, heading, "wave_droid", 1, cellID)

		if pBattleOne ~= nil then
			total = total + 1
			self:sendMobileToArenaCenter(pBattleOne, cellID)
		end

		local pBattleTwo = self:spawnEncounterMobile(instanceID, "ig88_factory_battle_droid", x * 0.7, z, y * 0.7, heading, "wave_droid", 1, cellID)

		if pBattleTwo ~= nil then
			total = total + 1
			self:sendMobileToArenaCenter(pBattleTwo, cellID)
		end

		local pBomb = self:spawnEncounterMobile(instanceID, "ig88_factory_bomb_droid", x, z, y, heading, "bomb_droid", 1, cellID)

		if pBomb ~= nil then
			total = total + 1
			SceneObject(pBomb):setCustomObjectName("Bomb Mouse Droid")
			AiAgent(pBomb):addObjectFlag(AI_NOAIAGGRO)
			createObserver(DESTINATIONREACHED, "ig88FactoryArena", "bombDroidReachedDestination", pBomb)
			self:sendMobileToArenaCenter(pBomb, cellID)
			createEvent(self.bombDroidFallbackDetonationMs, "ig88FactoryArena", "explodeBombDroid", pBomb, "")
		end
	end

	writeData(self:getKey(instanceID, "phaseRemaining"), total)
end

function ig88FactoryArena:spawnPhaseTwo(instanceID)
	writeData(self:getKey(instanceID, "phase"), 2)
	self:sendInstanceMessage(instanceID, "The first wave is down. Four factory droidekas roll into the arena.")

	local cellID = self:getArenaCellID(instanceID)
	local total = 0

	for _, doorData in pairs(ig88FactoryDoorSpawns) do
		local pDroideka = self:spawnEncounterMobile(instanceID, "ig88_factory_droideka", doorData[1], doorData[2], doorData[3], doorData[4], "droideka", 2, cellID)

		if pDroideka ~= nil then
			total = total + 1
			self:sendMobileToArenaCenter(pDroideka, cellID)
		end
	end

	writeData(self:getKey(instanceID, "phaseRemaining"), total)
end

function ig88FactoryArena:spawnPhaseThree(instanceID)
	writeData(self:getKey(instanceID, "phase"), 3)
	self:sendInstanceMessage(instanceID, "Warning: heavy flamethrower battle droids emerging from the main gate.")

	local cellID = self:getArenaCellID(instanceID)
	local total = 0
	local pLeft = self:spawnEncounterMobile(instanceID, "ig88_factory_flame_droid", ig88FactoryBossSpawn[1], ig88FactoryBossSpawn[2], ig88FactoryBossSpawn[3], ig88FactoryBossSpawn[4], "flame_droid", 3, cellID)
	local pRight = self:spawnEncounterMobile(instanceID, "ig88_factory_flame_droid", ig88FactoryBossSpawn[1], ig88FactoryBossSpawn[2], ig88FactoryBossSpawn[3], ig88FactoryBossSpawn[4], "flame_droid", 3, cellID)

	if pLeft ~= nil then
		total = total + 1
		SceneObject(pLeft):setCustomObjectName("Heavy Flamethrower Droid")
		createObserver(DESTINATIONREACHED, "ig88FactoryArena", "flameDroidReachedDestination", pLeft)
		writeStringData(SceneObject(pLeft):getObjectID() .. ":ig88FactoryRoute", "clockwise")
		createEvent(1000, "ig88FactoryArena", "moveFlameDroidToNextPoint", pLeft, "")
	end

	if pRight ~= nil then
		total = total + 1
		SceneObject(pRight):setCustomObjectName("Heavy Flamethrower Droid")
		createObserver(DESTINATIONREACHED, "ig88FactoryArena", "flameDroidReachedDestination", pRight)
		writeStringData(SceneObject(pRight):getObjectID() .. ":ig88FactoryRoute", "counterClockwise")
		createEvent(1000, "ig88FactoryArena", "moveFlameDroidToNextPoint", pRight, "")
	end

	writeData(self:getKey(instanceID, "phaseRemaining"), total)
end

function ig88FactoryArena:spawnPhaseFour(instanceID)
	writeData(self:getKey(instanceID, "phase"), 4)
	self:sendInstanceMessage(instanceID, "IG-88 enters the arena. Eliminate the droideka support waves whenever his defenses lock in.")

	local cellID = self:getArenaCellID(instanceID)
	local pBoss = self:spawnEncounterMobile(instanceID, "ig88_factory_ig88", ig88FactoryBossSpawn[1], ig88FactoryBossSpawn[2], ig88FactoryBossSpawn[3], ig88FactoryBossSpawn[4], "ig88", 4, cellID)

	if pBoss ~= nil then
		SceneObject(pBoss):setCustomObjectName("IG-88")
		createObserver(DAMAGERECEIVED, "ig88FactoryArena", "bossDamaged", pBoss)
		createObserver(DESTINATIONREACHED, "ig88FactoryArena", "bossReachedDestination", pBoss)
		writeData(self:getKey(instanceID, "bossThresholdIndex"), 0)
		self:sendMobileToPoint(pBoss, ig88FactoryBossPatrolCenter[1], ig88FactoryBossPatrolCenter[2], ig88FactoryBossPatrolCenter[3], cellID)
	end
end

function ig88FactoryArena:spawnShieldDroidekas(instanceID)
	local cellID = self:getArenaCellID(instanceID)
	local total = 0

	for _, doorData in pairs(ig88FactoryDoorSpawns) do
		local pDroideka = self:spawnEncounterMobile(instanceID, "ig88_factory_droideka", doorData[1], doorData[2], doorData[3], doorData[4], "shield_droideka", 4, cellID)

		if pDroideka ~= nil then
			total = total + 1
			self:sendMobileToArenaCenter(pDroideka, cellID)
		end
	end

	writeData(self:getKey(instanceID, "shieldDroidekaCount"), total)
end

function ig88FactoryArena:sendMobileToPoint(pMobile, x, z, y, cellID)
	if pMobile == nil or cellID == 0 then
		return
	end

	AiAgent(pMobile):setMovementState(AI_PATROLLING)
	AiAgent(pMobile):setNextPosition(x, z, y, cellID)
end

function ig88FactoryArena:sendMobileToArenaCenter(pMobile, cellID)
	self:sendMobileToPoint(pMobile, ig88FactoryArenaCenter[1], ig88FactoryArenaCenter[2], ig88FactoryArenaCenter[3], cellID)
end

function ig88FactoryArena:stopMobileAtDestination(pMobile)
	if pMobile == nil then
		return
	end

	AiAgent(pMobile):addObjectFlag(AI_STATIONARY)
end

function ig88FactoryArena:spawnEncounterMobile(instanceID, template, x, z, y, heading, role, phase, cellID)
	local pMobile = self:spawnTrackedMobile(instanceID, template, x, z, y, heading, cellID)

	if pMobile ~= nil then
		local mobileID = SceneObject(pMobile):getObjectID()
		writeData(mobileID .. ":ig88FactoryInstance", instanceID)
		writeStringData(mobileID .. ":ig88FactoryRole", role)
		writeData(mobileID .. ":ig88FactoryPhase", phase)
		writeData(mobileID .. ":ig88FactoryResolved", 0)
		createObserver(OBJECTDESTRUCTION, "ig88FactoryArena", "onEncounterMobDestroyed", pMobile)
	end

	return pMobile
end

function ig88FactoryArena:onEncounterMobDestroyed(pMobile, pPlayer)
	if pMobile == nil then
		return 0
	end

	self:resolveEncounterMobByID(SceneObject(pMobile):getObjectID())
	return 0
end

function ig88FactoryArena:resolveEncounterMobByID(mobileID)
	if mobileID == 0 or readData(mobileID .. ":ig88FactoryResolved") == 1 then
		return
	end

	writeData(mobileID .. ":ig88FactoryResolved", 1)

	local instanceID = readData(mobileID .. ":ig88FactoryInstance")
	local phase = readData(mobileID .. ":ig88FactoryPhase")
	local role = readStringData(mobileID .. ":ig88FactoryRole")

	deleteData(mobileID .. ":ig88FactoryInstance")
	deleteData(mobileID .. ":ig88FactoryPhase")
	deleteData(mobileID .. ":ig88FactoryResolved")
	deleteStringData(mobileID .. ":ig88FactoryRole")
	deleteStringData(mobileID .. ":ig88FactoryRoute")
	deleteData(mobileID .. ":ig88FactoryTriggerInstance")

	if instanceID == 0 then
		return
	end

	if role == "trigger" then
		self:startEncounter(instanceID)
		return
	elseif role == "ig88" then
		self:handleVictory(instanceID)
		return
	elseif role == "shield_droideka" then
		local remaining = math.max(0, readData(self:getKey(instanceID, "shieldDroidekaCount")) - 1)
		writeData(self:getKey(instanceID, "shieldDroidekaCount"), remaining)

		if remaining == 0 then
			self:deactivateIG88Shield(instanceID)
		end

		return
	end

	local remaining = math.max(0, readData(self:getKey(instanceID, "phaseRemaining")) - 1)
	writeData(self:getKey(instanceID, "phaseRemaining"), remaining)

	if remaining > 0 then
		return
	end

	if phase == 1 then
		self:spawnPhaseTwo(instanceID)
	elseif phase == 2 then
		self:spawnPhaseThree(instanceID)
	elseif phase == 3 then
		self:spawnPhaseFour(instanceID)
	end
end

function ig88FactoryArena:bombDroidReachedDestination(pDroid)
	if pDroid == nil then
		return 0
	end

	createEvent(250, "ig88FactoryArena", "explodeBombDroid", pDroid, "")
	return 0
end

function ig88FactoryArena:explodeBombDroid(pDroid)
	if pDroid == nil then
		return
	end

	local droidID = SceneObject(pDroid):getObjectID()

	if readData(droidID .. ":ig88FactoryResolved") == 1 then
		return
	end

	CreatureObject(pDroid):playEffect("clienteffect/combat_grenade_proton.cef", "")
	self:applyRadiusDamage(pDroid, self.bombDroidRadius, self.bombDroidMinDamage, self.bombDroidMaxDamage, "A bomb mouse droid detonates in the arena!")
	self:resolveEncounterMobByID(droidID)
	SceneObject(pDroid):destroyObjectFromWorld()
end

function ig88FactoryArena:moveFlameDroidToNextPoint(pDroid)
	if pDroid == nil then
		return
	end

	local routeName = readStringData(SceneObject(pDroid):getObjectID() .. ":ig88FactoryRoute")
	local route = ig88FactoryClockwiseRoute

	if routeName == "counterClockwise" then
		route = ig88FactoryCounterClockwiseRoute
	end

	local point = route[1]
	self:sendMobileToPoint(pDroid, point[1], point[2], point[3], SceneObject(pDroid):getParentID())
end

function ig88FactoryArena:flameDroidReachedDestination(pDroid)
	if pDroid == nil then
		return 0
	end

	local droidID = SceneObject(pDroid):getObjectID()

	if readData(droidID .. ":ig88FactoryResolved") == 1 then
		return 0
	end

	self:spawnFlameZone(readData(droidID .. ":ig88FactoryInstance"), pDroid)
	self:stopMobileAtDestination(pDroid)
	return 0
end

function ig88FactoryArena:bossReachedDestination(pBoss)
	if pBoss == nil then
		return 0
	end

	if readData(SceneObject(pBoss):getObjectID() .. ":ig88FactoryResolved") == 1 then
		return 0
	end

	self:stopMobileAtDestination(pBoss)
	return 0
end

function ig88FactoryArena:spawnFlameZone(instanceID, pDroid)
	if instanceID == 0 or pDroid == nil then
		return nil
	end

	local zoneName = self:getInstanceZoneForInstance(instanceID)
	local parentID = SceneObject(pDroid):getParentID()
	local pArea = spawnActiveArea(zoneName, "object/active_area.iff", SceneObject(pDroid):getWorldPositionX(), SceneObject(pDroid):getWorldPositionZ(), SceneObject(pDroid):getWorldPositionY(), self.flameZoneRadius, parentID)

	if pArea ~= nil then
		self:trackObject(instanceID, pArea)
		writeData(SceneObject(pArea):getObjectID() .. ":ig88FactoryInstance", instanceID)
		writeData(SceneObject(pArea):getObjectID() .. ":ig88FactorySource", SceneObject(pDroid):getObjectID())
		createObserver(ENTEREDAREA, "ig88FactoryArena", "notifyFlameZoneEntered", pArea)
		createEvent(1500, "ig88FactoryArena", "primeFlameZone", pArea, "")
	end

	return pArea
end

function ig88FactoryArena:notifyFlameZoneEntered(pArea, pPlayer)
	if pArea == nil or pPlayer == nil or not SceneObject(pPlayer):isPlayerCreature() then
		return 0
	end

	CreatureObject(pPlayer):sendSystemMessage("The floor glows with superheated plasma.")
	return 0
end

function ig88FactoryArena:primeFlameZone(pArea)
	if pArea == nil then
		return
	end

	local sourceID = readData(SceneObject(pArea):getObjectID() .. ":ig88FactorySource")
	local pSource = getSceneObject(sourceID)

	if pSource ~= nil then
		self:applyRadiusDamage(pSource, self.flameZoneRadius, self.flameZoneMinDamage, self.flameZoneMaxDamage, "A flamethrower wash engulfs the marked section of the arena.")
	end

	SceneObject(pArea):destroyObjectFromWorld()
	deleteData(SceneObject(pArea):getObjectID() .. ":ig88FactoryInstance")
	deleteData(SceneObject(pArea):getObjectID() .. ":ig88FactorySource")
end

function ig88FactoryArena:bossDamaged(pBoss, pPlayer)
	if pBoss == nil then
		return 0
	end

	local instanceID = readData(SceneObject(pBoss):getObjectID() .. ":ig88FactoryInstance")

	if instanceID == 0 then
		return 0
	end

	if readData(self:getKey(instanceID, "shieldDroidekaCount")) > 0 then
		CreatureObject(pBoss):setHAM(0, readData(self:getKey(instanceID, "bossShieldHealth")))
		CreatureObject(pBoss):setHAM(3, readData(self:getKey(instanceID, "bossShieldAction")))
		CreatureObject(pBoss):setHAM(6, readData(self:getKey(instanceID, "bossShieldMind")))
		return 0
	end

	local thresholdIndex = readData(self:getKey(instanceID, "bossThresholdIndex"))
	local nextThreshold = self.ig88ShieldThresholds[thresholdIndex + 1]

	if nextThreshold == nil then
		return 0
	end

	local bossHealth = CreatureObject(pBoss):getHAM(0)
	local bossMaxHealth = CreatureObject(pBoss):getMaxHAM(0)

	if bossMaxHealth <= 0 then
		return 0
	end

	if bossHealth <= (bossMaxHealth * (nextThreshold / 100)) then
		writeData(self:getKey(instanceID, "bossThresholdIndex"), thresholdIndex + 1)
		self:activateIG88Shield(instanceID, pBoss)
	end

	return 0
end

function ig88FactoryArena:activateIG88Shield(instanceID, pBoss)
	if pBoss == nil then
		return
	end

	writeData(self:getKey(instanceID, "bossShieldHealth"), CreatureObject(pBoss):getHAM(0))
	writeData(self:getKey(instanceID, "bossShieldAction"), CreatureObject(pBoss):getHAM(3))
	writeData(self:getKey(instanceID, "bossShieldMind"), CreatureObject(pBoss):getHAM(6))
	self:sendInstanceMessage(instanceID, "Droideka guard reinforcements lock IG-88 behind a defensive shield.")
	spatialChat(pBoss, "Secondary guards, advance and restore my perimeter.")
	self:spawnShieldDroidekas(instanceID)
end

function ig88FactoryArena:deactivateIG88Shield(instanceID)
	deleteData(self:getKey(instanceID, "bossShieldHealth"))
	deleteData(self:getKey(instanceID, "bossShieldAction"))
	deleteData(self:getKey(instanceID, "bossShieldMind"))
	self:sendInstanceMessage(instanceID, "IG-88's defenses collapse. He is vulnerable again.")
end

function ig88FactoryArena:applyRadiusDamage(pSource, radius, minDamage, maxDamage, message)
	if pSource == nil then
		return
	end

	local playerTable = SceneObject(pSource):getPlayersInRange(radius)

	if playerTable == nil then
		return
	end

	for i = 1, #playerTable, 1 do
		local pPlayer = playerTable[i]

		if pPlayer ~= nil and SceneObject(pPlayer):isPlayerCreature() and SceneObject(pPlayer):getParentID() == SceneObject(pSource):getParentID() and SceneObject(pPlayer):isInRangeWithObject3d(pSource, radius) then
			local damage = getRandomNumber(minDamage, maxDamage)
			CreatureObject(pPlayer):inflictDamage(pSource, 0, damage, true)
			CreatureObject(pPlayer):inflictDamage(pSource, 3, math.floor(damage / 2), true)
			CreatureObject(pPlayer):playEffect("clienteffect/combat_grenade_proton.cef", "")

			if message ~= nil and message ~= "" then
				CreatureObject(pPlayer):sendSystemMessage(message)
			end
		end
	end
end

function ig88FactoryArena:trackObject(instanceID, pObject)
	if pObject == nil then
		return
	end

	local nextIndex = readData(self:getKey(instanceID, "trackedCount")) + 1
	writeData(self:getKey(instanceID, "trackedCount"), nextIndex)
	writeData(self:getKey(instanceID, "tracked:" .. nextIndex), SceneObject(pObject):getObjectID())
end

function ig88FactoryArena:spawnTrackedSceneObject(instanceID, template, x, z, y, heading, cellID)
	local instanceZone = self:getInstanceZoneForInstance(instanceID)

	if instanceZone == "" or cellID == 0 then
		return nil
	end

	local pObject = spawnSceneObject(instanceZone, template, x, z, y, cellID, math.rad(heading))

	if pObject ~= nil then
		self:trackObject(instanceID, pObject)
	end

	return pObject
end

function ig88FactoryArena:spawnTrackedMobile(instanceID, template, x, z, y, heading, cellID)
	local instanceZone = self:getInstanceZoneForInstance(instanceID)

	if instanceZone == "" or cellID == 0 then
		return nil
	end

	local pMobile = spawnMobile(instanceZone, template, 0, x, z, y, heading, cellID)

	if pMobile ~= nil then
		self:trackObject(instanceID, pMobile)
	end

	return pMobile
end

function ig88FactoryArena:getPreferredCellID(instanceID, suffix, preferredIndexes)
	local cachedCellID = readData(self:getKey(instanceID, suffix))

	if cachedCellID ~= 0 and getSceneObject(cachedCellID) ~= nil then
		return cachedCellID
	end

	local pBuilding = getSceneObject(instanceID)

	if pBuilding == nil then
		return 0
	end

	local totalCells = BuildingObject(pBuilding):getTotalCellNumber()

	if totalCells <= 0 then
		printLuaError("ig88FactoryArena: building " .. instanceID .. " has no cells while resolving " .. suffix)
		return 0
	end

	self:logActivationStep(instanceID, "resolving " .. suffix .. " across " .. totalCells .. " cells")

	for i = 1, #preferredIndexes, 1 do
		local preferredIndex = preferredIndexes[i]

		if preferredIndex >= 1 and preferredIndex <= totalCells then
			local pCell = BuildingObject(pBuilding):getCell(preferredIndex)

			if pCell ~= nil then
				local cellID = SceneObject(pCell):getObjectID()
				writeData(self:getKey(instanceID, suffix), cellID)
				return cellID
			end
		end
	end

	for i = 1, totalCells, 1 do
		local pCell = BuildingObject(pBuilding):getCell(i)

		if pCell ~= nil then
			local cellID = SceneObject(pCell):getObjectID()
			writeData(self:getKey(instanceID, suffix), cellID)
			return cellID
		end
	end

	return 0
end

function ig88FactoryArena:logActivationStep(instanceID, message)
	print("ig88FactoryArena [" .. tostring(instanceID) .. "] " .. message)
end

function ig88FactoryArena:getEntryCellID(instanceID)
	return self:getPreferredCellID(instanceID, "entryCellID", self.entryCellPreferences)
end

function ig88FactoryArena:getArenaCellID(instanceID)
	return self:getPreferredCellID(instanceID, "arenaCellID", self.arenaCellPreferences)
end

function ig88FactoryArena:checkInstanceTimer(pBuilding)
	if pBuilding == nil then
		return
	end

	local instanceID = SceneObject(pBuilding):getObjectID()

	if readData(self:getKey(instanceID, "active")) ~= 1 then
		return
	end

	local startTime = readData(self:getKey(instanceID, "startTime"))
	local elapsed = os.time() - startTime
	local timeLeftSecs = self.durationSeconds - elapsed

	if timeLeftSecs <= 0 then
		self:expireInstance(pBuilding)
		return
	end

	local minutesLeft = math.floor(timeLeftSecs / 60)
	self:sendInstanceMessage(instanceID, "IG-88 Factory Arena [Instance] time remaining: " .. minutesLeft .. " minutes.")

	local nextCheck = 5 * 60 * 1000

	if timeLeftSecs <= 60 then
		nextCheck = 10 * 1000
	elseif timeLeftSecs <= 10 * 60 then
		nextCheck = 60 * 1000
	end

	createEvent(nextCheck, "ig88FactoryArena", "checkInstanceTimer", pBuilding, "")
end

function ig88FactoryArena:expireInstance(pBuilding)
	if pBuilding == nil then
		return
	end

	local instanceID = SceneObject(pBuilding):getObjectID()
	self:sendInstanceMessage(instanceID, "The IG-88 Factory Arena [Instance] timer has expired.")
	self:resetInstance(pBuilding)
end

function ig88FactoryArena:handleVictory(instanceID)
	self:sendInstanceMessage(instanceID, "IG-88 has been destroyed. You will be removed from the instance in 120 seconds.")

	local pBuilding = getSceneObject(instanceID)

	if pBuilding ~= nil then
		createEvent(120 * 1000, "ig88FactoryArena", "resetInstance", pBuilding, "")
	end
end

function ig88FactoryArena:resetInstance(pBuilding)
	if pBuilding == nil then
		return
	end

	local instanceID = SceneObject(pBuilding):getObjectID()
	writeData(self:getKey(instanceID, "active"), 0)
	self:ejectAllPlayers(pBuilding, "You are now being removed from the IG-88 Factory Arena [Instance].")
	createEvent(10 * 1000, "ig88FactoryArena", "destroyInstance", pBuilding, "")
end

function ig88FactoryArena:destroyInstance(pBuilding)
	if pBuilding == nil then
		return
	end

	local instanceID = SceneObject(pBuilding):getObjectID()

	if self:hasPlayersInside(pBuilding) then
		self:ejectAllPlayers(pBuilding, "You are now being removed from the IG-88 Factory Arena [Instance].")
		createEvent(10 * 1000, "ig88FactoryArena", "destroyInstance", pBuilding, "")
		return
	end

	self:cleanupTrackedObjects(instanceID)
	self:cleanupInstanceData(instanceID)
	SceneObject(pBuilding):destroyObjectFromWorld()
end

function ig88FactoryArena:onExitedInstance(pBuilding, pPlayer)
	if pBuilding == nil or pPlayer == nil or not SceneObject(pPlayer):isPlayerCreature() then
		return 0
	end

	deleteData(SceneObject(pPlayer):getObjectID() .. ":ig88FactoryInstance")

	if not self:hasPlayersInside(pBuilding) then
		createEvent(60 * 1000, "ig88FactoryArena", "destroyInstance", pBuilding, "")
	end

	return 0
end

function ig88FactoryArena:ejectAllPlayers(pBuilding, message)
	for i = 1, BuildingObject(pBuilding):getTotalCellNumber(), 1 do
		local pCell = BuildingObject(pBuilding):getCell(i)

		if pCell ~= nil then
			for j = SceneObject(pCell):getContainerObjectsSize(), 1, -1 do
				local pObject = SceneObject(pCell):getContainerObject(j - 1)

				if pObject ~= nil and SceneObject(pObject):isPlayerCreature() then
					self:ejectPlayer(pObject, message)
				end
			end
		end
	end
end

function ig88FactoryArena:ejectPlayer(pPlayer, message)
	if pPlayer == nil then
		return
	end

	if message ~= nil then
		CreatureObject(pPlayer):sendSystemMessage(message)
	end

	local returnZ = getWorldFloor(self.returnX, self.returnY, self.returnZone)
	deleteData(SceneObject(pPlayer):getObjectID() .. ":ig88FactoryInstance")
	dropObserver(LOGGEDIN, "ig88FactoryArena", "onPlayerLoggedIn", pPlayer)
	SceneObject(pPlayer):switchZone(self.returnZone, self.returnX, returnZ, self.returnY, 0)
end

function ig88FactoryArena:sendInstanceMessage(instanceID, message)
	local pBuilding = getSceneObject(instanceID)

	if pBuilding == nil then
		return
	end

	for i = 1, BuildingObject(pBuilding):getTotalCellNumber(), 1 do
		local pCell = BuildingObject(pBuilding):getCell(i)

		if pCell ~= nil then
			for j = SceneObject(pCell):getContainerObjectsSize(), 1, -1 do
				local pObject = SceneObject(pCell):getContainerObject(j - 1)

				if pObject ~= nil and SceneObject(pObject):isPlayerCreature() then
					CreatureObject(pObject):sendSystemMessage(message)
				end
			end
		end
	end
end

function ig88FactoryArena:hasPlayersInside(pBuilding)
	for i = 1, BuildingObject(pBuilding):getTotalCellNumber(), 1 do
		local pCell = BuildingObject(pBuilding):getCell(i)

		if pCell ~= nil then
			for j = SceneObject(pCell):getContainerObjectsSize(), 1, -1 do
				local pObject = SceneObject(pCell):getContainerObject(j - 1)

				if pObject ~= nil and SceneObject(pObject):isPlayerCreature() then
					return true
				end
			end
		end
	end

	return false
end

function ig88FactoryArena:getPlayerInstance(pPlayer)
	local playerID = SceneObject(pPlayer):getObjectID()
	local instanceID = readData(playerID .. ":ig88FactoryInstance")

	if instanceID == 0 then
		return 0
	end

	if getSceneObject(instanceID) == nil or readData(self:getKey(instanceID, "active")) ~= 1 then
		deleteData(playerID .. ":ig88FactoryInstance")
		return 0
	end

	return instanceID
end

function ig88FactoryArena:getGroupInstance(groupID)
	if groupID == 0 then
		return 0
	end

	local instanceID = readData(self:getGroupKey(groupID))

	if instanceID == 0 then
		return 0
	end

	if getSceneObject(instanceID) == nil or readData(self:getKey(instanceID, "active")) ~= 1 then
		deleteData(self:getGroupKey(groupID))
		return 0
	end

	return instanceID
end

function ig88FactoryArena:canJoinInstance(pPlayer, instanceID)
	if pPlayer == nil or instanceID == 0 then
		return false
	end

	if readData(self:getKey(instanceID, "active")) ~= 1 then
		return false
	end

	if not CreatureObject(pPlayer):isGrouped() then
		return false
	end

	return CreatureObject(pPlayer):getGroupID() == readData(self:getKey(instanceID, "groupID"))
end

function ig88FactoryArena:getKey(instanceID, suffix)
	return "ig88FactoryArena:" .. instanceID .. ":" .. suffix
end

function ig88FactoryArena:getGroupKey(groupID)
	return "ig88FactoryArena:group:" .. groupID .. ":instance"
end

function ig88FactoryArena:cleanupTrackedObjects(instanceID)
	local trackedCount = readData(self:getKey(instanceID, "trackedCount"))

	for i = 1, trackedCount, 1 do
		local objectID = readData(self:getKey(instanceID, "tracked:" .. i))
		local pObject = getSceneObject(objectID)

		if pObject ~= nil then
			SceneObject(pObject):destroyObjectFromWorld()
		end

		deleteData(self:getKey(instanceID, "tracked:" .. i))
	end
end

function ig88FactoryArena:cleanupInstanceData(instanceID)
	local exitTerminalID = readData(self:getKey(instanceID, "exitTerminalID"))

	if exitTerminalID ~= 0 then
		deleteData(exitTerminalID .. ":ig88FactoryArenaInstance")
	end

	self:releaseInstancePlacement(instanceID)

	deleteData(self:getKey(instanceID, "active"))
	deleteData(self:getKey(instanceID, "leaderID"))
	deleteData(self:getGroupKey(readData(self:getKey(instanceID, "groupID"))))
	deleteData(self:getKey(instanceID, "groupID"))
	deleteData(self:getKey(instanceID, "startTime"))
	deleteData(self:getKey(instanceID, "exitTerminalID"))
	deleteData(self:getKey(instanceID, "phase"))
	deleteData(self:getKey(instanceID, "phaseRemaining"))
	deleteData(self:getKey(instanceID, "started"))
	deleteData(self:getKey(instanceID, "entryCellID"))
	deleteData(self:getKey(instanceID, "arenaCellID"))
	deleteData(self:getKey(instanceID, "bossThresholdIndex"))
	deleteData(self:getKey(instanceID, "bossShieldHealth"))
	deleteData(self:getKey(instanceID, "bossShieldAction"))
	deleteData(self:getKey(instanceID, "bossShieldMind"))
	deleteData(self:getKey(instanceID, "shieldDroidekaCount"))
	deleteData(self:getKey(instanceID, "trackedCount"))
	deleteStringData(self:getKey(instanceID, "zone"))
end
