-- Axkva Instanced Dungeon: by Levarris for use with Stardust.
local ObjectManager = require("managers.object.object_manager")

axkvaMin = ScreenPlay:new {
	numberOfActs = 1,
	screenplayName = "axkvaMin",
	instanceZone = "axkvaminprison",
	fallbackInstanceZone = "tutorial",
	returnZone = "dathomir",
	maxGroupSize = 10,
	durationSeconds = 60 * 60,
	buildingTemplate = "object/building/heroic/axkva_min_lair.iff",
	exitTerminalTemplate = "object/tangible/item/axkva_min_entrance.iff",
	instanceTerrainMinCoordinate = -8192,
	instanceTerrainMaxCoordinate = 8192,
	instanceMinCoordinate = 3200,
	instanceMaxCoordinate = 5200,
	instancePlacementClearRadius = 250,
	instancePlacementGridSize = 250,
	instancePlacementAttempts = 40,
	grovoPoisonCooldown = 60,
	grovoPoisonRadius = 18,
	grovoPoisonMinDamage = 550,
	grovoPoisonMaxDamage = 850,
	entryCellIndex = 1,
	encounterCellIndex = 2,
	entryX = 30.4,
	entryZ = 0.1,
	entryY = 0.3,
	exitTerminalX = 30.4,
	exitTerminalZ = 0.1,
	exitTerminalY = 0.3,
	exitTerminalHeading = 0,
	returnX = -4029,
	returnZ = 132,
	returnY = -19,
}

registerScreenPlay("axkvaMin", true)

function axkvaMin:start()
end

function axkvaMin:getAvailableInstanceZone()
	if isZoneEnabled(self.instanceZone) then
		return self.instanceZone
	end

	if self.fallbackInstanceZone ~= nil and self.fallbackInstanceZone ~= "" and isZoneEnabled(self.fallbackInstanceZone) then
		return self.fallbackInstanceZone
	end

	return ""
end

function axkvaMin:getInstanceZoneForInstance(instanceID)
	if instanceID ~= nil and instanceID ~= 0 then
		local zoneName = readStringData(self:getKey(instanceID, "zone"))

		if zoneName ~= nil and zoneName ~= "" then
			return zoneName
		end
	end

	return self:getAvailableInstanceZone()
end

function axkvaMin:isManagedInstanceZone(zoneName)
	if zoneName == nil or zoneName == "" then
		return false
	end

	return zoneName == self.instanceZone or zoneName == self.fallbackInstanceZone
end

function axkvaMin:sendStartSui(pPlayer)
	if pPlayer == nil then
		return
	end

	local sui = SuiMessageBox.new("axkvaMin", "startSuiCallback")
	sui.setTitle("The Chamber of Banishment")
	sui.setPrompt("You are about to start a Chamber of Banishment [Instance]. This will create a new instance for your group and send travel invitations to the other group members. Continue?")
	sui.setOkButtonText("Start")
	sui.setCancelButtonText("Cancel")

	local pageId = sui.sendTo(pPlayer)
	createEvent(30 * 1000, "axkvaMin", "closeStartSui", pPlayer, pageId)
end

function axkvaMin:startSuiCallback(pPlayer, pSui, eventIndex, args, ...)
	if pPlayer == nil then
		return
	end

	if eventIndex == 1 then
		CreatureObject(pPlayer):sendSystemMessage("You decide not to start the Chamber of Banishment [Instance].")
		return
	end

	createEvent(1, "axkvaMin", "activate", pPlayer, "")
end

function axkvaMin:closeStartSui(pPlayer, pageId)
	if pPlayer == nil then
		return
	end

	local pGhost = CreatureObject(pPlayer):getPlayerObject()

	if pGhost ~= nil then
		PlayerObject(pGhost):removeSuiBox(pageId)
	end
end

function axkvaMin:activate(pPlayer)
	if pPlayer == nil then
		return false
	end

	local instanceZone = self:getAvailableInstanceZone()

	if not isZoneEnabled("dathomir") or instanceZone == "" then
		CreatureObject(pPlayer):sendSystemMessage("The Chamber of Banishment [Instance] is currently unavailable.")
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
		CreatureObject(pPlayer):sendSystemMessage("You must be in a group to start the Chamber of Banishment [Instance].")
		return false
	end

	if CreatureObject(pPlayer):getGroupSize() > self.maxGroupSize then
		CreatureObject(pPlayer):sendSystemMessage("Your group is too large. Axkva Min allows a maximum of 10 players.")
		return false
	end

	local playerInstanceID = self:getPlayerInstance(pPlayer)

	if playerInstanceID ~= 0 then
		CreatureObject(pPlayer):sendSystemMessage("You are already assigned to a Chamber of Banishment [Instance].")
		return false
	end

	local groupID = CreatureObject(pPlayer):getGroupID()
	local groupInstanceID = self:getGroupInstance(groupID)

	if groupInstanceID ~= 0 then
		self:transportPlayerToInstance(pPlayer, groupInstanceID)
		CreatureObject(pPlayer):sendSystemMessage("You enter your group's active Chamber of Banishment [Instance].")
		return true
	end

	local pBuilding = self:createInstanceBuilding(instanceZone)

	if pBuilding == nil then
		CreatureObject(pPlayer):sendSystemMessage("Unable to create the Chamber of Banishment [Instance]. Please try again later.")
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

	createObserver(EXITEDBUILDING, "axkvaMin", "onExitedInstance", pBuilding)

	self:spawnExitTerminal(instanceID)
	self:transportPlayerToInstance(pPlayer, instanceID)
	self:inviteGroupMembers(pPlayer, instanceID)
	self:spawnBossRoomOne(instanceID)
	self:sendInstanceMessage(instanceID, "Instance started: you have 60 minutes to complete the Chamber of Banishment.")

	createEvent(5 * 60 * 1000, "axkvaMin", "checkInstanceTimer", pBuilding, "")

	return true
end

function axkvaMin:getPlacementGridCoordinate(value)
	return math.floor(value / self.instancePlacementGridSize)
end

function axkvaMin:getPlacementReservationKey(instanceZone, gridX, gridY)
	return self.screenplayName .. ":placement:" .. instanceZone .. ":" .. gridX .. ":" .. gridY
end

function axkvaMin:isPlacementAvailable(instanceZone, x, y)
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

function axkvaMin:findAvailableInstanceLocation(instanceZone)
	for attempt = 1, self.instancePlacementAttempts, 1 do
		local x = getRandomNumber(self.instanceMinCoordinate, self.instanceMaxCoordinate)
		local y = getRandomNumber(self.instanceMinCoordinate, self.instanceMaxCoordinate)

		if self:isPlacementAvailable(instanceZone, x, y) then
			return x, y
		end
	end

	return nil, nil
end

function axkvaMin:reserveInstancePlacement(instanceID, instanceZone, x, y)
	local gridX = self:getPlacementGridCoordinate(x)
	local gridY = self:getPlacementGridCoordinate(y)

	writeData(self:getKey(instanceID, "spawnX"), x)
	writeData(self:getKey(instanceID, "spawnY"), y)
	writeData(self:getKey(instanceID, "spawnGridX"), gridX)
	writeData(self:getKey(instanceID, "spawnGridY"), gridY)
	writeData(self:getPlacementReservationKey(instanceZone, gridX, gridY), instanceID)
end

function axkvaMin:releaseInstancePlacement(instanceID)
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

function axkvaMin:createInstanceBuilding(instanceZone)
	local x, y = self:findAvailableInstanceLocation(instanceZone)

	if x == nil or y == nil then
		printLuaError("axkvaMin: unable to find an open instance location in zone " .. instanceZone)
		return nil
	end

	local pBuilding = spawnSceneObject(instanceZone, self.buildingTemplate, x, 0, y, 0, 0)

	if pBuilding == nil then
		return nil
	end

	SceneObject(pBuilding):setCustomObjectName("The Chamber of Banishment")
	return pBuilding
end

function axkvaMin:spawnExitTerminal(instanceID)
	local pTerminal = self:spawnInstanceSceneObject(instanceID, self.exitTerminalTemplate, self.exitTerminalX, self.exitTerminalZ, self.exitTerminalY, self.exitTerminalHeading, self.entryCellIndex)

	if pTerminal == nil then
		printLuaError("axkvaMin: unable to spawn exit terminal for instance " .. instanceID)
		return nil
	end

	SceneObject(pTerminal):setCustomObjectName("Exit the Chamber of Banishment [Instance]")
	SceneObject(pTerminal):setObjectMenuComponent("axkvaMinExitMenuComponent")
	writeData(SceneObject(pTerminal):getObjectID() .. ":axkvaMinInstance", instanceID)
	writeData(self:getKey(instanceID, "exitTerminalID"), SceneObject(pTerminal):getObjectID())
	return pTerminal
end

function axkvaMin:inviteGroupMembers(pLeader, instanceID)
	local groupSize = CreatureObject(pLeader):getGroupSize()

	for i = 0, groupSize - 1, 1 do
		local pMember = CreatureObject(pLeader):getGroupMember(i)

		if pMember ~= nil and pMember ~= pLeader and not SceneObject(pMember):isAiAgent() then
			self:sendAuthorizationSui(pMember, pLeader, instanceID)
		end
	end
end

function axkvaMin:sendAuthorizationSui(pPlayer, pLeader, instanceID)
	if (pPlayer == nil) then
		return
	end

	writeData(SceneObject(pPlayer):getObjectID() .. ":axkvaMinPendingInstance", instanceID)

	local sui = SuiMessageBox.new("axkvaMin", "authorizationSuiCallback")

	sui.setTitle("The Chamber of Banishment")
	sui.setPrompt(CreatureObject(pLeader):getFirstName() .. " has started a Chamber of Banishment [Instance]. Do you want to enter?")
	sui.setOkButtonText("Yes")
	sui.setCancelButtonText("No")

	local pageId = sui.sendTo(pPlayer)
	createEvent(30 * 1000, "axkvaMin", "closeAuthorizationSui", pPlayer, pageId)
end

function axkvaMin:authorizationSuiCallback(pPlayer, pSui, eventIndex, args, ...)
	if pPlayer == nil then
		return
	end

	local playerID = SceneObject(pPlayer):getObjectID()
	local instanceID = readData(playerID .. ":axkvaMinPendingInstance")
	deleteData(playerID .. ":axkvaMinPendingInstance")

	if eventIndex == 1 then
		CreatureObject(pPlayer):sendSystemMessage("You decline to enter the Chamber of Banishment [Instance].")
		return
	end

	if instanceID == 0 or readData(self:getKey(instanceID, "active")) ~= 1 then
		CreatureObject(pPlayer):sendSystemMessage("That Chamber of Banishment [Instance] is no longer available.")
		return
	end

	if not self:canJoinInstance(pPlayer, instanceID) then
		CreatureObject(pPlayer):sendSystemMessage("You are no longer in the group assigned to that Chamber of Banishment [Instance].")
		return
	end

	if self:getPlayerInstance(pPlayer) ~= 0 then
		CreatureObject(pPlayer):sendSystemMessage("You are already assigned to a Chamber of Banishment [Instance].")
		return
	end

	if CreatureObject(pPlayer):isRidingMount() then
		CreatureObject(pPlayer):sendSystemMessage("You fail to enter the instance because you are riding a mount.")
		return
	end

	self:transportPlayerToInstance(pPlayer, instanceID)
end

function axkvaMin:closeAuthorizationSui(pPlayer, pageId)
	if pPlayer == nil then
		return
	end

	local pGhost = CreatureObject(pPlayer):getPlayerObject()

	if pGhost ~= nil then
		PlayerObject(pGhost):removeSuiBox(pageId)
	end
end

function axkvaMin:sendExitSui(pPlayer)
	if pPlayer == nil then
		return
	end

	local instanceID = self:getPlayerInstance(pPlayer)

	if instanceID == 0 then
		CreatureObject(pPlayer):sendSystemMessage("You are not currently inside a Chamber of Banishment [Instance].")
		return
	end

	local sui = SuiMessageBox.new("axkvaMin", "exitInstanceSuiCallback")
	sui.setTitle("Exit the Chamber of Banishment [Instance]")
	sui.setPrompt("Leave the Chamber of Banishment [Instance] and return to Dathomir?")
	sui.setOkButtonText("Exit")
	sui.setCancelButtonText("Stay")
	sui.sendTo(pPlayer)
end

function axkvaMin:exitInstanceSuiCallback(pPlayer, pSui, eventIndex, args, ...)
	if pPlayer == nil then
		return
	end

	if eventIndex == 1 then
		CreatureObject(pPlayer):sendSystemMessage("You remain inside the Chamber of Banishment [Instance].")
		return
	end

	local instanceID = self:getPlayerInstance(pPlayer)

	if instanceID == 0 then
		CreatureObject(pPlayer):sendSystemMessage("That Chamber of Banishment [Instance] is no longer available.")
		return
	end

	self:ejectPlayer(pPlayer, "You leave the Chamber of Banishment [Instance].")
end

function axkvaMin:transportPlayerToInstance(pPlayer, instanceID)
	local cellID = self:getCellID(instanceID, self.entryCellIndex)
	local instanceZone = self:getInstanceZoneForInstance(instanceID)

	if cellID == 0 or instanceZone == "" then
		CreatureObject(pPlayer):sendSystemMessage("Unable to find the Chamber of Banishment [Instance] entry cell.")
		return false
	end

	writeData(SceneObject(pPlayer):getObjectID() .. ":axkvaMinInstance", instanceID)
	writeData(self:getKey(instanceID, "member:" .. SceneObject(pPlayer):getObjectID()), 1)
	deleteData(SceneObject(pPlayer):getObjectID() .. ":axkvaMinPendingInstance")
	dropObserver(LOGGEDIN, "axkvaMin", "onPlayerLoggedIn", pPlayer)
	createObserver(LOGGEDIN, "axkvaMin", "onPlayerLoggedIn", pPlayer, 1)
	SceneObject(pPlayer):switchZone(instanceZone, self.entryX, self.entryZ, self.entryY, cellID)
	return true
end

function axkvaMin:onPlayerLoggedIn(pPlayer)
	if pPlayer == nil then
		return 0
	end

	createEvent(5 * 1000, "axkvaMin", "recoverPlayerAfterLogin", pPlayer, "")
	return 0
end

function axkvaMin:recoverPlayerAfterLogin(pPlayer)
	if pPlayer == nil then
		return
	end

	local playerID = SceneObject(pPlayer):getObjectID()
	local instanceID = readData(playerID .. ":axkvaMinInstance")

	if instanceID ~= 0 then
		if getSceneObject(instanceID) == nil or readData(self:getKey(instanceID, "active")) ~= 1 then
			self:ejectPlayer(pPlayer, "Your Chamber of Banishment [Instance] was closed while the server was offline.")
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
		self:ejectPlayer(pPlayer, "Your previous Chamber of Banishment [Instance] is no longer active.")
	end
end

function axkvaMin:isInInstanceCoordinateRange(x, y)
	return x >= self.instanceMinCoordinate and x <= self.instanceMaxCoordinate and y >= self.instanceMinCoordinate and y <= self.instanceMaxCoordinate
end

function axkvaMin:spawnBossRoomOne(instanceID)
	local boss1 = self:spawnInstanceMobile(instanceID, "axkva_min_nandina", -78, 17.8, 29.8, 127, self.encounterCellIndex)
	local pGrovo = self:spawnInstanceMobile(instanceID, "axkva_min_grovo", -81.8, 17.8, 17.6, 97, self.encounterCellIndex)

	if boss1 ~= nil then
		createObserver(OBJECTDESTRUCTION, "axkvaMin", "bossOneKilled", boss1)
		createObserver(DAMAGERECEIVED, "axkvaMin", "boss1_damage", boss1)
		writeData(SceneObject(boss1):getObjectID() .. ":axkvaMinFightState", 0)
	end

	if pGrovo ~= nil then
		writeData(self:getKey(instanceID, "grovoID"), SceneObject(pGrovo):getObjectID())
	end

	return boss1
end

function axkvaMin:boss1_damage(boss1, pPlayer)
	if boss1 == nil then
		return 0
	end

	local boss = LuaCreatureObject(boss1)

	if (boss ~= nil) then
      local bossID = SceneObject(boss1):getObjectID()
      local instanceID = readData(bossID .. ":axkvaMinInstance")
      local stateKey = bossID .. ":axkvaMinFightState"
      local bossHealth = boss:getHAM(0)
      local bossAction = boss:getHAM(3)
      local bossMind = boss:getHAM(6)
      local bossMaxHealth = boss:getMaxHAM(0)
      local bossMaxAction = boss:getMaxHAM(3)
      local bossMaxMind = boss:getMaxHAM(6)
    --[[
      local x1 = -79.5
      local y1 = 23.4
      local x2 = boss:getPositionX()
      local y2 = boss:getPositionY()
     
      local distance = ((x2 - x1)*(x2 - x1)) + ((y2 - y1)*(y2 - y1))
      local maxDistance = 32
   
     if distance > (maxDistance * maxDistance) then
      spatialChat(boss1, "Cowards, you face me before the crystal or not at all!")
      forcePeace(boss1)
     --]]  
     
  
      if (((bossHealth <= (bossMaxHealth *0.995))) and readData(stateKey) == 0) then
      spatialChat(boss1, "Why have you come here? Did our sisters send you? What did you think you would find here other than your own deaths!")
      CreatureObject(boss1):playEffect("clienteffect/space_command/shp_shocked_01.cef", "")
      local pGrovo = self:getInstanceGrovo(instanceID)
      self:activateEncounterAdd(pGrovo, pPlayer, boss1)
        writeData(stateKey, 1)
      end 

      self:triggerGrovoPoisonPulse(instanceID, pPlayer, boss1)
      
      if (((bossAction <= (bossMaxAction *0.3)))) then
           CreatureObject(boss1):setHAM(3, bossMaxAction)
           CreatureObject(boss1):playEffect("clienteffect/pl_force_channel_self.cef", "")
           spatialChat(boss1, "I am renewed!")   
      end 
      
      if (((bossHealth <= (bossMaxHealth *0.75))) and readData(stateKey) == 1) then
      spatialChat(boss1, "Your essences will feed my lady's power, after my pet tears you apart of course.")
      CreatureObject(boss1):playEffect("clienteffect/combat_pt_electricalfield.cef", "")
        writeData(stateKey, 2)
      end
      
      if (((bossHealth <= (bossMaxHealth *0.50))) and readData(stateKey) == 2) then
      spatialChat(boss1, "My sisters are weak.  They fear what we intended.  Without the mother our clan is nothing.")
        CreatureObject(boss1):playEffect("clienteffect/pl_force_resist_states_self.cef", "")
        writeData(stateKey, 3)
      end  
      
      if (((bossHealth <= (bossMaxHealth *0.25))) and readData(stateKey) == 3) then
      spatialChat(boss1, "Yes, Strike me with all of your strength.")
      CreatureObject(boss1):playEffect("clienteffect/pl_force_resist_bleeding_self.cef", "")
      local pRancor1 = self:spawnInstanceMobile(instanceID, "axkva_min_mutant_rancor", -81.3, 17.9, 18.4, 65, self.encounterCellIndex)
      local pRancor2 = self:spawnInstanceMobile(instanceID, "axkva_min_mutant_rancor", -77.2, 17.9, 18.8, 118, self.encounterCellIndex)
      self:activateEncounterAdd(pRancor1, pPlayer, boss1)
      self:activateEncounterAdd(pRancor2, pPlayer, boss1)
        writeData(stateKey, 4)
      end
      
      if (((bossHealth <= (bossMaxHealth *0.1))) and readData(stateKey) == 4) then
      spatialChat(boss1, "Mistress, take my essence...  Let the mother live... again.")
      CreatureObject(boss1):playEffect("clienteffect/pl_storm_lord_special.cef", "")
      CreatureObject(boss1):playEffect("clienteffect/combat_pt_electricalfield.cef", "")
        writeData(stateKey, 5)
      end  
      
      if (((bossHealth <= (bossMaxHealth *0.1))) and readData(stateKey) == 5) then      
        writeData(stateKey, 6)
      end
    end
    return 0
end

function axkvaMin:bossOneKilled(boss1) 
	local bossID = SceneObject(boss1):getObjectID()
	local instanceID = readData(bossID .. ":axkvaMinInstance")

	deleteData(bossID .. ":axkvaMinFightState")
	deleteData(bossID .. ":axkvaMinInstance")
	self:spawnBossRoomTwo(instanceID)
	return 0
end

function axkvaMin:getEncounterTarget(pPreferredTarget, pAnchor)
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

function axkvaMin:getInstanceGrovo(instanceID)
	local grovoID = readData(self:getKey(instanceID, "grovoID"))

	if grovoID == 0 then
		return nil
	end

	local pGrovo = getSceneObject(grovoID)

	if pGrovo == nil or CreatureObject(pGrovo):isDead() then
		return nil
	end

	return pGrovo
end

function axkvaMin:activateEncounterAdd(pMobile, pPreferredTarget, pAnchor)
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

function axkvaMin:triggerGrovoPoisonPulse(instanceID, pPreferredTarget, pAnchor)
	local pGrovo = self:getInstanceGrovo(instanceID)

	if pGrovo == nil then
		return
	end

	local cooldownKey = self:getKey(instanceID, "grovoPoisonTime")
	local currentTime = os.time()

	if readData(cooldownKey) > currentTime then
		return
	end

	self:activateEncounterAdd(pGrovo, pPreferredTarget, pAnchor)

	local pBuilding = getSceneObject(instanceID)

	if pBuilding == nil then
		return
	end

	local grovoCellID = SceneObject(pGrovo):getParentID()
	local grovoX = SceneObject(pGrovo):getPositionX()
	local grovoY = SceneObject(pGrovo):getPositionY()
	local radiusSquared = self.grovoPoisonRadius * self.grovoPoisonRadius
	local instanceZone = self:getInstanceZoneForInstance(instanceID)
	local affectedPlayers = 0

	for i = 1, BuildingObject(pBuilding):getTotalCellNumber(), 1 do
		local pCell = BuildingObject(pBuilding):getCell(i)

		if pCell ~= nil and SceneObject(pCell):getObjectID() == grovoCellID then
			for j = SceneObject(pCell):getContainerObjectsSize(), 1, -1 do
				local pObject = SceneObject(pCell):getContainerObject(j - 1)

				if pObject ~= nil and SceneObject(pObject):isPlayerCreature()
					and not CreatureObject(pObject):isDead()
					and not CreatureObject(pObject):isIncapacitated() then
					local deltaX = SceneObject(pObject):getPositionX() - grovoX
					local deltaY = SceneObject(pObject):getPositionY() - grovoY

					if (deltaX * deltaX) + (deltaY * deltaY) <= radiusSquared then
						CreatureObject(pObject):playEffect("clienteffect/dot_poisoned.cef", "")
						playClientEffectLoc(pObject, "clienteffect/item_gas_leak_trap_on.cef", instanceZone, grovoX, SceneObject(pGrovo):getPositionZ(), grovoY, grovoCellID)
						CreatureObject(pObject):inflictDamage(pObject, 3, getRandomNumber(self.grovoPoisonMinDamage, self.grovoPoisonMaxDamage), 1)
						CreatureObject(pObject):sendSystemMessage("Grovo exhales a poisonous cloud that burns your action.")
						affectedPlayers = affectedPlayers + 1
					end
				end
			end
		end
	end

	if affectedPlayers > 0 then
		spatialChat(pGrovo, "Breathe deep, interlopers!")
	end

	writeData(cooldownKey, currentTime + self.grovoPoisonCooldown)
end

function axkvaMin:spawnBossRoomTwo(instanceID)
  local boss2 = self:spawnInstanceMobile(instanceID, "axkva_min_lelli_hi", -74.4, 16.5, 31.4, 154, self.encounterCellIndex)

  if boss2 ~= nil then
    createObserver(DAMAGERECEIVED, "axkvaMin", "boss2_damage", boss2)
    createObserver(OBJECTDESTRUCTION, "axkvaMin", "bossTwoKilled", boss2)
    writeData(SceneObject(boss2):getObjectID() .. ":axkvaMinFightState", 0)
  end
end

function axkvaMin:boss2_damage(boss2, pPlayer)
	if boss2 == nil then
		return 0
	end

	local boss = LuaCreatureObject(boss2)

	if (boss ~= nil) then
      local bossID = SceneObject(boss2):getObjectID()
      local instanceID = readData(bossID .. ":axkvaMinInstance")
      local stateKey = bossID .. ":axkvaMinFightState"
      local bossHealth = boss:getHAM(0)
      local bossAction = boss:getHAM(3)
      local bossMind = boss:getHAM(6)
      local bossMaxHealth = boss:getMaxHAM(0)
      local bossMaxAction = boss:getMaxHAM(3)
      local bossMaxMind = boss:getMaxHAM(6)
      
      
   
  
      if (((bossHealth <= (bossMaxHealth *0.99))) and readData(stateKey) == 0) then
      spatialChat(boss2, "You will not stop us from bringing back Mother!")
        CreatureObject(boss2):playEffect("clienteffect/space_command/shp_shocked_01.cef", "")
        writeData(stateKey, 1)
      end 
      
      if (((bossAction <= (bossMaxAction *0.3)))) then
           CreatureObject(boss2):setHAM(3, bossMaxAction)
           CreatureObject(boss2):playEffect("clienteffect/pl_force_channel_self.cef", "")
           spatialChat(boss2, "My strength is renewed.  Thank you mother!")   
      end 
      
      if (((bossHealth <= (bossMaxHealth *0.75))) and readData(stateKey) == 1) then
     -- spatialChat(boss2, "Insert witty dialogue here.")
        writeData(stateKey, 2)
              
      end
      
      if (((bossHealth <= (bossMaxHealth *0.50))) and readData(stateKey) == 2) then
      spatialChat(boss2, "Sisters, stop these invaders!")
        CreatureObject(boss2):playEffect("clienteffect/pl_storm_lord_special.cef", "")
        CreatureObject(boss2):playEffect("clienteffect/combat_pt_electricalfield.cef", "")
        writeData(stateKey, 3)
        self:spawnSentinelWave(instanceID, pPlayer, boss2)
           
      end  
      
      if (((bossHealth <= (bossMaxHealth *0.25))) and readData(stateKey) == 3) then
      spatialChat(boss2, "You will not stop us from bringing back our Mother!")
        CreatureObject(boss2):playEffect("clienteffect/pl_storm_lord_special.cef", "")
        CreatureObject(boss2):playEffect("clienteffect/combat_pt_electricalfield.cef", "")
        writeData(stateKey, 4)
        self:spawnSentinelWave(instanceID, pPlayer, boss2)
                 
      end
      
      if (((bossHealth <= (bossMaxHealth *0.1))) and readData(stateKey) == 4) then
      spatialChat(boss2, "Mother, take my life. Let it fuel your rebirth!")
        writeData(stateKey, 5)
      end  
      
      if (((bossHealth <= (bossMaxHealth *0.1))) and readData(stateKey) == 5) then      
        writeData(stateKey, 6)
      end
    end
    return 0
end

function axkvaMin:bossTwoKilled(boss2)
	local bossID = SceneObject(boss2):getObjectID()
	local instanceID = readData(bossID .. ":axkvaMinInstance")

	deleteData(bossID .. ":axkvaMinFightState")
	deleteData(bossID .. ":axkvaMinInstance")
	self:spawnBossRoomThree(instanceID)
	return 0
end

function axkvaMin:spawnBossRoomThree(instanceID)  -- Adds for this phase:   exar_kun_warrior (A Caretaker Protector) , exar_kun_warrior_f (The Executioner)
  local boss3 = self:spawnInstanceMobile(instanceID, "axkva_min_kimaru", -79.3, 16.8, 14.2, 45, self.encounterCellIndex)

  if boss3 ~= nil then
    createObserver(DAMAGERECEIVED, "axkvaMin", "boss3_damage", boss3)
    createObserver(OBJECTDESTRUCTION, "axkvaMin", "bossThreeKilled", boss3)
    writeData(SceneObject(boss3):getObjectID() .. ":axkvaMinFightState", 0)
  end
end

function axkvaMin:boss3_damage(boss3, pPlayer)
	if boss3 == nil then
		return 0
	end

	local boss = LuaCreatureObject(boss3)

	if (boss ~= nil) then
      local bossID = SceneObject(boss3):getObjectID()
      local instanceID = readData(bossID .. ":axkvaMinInstance")
      local stateKey = bossID .. ":axkvaMinFightState"
      local bossHealth = boss:getHAM(0)
      local bossAction = boss:getHAM(3)
      local bossMind = boss:getHAM(6)
      local bossMaxHealth = boss:getMaxHAM(0)
      local bossMaxAction = boss:getMaxHAM(3)
      local bossMaxMind = boss:getMaxHAM(6)
      
      
   
  
      if (((bossHealth <= (bossMaxHealth *0.99))) and readData(stateKey) == 0) then
      spatialChat(boss3, "Kill them Sisters!")
        writeData(stateKey, 1)
        local pAdd1 = self:spawnInstanceMobile(instanceID, "axkva_min_spell_weaver", -47.4, 8.0, 7.3, -57, self.encounterCellIndex)
        self:activateEncounterAdd(pAdd1, pPlayer, boss3)
        CreatureObject(pAdd1):playEffect("clienteffect/pl_force_regain_consciousness_self.cef", "")
        spatialChat(pAdd1, "Die Interloper!")         
      end 
      
      if (((bossAction <= (bossMaxAction *0.3)))) then
           CreatureObject(boss3):setHAM(3, bossMaxAction)
           CreatureObject(boss3):playEffect("clienteffect/pl_force_channel_self.cef", "")
           spatialChat(boss3, "My strength is renewed.  Thank you master!")   
      end 
      
      if (((bossHealth <= (bossMaxHealth *0.75))) and readData(stateKey) == 1) then
      spatialChat(boss3, "Kill them Sisters!")
        writeData(stateKey, 2)
        local pAdd2 = self:spawnInstanceMobile(instanceID, "axkva_min_spell_weaver", -47.4, 8.0, 7.3, -57, self.encounterCellIndex)
        self:activateEncounterAdd(pAdd2, pPlayer, boss3)
        CreatureObject(pAdd2):playEffect("clienteffect/pl_force_regain_consciousness_self.cef", "")
        spatialChat(pAdd2, "Die Interloper!")         
      end
      
      if (((bossHealth <= (bossMaxHealth *0.50))) and readData(stateKey) == 2) then
      spatialChat(boss3, "Kill them Sisters!")
        writeData(stateKey, 3)
        local pAdd3 = self:spawnInstanceMobile(instanceID, "axkva_min_elder", -47.4, 8.0, 7.3, -57, self.encounterCellIndex)
        self:activateEncounterAdd(pAdd3, pPlayer, boss3)
        CreatureObject(pAdd3):playEffect("clienteffect/pl_force_regain_consciousness_self.cef", "")
        spatialChat(pAdd3, "Die Interloper!")
        self:spawnSentinelWave(instanceID, pPlayer, boss3)
      end  
      
      if (((bossHealth <= (bossMaxHealth *0.25))) and readData(stateKey) == 3) then
      spatialChat(boss3, "I will rip your essence from your lifeless bodies!")
        writeData(stateKey, 4)
        CreatureObject(boss3):playEffect("clienteffect/pl_storm_lord_special.cef", "")
        CreatureObject(boss3):playEffect("clienteffect/combat_pt_electricalfield.cef", "")        
      end
      
      if (((bossHealth <= (bossMaxHealth *0.1))) and readData(stateKey) == 4) then
      spatialChat(boss3, "Mother... I....")
        writeData(stateKey, 5)
      end  
      
      if (((bossHealth <= (bossMaxHealth *0.1))) and readData(stateKey) == 5) then      
        writeData(stateKey, 6)
      end
    end
    return 0
end

function axkvaMin:bossThreeKilled(boss3)
	local bossID = SceneObject(boss3):getObjectID()
	local instanceID = readData(bossID .. ":axkvaMinInstance")

	deleteData(bossID .. ":axkvaMinFightState")
	deleteData(bossID .. ":axkvaMinInstance")
	self:spawnBossRoomFour(instanceID)
	return 0
end

function axkvaMin:spawnBossRoomFour(instanceID)
  local boss4 = self:spawnInstanceMobile(instanceID, "axkva_min_suin_chalo", -82.5, 17.8, 17.8, 55, self.encounterCellIndex)

  if boss4 ~= nil then
    createObserver(DAMAGERECEIVED, "axkvaMin", "boss4_damage", boss4)
    createObserver(OBJECTDESTRUCTION, "axkvaMin", "bossFourKilled", boss4)
    writeData(SceneObject(boss4):getObjectID() .. ":axkvaMinFightState", 0)
  end
end

function axkvaMin:boss4_damage(boss4, pPlayer)
	if boss4 == nil then
		return 0
	end

	local boss = LuaCreatureObject(boss4)

	if (boss ~= nil) then
      local bossID = SceneObject(boss4):getObjectID()
      local instanceID = readData(bossID .. ":axkvaMinInstance")
      local stateKey = bossID .. ":axkvaMinFightState"
      local bossHealth = boss:getHAM(0)
      local bossAction = boss:getHAM(3)
      local bossMind = boss:getHAM(6)
      local bossMaxHealth = boss:getMaxHAM(0)
      local bossMaxAction = boss:getMaxHAM(3)
      local bossMaxMind = boss:getMaxHAM(6)
      
      
   
  
      if (((bossHealth <= (bossMaxHealth *0.995))) and readData(stateKey) == 0) then
      spatialChat(boss4, "You come this far and no further, the line must be drawn here.")
        writeData(stateKey, 1)
        CreatureObject(boss4):playEffect("clienteffect/pl_storm_lord_special.cef", "")
        CreatureObject(boss4):playEffect("clienteffect/combat_pt_electricalfield.cef", "")
        local pAdd1 = self:spawnInstanceMobile(instanceID, "axkva_min_elder", -42.2, 7.4, 11.3, -75, self.encounterCellIndex)
        self:activateEncounterAdd(pAdd1, pPlayer, boss4)
        spatialChat(pAdd1, "Die!")         
      end 
      
      if (((bossAction <= (bossMaxAction *0.3)))) then
           CreatureObject(boss4):setHAM(3, bossMaxAction)
           CreatureObject(boss4):playEffect("clienteffect/pl_force_channel_self.cef", "")
           spatialChat(boss4, "My strength is renewed.  Thank you master!")   
      end 
      
      if (((bossHealth <= (bossMaxHealth *0.75))) and readData(stateKey) == 1) then
      spatialChat(boss4, "There is no way out for you but to embrace death.")
        writeData(stateKey, 2)
        local pAdd2 = self:spawnInstanceMobile(instanceID, "axkva_min_elder", -42.2, 7.4, 11.3, -75, self.encounterCellIndex)
        self:activateEncounterAdd(pAdd2, pPlayer, boss4)
        spatialChat(pAdd2, "Die!")         
      end
      
      if (((bossHealth <= (bossMaxHealth *0.50))) and readData(stateKey) == 2) then
      spatialChat(boss4, "It will be over soon, give in to the inevitable!")
        writeData(stateKey, 3)
        local pAdd3 = self:spawnInstanceMobile(instanceID, "axkva_min_elder", -42.2, 7.4, 11.3, -75, self.encounterCellIndex)
        self:activateEncounterAdd(pAdd3, pPlayer, boss4)
        spatialChat(pAdd3, "Die!")  
        self:spawnSentinelWave(instanceID, pPlayer, boss4)
      end  
      
      if (((bossHealth <= (bossMaxHealth *0.25))) and readData(stateKey) == 3) then
      spatialChat(boss4, "Too long she has been denied, No more!  NO MORE!!!!")
        CreatureObject(boss4):playEffect("clienteffect/pl_storm_lord_special.cef", "")
        CreatureObject(boss4):playEffect("clienteffect/combat_pt_electricalfield.cef", "")
        writeData(stateKey, 4)
      end
      
      if (((bossHealth <= (bossMaxHealth *0.1))) and readData(stateKey) == 4) then
      spatialChat(boss4, "Axkva, it's up to you...")
        writeData(stateKey, 5)
      end  
      
      if (((bossHealth <= (bossMaxHealth *0.1))) and readData(stateKey) == 5) then      
        writeData(stateKey, 6)
      end
    end
    return 0
end

function axkvaMin:bossFourKilled(boss4)
	local bossID = SceneObject(boss4):getObjectID()
	local instanceID = readData(bossID .. ":axkvaMinInstance")

	deleteData(bossID .. ":axkvaMinFightState")
	deleteData(bossID .. ":axkvaMinInstance")
	self:spawnBossRoomFive(instanceID)
	return 0
end

function axkvaMin:spawnBossRoomFive(instanceID)
  local boss5 = self:spawnInstanceMobile(instanceID, "axkva_min_boss", -79, 17.8, 23.8, 99, self.encounterCellIndex)

  if boss5 ~= nil then
    spatialChat(boss5, "Our destiny was denied for so long, by the Jedi, by the Sith.  Now it is our time.")
    createObserver(DAMAGERECEIVED, "axkvaMin", "boss5_damage", boss5)
    createObserver(OBJECTDESTRUCTION, "axkvaMin", "bossFiveKilled", boss5)
    writeData(SceneObject(boss5):getObjectID() .. ":axkvaMinFightState", 0)
  end
end

function axkvaMin:boss5_damage(boss5, pPlayer)
	if boss5 == nil then
		return 0
	end

	local boss = LuaCreatureObject(boss5)

	if (boss ~= nil) then
      local bossID = SceneObject(boss5):getObjectID()
      local instanceID = readData(bossID .. ":axkvaMinInstance")
      local stateKey = bossID .. ":axkvaMinFightState"
      local bossHealth = boss:getHAM(0)
      local bossAction = boss:getHAM(3)
      local bossMind = boss:getHAM(6)
      local bossMaxHealth = boss:getMaxHAM(0)
      local bossMaxAction = boss:getMaxHAM(3)
      local bossMaxMind = boss:getMaxHAM(6)
      
      
   
  
      if (((bossHealth <= (bossMaxHealth *0.995))) and readData(stateKey) == 0) then
      spatialChat(boss5, "It seems that you have come all this way for nothing.  Death awaits you!")
      CreatureObject(boss5):playEffect("clienteffect/pl_storm_lord_special.cef", "")     
        writeData(stateKey, 1)
      end 
      
      if (((bossAction <= (bossMaxAction *0.3)))) then
           CreatureObject(boss5):setHAM(3, bossMaxAction)
           CreatureObject(boss5):playEffect("clienteffect/pl_force_meditate_self.cef", "")
           spatialChat(boss5, "I am renewed!")   
      end 
      
      if (((bossHealth <= (bossMaxHealth *0.75))) and readData(stateKey) == 1) then
      spatialChat(boss5, "Sisters, kill them! Kill them all!!!")
        CreatureObject(boss5):playEffect("clienteffect/pl_storm_lord_special.cef", "")
        CreatureObject(boss5):playEffect("clienteffect/combat_pt_electricalfield.cef", "")
        
        writeData(stateKey, 2)
        self:spawnSentinelWave(instanceID, pPlayer, boss5)
      end
      
      if (((bossHealth <= (bossMaxHealth *0.50))) and readData(stateKey) == 2) then
        CreatureObject(boss5):playEffect("clienteffect/pl_storm_lord_special.cef", "")
        
        writeData(stateKey, 3)
        local pAdd2 = self:spawnInstanceMobile(instanceID, "axkva_min_elder", -42.2, 7.4, 11.3, -75, self.encounterCellIndex)
        self:activateEncounterAdd(pAdd2, pPlayer, boss5)
        spatialChat(pAdd2, "Your death will give life to the Mother!")
        CreatureObject(pAdd2):playEffect("clienteffect/pl_force_regain_consciousness_self.cef", "")
        self:spawnSentinelWave(instanceID, pPlayer, boss5)
      end  
      
      if (((bossHealth <= (bossMaxHealth *0.25))) and readData(stateKey) == 3) then
        CreatureObject(boss5):playEffect("clienteffect/pl_storm_lord_special.cef", "")
        
        spatialChat(boss5, "I have a surprise for you.")
        writeData(stateKey, 4)
        local pAdd3 = self:spawnInstanceMobile(instanceID, "axkva_min_elder", -42.2, 7.4, 11.3, -75, self.encounterCellIndex)
        self:activateEncounterAdd(pAdd3, pPlayer, boss5)
        spatialChat(pAdd3, "Mother, you are near now I feel it!") 
        CreatureObject(pAdd3):playEffect("clienteffect/pl_force_regain_consciousness_self.cef", "") 
        self:spawnSentinelWave(instanceID, pPlayer, boss5)
      end
      
      if (((bossHealth <= (bossMaxHealth *0.1))) and readData(stateKey) == 4) then
      spatialChat(boss5, "You think this is over do you?  You think they were trying to free me?  No...  You'll see soon.  She is coming...")
        CreatureObject(boss5):playEffect("clienteffect/pl_storm_lord_special.cef", "")
        CreatureObject(boss5):playEffect("clienteffect/combat_pt_electricalfield.cef", "")       
        writeData(stateKey, 5)
      end  
      
      if (((bossHealth <= (bossMaxHealth *0.1))) and readData(stateKey) == 5) then      
        writeData(stateKey, 6)
      end
    end
    return 0
end

function axkvaMin:bossFiveKilled(boss5, pPlayer)  -- TODO Use this function to reset the instance on success.   Delay by 30 seconds to allow looting time.
	local bossID = SceneObject(boss5):getObjectID()
	local instanceID = readData(bossID .. ":axkvaMinInstance")
	local pBuilding = getSceneObject(instanceID)

	deleteData(bossID .. ":axkvaMinFightState")
	deleteData(bossID .. ":axkvaMinInstance")
	self:sendInstanceMessage(instanceID, "As Axkva Min falls, a flash of light leaves her body and enters the crystal.")

	if pBuilding ~= nil then
		createEvent(20, "axkvaMin", "spawnBossRoomSixFromBuilding", pBuilding, "")
	end

	return 0
end

function axkvaMin:spawnBossRoomSixFromBuilding(pBuilding)
	if pBuilding == nil then
		return
	end

	self:spawnBossRoomSix(SceneObject(pBuilding):getObjectID())
end

function axkvaMin:spawnBossRoomSix(instanceID)
  local boss6 = self:spawnInstanceMobile(instanceID, "axkva_min_mother_talzin", -74.3, 16.0, 22.5, 97, self.encounterCellIndex)

  if boss6 ~= nil then
    spatialChat(boss6, "What... is this?  I.. am alive?  This is a surprise to be sure, but a welcome one.")
    CreatureObject(boss6):playEffect("clienteffect/pl_force_regain_consciousness_self.cef", "")
    createObserver(DAMAGERECEIVED, "axkvaMin", "boss6_damage", boss6)
    createObserver(OBJECTDESTRUCTION, "axkvaMin", "bossSixKilled", boss6)
    writeData(SceneObject(boss6):getObjectID() .. ":axkvaMinFightState", 0)
  end
end

function axkvaMin:boss6_damage(boss6, pPlayer)
	if boss6 == nil then
		return 0
	end

	local boss = LuaCreatureObject(boss6)

	if (boss ~= nil) then
      local bossID = SceneObject(boss6):getObjectID()
      local instanceID = readData(bossID .. ":axkvaMinInstance")
      local stateKey = bossID .. ":axkvaMinFightState"
      local bossHealth = boss:getHAM(0)
      local bossAction = boss:getHAM(3)
      local bossMind = boss:getHAM(6)
      local bossMaxHealth = boss:getMaxHAM(0)
      local bossMaxAction = boss:getMaxHAM(3)
      local bossMaxMind = boss:getMaxHAM(6)
      
      
   
  
      if (((bossHealth <= (bossMaxHealth *0.99))) and readData(stateKey) == 0) then
      spatialChat(boss6, "Pitiful brutes. You will understand true power.")
      CreatureObject(boss6):playEffect("clienteffect/pl_storm_lord_special.cef", "")
      
        writeData(stateKey, 1)
      end 
      
      if (((bossAction <= (bossMaxAction *0.3)))) then
           CreatureObject(boss6):setHAM(3, bossMaxAction)
           CreatureObject(boss6):playEffect("clienteffect/pl_force_meditate_self.cef", "")
           spatialChat(boss6, "Behold my endless power!")   
      end 
      
      if (((bossHealth <= (bossMaxHealth *0.75))) and readData(stateKey) == 1) then
      spatialChat(boss6, "My daughters, rise again and fight for your mother!")
        CreatureObject(boss6):playEffect("clienteffect/pl_storm_lord_special.cef", "")
        CreatureObject(boss6):playEffect("clienteffect/combat_pt_electricalfield.cef", "")
        
        writeData(stateKey, 2)

        local pCult1 = self:spawnInstanceMobile(instanceID, "axkva_min_nandina", -53.9, 9.8, 13.0, -51, self.encounterCellIndex)
          self:activateEncounterAdd(pCult1, pPlayer, boss6)
          CreatureObject(pCult1):playEffect("clienteffect/pl_force_regain_consciousness_self.cef", "")
          spatialChat(pCult1, "Yes mother!") 
        local pCult2 = self:spawnInstanceMobile(instanceID, "axkva_min_lelli_hi", -63.4, 11.8, 8.3, 67, self.encounterCellIndex)
          self:activateEncounterAdd(pCult2, pPlayer, boss6)
          CreatureObject(pCult2):playEffect("clienteffect/pl_force_regain_consciousness_self.cef", "")
          spatialChat(pCult2, "Yes mother!") 
        local pCult3 = self:spawnInstanceMobile(instanceID, "axkva_min_kimaru", -53.8, 11.5, 23.7, -116, self.encounterCellIndex)
          self:activateEncounterAdd(pCult3, pPlayer, boss6)
          CreatureObject(pCult3):playEffect("clienteffect/pl_force_regain_consciousness_self.cef", "")
          spatialChat(pCult3, "Yes mother!") 
        local pCult4 = self:spawnInstanceMobile(instanceID, "axkva_min_suin_chalo", -49.6, 9.3, 18.0, -60, self.encounterCellIndex)
          self:activateEncounterAdd(pCult4, pPlayer, boss6)
          CreatureObject(pCult4):playEffect("clienteffect/pl_force_regain_consciousness_self.cef", "") 
          spatialChat(pCult4, "Yes mother!")
        local pCult5 = self:spawnInstanceMobile(instanceID, "axkva_min_boss", -70.8, 14.4, 17.6, 69, self.encounterCellIndex)
          self:activateEncounterAdd(pCult5, pPlayer, boss6)
          CreatureObject(pCult5):playEffect("clienteffect/pl_force_regain_consciousness_self.cef", "")
          spatialChat(pCult5, "Yes mother!")
        
             
      end
      
      if (((bossHealth <= (bossMaxHealth *0.50))) and readData(stateKey) == 2) then
        CreatureObject(boss6):playEffect("clienteffect/pl_storm_lord_special.cef", "")
        
        writeData(stateKey, 3)
        self:spawnSentinelWave(instanceID, pPlayer, boss6)
      end  
      
      if (((bossHealth <= (bossMaxHealth *0.25))) and readData(stateKey) == 3) then
        CreatureObject(boss6):playEffect("clienteffect/pl_storm_lord_special.cef", "")
        
        spatialChat(boss6, "This is not possible. I am weakening!")
        writeData(stateKey, 4)
        self:spawnSentinelWave(instanceID, pPlayer, boss6)
      end
      
      if (((bossHealth <= (bossMaxHealth *0.1))) and readData(stateKey) == 4) then
      spatialChat(boss6, "No, it can not end.  It can't!")
        CreatureObject(boss6):playEffect("clienteffect/pl_storm_lord_special.cef", "")
        CreatureObject(boss6):playEffect("clienteffect/combat_pt_electricalfield.cef", "")
        
        writeData(stateKey, 5)
      end  
      
      if (((bossHealth <= (bossMaxHealth *0.1))) and readData(stateKey) == 5) then      
        writeData(stateKey, 6)
      end
    end
    return 0
end

function axkvaMin:bossSixKilled(boss6, pPlayer)  -- TODO Use this function to reset the instance on success.   Delay by 30 seconds to allow looting time.
	local bossID = SceneObject(boss6):getObjectID()
	local instanceID = readData(bossID .. ":axkvaMinInstance")
	local pBuilding = getSceneObject(instanceID)

	deleteData(bossID .. ":axkvaMinFightState")
	deleteData(bossID .. ":axkvaMinInstance")
	self:sendInstanceMessage(instanceID, "You and your group have defeated Mother Talzin! This instance will close in 120 seconds.")
	self:awardBadgeToAll(instanceID)

	if pBuilding ~= nil then
		createEvent(120000, "axkvaMin", "handleVictory", pBuilding, "")
	end

	return 0
end

function axkvaMin:spawnSentinelWave(instanceID, pTarget, pAnchor)
	local sentinels = {
		{-43.7, 7.8, -6.6, -56},
		{-41.3, 7.2, -3.1, -51},
		{-39.5, 7.0, 0.5, -60},
		{-37.4, 7.0, 4.5, -60},
		{-36.4, 7.1, 8.6, -73},
		{-36.2, 7.1, 11.3, -88},
		{-36.8, 7.0, 15.1, -84},
		{-37.3, 7.0, 19.0, -93},
	}

	for i = 1, #sentinels, 1 do
		local spawnData = sentinels[i]
		local pCultist = self:spawnInstanceMobile(instanceID, "axkva_min_sentinel", spawnData[1], spawnData[2], spawnData[3], spawnData[4], self.encounterCellIndex)

		if pCultist ~= nil then
			CreatureObject(pCultist):playEffect("clienteffect/pl_force_regain_consciousness_self.cef", "")
			self:activateEncounterAdd(pCultist, pTarget, pAnchor)
		end
	end
end

function axkvaMin:spawnInstanceSceneObject(instanceID, template, x, z, y, heading, cellIndex)
	local cellID = self:getCellID(instanceID, cellIndex)
	local instanceZone = self:getInstanceZoneForInstance(instanceID)

	if cellID == 0 or instanceZone == "" then
		printLuaError("axkvaMin: unable to find cell index " .. cellIndex .. " for scene object in instance " .. instanceID)
		return nil
	end

	return spawnSceneObject(instanceZone, template, x, z, y, cellID, math.rad(heading))
end

function axkvaMin:spawnInstanceMobile(instanceID, template, x, z, y, heading, cellIndex)
	local cellID = self:getCellID(instanceID, cellIndex)
	local instanceZone = self:getInstanceZoneForInstance(instanceID)

	if cellID == 0 or instanceZone == "" then
		printLuaError("axkvaMin: unable to find cell index " .. cellIndex .. " for mobile in instance " .. instanceID)
		return nil
	end

	local pMobile = spawnMobile(instanceZone, template, 0, x, z, y, heading, cellID)

	if pMobile ~= nil then
		writeData(SceneObject(pMobile):getObjectID() .. ":axkvaMinInstance", instanceID)
	end

	return pMobile
end

function axkvaMin:checkInstanceTimer(pBuilding)
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
	self:sendInstanceMessage(instanceID, "Chamber of Banishment [Instance] time remaining: " .. minutesLeft .. " minutes.")

	local nextCheck = 5 * 60 * 1000

	if timeLeftSecs <= 60 then
		nextCheck = 10 * 1000
	elseif timeLeftSecs <= 10 * 60 then
		nextCheck = 60 * 1000
	end

	createEvent(nextCheck, "axkvaMin", "checkInstanceTimer", pBuilding, "")
end

function axkvaMin:expireInstance(pBuilding)
	if pBuilding == nil then
		return
	end

	local instanceID = SceneObject(pBuilding):getObjectID()
	self:sendInstanceMessage(instanceID, "The Chamber of Banishment [Instance] timer has expired.")
	self:resetInstance(pBuilding)
end

function axkvaMin:handleVictory(pBuilding)
	if pBuilding == nil then
		return
	end

	self:resetInstance(pBuilding)
end

function axkvaMin:resetInstance(pBuilding)
	if pBuilding == nil then
		return
	end

	local instanceID = SceneObject(pBuilding):getObjectID()
	writeData(self:getKey(instanceID, "active"), 0)
	self:ejectAllPlayers(pBuilding, "You are now being removed from the Chamber of Banishment [Instance].")
	createEvent(10 * 1000, "axkvaMin", "destroyInstance", pBuilding, "")
end

function axkvaMin:destroyInstance(pBuilding)
	if pBuilding == nil then
		return
	end

	local instanceID = SceneObject(pBuilding):getObjectID()

	if self:hasPlayersInside(pBuilding) then
		self:ejectAllPlayers(pBuilding, "You are now being removed from the Chamber of Banishment [Instance].")
		createEvent(10 * 1000, "axkvaMin", "destroyInstance", pBuilding, "")
		return
	end

	self:cleanupInstanceData(instanceID)
	SceneObject(pBuilding):destroyObjectFromWorld()
end

function axkvaMin:onExitedInstance(pBuilding, pPlayer)
	if pBuilding == nil or pPlayer == nil or not SceneObject(pPlayer):isPlayerCreature() then
		return 0
	end

	deleteData(SceneObject(pPlayer):getObjectID() .. ":axkvaMinInstance")

	if not self:hasPlayersInside(pBuilding) then
		createEvent(60 * 1000, "axkvaMin", "destroyInstance", pBuilding, "")
	end

	return 0
end

function axkvaMin:ejectAllPlayers(pBuilding, message)
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

function axkvaMin:ejectPlayer(pPlayer, message)
	if pPlayer == nil then
		return
	end

	if message ~= nil then
		CreatureObject(pPlayer):sendSystemMessage(message)
	end

	deleteData(SceneObject(pPlayer):getObjectID() .. ":axkvaMinInstance")
	dropObserver(LOGGEDIN, "axkvaMin", "onPlayerLoggedIn", pPlayer)
	SceneObject(pPlayer):switchZone(self.returnZone, self.returnX, self.returnZ, self.returnY, 0)
end

function axkvaMin:awardBadge(pPlayer)
  local pGhost = CreatureObject(pPlayer):getPlayerObject()

  if (pGhost ~= nil and not PlayerObject(pGhost):hasBadge(154)) then
        PlayerObject(pGhost):awardBadge(154)
  end
end

function axkvaMin:awardBadgeToAll(instanceID)
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

function axkvaMin:sendInstanceMessage(instanceID, message)
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

function axkvaMin:hasPlayersInside(pBuilding)
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

function axkvaMin:getPlayerInstance(pPlayer)
	local playerID = SceneObject(pPlayer):getObjectID()
	local instanceID = readData(playerID .. ":axkvaMinInstance")

	if instanceID == 0 then
		return 0
	end

	if getSceneObject(instanceID) == nil or readData(self:getKey(instanceID, "active")) ~= 1 then
		deleteData(playerID .. ":axkvaMinInstance")
		return 0
	end

	return instanceID
end

function axkvaMin:getGroupInstance(groupID)
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

function axkvaMin:canJoinInstance(pPlayer, instanceID)
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

function axkvaMin:getCellID(instanceID, cellIndex)
	local pBuilding = getSceneObject(instanceID)

	if pBuilding == nil then
		return 0
	end

	local pCell = BuildingObject(pBuilding):getCell(cellIndex)

	if pCell == nil then
		return 0
	end

	return SceneObject(pCell):getObjectID()
end

function axkvaMin:getKey(instanceID, suffix)
	return "axkvaMin:" .. instanceID .. ":" .. suffix
end

function axkvaMin:getGroupKey(groupID)
	return "axkvaMin:group:" .. groupID .. ":instance"
end

function axkvaMin:cleanupInstanceData(instanceID)
	local exitTerminalID = readData(self:getKey(instanceID, "exitTerminalID"))

	if exitTerminalID ~= 0 then
		deleteData(exitTerminalID .. ":axkvaMinInstance")
	end

	self:releaseInstancePlacement(instanceID)

	deleteData(self:getKey(instanceID, "active"))
	deleteData(self:getKey(instanceID, "leaderID"))
	deleteData(self:getGroupKey(readData(self:getKey(instanceID, "groupID"))))
	deleteData(self:getKey(instanceID, "groupID"))
	deleteData(self:getKey(instanceID, "grovoID"))
	deleteData(self:getKey(instanceID, "grovoPoisonTime"))
	deleteData(self:getKey(instanceID, "startTime"))
	deleteData(self:getKey(instanceID, "exitTerminalID"))
	deleteStringData(self:getKey(instanceID, "zone"))
end
