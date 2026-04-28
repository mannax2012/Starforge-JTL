local ObjectManager = require("managers.object.object_manager")

exarKun = ScreenPlay:new {
	numberOfActs = 1,
	screenplayName = "exarKun",
	instanceZone = "exarkuntomb",
	fallbackInstanceZone = "tutorial",
	returnZone = "yavin4",
	maxGroupSize = 10,
	durationSeconds = 2 * 60 * 60,
	buildingTemplate = "object/building/heroic/exar_kun_tomb.iff",
	exitTerminalTemplate = "object/tangible/item/yavin4_exar_kun_entry.iff",
	instanceTerrainMinCoordinate = -8192,
	instanceTerrainMaxCoordinate = 8192,
	instanceMinCoordinate = 6000,
	instanceMaxCoordinate = 7800,
	instancePlacementClearRadius = 250,
	instancePlacementGridSize = 250,
	instancePlacementAttempts = 40,
	entryCell = "r1",
	entryX = -11.8,
	entryZ = 0.2,
	entryY = -121.8,
	exitTerminalX = -15.6,
	exitTerminalZ = 0.2,
	exitTerminalY = -97.0,
	exitTerminalHeading = 89,
	returnX = 5093,
	returnZ = 73.5,
	returnY = 5546.1,
}

registerScreenPlay("exarKun", true)

function exarKun:start()
end

function exarKun:getAvailableInstanceZone()
	if isZoneEnabled(self.instanceZone) then
		return self.instanceZone
	end

	if self.fallbackInstanceZone ~= nil and self.fallbackInstanceZone ~= "" and isZoneEnabled(self.fallbackInstanceZone) then
		return self.fallbackInstanceZone
	end

	return ""
end

function exarKun:getInstanceZoneForInstance(instanceID)
	if instanceID ~= nil and instanceID ~= 0 then
		local zoneName = readStringData(self:getKey(instanceID, "zone"))

		if zoneName ~= nil and zoneName ~= "" then
			return zoneName
		end
	end

	return self:getAvailableInstanceZone()
end

function exarKun:isManagedInstanceZone(zoneName)
	if zoneName == nil or zoneName == "" then
		return false
	end

	return zoneName == self.instanceZone or zoneName == self.fallbackInstanceZone
end

function exarKun:activate(pPlayer)
	if pPlayer == nil then
		return false
	end

	local instanceZone = self:getAvailableInstanceZone()

	if not isZoneEnabled("yavin4") or instanceZone == "" then
		CreatureObject(pPlayer):sendSystemMessage("The Exar Kun's Tomb [Instance] is currently unavailable.")
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
		CreatureObject(pPlayer):sendSystemMessage("You must be in a group to start the Exar Kun's Tomb [Instance].")
		return false
	end

	if CreatureObject(pPlayer):getGroupSize() > self.maxGroupSize then
		CreatureObject(pPlayer):sendSystemMessage("Your group is too large. Exar Kun allows a maximum of 10 players.")
		return false
	end

	local playerInstanceID = self:getPlayerInstance(pPlayer)

	if playerInstanceID ~= 0 then
		CreatureObject(pPlayer):sendSystemMessage("You are already assigned to an Exar Kun's Tomb [Instance].")
		return false
	end

	local groupID = CreatureObject(pPlayer):getGroupID()
	local groupInstanceID = self:getGroupInstance(groupID)

	if groupInstanceID ~= 0 then
		self:transportPlayerToInstance(pPlayer, groupInstanceID)
		CreatureObject(pPlayer):sendSystemMessage("You enter your group's active Exar Kun's Tomb [Instance].")
		return true
	end

	local pBuilding = self:createInstanceBuilding(instanceZone)

	if pBuilding == nil then
		CreatureObject(pPlayer):sendSystemMessage("Unable to create the Exar Kun's Tomb [Instance]. Please try again later.")
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

	createObserver(EXITEDBUILDING, "exarKun", "onExitedInstance", pBuilding)

	self:spawnExitTerminal(instanceID)
	self:transportPlayerToInstance(pPlayer, instanceID)
	self:inviteGroupMembers(pPlayer, instanceID)
	self:spawnInitialEncounter(instanceID)
	self:sendInstanceMessage(instanceID, "Instance started: you have 120 minutes to defeat Exar Kun.")

	createEvent(5 * 60 * 1000, "exarKun", "checkInstanceTimer", pBuilding, "")
	return true
end

function exarKun:getPlacementGridCoordinate(value)
	return math.floor(value / self.instancePlacementGridSize)
end

function exarKun:getPlacementReservationKey(instanceZone, gridX, gridY)
	return self.screenplayName .. ":placement:" .. instanceZone .. ":" .. gridX .. ":" .. gridY
end

function exarKun:isPlacementAvailable(instanceZone, x, y)
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

function exarKun:findAvailableInstanceLocation(instanceZone)
	for attempt = 1, self.instancePlacementAttempts, 1 do
		local x = getRandomNumber(self.instanceMinCoordinate, self.instanceMaxCoordinate)
		local y = getRandomNumber(self.instanceMinCoordinate, self.instanceMaxCoordinate)

		if self:isPlacementAvailable(instanceZone, x, y) then
			return x, y
		end
	end

	return nil, nil
end

function exarKun:reserveInstancePlacement(instanceID, instanceZone, x, y)
	local gridX = self:getPlacementGridCoordinate(x)
	local gridY = self:getPlacementGridCoordinate(y)

	writeData(self:getKey(instanceID, "spawnX"), x)
	writeData(self:getKey(instanceID, "spawnY"), y)
	writeData(self:getKey(instanceID, "spawnGridX"), gridX)
	writeData(self:getKey(instanceID, "spawnGridY"), gridY)
	writeData(self:getPlacementReservationKey(instanceZone, gridX, gridY), instanceID)
end

function exarKun:releaseInstancePlacement(instanceID)
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

function exarKun:createInstanceBuilding(instanceZone)
	local x, y = self:findAvailableInstanceLocation(instanceZone)

	if x == nil or y == nil then
		printLuaError("exarKun: unable to find an open instance location in zone " .. instanceZone)
		return nil
	end

	local pBuilding = spawnSceneObject(instanceZone, self.buildingTemplate, x, 0, y, 0, 0)

	if pBuilding == nil then
		return nil
	end

	SceneObject(pBuilding):setCustomObjectName("Exar Kun Temple")
	return pBuilding
end

function exarKun:spawnExitTerminal(instanceID)
	local pTerminal = self:spawnInstanceSceneObject(instanceID, self.exitTerminalTemplate, self.exitTerminalX, self.exitTerminalZ, self.exitTerminalY, self.exitTerminalHeading, self.entryCell)

	if pTerminal == nil then
		printLuaError("exarKun: unable to spawn exit terminal for instance " .. instanceID)
		return nil
	end

	SceneObject(pTerminal):setCustomObjectName("Exit Exar Kun's Tomb [Instance]")
	SceneObject(pTerminal):setObjectMenuComponent("exarKunExitMenuComponent")
	writeData(SceneObject(pTerminal):getObjectID() .. ":exarKunInstance", instanceID)
	writeData(self:getKey(instanceID, "exitTerminalID"), SceneObject(pTerminal):getObjectID())
	return pTerminal
end

function exarKun:inviteGroupMembers(pLeader, instanceID)
	local groupSize = CreatureObject(pLeader):getGroupSize()

	for i = 0, groupSize - 1, 1 do
		local pMember = CreatureObject(pLeader):getGroupMember(i)

		if pMember ~= nil and pMember ~= pLeader and not SceneObject(pMember):isAiAgent() and CreatureObject(pLeader):isInRangeWithObject(pMember, 50) then
			self:sendAuthorizationSui(pMember, pLeader, instanceID)
		end
	end
end

function exarKun:sendAuthorizationSui(pPlayer, pLeader, instanceID)
	if pPlayer == nil then
		return
	end

	writeData(SceneObject(pPlayer):getObjectID() .. ":exarKunPendingInstance", instanceID)

	local sui = SuiMessageBox.new("exarKun", "authorizationSuiCallback")
	sui.setTitle("Exar Kun's Tomb [Instance]")
	sui.setPrompt(CreatureObject(pLeader):getFirstName() .. " has started an Exar Kun's Tomb [Instance]. Do you want to enter?")
	sui.setOkButtonText("Yes")
	sui.setCancelButtonText("No")

	local pageId = sui.sendTo(pPlayer)
	createEvent(30 * 1000, "exarKun", "closeAuthorizationSui", pPlayer, pageId)
end

function exarKun:authorizationSuiCallback(pPlayer, pSui, eventIndex, args, ...)
	if pPlayer == nil then
		return
	end

	local playerID = SceneObject(pPlayer):getObjectID()
	local instanceID = readData(playerID .. ":exarKunPendingInstance")
	deleteData(playerID .. ":exarKunPendingInstance")

	if eventIndex == 1 then
		CreatureObject(pPlayer):sendSystemMessage("You decline to enter Exar Kun's Tomb [Instance].")
		return
	end

	if instanceID == 0 or readData(self:getKey(instanceID, "active")) ~= 1 then
		CreatureObject(pPlayer):sendSystemMessage("That Exar Kun's Tomb [Instance] is no longer available.")
		return
	end

	if not self:canJoinInstance(pPlayer, instanceID) then
		CreatureObject(pPlayer):sendSystemMessage("You are no longer in the group assigned to that Exar Kun's Tomb [Instance].")
		return
	end

	if self:getPlayerInstance(pPlayer) ~= 0 then
		CreatureObject(pPlayer):sendSystemMessage("You are already assigned to an Exar Kun's Tomb [Instance].")
		return
	end

	if CreatureObject(pPlayer):isRidingMount() then
		CreatureObject(pPlayer):sendSystemMessage("You fail to enter the instance because you are riding a mount.")
		return
	end

	self:transportPlayerToInstance(pPlayer, instanceID)
end

function exarKun:closeAuthorizationSui(pPlayer, pageId)
	if pPlayer == nil then
		return
	end

	local pGhost = CreatureObject(pPlayer):getPlayerObject()

	if pGhost ~= nil then
		PlayerObject(pGhost):removeSuiBox(pageId)
	end
end

function exarKun:sendExitSui(pPlayer)
	if pPlayer == nil then
		return
	end

	local instanceID = self:getPlayerInstance(pPlayer)

	if instanceID == 0 then
		CreatureObject(pPlayer):sendSystemMessage("You are not currently inside an Exar Kun's Tomb [Instance].")
		return
	end

	local sui = SuiMessageBox.new("exarKun", "exitInstanceSuiCallback")
	sui.setTitle("Exit Exar Kun's Tomb [Instance]")
	sui.setPrompt("Leave the Exar Kun's Tomb [Instance] and return to Yavin IV?")
	sui.setOkButtonText("Exit")
	sui.setCancelButtonText("Stay")
	sui.sendTo(pPlayer)
end

function exarKun:exitInstanceSuiCallback(pPlayer, pSui, eventIndex, args, ...)
	if pPlayer == nil then
		return
	end

	if eventIndex == 1 then
		CreatureObject(pPlayer):sendSystemMessage("You remain inside the Exar Kun's Tomb [Instance].")
		return
	end

	local instanceID = self:getPlayerInstance(pPlayer)

	if instanceID == 0 then
		CreatureObject(pPlayer):sendSystemMessage("That Exar Kun's Tomb [Instance] is no longer available.")
		return
	end

	self:ejectPlayer(pPlayer, "You leave the Exar Kun's Tomb [Instance].")
end

function exarKun:transportPlayerToInstance(pPlayer, instanceID)
	local cellID = self:getCellID(instanceID, self.entryCell)
	local instanceZone = self:getInstanceZoneForInstance(instanceID)

	if cellID == 0 or instanceZone == "" then
		CreatureObject(pPlayer):sendSystemMessage("Unable to find the Exar Kun's Tomb [Instance] entry cell.")
		return false
	end

	writeData(SceneObject(pPlayer):getObjectID() .. ":exarKunInstance", instanceID)
	writeData(self:getKey(instanceID, "member:" .. SceneObject(pPlayer):getObjectID()), 1)
	deleteData(SceneObject(pPlayer):getObjectID() .. ":exarKunPendingInstance")
	dropObserver(LOGGEDIN, "exarKun", "onPlayerLoggedIn", pPlayer)
	createObserver(LOGGEDIN, "exarKun", "onPlayerLoggedIn", pPlayer, 1)
	SceneObject(pPlayer):switchZone(instanceZone, self.entryX, self.entryZ, self.entryY, cellID)
	return true
end

function exarKun:onPlayerLoggedIn(pPlayer)
	if pPlayer == nil then
		return 0
	end

	createEvent(5 * 1000, "exarKun", "recoverPlayerAfterLogin", pPlayer, "")
	return 0
end

function exarKun:recoverPlayerAfterLogin(pPlayer)
	if pPlayer == nil then
		return
	end

	local playerID = SceneObject(pPlayer):getObjectID()
	local instanceID = readData(playerID .. ":exarKunInstance")

	if instanceID ~= 0 then
		if getSceneObject(instanceID) == nil or readData(self:getKey(instanceID, "active")) ~= 1 then
			self:ejectPlayer(pPlayer, "Your Exar Kun's Tomb [Instance] was closed while the server was offline.")
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
		self:ejectPlayer(pPlayer, "Your previous Exar Kun's Tomb [Instance] is no longer active.")
	end
end

function exarKun:isInInstanceCoordinateRange(x, y)
	return x >= self.instanceMinCoordinate and x <= self.instanceMaxCoordinate and y >= self.instanceMinCoordinate and y <= self.instanceMaxCoordinate
end

function exarKun:spawnInitialEncounter(instanceID)
	for i = 1, #exarKunTrashSpawns, 1 do
		self:spawnFromData(instanceID, exarKunTrashSpawns[i])
	end

	self:spawnBarricades(instanceID, exarKunInitialBarricades)
	self:spawnBoss(instanceID, 1)
end

function exarKun:getEncounterTarget(pPreferredTarget, pAnchor)
	if pPreferredTarget ~= nil and SceneObject(pPreferredTarget):isPlayerCreature() then
		return pPreferredTarget
	end

	if pAnchor ~= nil then
		local targetID = CreatureObject(pAnchor):getTargetID()

		if targetID ~= 0 then
			local pTarget = getSceneObject(targetID)

			if pTarget ~= nil then
				return pTarget
			end
		end
	end

	return nil
end

function exarKun:activateEncounterAdd(pMobile, pPreferredTarget, pAnchor)
	if pMobile == nil then
		return
	end

	local pTarget = self:getEncounterTarget(pPreferredTarget, pAnchor)

	if pTarget ~= nil then
		CreatureObject(pMobile):engageCombat(pTarget)
		return
	end

	if pAnchor ~= nil and SceneObject(pMobile):isAiAgent() then
		AiAgent(pMobile):addObjectFlag(AI_FOLLOW)
		AiAgent(pMobile):setFollowObject(pAnchor)
		AiAgent(pMobile):setMovementState(AI_FOLLOWING)
		AiAgent(pMobile):setAITemplate()
	end
end

function exarKun:spawnBoss(instanceID, bossNumber, pTarget)
	local bossData = exarKunBossSpawns[bossNumber]

	if bossData == nil then
		return nil
	end

	if bossNumber == 4 then
		self:spawnWave(instanceID, exarKunBossFourGuards, pTarget)
	end

	local pBoss = self:spawnFromData(instanceID, bossData)

	if pBoss ~= nil then
		self:activateEncounterAdd(pBoss, pTarget, nil)
		writeData(SceneObject(pBoss):getObjectID() .. ":exarKunBossNumber", bossNumber)
		writeData(self:getKey(instanceID, "boss" .. bossNumber .. "State"), 0)
		createObserver(OBJECTDESTRUCTION, "exarKun", "bossKilled", pBoss)
		createObserver(DAMAGERECEIVED, "exarKun", "bossDamaged", pBoss)

		if bossNumber == 3 then
			spatialChat(pBoss, "The secrets of the master's sanctum are not for you. This is as far as you come.")
		elseif bossNumber == 5 then
			spatialChat(pBoss, "You tread into the abyss. I was the greatest Dark Lord of the Sith. I am Exar Kun.")
		end
	end

	return pBoss
end

function exarKun:bossDamaged(pBoss, pPlayer)
	if pBoss == nil then
		return 0
	end

	local instanceID = readData(SceneObject(pBoss):getObjectID() .. ":exarKunInstance")
	local bossNumber = readData(SceneObject(pBoss):getObjectID() .. ":exarKunBossNumber")

	if instanceID == 0 or bossNumber == 0 then
		return 0
	end

	local boss = LuaCreatureObject(pBoss)

	if boss == nil then
		return 0
	end

	local bossHealth = boss:getHAM(0)
	local bossAction = boss:getHAM(3)
	local bossMaxHealth = boss:getMaxHAM(0)
	local bossMaxAction = boss:getMaxHAM(3)

	if bossMaxHealth <= 0 then
		return 0
	end

	if bossAction <= (bossMaxAction * 0.3) then
		CreatureObject(pBoss):setHAM(3, bossMaxAction)
		CreatureObject(pBoss):playEffect("clienteffect/pl_force_channel_self.cef", "")
		spatialChat(pBoss, "My strength is renewed. Thank you, master!")
	end

	local stateKey = self:getKey(instanceID, "boss" .. bossNumber .. "State")
	local state = readData(stateKey)
	local phases = exarKunBossPhases[bossNumber]

	if phases == nil then
		return 0
	end

	local nextPhase = phases[state + 1]

	if nextPhase ~= nil and bossHealth <= (bossMaxHealth * (nextPhase.percent / 100)) then
		if nextPhase.text ~= nil then
			spatialChat(pBoss, nextPhase.text)
		end

		if nextPhase.effect ~= nil then
			CreatureObject(pBoss):playEffect(nextPhase.effect, "")
		end

		if nextPhase.spawns ~= nil then
			self:spawnWave(instanceID, nextPhase.spawns, pPlayer, pBoss)
		end

		writeData(stateKey, state + 1)
	end

	return 0
end

function exarKun:bossKilled(pBoss, pPlayer)
	if pBoss == nil then
		return 0
	end

	local instanceID = readData(SceneObject(pBoss):getObjectID() .. ":exarKunInstance")
	local bossNumber = readData(SceneObject(pBoss):getObjectID() .. ":exarKunBossNumber")

	if instanceID == 0 or bossNumber == 0 then
		return 0
	end

	if bossNumber >= 5 then
		self:destroyBarricades(instanceID)
		self:handleVictory(instanceID)
	else
		local unlocks = exarKunBarricadeUnlocks[bossNumber]

		if unlocks ~= nil then
			self:destroyBarricades(instanceID, unlocks)
		end

		self:sendInstanceMessage(instanceID, "A guardian of Exar Kun has fallen. The path forward opens.")
		self:spawnBoss(instanceID, bossNumber + 1, pPlayer)
	end

	return 0
end

function exarKun:spawnWave(instanceID, spawnData, pTarget, pAnchor)
	for i = 1, #spawnData, 1 do
		local pMobile = self:spawnFromData(instanceID, spawnData[i])

		if pMobile ~= nil then
			CreatureObject(pMobile):playEffect("clienteffect/pl_force_regain_consciousness_self.cef", "")
			self:activateEncounterAdd(pMobile, pTarget, pAnchor)
		end
	end
end

function exarKun:spawnFromData(instanceID, spawnData)
	return self:spawnInstanceMobile(instanceID, spawnData[1], spawnData[2], spawnData[3], spawnData[4], spawnData[5], spawnData[6])
end

function exarKun:spawnInstanceSceneObject(instanceID, template, x, z, y, heading, cellName)
	local cellID = self:getCellID(instanceID, cellName)
	local instanceZone = self:getInstanceZoneForInstance(instanceID)

	if cellID == 0 or instanceZone == "" then
		printLuaError("exarKun: unable to find cell " .. cellName .. " for scene object in instance " .. instanceID)
		return nil
	end

	return spawnSceneObject(instanceZone, template, x, z, y, cellID, math.rad(heading))
end

function exarKun:spawnInstanceMobile(instanceID, template, x, z, y, heading, cellName)
	local cellID = self:getCellID(instanceID, cellName)
	local instanceZone = self:getInstanceZoneForInstance(instanceID)

	if cellID == 0 or instanceZone == "" then
		printLuaError("exarKun: unable to find cell " .. cellName .. " for instance " .. instanceID)
		return nil
	end

	local pMobile = spawnMobile(instanceZone, template, 0, x, z, y, heading, cellID)

	if pMobile ~= nil then
		writeData(SceneObject(pMobile):getObjectID() .. ":exarKunInstance", instanceID)
	end

	return pMobile
end

function exarKun:spawnBarricades(instanceID, barricadeIndexes)
	local indexes = barricadeIndexes or self:getAllBarricadeIndexes()

	for i = 1, #indexes, 1 do
		local barricadeIndex = indexes[i]
		local barricadeData = exarKunBarricadeSpawns[barricadeIndex]

		if barricadeData ~= nil and readData(self:getKey(instanceID, "barricade:" .. barricadeIndex)) == 0 then
			local pBarricade = self:spawnInstanceSceneObject(instanceID, barricadeData.template, barricadeData.x, barricadeData.z, barricadeData.y, barricadeData.heading, barricadeData.cell)

			if pBarricade ~= nil then
				SceneObject(pBarricade):setCustomObjectName("Collapsed Stone")
				writeData(SceneObject(pBarricade):getObjectID() .. ":exarKunInstance", instanceID)
				writeData(self:getKey(instanceID, "barricade:" .. barricadeIndex), SceneObject(pBarricade):getObjectID())
			end
		end
	end
end

function exarKun:destroyBarricades(instanceID, barricadeIndexes)
	local indexes = barricadeIndexes or self:getAllBarricadeIndexes()

	for i = 1, #indexes, 1 do
		local barricadeIndex = indexes[i]
		local barricadeID = readData(self:getKey(instanceID, "barricade:" .. barricadeIndex))

		if barricadeID ~= 0 then
			local pBarricade = getSceneObject(barricadeID)

			if pBarricade ~= nil then
				SceneObject(pBarricade):destroyObjectFromWorld()
			end

			deleteData(barricadeID .. ":exarKunInstance")
			deleteData(self:getKey(instanceID, "barricade:" .. barricadeIndex))
		end
	end
end

function exarKun:getAllBarricadeIndexes()
	local indexes = {}

	for i = 1, #exarKunBarricadeSpawns, 1 do
		indexes[#indexes + 1] = i
	end

	return indexes
end

function exarKun:checkInstanceTimer(pBuilding)
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
	self:sendInstanceMessage(instanceID, "Exar Kun's Tomb [Instance] time remaining: " .. minutesLeft .. " minutes.")

	local nextCheck = 5 * 60 * 1000

	if timeLeftSecs <= 60 then
		nextCheck = 10 * 1000
	elseif timeLeftSecs <= 10 * 60 then
		nextCheck = 60 * 1000
	end

	createEvent(nextCheck, "exarKun", "checkInstanceTimer", pBuilding, "")
end

function exarKun:expireInstance(pBuilding)
	if pBuilding == nil then
		return
	end

	local instanceID = SceneObject(pBuilding):getObjectID()
	self:sendInstanceMessage(instanceID, "The Exar Kun's Tomb [Instance] timer has expired.")
	self:resetInstance(pBuilding)
end

function exarKun:handleVictory(instanceID)
	self:sendInstanceMessage(instanceID, "You and your group have defeated Exar Kun. You will be removed from the instance in 120 seconds.")
	self:awardBadgeToAll(instanceID)

	local pBuilding = getSceneObject(instanceID)

	if pBuilding ~= nil then
		createEvent(120 * 1000, "exarKun", "resetInstance", pBuilding, "")
	end
end

function exarKun:resetInstance(pBuilding)
	if pBuilding == nil then
		return
	end

	local instanceID = SceneObject(pBuilding):getObjectID()
	writeData(self:getKey(instanceID, "active"), 0)
	self:destroyBarricades(instanceID)
	self:ejectAllPlayers(pBuilding, "You are now being removed from the Exar Kun's Tomb [Instance].")
	createEvent(10 * 1000, "exarKun", "destroyInstance", pBuilding, "")
end

function exarKun:destroyInstance(pBuilding)
	if pBuilding == nil then
		return
	end

	local instanceID = SceneObject(pBuilding):getObjectID()

	if self:hasPlayersInside(pBuilding) then
		self:ejectAllPlayers(pBuilding, "You are now being removed from the Exar Kun's Tomb [Instance].")
		createEvent(10 * 1000, "exarKun", "destroyInstance", pBuilding, "")
		return
	end

	self:destroyBarricades(instanceID)
	self:cleanupInstanceData(instanceID)
	SceneObject(pBuilding):destroyObjectFromWorld()
end

function exarKun:onExitedInstance(pBuilding, pPlayer)
	if pBuilding == nil or pPlayer == nil or not SceneObject(pPlayer):isPlayerCreature() then
		return 0
	end

	deleteData(SceneObject(pPlayer):getObjectID() .. ":exarKunInstance")

	if not self:hasPlayersInside(pBuilding) then
		createEvent(60 * 1000, "exarKun", "destroyInstance", pBuilding, "")
	end

	return 0
end

function exarKun:ejectAllPlayers(pBuilding, message)
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

function exarKun:ejectPlayer(pPlayer, message)
	if pPlayer == nil then
		return
	end

	if message ~= nil then
		CreatureObject(pPlayer):sendSystemMessage(message)
	end

	deleteData(SceneObject(pPlayer):getObjectID() .. ":exarKunInstance")
	dropObserver(LOGGEDIN, "exarKun", "onPlayerLoggedIn", pPlayer)
	SceneObject(pPlayer):switchZone(self.returnZone, self.returnX, self.returnZ, self.returnY, 0)
end

function exarKun:awardBadgeToAll(instanceID)
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
					self:awardBadge(pObject)
				end
			end
		end
	end
end

function exarKun:awardBadge(pPlayer)
	local pGhost = CreatureObject(pPlayer):getPlayerObject()

	if pGhost ~= nil and not PlayerObject(pGhost):hasBadge(152) then
		PlayerObject(pGhost):awardBadge(152)
	end
end

function exarKun:sendInstanceMessage(instanceID, message)
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

function exarKun:hasPlayersInside(pBuilding)
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

function exarKun:getPlayerInstance(pPlayer)
	local playerID = SceneObject(pPlayer):getObjectID()
	local instanceID = readData(playerID .. ":exarKunInstance")

	if instanceID == 0 then
		return 0
	end

	if getSceneObject(instanceID) == nil or readData(self:getKey(instanceID, "active")) ~= 1 then
		deleteData(playerID .. ":exarKunInstance")
		return 0
	end

	return instanceID
end

function exarKun:getGroupInstance(groupID)
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

function exarKun:canJoinInstance(pPlayer, instanceID)
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

function exarKun:getCellID(instanceID, cellName)
	local pBuilding = getSceneObject(instanceID)

	if pBuilding == nil then
		return 0
	end

	local pCell = BuildingObject(pBuilding):getNamedCell(cellName)

	if pCell == nil then
		return 0
	end

	return SceneObject(pCell):getObjectID()
end

function exarKun:getKey(instanceID, suffix)
	return "exarKun:" .. instanceID .. ":" .. suffix
end

function exarKun:getGroupKey(groupID)
	return "exarKun:group:" .. groupID .. ":instance"
end

function exarKun:cleanupInstanceData(instanceID)
	local exitTerminalID = readData(self:getKey(instanceID, "exitTerminalID"))

	if exitTerminalID ~= 0 then
		deleteData(exitTerminalID .. ":exarKunInstance")
	end

	self:releaseInstancePlacement(instanceID)

	deleteData(self:getKey(instanceID, "active"))
	deleteData(self:getKey(instanceID, "leaderID"))
	deleteData(self:getGroupKey(readData(self:getKey(instanceID, "groupID"))))
	deleteData(self:getKey(instanceID, "groupID"))
	deleteData(self:getKey(instanceID, "startTime"))
	deleteData(self:getKey(instanceID, "exitTerminalID"))
	deleteData(self:getKey(instanceID, "barricadeSpawnState"))
	deleteStringData(self:getKey(instanceID, "zone"))

	for i = 1, 5, 1 do
		deleteData(self:getKey(instanceID, "boss" .. i .. "State"))
	end

	for i = 1, #exarKunBarricadeSpawns, 1 do
		deleteData(self:getKey(instanceID, "barricade:" .. i))
	end
end
