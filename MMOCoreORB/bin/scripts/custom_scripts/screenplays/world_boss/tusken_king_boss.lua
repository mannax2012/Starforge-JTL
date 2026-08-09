tusken_king_bossScreenplay = ScreenPlay:new {
	numberOfActs = 1,
	planet = "tatooine",
	bossTemplate = "tusken_king_boss",
	bossX = 37.2,
	bossZ = 22.9,
	bossY = 19.7,
	bossDirection = 165,
	bossCell = 1189182,
	corpseDespawnDelay = 120 * 1000,
	respawnMinimum = 7200 * 1000,
	respawnMaximum = 10800 * 1000,
	spawnRetryDelay = 60 * 1000,
	spawnStateKey = "tusken_king_bossScreenplay:spawnState",
	respawnScheduledKey = "tusken_king_bossScreenplay:respawnScheduled",
}
registerScreenPlay("tusken_king_bossScreenplay", true)

function tusken_king_bossScreenplay:start()
	if (isZoneEnabled(self.planet)) then
		-- Script events do not survive a zone restart, so begin each zone boot with
		-- a fresh boss instead of honoring an orphaned scheduled-respawn flag.
		writeData(self.respawnScheduledKey, 0)
		self:spawnBoss()
		print("Tusken King Loaded")
	end
end

function tusken_king_bossScreenplay:spawnMobiles()
	self:spawnBoss()
end

function tusken_king_bossScreenplay:spawnBoss()
	-- Use -1 because this screenplay owns the respawn timer. A positive
	-- spawnMobile delay would create a second, independent respawn path.
	local pBoss = spawnMobile(self.planet, self.bossTemplate, -1, self.bossX, self.bossZ, self.bossY, self.bossDirection, self.bossCell)

	if (pBoss == nil) then
		print("ERROR: Tusken King spawn failed; retrying in 60 seconds.")
		writeData(self.respawnScheduledKey, 1)
		createEvent(self.spawnRetryDelay, "tusken_king_bossScreenplay", "spawnBoss", "", "")
		return 1
	end

	writeData(self.spawnStateKey, 0)
	writeData(self.respawnScheduledKey, 0)
	createObserver(DAMAGERECEIVED, "tusken_king_bossScreenplay", "npcDamageObserver", pBoss)
	createObserver(OBJECTDESTRUCTION, "tusken_king_bossScreenplay", "bossDead", pBoss)
	print("Tusken King Spawned")
	return 0
end

function tusken_king_bossScreenplay:npcDamageObserver(bossObject, playerObject, damage)

	local player = LuaCreatureObject(playerObject)
	local boss = LuaCreatureObject(bossObject)

	local health = boss:getHAM(0)
	local maxHealth = boss:getMaxHAM(0)

	if (((health <= (maxHealth * 0.9))) and readData(self.spawnStateKey) == 0) then
		writeData(self.spawnStateKey,1)
			createEvent(0 * 1000, "tusken_king_bossScreenplay", "poisonbomb", playerObject, "")
 			createEvent(5 * 1000, "tusken_king_bossScreenplay", "poisonbomb", playerObject, "")
			createEvent(10 * 1000, "tusken_king_bossScreenplay", "poisonbomb", playerObject, "")
			createEvent(15 * 1000, "tusken_king_bossScreenplay", "poisonbomb", playerObject, "")
			createEvent(20 * 1000, "tusken_king_bossScreenplay", "poisonbomb", playerObject, "")       
      			CreatureObject(bossObject):playEffect("clienteffect/attacker_berserk.cef", "")
	end

	if (((health <= (maxHealth * 0.7))) and readData(self.spawnStateKey) == 1) then
		writeData(self.spawnStateKey,2)
			createEvent(0 * 1000, "tusken_king_bossScreenplay", "poisonbomb", playerObject, "")
 			createEvent(5 * 1000, "tusken_king_bossScreenplay", "poisonbomb", playerObject, "")
			createEvent(10 * 1000, "tusken_king_bossScreenplay", "poisonbomb", playerObject, "")
			createEvent(15 * 1000, "tusken_king_bossScreenplay", "poisonbomb", playerObject, "")
			createEvent(20 * 1000, "tusken_king_bossScreenplay", "poisonbomb", playerObject, "")        
			self:spawnSupport(playerObject)
      			CreatureObject(playerObject):sendSystemMessage("You hear footsteps approaching!")
      			CreatureObject(bossObject):playEffect("clienteffect/attacker_berserk.cef", "")
	end

	if (((health <= (maxHealth * 0.5))) and readData(self.spawnStateKey) == 2) then
		writeData(self.spawnStateKey,3)
			createEvent(0 * 1000, "tusken_king_bossScreenplay", "poisonbomb", playerObject, "")
 			createEvent(5 * 1000, "tusken_king_bossScreenplay", "poisonbomb", playerObject, "")
			createEvent(10 * 1000, "tusken_king_bossScreenplay", "poisonbomb", playerObject, "")
			createEvent(15 * 1000, "tusken_king_bossScreenplay", "poisonbomb", playerObject, "")
			createEvent(20 * 1000, "tusken_king_bossScreenplay", "poisonbomb", playerObject, "")     
			self:spawnSupport(playerObject)
      			CreatureObject(playerObject):sendSystemMessage("You hear more footsteps approaching!")
      			CreatureObject(bossObject):playEffect("clienteffect/attacker_berserk.cef", "")
	end

	if (((health <= (maxHealth * 0.3))) and readData(self.spawnStateKey) == 3) then
		writeData(self.spawnStateKey,4)
			createEvent(0 * 1000, "tusken_king_bossScreenplay", "poisonbomb", playerObject, "")
 			createEvent(5 * 1000, "tusken_king_bossScreenplay", "poisonbomb", playerObject, "")
			createEvent(10 * 1000, "tusken_king_bossScreenplay", "poisonbomb", playerObject, "")
			createEvent(15 * 1000, "tusken_king_bossScreenplay", "poisonbomb", playerObject, "")
			createEvent(20 * 1000, "tusken_king_bossScreenplay", "poisonbomb", playerObject, "")      
			self:spawnSupport(playerObject)
      			CreatureObject(playerObject):sendSystemMessage("More footsteps echo in the tunnels")
      			CreatureObject(bossObject):playEffect("clienteffect/attacker_berserk.cef", "")
	end

	if (((health <= (maxHealth * 0.1))) and readData(self.spawnStateKey) == 4) then
		writeData(self.spawnStateKey,5)
			createEvent(0 * 1000, "tusken_king_bossScreenplay", "tuskenfinisher", playerObject, "")  
				CreatureObject(playerObject):sendSystemMessage("The Tusken King roars and swings his Gaffi stick in a last ditch attempt to kill you.")			
      			CreatureObject(bossObject):playEffect("clienteffect/attacker_berserk.cef", "")
		end
	return 0

end

function tusken_king_bossScreenplay:poisonbomb(playerObject)
if (CreatureObject(playerObject):isGrouped()) then
	local groupSize = CreatureObject(playerObject):getGroupSize()
	for i = 0, groupSize - 1, 1 do
		local pMember = CreatureObject(playerObject):getGroupMember(i)
		if pMember ~= nil and SceneObject(pMember):isInRangeWithObject(playerObject, 200) then
		local trapDmg = getRandomNumber(400, 500)
		CreatureObject(pMember):inflictDamage(pMember, 0, trapDmg, 1)
      		CreatureObject(pMember):playEffect("clienteffect/avatar_wke_sonic.cef", "")
		end
	end
else
	local trapDmg = getRandomNumber(400, 500)
	CreatureObject(playerObject):inflictDamage(playerObject, 0, trapDmg, 1)
      	CreatureObject(playerObject):playEffect("clienteffect/avatar_wke_sonic.cef", "")
	end
end

function tusken_king_bossScreenplay:tuskenfinisher(playerObject)
if (CreatureObject(playerObject):isGrouped()) then
	local groupSize = CreatureObject(playerObject):getGroupSize()
	for i = 0, groupSize - 1, 1 do
		local pMember = CreatureObject(playerObject):getGroupMember(i)
		if pMember ~= nil and SceneObject(pMember):isInRangeWithObject(playerObject, 200) then
		local trapDmg = getRandomNumber(2800, 4200)
		CreatureObject(pMember):inflictDamage(pMember, 0, trapDmg, 1)
      		CreatureObject(pMember):playEffect("clienteffect/avatar_wke_sonic.cef", "")
		end
	end
else
	local trapDmg = getRandomNumber(2800, 4200)
	CreatureObject(playerObject):inflictDamage(playerObject, 0, trapDmg, 1)
      	CreatureObject(playerObject):playEffect("clienteffect/avatar_wke_sonic.cef", "")
	end
end

function tusken_king_bossScreenplay:spawnSupport(playerObject)
	local pGuard1 = spawnMobile("tatooine", "tusken_king_guard", -1, 43.3, 21.6, 6.6, -40, 1189182) 
	CreatureObject(pGuard1):engageCombat(playerObject)
      	CreatureObject(pGuard1):playEffect("clienteffect/ui_missile_aquiring.cef", "")
	local pGuard2 = spawnMobile("tatooine", "tusken_king_guard", -1, 36.2, 21.7, 4.0, 12, 1189182) 
	CreatureObject(pGuard2):engageCombat(playerObject)
	local pGuard3 = spawnMobile("tatooine", "tusken_king_guard", -1, 35.5, 22.4, 9.2, 12, 1189182) 
	CreatureObject(pGuard3):engageCombat(playerObject)

end  

function tusken_king_bossScreenplay:bossDead(pBoss)
	if (pBoss == nil or readData(self.respawnScheduledKey) == 1) then
		return 0
	end

	print("Tusken King has been killed.")
	writeData(self.respawnScheduledKey, 1)
	local respawnDelay = math.random(self.respawnMinimum, self.respawnMaximum)

	createEvent(self.corpseDespawnDelay, "tusken_king_bossScreenplay", "despawnBoss", pBoss, "")
	createEvent(respawnDelay, "tusken_king_bossScreenplay", "spawnBoss", "", "")
	return 0
end

function tusken_king_bossScreenplay:despawnBoss(pBoss)
	writeData(self.spawnStateKey, 0)
	dropObserver(pBoss, OBJECTDESTRUCTION)
	if SceneObject(pBoss) then
		SceneObject(pBoss):destroyObjectFromWorld()
	end
	return 0
end
