randomWorldBossEvent = ScreenPlay:new {
	numberOfActs = 1,
	screenplayName = "randomWorldBossEvent",
	checkIntervalMs = 60 * 60 * 1000,
	initialDelayMs = 60 * 1000,
	corpseCleanupMs = 120 * 1000,
	spawnChance = 35,
	bossConfigs = {
		{
			id = "kraytbone_chieftain",
			displayName = "Kraytbone Chieftain",
			template = "event_boss_kraytbone_chieftain",
			handler = "handleKraytboneChieftainDamage",
			spawnAreas = {
				{
					planet = "tatooine",
					minX = -5400,
					maxX = -5200,
					minY = -4550,
					maxY = -4350,
					heading = 165,
					cell = 0,
					useWorldFloor = true,
				},
			},
		},
		{
			id = "krayt_dragon_queen",
			displayName = "Krayt Dragon Queen",
			template = "event_boss_krayt_dragon_queen",
			handler = "handleKraytDragonQueenDamage",
			spawnAreas = {
				{
					planet = "tatooine",
					minX = 7280,
					maxX = 7480,
					minY = 4420,
					maxY = 4620,
					heading = 0,
					cell = 0,
					useWorldFloor = true,
				},
			},
		},
		{
			id = "necrosis",
			displayName = "Necrosis",
			template = "event_boss_necrosis",
			handler = "handleNecrosisDamage",
			spawnAreas = {
				{
					planet = "yavin4",
					minX = 1109,
					maxX = 1637,
					minY = -6710,
					maxY = -6261,
					heading = -90,
					cell = 0,
					useWorldFloor = true,
				},
			},
		},
		{
			id = "vx9_warden_prime",
			displayName = "VX-9 Warden Prime",
			template = "event_boss_vx9_warden_prime",
			handler = "handleVx9WardenPrimeDamage",
			spawnAreas = {
				{
					planet = "lok",
					minX = 3315,
					maxX = 3838,
					minY = -5130,
					maxY = -5000,
					heading = 180,
					cell = 0,
					useWorldFloor = true,
				},
			},
		},
		{
			id = "mother_nharra",
			displayName = "Mother Nharra",
			template = "event_boss_mother_nharra",
			handler = "handleMotherNharraDamage",
			spawnAreas = {
				{
					planet = "dathomir",
					minX = -120,
					maxX = -60,
					minY = -140,
					maxY = -70,
					heading = 0,
					cell = 0,
					useWorldFloor = true,
				},
			},
		},
	},
}

registerScreenPlay("randomWorldBossEvent", true)

function randomWorldBossEvent:start()
	if not self:hasEnabledBossZone() then
		return
	end

	self:clearActiveBossIfMissing()
	createEvent(self.initialDelayMs, self.screenplayName, "hourlySpawnCheck", nil, "")
end

function randomWorldBossEvent:hasEnabledBossZone()
	for i = 1, #self.bossConfigs, 1 do
		if self:hasEnabledSpawnArea(self.bossConfigs[i]) then
			return true
		end
	end

	return false
end

function randomWorldBossEvent:hourlySpawnCheck()
	self:clearActiveBossIfMissing()

	local pBoss = self:getActiveBoss()

	if pBoss ~= nil then
		local config = self:getActiveBossConfig()
		local planetName = readStringData(self:getGlobalKey("activeBossPlanet"))

		if config ~= nil then
			if CreatureObject(pBoss):isInCombat() or CreatureObject(pBoss):getTargetID() ~= 0 then
				self:broadcastGalaxy(self:getEngagedAnnouncement(config, planetName), pBoss)
			else
				self:broadcastGalaxy(self:getAtLargeAnnouncement(config, planetName), pBoss)
			end
		end
	elseif getRandomNumber(1, 100) <= self.spawnChance then
		self:spawnRandomBoss()
	end

	createEvent(self.checkIntervalMs, self.screenplayName, "hourlySpawnCheck", nil, "")
	return 0
end

function randomWorldBossEvent:spawnRandomBoss()
	local enabledBossIndexes = {}

	for i = 1, #self.bossConfigs, 1 do
		if self:hasEnabledSpawnArea(self.bossConfigs[i]) then
			table.insert(enabledBossIndexes, i)
		end
	end

	if #enabledBossIndexes == 0 then
		return nil
	end

	local configIndex = enabledBossIndexes[getRandomNumber(1, #enabledBossIndexes)]
	local config = self.bossConfigs[configIndex]
	local spawnLocation = self:rollSpawnLocation(config)

	if spawnLocation == nil then
		return nil
	end

	local pBoss = spawnMobile(
		spawnLocation.planet,
		config.template,
		0,
		spawnLocation.x,
		spawnLocation.z,
		spawnLocation.y,
		spawnLocation.heading,
		spawnLocation.cell
	)

	if pBoss == nil then
		return nil
	end

	local bossID = SceneObject(pBoss):getObjectID()
	writeData(self:getGlobalKey("activeBossID"), bossID)
	writeData(self:getGlobalKey("activeBossConfigIndex"), configIndex)
	writeStringData(self:getGlobalKey("activeBossPlanet"), spawnLocation.planet)
	writeData(self:getGlobalKey("activeBossX"), spawnLocation.x)
	writeData(self:getGlobalKey("activeBossY"), spawnLocation.y)
	writeStringData(self:getGlobalKey("activeBossName"), config.displayName)
	writeData(self:getBossKey(bossID, "phase"), 0)
	writeData(self:getBossKey(bossID, "supportCount"), 0)

	createObserver(DAMAGERECEIVED, self.screenplayName, "onBossDamaged", pBoss)
	createObserver(OBJECTDESTRUCTION, self.screenplayName, "onBossKilled", pBoss)

	self:broadcastGalaxy(self:getSpawnAnnouncement(config, spawnLocation.planet), pBoss)
	print("Random world boss spawned: " .. config.displayName .. " on " .. spawnLocation.planet .. " at " .. self:formatCoordinates(spawnLocation.x, spawnLocation.y))
	return pBoss
end

function randomWorldBossEvent:hasEnabledSpawnArea(config)
	if config == nil or config.spawnAreas == nil then
		return false
	end

	for i = 1, #config.spawnAreas, 1 do
		if isZoneEnabled(config.spawnAreas[i].planet) then
			return true
		end
	end

	return false
end

function randomWorldBossEvent:rollSpawnLocation(config)
	if config == nil or config.spawnAreas == nil or #config.spawnAreas == 0 then
		return nil
	end

	local enabledAreas = {}

	for i = 1, #config.spawnAreas, 1 do
		local area = config.spawnAreas[i]

		if isZoneEnabled(area.planet) then
			table.insert(enabledAreas, area)
		end
	end

	if #enabledAreas == 0 then
		return nil
	end

	local area = enabledAreas[getRandomNumber(1, #enabledAreas)]
	local x = getRandomNumber(area.minX, area.maxX)
	local y = getRandomNumber(area.minY, area.maxY)
	local heading = area.heading or 0
	local cell = area.cell or 0
	local z = area.z or 0

	if cell == 0 and area.useWorldFloor == true then
		z = getWorldFloor(x, y, area.planet) + 1
	end

	return {
		planet = area.planet,
		x = x,
		y = y,
		z = z,
		heading = heading,
		cell = cell,
	}
end

function randomWorldBossEvent:onBossDamaged(pBoss, pPlayer)
	if pBoss == nil then
		return 0
	end

	if self:getActiveBossID() ~= SceneObject(pBoss):getObjectID() then
		return 0
	end

	local config = self:getActiveBossConfig()

	if config == nil or config.handler == nil then
		return 0
	end

	local handler = self[config.handler]

	if handler == nil then
		return 0
	end

	return handler(self, pBoss, self:getCombatTarget(pBoss, pPlayer))
end

function randomWorldBossEvent:onBossKilled(pBoss)
	if pBoss == nil then
		return 0
	end

	local bossID = SceneObject(pBoss):getObjectID()
	local config = self:getActiveBossConfig()
	local planetName = readStringData(self:getGlobalKey("activeBossPlanet"))

	if config ~= nil then
		self:broadcastGalaxy(self:getDefeatedAnnouncement(config, planetName), pBoss)
	end

	self:cleanupTrackedSupport(bossID)
	self:clearActiveBoss()
	createEvent(self.corpseCleanupMs, self.screenplayName, "cleanupBossCorpse", pBoss, "")
	return 0
end

function randomWorldBossEvent:cleanupBossCorpse(pBoss)
	if pBoss == nil then
		return 0
	end

	local bossID = SceneObject(pBoss):getObjectID()
	self:resetBossState(bossID)

	if SceneObject(pBoss) ~= nil then
		SceneObject(pBoss):destroyObjectFromWorld()
	end

	return 0
end

function randomWorldBossEvent:handleKraytboneChieftainDamage(pBoss, pTarget)
	local boss = LuaCreatureObject(pBoss)

	if boss == nil then
		return 0
	end

	local health = boss:getHAM(0)
	local maxHealth = boss:getMaxHAM(0)
	local phaseKey = self:getBossKey(SceneObject(pBoss):getObjectID(), "phase")
	local phase = readData(phaseKey)

	if maxHealth <= 0 then
		return 0
	end

	if health <= (maxHealth * 0.9) and phase == 0 then
		writeData(phaseKey, 1)
		spatialChat(pBoss, "The Kraytbone will strip your bones in the sand!")
		self:scheduleTuskenPoisonVolley(pTarget)
		CreatureObject(pBoss):playEffect("clienteffect/attacker_berserk.cef", "")
	elseif health <= (maxHealth * 0.7) and phase == 1 then
		writeData(phaseKey, 2)
		spatialChat(pBoss, "Bloodguards, drive them into the dust!")
		self:scheduleTuskenPoisonVolley(pTarget)
		self:spawnTuskenSupport(pBoss, pTarget)
		self:sendMessageToGroup(pTarget, "You hear footsteps approaching!")
		CreatureObject(pBoss):playEffect("clienteffect/attacker_berserk.cef", "")
	elseif health <= (maxHealth * 0.5) and phase == 2 then
		writeData(phaseKey, 3)
		spatialChat(pBoss, "More of my tribe come for your heads!")
		self:scheduleTuskenPoisonVolley(pTarget)
		self:spawnTuskenSupport(pBoss, pTarget)
		self:sendMessageToGroup(pTarget, "You hear more footsteps approaching!")
		CreatureObject(pBoss):playEffect("clienteffect/attacker_berserk.cef", "")
	elseif health <= (maxHealth * 0.3) and phase == 3 then
		writeData(phaseKey, 4)
		spatialChat(pBoss, "The dunes themselves rise against you!")
		self:scheduleTuskenPoisonVolley(pTarget)
		self:spawnTuskenSupport(pBoss, pTarget)
		self:sendMessageToGroup(pTarget, "More footsteps echo in the tunnels.")
		CreatureObject(pBoss):playEffect("clienteffect/attacker_berserk.cef", "")
	elseif health <= (maxHealth * 0.1) and phase == 4 then
		writeData(phaseKey, 5)
		spatialChat(pBoss, "I will bury you beneath the krayt graves!")
		self:sendMessageToGroup(pTarget, "The Kraytbone Chieftain roars and charges in a final killing rush.")
		createEvent(1, self.screenplayName, "tuskenFinisher", pTarget, "")
		CreatureObject(pBoss):playEffect("clienteffect/attacker_berserk.cef", "")
	end

	return 0
end

function randomWorldBossEvent:handleVx9WardenPrimeDamage(pBoss, pTarget)
	local bossID = SceneObject(pBoss):getObjectID()
	local shieldCountKey = self:getBossKey(bossID, "shieldCount")

	if readData(shieldCountKey) > 0 then
		CreatureObject(pBoss):setHAM(0, readData(self:getBossKey(bossID, "shieldHealth")))
		CreatureObject(pBoss):setHAM(3, readData(self:getBossKey(bossID, "shieldAction")))
		CreatureObject(pBoss):setHAM(6, readData(self:getBossKey(bossID, "shieldMind")))
		return 0
	end

	local boss = LuaCreatureObject(pBoss)

	if boss == nil then
		return 0
	end

	local health = boss:getHAM(0)
	local maxHealth = boss:getMaxHAM(0)
	local phaseKey = self:getBossKey(bossID, "phase")
	local phase = readData(phaseKey)

	if maxHealth <= 0 then
		return 0
	end

	if health <= (maxHealth * 0.75) and phase == 0 then
		writeData(phaseKey, 1)
		spatialChat(pBoss, "Threat threshold exceeded. Shield lattice online.")
		self:activateWardenShield(pBoss, pTarget, {
			{"ig88_factory_droideka", -4, -2, 60},
			{"ig88_factory_droideka", 4, -2, -60},
		})
	elseif health <= (maxHealth * 0.5) and phase == 1 then
		writeData(phaseKey, 2)
		spatialChat(pBoss, "Escalating to full perimeter lockdown.")
		self:activateWardenShield(pBoss, pTarget, {
			{"ig88_factory_droideka", -5, 0, 45},
			{"ig88_factory_droideka", 5, 0, -45},
			{"ig88_factory_flame_droid", 0, 6, 180},
		})
	elseif health <= (maxHealth * 0.25) and phase == 2 then
		writeData(phaseKey, 3)
		spatialChat(pBoss, "Primary chassis compromised. All units converge.")
		self:activateWardenShield(pBoss, pTarget, {
			{"ig88_factory_droideka", -6, 2, 30},
			{"ig88_factory_droideka", 6, 2, -30},
			{"ig88_factory_droideka", 0, -6, 180},
			{"ig88_factory_flame_droid", 0, 7, 0},
		})
	end

	return 0
end

function randomWorldBossEvent:handleKraytDragonQueenDamage(pBoss, pTarget)
	local boss = LuaCreatureObject(pBoss)

	if boss == nil then
		return 0
	end

	local bossID = SceneObject(pBoss):getObjectID()
	local health = boss:getHAM(0)
	local maxHealth = boss:getMaxHAM(0)
	local phaseKey = self:getBossKey(bossID, "phase")
	local phase = readData(phaseKey)

	if maxHealth <= 0 then
		return 0
	end

	if health <= (maxHealth * 0.9) and phase == 0 then
		writeData(phaseKey, 1)
		CreatureObject(pBoss):playEffect("clienteffect/combat_special_defender_intimidate.cef", "")
		self:sendMessageToGroup(pTarget, "The Krayt Dragon Queen unleashes a terror-shaking roar!")
		self:applyGroupIntimidate(pBoss, pTarget, 18, nil)
	elseif health <= (maxHealth * 0.75) and phase == 1 then
		writeData(phaseKey, 2)
		CreatureObject(pBoss):playEffect("clienteffect/attacker_berserk.cef", "")
		self:sendMessageToGroup(pTarget, "Venom sprays from the Krayt Dragon Queen's maw!")
		self:scheduleKraytQueenPoisonStorm(pBoss, pTarget, 5)
		self:spawnKraytQueenWave(pBoss, pTarget, {
			{"event_boss_krayt_whelp", 10, -5, -20},
			{"event_boss_krayt_whelp", -10, -5, 20},
		})
	elseif health <= (maxHealth * 0.5) and phase == 2 then
		writeData(phaseKey, 3)
		CreatureObject(pBoss):playEffect("clienteffect/combat_special_defender_intimidate.cef", "")
		self:sendMessageToGroup(pTarget, "The Krayt Dragon Queen bellows and her brood surges forward!")
		self:applyGroupIntimidate(pBoss, pTarget, 18, nil)
		self:spawnKraytQueenWave(pBoss, pTarget, {
			{"event_boss_krayt_broodling", 0, 11, 180},
			{"event_boss_krayt_whelp", 8, -7, -30},
			{"event_boss_krayt_whelp", -8, -7, 30},
		})
	elseif health <= (maxHealth * 0.3) and phase == 3 then
		writeData(phaseKey, 4)
		CreatureObject(pBoss):playEffect("clienteffect/attacker_berserk.cef", "")
		self:sendMessageToGroup(pTarget, "Toxic clouds billow out across the battlefield!")
		self:scheduleKraytQueenPoisonStorm(pBoss, pTarget, 5)
		self:spawnKraytQueenWave(pBoss, pTarget, {
			{"event_boss_krayt_broodling", 7, 8, -45},
			{"event_boss_krayt_broodling", -7, 8, 45},
		})
	elseif health <= (maxHealth * 0.1) and phase == 4 then
		writeData(phaseKey, 5)
		CreatureObject(pBoss):playEffect("clienteffect/combat_special_defender_intimidate.cef", "")
		self:sendMessageToGroup(pTarget, "The Krayt Dragon Queen enters a furious last stand!")
		self:applyGroupIntimidate(pBoss, pTarget, 24, nil)
		self:scheduleKraytQueenPoisonStorm(pBoss, pTarget, 6)
		self:spawnKraytQueenWave(pBoss, pTarget, {
			{"event_boss_krayt_broodling", 0, 12, 180},
			{"event_boss_krayt_broodling", 10, 6, -60},
			{"event_boss_krayt_broodling", -10, 6, 60},
			{"event_boss_krayt_whelp", 12, -4, -25},
			{"event_boss_krayt_whelp", -12, -4, 25},
		})
	end

	return 0
end

function randomWorldBossEvent:handleNecrosisDamage(pBoss, pTarget)
	local boss = LuaCreatureObject(pBoss)

	if boss == nil then
		return 0
	end

	local bossID = SceneObject(pBoss):getObjectID()
	local health = boss:getHAM(0)
	local maxHealth = boss:getMaxHAM(0)
	local phaseKey = self:getBossKey(bossID, "phase")
	local phase = readData(phaseKey)

	if maxHealth <= 0 then
		return 0
	end

	if health <= (maxHealth * 0.9) and phase == 0 then
		writeData(phaseKey, 1)
		spatialChat(pBoss, "I walked into death centuries ago, and death learned to fear me.")
		CreatureObject(pBoss):playEffect("clienteffect/pl_storm_lord_special.cef", "")
	elseif health <= (maxHealth * 0.75) and phase == 1 then
		writeData(phaseKey, 2)
		spatialChat(pBoss, "Breathe deep. Let the grave mist settle in your lungs.")
		CreatureObject(pBoss):playEffect("clienteffect/pl_force_resist_states_self.cef", "")
		self:scheduleNecrosisPoisonFog(pBoss, pTarget, 5)
		self:spawnNecrosisWave(pBoss, pTarget, {
			{"event_boss_necrotic_thrall", -5, -3, 35},
			{"event_boss_necrotic_thrall", 5, -3, -35},
		})
	elseif health <= (maxHealth * 0.55) and phase == 2 then
		writeData(phaseKey, 3)
		spatialChat(pBoss, "Your heartbeat is a prayer. I will answer it with hunger.")
		CreatureObject(pBoss):playEffect("clienteffect/pl_force_channel_self.cef", "")
		createEvent(1, self.screenplayName, "necrosisLifeDrain", pBoss, "")
	elseif health <= (maxHealth * 0.35) and phase == 3 then
		writeData(phaseKey, 4)
		spatialChat(pBoss, "Rise, my shadows. The living are nearly yours.")
		CreatureObject(pBoss):playEffect("clienteffect/combat_special_defender_intimidate.cef", "")
		self:scheduleNecrosisPoisonFog(pBoss, pTarget, 6)
		self:spawnNecrosisWave(pBoss, pTarget, {
			{"event_boss_gravebound_shadow", 0, 7, 180},
			{"event_boss_necrotic_thrall", -7, 1, 55},
			{"event_boss_necrotic_thrall", 7, 1, -55},
		})
	elseif health <= (maxHealth * 0.15) and phase == 4 then
		writeData(phaseKey, 5)
		spatialChat(pBoss, "I am the rot beneath the temple stones. I do not end.")
		CreatureObject(pBoss):playEffect("clienteffect/pl_force_channel_self.cef", "")
		createEvent(1, self.screenplayName, "necrosisLifeDrain", pBoss, "")
		self:spawnNecrosisWave(pBoss, pTarget, {
			{"event_boss_gravebound_shadow", -6, 4, 45},
			{"event_boss_gravebound_shadow", 6, 4, -45},
		})
	end

	return 0
end

function randomWorldBossEvent:handleMotherNharraDamage(pBoss, pTarget)
	local boss = LuaCreatureObject(pBoss)

	if boss == nil then
		return 0
	end

	local bossID = SceneObject(pBoss):getObjectID()
	local health = boss:getHAM(0)
	local maxHealth = boss:getMaxHAM(0)
	local action = boss:getHAM(3)
	local maxAction = boss:getMaxHAM(3)
	local phaseKey = self:getBossKey(bossID, "phase")
	local phase = readData(phaseKey)

	if maxHealth <= 0 then
		return 0
	end

	if action <= (maxAction * 0.3) then
		CreatureObject(pBoss):setHAM(3, maxAction)
		CreatureObject(pBoss):playEffect("clienteffect/pl_force_meditate_self.cef", "")
		spatialChat(pBoss, "The spirits restore my strength!")
	end

	if health <= (maxHealth * 0.9) and phase == 0 then
		writeData(phaseKey, 1)
		spatialChat(pBoss, "The spirits warned me that hunters would come.")
		CreatureObject(pBoss):playEffect("clienteffect/pl_storm_lord_special.cef", "")
	elseif health <= (maxHealth * 0.75) and phase == 1 then
		writeData(phaseKey, 2)
		spatialChat(pBoss, "Daughters of the mist, harvest them!")
		CreatureObject(pBoss):playEffect("clienteffect/combat_pt_electricalfield.cef", "")
		self:spawnNightsisterWave(pBoss, pTarget, {
			{"event_boss_nightsister_reaver", -4, -3, 30},
			{"event_boss_nightsister_reaver", 4, -3, -30},
			{"event_boss_nightsister_reaver", -2, 5, 90},
			{"event_boss_nightsister_reaver", 2, 5, -90},
		})
	elseif health <= (maxHealth * 0.5) and phase == 2 then
		writeData(phaseKey, 3)
		spatialChat(pBoss, "Your fear sweetens the air. I will drink it in.")
		CreatureObject(pBoss):playEffect("clienteffect/pl_force_resist_states_self.cef", "")
		self:spawnNightsisterWave(pBoss, pTarget, {
			{"event_boss_nightsister_crone", 0, 6, 180},
			{"event_boss_nightsister_reaver", -5, 2, 45},
			{"event_boss_nightsister_reaver", 5, 2, -45},
		})
	elseif health <= (maxHealth * 0.25) and phase == 3 then
		writeData(phaseKey, 4)
		spatialChat(pBoss, "Even now the dead gather to shield me.")
		CreatureObject(pBoss):playEffect("clienteffect/pl_storm_lord_special.cef", "")
		self:spawnNightsisterWave(pBoss, pTarget, {
			{"event_boss_nightsister_reaver", -6, -1, 10},
			{"event_boss_nightsister_reaver", 6, -1, -10},
			{"event_boss_nightsister_reaver", -3, 6, 110},
			{"event_boss_nightsister_reaver", 3, 6, -110},
		})
	elseif health <= (maxHealth * 0.1) and phase == 4 then
		writeData(phaseKey, 5)
		spatialChat(pBoss, "No. The spirits cannot abandon me now!")
		CreatureObject(pBoss):playEffect("clienteffect/combat_pt_electricalfield.cef", "")
		createEvent(1, self.screenplayName, "motherNharraForcePulse", pTarget, "")
	end

	return 0
end

function randomWorldBossEvent:scheduleTuskenPoisonVolley(pTarget)
	createEvent(0, self.screenplayName, "tuskenPoisonBomb", pTarget, "")
	createEvent(5 * 1000, self.screenplayName, "tuskenPoisonBomb", pTarget, "")
	createEvent(10 * 1000, self.screenplayName, "tuskenPoisonBomb", pTarget, "")
	createEvent(15 * 1000, self.screenplayName, "tuskenPoisonBomb", pTarget, "")
	createEvent(20 * 1000, self.screenplayName, "tuskenPoisonBomb", pTarget, "")
end

function randomWorldBossEvent:tuskenPoisonBomb(pTarget)
	self:applyGroupPulseDamage(pTarget, 400, 500, "clienteffect/avatar_wke_sonic.cef", nil)
	return 0
end

function randomWorldBossEvent:tuskenFinisher(pTarget)
	self:applyGroupPulseDamage(pTarget, 2800, 4200, "clienteffect/avatar_wke_sonic.cef", nil)
	return 0
end

function randomWorldBossEvent:scheduleKraytQueenPoisonStorm(pBoss, pTarget, tickCount)
	if pBoss == nil then
		return
	end

	local ticks = tickCount or 5
	self:sendMessageToGroup(pTarget, "A corrosive venom clings to your lungs and saps your strength.")

	for i = 0, ticks - 1, 1 do
		createEvent(i * 3 * 1000, self.screenplayName, "kraytQueenPoisonTick", pBoss, "")
	end
end

function randomWorldBossEvent:kraytQueenPoisonTick(pBoss)
	if pBoss == nil then
		return 0
	end

	local pTarget = self:getCombatTarget(pBoss, nil)

	if pTarget == nil then
		return 0
	end

	self:applyGroupActionDamage(pBoss, pTarget, 0.5, 200, nil)
	return 0
end

function randomWorldBossEvent:scheduleNecrosisPoisonFog(pBoss, pTarget, tickCount)
	if pBoss == nil then
		return
	end

	local ticks = tickCount or 5
	self:sendMessageToGroup(pTarget, "A poison fog rolls out from Necrosis and gnaws at living flesh.")

	for i = 0, ticks - 1, 1 do
		createEvent(i * 3 * 1000, self.screenplayName, "necrosisPoisonFogTick", pBoss, "")
	end
end

function randomWorldBossEvent:necrosisPoisonFogTick(pBoss)
	if pBoss == nil then
		return 0
	end

	local pTarget = self:getCombatTarget(pBoss, nil)

	if pTarget == nil then
		return 0
	end

	self:applyGroupHealthDamage(pBoss, pTarget, 900, 1350, 200, "clienteffect/pl_force_shock.cef", nil)
	return 0
end

function randomWorldBossEvent:necrosisLifeDrain(pBoss)
	if pBoss == nil then
		return 0
	end

	local pTarget = self:getCombatTarget(pBoss, nil)

	if pTarget == nil then
		return 0
	end

	local totalDamage = self:drainLifeFromGroup(pBoss, pTarget, 1400, 2000, 200, "clienteffect/pl_force_shock.cef", "Necrosis tears vitality from the living!")

	if totalDamage > 0 then
		self:healBossFromDrain(pBoss, math.floor(totalDamage * 0.35))
	end

	return 0
end

function randomWorldBossEvent:motherNharraForcePulse(pTarget)
	self:applyGroupPulseDamage(pTarget, 2000, 3000, "clienteffect/pl_force_shock.cef", "Mother Nharra lashes out with a violent force pulse!")
	return 0
end

function randomWorldBossEvent:spawnNecrosisWave(pBoss, pTarget, waveData)
	for i = 1, #waveData, 1 do
		local spawnData = waveData[i]
		self:spawnTrackedSupport(pBoss, spawnData[1], spawnData[2], spawnData[3], spawnData[4], pTarget, nil)
	end
end

function randomWorldBossEvent:spawnKraytQueenWave(pBoss, pTarget, waveData)
	for i = 1, #waveData, 1 do
		local spawnData = waveData[i]
		self:spawnTrackedSupport(pBoss, spawnData[1], spawnData[2], spawnData[3], spawnData[4], pTarget, nil)
	end
end

function randomWorldBossEvent:spawnTuskenSupport(pBoss, pTarget)
	self:spawnTrackedSupport(pBoss, "event_boss_tusken_bloodguard", 6, -5, -40, pTarget, nil)
	self:spawnTrackedSupport(pBoss, "event_boss_tusken_bloodguard", -1, -7, 12, pTarget, nil)
	self:spawnTrackedSupport(pBoss, "event_boss_tusken_bloodguard", -2, -3, 48, pTarget, nil)
end

function randomWorldBossEvent:spawnNightsisterWave(pBoss, pTarget, waveData)
	for i = 1, #waveData, 1 do
		local spawnData = waveData[i]
		self:spawnTrackedSupport(pBoss, spawnData[1], spawnData[2], spawnData[3], spawnData[4], pTarget, nil)
	end
end

function randomWorldBossEvent:activateWardenShield(pBoss, pTarget, waveData)
	local bossID = SceneObject(pBoss):getObjectID()
	writeData(self:getBossKey(bossID, "shieldHealth"), CreatureObject(pBoss):getHAM(0))
	writeData(self:getBossKey(bossID, "shieldAction"), CreatureObject(pBoss):getHAM(3))
	writeData(self:getBossKey(bossID, "shieldMind"), CreatureObject(pBoss):getHAM(6))
	writeData(self:getBossKey(bossID, "shieldCount"), 0)
	spatialChat(pBoss, "Auxiliary units, restore the perimeter.")
	CreatureObject(pBoss):playEffect("clienteffect/combat_pt_electricalfield.cef", "")

	for i = 1, #waveData, 1 do
		local spawnData = waveData[i]
		self:spawnTrackedSupport(pBoss, spawnData[1], spawnData[2], spawnData[3], spawnData[4], pTarget, "wardenShield")
	end
end

function randomWorldBossEvent:onSupportAddKilled(pAdd)
	if pAdd == nil then
		return 0
	end

	local addID = SceneObject(pAdd):getObjectID()
	local role = readStringData(self:getSupportKey(addID, "role"))

	if role == "wardenShield" then
		local bossID = readData(self:getSupportKey(addID, "bossID"))
		local remaining = math.max(0, readData(self:getBossKey(bossID, "shieldCount")) - 1)
		writeData(self:getBossKey(bossID, "shieldCount"), remaining)

		if remaining == 0 then
			deleteData(self:getBossKey(bossID, "shieldHealth"))
			deleteData(self:getBossKey(bossID, "shieldAction"))
			deleteData(self:getBossKey(bossID, "shieldMind"))

			local pBoss = getSceneObject(bossID)
			if pBoss ~= nil then
				spatialChat(pBoss, "Defensive perimeter breached.")
			end
		end
	end

	deleteData(self:getSupportKey(addID, "bossID"))
	deleteStringData(self:getSupportKey(addID, "role"))
	return 0
end

function randomWorldBossEvent:spawnTrackedSupport(pBoss, template, offsetX, offsetY, heading, pTarget, role)
	if pBoss == nil then
		return nil
	end

	local boss = LuaCreatureObject(pBoss)

	if boss == nil then
		return nil
	end

	local zoneName = SceneObject(pBoss):getZoneName()
	local cellID = SceneObject(pBoss):getParentID()
	local spawnX = boss:getPositionX() + offsetX
	local spawnY = boss:getPositionY() + offsetY
	local spawnZ = boss:getPositionZ()
	local pAdd = spawnMobile(zoneName, template, 0, spawnX, spawnZ, spawnY, heading, cellID)

	if pAdd == nil then
		return nil
	end

	local bossID = SceneObject(pBoss):getObjectID()
	local addID = SceneObject(pAdd):getObjectID()
	local supportCountKey = self:getBossKey(bossID, "supportCount")
	local supportCount = readData(supportCountKey) + 1

	writeData(supportCountKey, supportCount)
	writeData(self:getBossKey(bossID, "support:" .. supportCount), addID)
	writeData(self:getSupportKey(addID, "bossID"), bossID)

	if role ~= nil then
		writeStringData(self:getSupportKey(addID, "role"), role)
		createObserver(OBJECTDESTRUCTION, self.screenplayName, "onSupportAddKilled", pAdd)

		if role == "wardenShield" then
			writeData(self:getBossKey(bossID, "shieldCount"), readData(self:getBossKey(bossID, "shieldCount")) + 1)
		end
	end

	if pTarget ~= nil then
		CreatureObject(pAdd):engageCombat(pTarget)
	end

	return pAdd
end

function randomWorldBossEvent:cleanupTrackedSupport(bossID)
	local supportCount = readData(self:getBossKey(bossID, "supportCount"))

	for i = 1, supportCount, 1 do
		local addID = readData(self:getBossKey(bossID, "support:" .. i))
		local pAdd = getSceneObject(addID)

		if pAdd ~= nil then
			SceneObject(pAdd):destroyObjectFromWorld()
		end

		deleteData(self:getSupportKey(addID, "bossID"))
		deleteStringData(self:getSupportKey(addID, "role"))
		deleteData(self:getBossKey(bossID, "support:" .. i))
	end
end

function randomWorldBossEvent:applyGroupPulseDamage(pTarget, minDamage, maxDamage, effect, message)
	if pTarget == nil or not SceneObject(pTarget):isPlayerCreature() then
		return
	end

	if CreatureObject(pTarget):isGrouped() then
		local groupSize = CreatureObject(pTarget):getGroupSize()

		for i = 0, groupSize - 1, 1 do
			local pMember = CreatureObject(pTarget):getGroupMember(i)

			if pMember ~= nil and SceneObject(pMember):isInRangeWithObject(pTarget, 200) then
				self:damageTarget(pMember, minDamage, maxDamage, effect, message)
			end
		end
	else
		self:damageTarget(pTarget, minDamage, maxDamage, effect, message)
	end
end

function randomWorldBossEvent:damageTarget(pTarget, minDamage, maxDamage, effect, message)
	local damage = getRandomNumber(minDamage, maxDamage)
	CreatureObject(pTarget):inflictDamage(pTarget, 0, damage, 1)

	if effect ~= nil and effect ~= "" then
		CreatureObject(pTarget):playEffect(effect, "")
	end

	if message ~= nil and message ~= "" then
		CreatureObject(pTarget):sendSystemMessage(message)
	end
end

function randomWorldBossEvent:applyGroupHealthDamage(pBoss, pTarget, minDamage, maxDamage, range, effect, message)
	if pBoss == nil or pTarget == nil or not SceneObject(pTarget):isPlayerCreature() then
		return
	end

	local maxRange = range or 200

	if CreatureObject(pTarget):isGrouped() then
		local groupSize = CreatureObject(pTarget):getGroupSize()

		for i = 0, groupSize - 1, 1 do
			local pMember = CreatureObject(pTarget):getGroupMember(i)

			if pMember ~= nil and SceneObject(pMember):isInRangeWithObject(pBoss, maxRange) then
				self:damageTargetFromSource(pBoss, pMember, minDamage, maxDamage, effect, message)
			end
		end
	else
		self:damageTargetFromSource(pBoss, pTarget, minDamage, maxDamage, effect, message)
	end
end

function randomWorldBossEvent:damageTargetFromSource(pSource, pTarget, minDamage, maxDamage, effect, message)
	local damage = getRandomNumber(minDamage, maxDamage)
	CreatureObject(pTarget):inflictDamage(pSource, 0, damage, 1)

	if effect ~= nil and effect ~= "" then
		CreatureObject(pTarget):playEffect(effect, "")
	end

	if message ~= nil and message ~= "" then
		CreatureObject(pTarget):sendSystemMessage(message)
	end
end

function randomWorldBossEvent:drainLifeFromGroup(pBoss, pTarget, minDamage, maxDamage, range, effect, message)
	if pBoss == nil or pTarget == nil or not SceneObject(pTarget):isPlayerCreature() then
		return 0
	end

	local totalDamage = 0
	local maxRange = range or 200

	if CreatureObject(pTarget):isGrouped() then
		local groupSize = CreatureObject(pTarget):getGroupSize()

		for i = 0, groupSize - 1, 1 do
			local pMember = CreatureObject(pTarget):getGroupMember(i)

			if pMember ~= nil and SceneObject(pMember):isInRangeWithObject(pBoss, maxRange) then
				totalDamage = totalDamage + self:drainTargetHealth(pBoss, pMember, minDamage, maxDamage, effect, message)
			end
		end
	else
		totalDamage = self:drainTargetHealth(pBoss, pTarget, minDamage, maxDamage, effect, message)
	end

	return totalDamage
end

function randomWorldBossEvent:drainTargetHealth(pBoss, pTarget, minDamage, maxDamage, effect, message)
	local damage = getRandomNumber(minDamage, maxDamage)
	CreatureObject(pTarget):inflictDamage(pBoss, 0, damage, 1)

	if effect ~= nil and effect ~= "" then
		CreatureObject(pTarget):playEffect(effect, "")
	end

	if message ~= nil and message ~= "" then
		CreatureObject(pTarget):sendSystemMessage(message)
	end

	return damage
end

function randomWorldBossEvent:healBossFromDrain(pBoss, healAmount)
	if pBoss == nil or healAmount <= 0 then
		return
	end

	local currentHealth = CreatureObject(pBoss):getHAM(0)
	local maxHealth = CreatureObject(pBoss):getMaxHAM(0)
	local newHealth = math.min(maxHealth, currentHealth + healAmount)
	CreatureObject(pBoss):setHAM(0, newHealth)
	CreatureObject(pBoss):playEffect("clienteffect/pl_force_channel_self.cef", "")
end

function randomWorldBossEvent:applyGroupActionDamage(pBoss, pTarget, maxActionPercent, range, message)
	if pBoss == nil or pTarget == nil or not SceneObject(pTarget):isPlayerCreature() then
		return
	end

	local maxRange = range or 200

	if CreatureObject(pTarget):isGrouped() then
		local groupSize = CreatureObject(pTarget):getGroupSize()

		for i = 0, groupSize - 1, 1 do
			local pMember = CreatureObject(pTarget):getGroupMember(i)

			if pMember ~= nil and SceneObject(pMember):isInRangeWithObject(pBoss, maxRange) then
				self:damageTargetActionPool(pBoss, pMember, maxActionPercent, message)
			end
		end
	else
		self:damageTargetActionPool(pBoss, pTarget, maxActionPercent, message)
	end
end

function randomWorldBossEvent:damageTargetActionPool(pSource, pTarget, maxActionPercent, message)
	local actionDamage = math.max(1, math.floor(CreatureObject(pTarget):getMaxHAM(3) * maxActionPercent))
	CreatureObject(pTarget):inflictDamage(pSource, 3, actionDamage, true)

	if message ~= nil and message ~= "" then
		CreatureObject(pTarget):sendSystemMessage(message)
	end
end

function randomWorldBossEvent:applyGroupIntimidate(pBoss, pTarget, durationSeconds, message)
	if pBoss == nil or pTarget == nil or not SceneObject(pTarget):isPlayerCreature() then
		return
	end

	local duration = durationSeconds or 15

	if CreatureObject(pTarget):isGrouped() then
		local groupSize = CreatureObject(pTarget):getGroupSize()

		for i = 0, groupSize - 1, 1 do
			local pMember = CreatureObject(pTarget):getGroupMember(i)

			if pMember ~= nil and SceneObject(pMember):isInRangeWithObject(pBoss, 200) then
				self:intimidateTarget(pMember, duration, message)
			end
		end
	else
		self:intimidateTarget(pTarget, duration, message)
	end
end

function randomWorldBossEvent:intimidateTarget(pTarget, durationSeconds, message)
	CreatureObject(pTarget):setIntimidatedState(durationSeconds)

	if message ~= nil and message ~= "" then
		CreatureObject(pTarget):sendSystemMessage(message)
	end
end

function randomWorldBossEvent:sendMessageToGroup(pTarget, message)
	if pTarget == nil or message == nil or message == "" or not SceneObject(pTarget):isPlayerCreature() then
		return
	end

	if CreatureObject(pTarget):isGrouped() then
		local groupSize = CreatureObject(pTarget):getGroupSize()

		for i = 0, groupSize - 1, 1 do
			local pMember = CreatureObject(pTarget):getGroupMember(i)

			if pMember ~= nil and SceneObject(pMember):isInRangeWithObject(pTarget, 200) then
				CreatureObject(pMember):sendSystemMessage(message)
			end
		end
	else
		CreatureObject(pTarget):sendSystemMessage(message)
	end
end

function randomWorldBossEvent:getCombatTarget(pBoss, pPlayer)
	if pPlayer ~= nil and SceneObject(pPlayer):isPlayerCreature() then
		return pPlayer
	end

	if pBoss == nil then
		return nil
	end

	local targetID = CreatureObject(pBoss):getTargetID()

	if targetID == 0 then
		return nil
	end

	local pTarget = getSceneObject(targetID)

	if pTarget ~= nil and SceneObject(pTarget):isPlayerCreature() then
		return pTarget
	end

	return nil
end

function randomWorldBossEvent:broadcastGalaxy(message, pReference)
	if message == nil or message == "" or pReference == nil then
		return
	end

	broadcastToGalaxy(pReference, message)
end

function randomWorldBossEvent:getSpawnAnnouncement(config, planetName)
	return config.displayName .. " has spawned on " .. self:formatPlanetName(planetName) .. "."
end

function randomWorldBossEvent:getAtLargeAnnouncement(config, planetName)
	return config.displayName .. " is still at large on " .. self:formatPlanetName(planetName) .. "."
end

function randomWorldBossEvent:getEngagedAnnouncement(config, planetName)
	return config.displayName .. " has been engaged on " .. self:formatPlanetName(planetName) .. ". Wish the heroes luck!"
end

function randomWorldBossEvent:getDefeatedAnnouncement(config, planetName)
	return config.displayName .. " has been slain on " .. self:formatPlanetName(planetName) .. ". Congratulations to the adventurers who defeated this menace!"
end

function randomWorldBossEvent:formatPlanetName(planetName)
	if planetName == nil or planetName == "" then
		return "parts unknown"
	end

	local formatted = string.gsub(planetName, "_", " ")
	return string.upper(string.sub(formatted, 1, 1)) .. string.sub(formatted, 2)
end

function randomWorldBossEvent:formatCoordinates(x, y)
	return "(" .. math.floor(x or 0) .. ", " .. math.floor(y or 0) .. ")"
end

function randomWorldBossEvent:getActiveBoss()
	local activeBossID = self:getActiveBossID()

	if activeBossID == 0 then
		return nil
	end

	return getSceneObject(activeBossID)
end

function randomWorldBossEvent:getActiveBossID()
	return readData(self:getGlobalKey("activeBossID"))
end

function randomWorldBossEvent:getActiveBossConfig()
	local configIndex = readData(self:getGlobalKey("activeBossConfigIndex"))

	if configIndex <= 0 then
		return nil
	end

	return self.bossConfigs[configIndex]
end

function randomWorldBossEvent:clearActiveBossIfMissing()
	local activeBossID = self:getActiveBossID()

	if activeBossID == 0 then
		return
	end

	if getSceneObject(activeBossID) == nil then
		self:clearActiveBoss()
	end
end

function randomWorldBossEvent:clearActiveBoss()
	deleteData(self:getGlobalKey("activeBossID"))
	deleteData(self:getGlobalKey("activeBossConfigIndex"))
	deleteStringData(self:getGlobalKey("activeBossPlanet"))
	deleteData(self:getGlobalKey("activeBossX"))
	deleteData(self:getGlobalKey("activeBossY"))
	deleteStringData(self:getGlobalKey("activeBossName"))
end

function randomWorldBossEvent:resetBossState(bossID)
	deleteData(self:getBossKey(bossID, "phase"))
	deleteData(self:getBossKey(bossID, "supportCount"))
	deleteData(self:getBossKey(bossID, "shieldCount"))
	deleteData(self:getBossKey(bossID, "shieldHealth"))
	deleteData(self:getBossKey(bossID, "shieldAction"))
	deleteData(self:getBossKey(bossID, "shieldMind"))
end

function randomWorldBossEvent:getGlobalKey(suffix)
	return self.screenplayName .. ":" .. suffix
end

function randomWorldBossEvent:getBossKey(bossID, suffix)
	return self.screenplayName .. ":" .. bossID .. ":" .. suffix
end

function randomWorldBossEvent:getSupportKey(addID, suffix)
	return self.screenplayName .. ":support:" .. addID .. ":" .. suffix
end
