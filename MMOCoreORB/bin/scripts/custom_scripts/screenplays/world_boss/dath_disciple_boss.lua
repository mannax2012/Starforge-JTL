--Created By: Voxxy
--Modified By: Mannax for use on Starforge
dath_discipleScreenplay = ScreenPlay:new {
	numberOfActs = 1,
  	planet = "dathomir",
}
registerScreenPlay("dath_discipleScreenplay", true)

function dath_discipleScreenplay:start()
	if (isZoneEnabled(self.planet)) then
		self:spawnMobiles()
		self:spawnSceneObjects()
		print("Dathomir Disciple Loaded")
	end
end

function dath_discipleScreenplay:spawnSceneObjects()
	spawnSceneObject(self.planet, "object/tangible/item/dath_disciple_alter.iff", -2593.6, 77.0, -5510.3, 0, math.rad(-90))
	spawnSceneObject(self.planet, "object/tangible/furniture/all/frn_all_tiki_torch_s1.iff", -2596.0, 77.0, -5507.6, 0, math.rad(-90))
	spawnSceneObject(self.planet, "object/tangible/furniture/all/frn_all_tiki_torch_s1.iff", -2587.3, 77.0, -5510.8, 0, math.rad(-90))
	spawnSceneObject(self.planet, "object/tangible/furniture/all/frn_all_tiki_torch_s1.iff", -2575.2, 77.0, -5512.2, 0, math.rad(-90))
	
end

function dath_discipleScreenplay:spawnMobiles()
	spawnMobile("dathomir", "nightsister_ascendant",900, -2574.3, 77.0, -5503.8, -156, 0)
	spawnMobile("dathomir", "nightsister_ascendant",900, -2581.1, 77.0, -5506.0, 60, 0)
	spawnMobile("dathomir", "nightsister_ascendant",900, -2588.3, 77.0, -5508.0, -126, 0)
	spawnMobile("dathomir", "nightsister_ascendant",900, -2598.0, 77.0, -5498.8, 151, 0)
	spawnMobile("dathomir", "nightsister_ascendant",900, -2570.0, 77.0, -5512.6, -97, 0)
end

function dath_discipleScreenplay:spawnBoss(pPlayer)
    -- Spawn the boss
    local pBoss = spawnMobile("dathomir", "rakata_disciple", -1, -2578.3, 77.0, -5517.9, -2, 0)
	CreatureObject(pPlayer):sendSystemMessage("A dark presence emerges from the shadows...")

        local creature = CreatureObject(pBoss)
        CreatureObject(pBoss):engageCombat(pPlayer)
        createObserver(DAMAGERECEIVED, "dath_discipleScreenplay", "npcDamageObserver", pBoss)
        createObserver(OBJECTDESTRUCTION, "dath_discipleScreenplay", "bossDead", pBoss)
end


function dath_discipleScreenplay:npcDamageObserver(bossObject, playerObject, damage)

	local player = LuaCreatureObject(playerObject)
	local boss = LuaCreatureObject(bossObject)

	health = boss:getHAM(0)
	action = boss:getHAM(3)
	mind = boss:getHAM(6)

	maxHealth = boss:getMaxHAM(0)
	maxAction = boss:getMaxHAM(3)
	maxMind = boss:getMaxHAM(6)

	if (((health <= (maxHealth * 0.99))) and readData("dath_discipleScreenplay:spawnState") == 0) then
	writeData("dath_discipleScreenplay:spawnState",1)
      		spatialChat(bossObject, "I am the new Mother of Dathomir, behold my terror.")
			createEvent(5 * 1000, "dath_discipleScreenplay", "rockthrow_last", playerObject, "")
 			createEvent(10 * 1000, "dath_discipleScreenplay", "rockthrow_last", playerObject, "")   			
      		CreatureObject(bossObject):playEffect("clienteffect/mustafar/som_dark_jedi_laugh.cef", "")
	end

	if (((health <= (maxHealth * 0.95))) and readData("dath_discipleScreenplay:spawnState") == 1) then
			writeData("dath_discipleScreenplay:spawnState",2)
			createEvent(5 * 1000, "dath_discipleScreenplay", "rockthrow", playerObject, "")
 			createEvent(10 * 1000, "dath_discipleScreenplay", "rockthrow", playerObject, "")
			createEvent(20 * 1000, "dath_discipleScreenplay", "rockthrow", playerObject, "")
			createEvent(30 * 1000, "dath_discipleScreenplay", "rockthrow", playerObject, "")
			createEvent(50 * 1000, "dath_discipleScreenplay", "rockthrow", playerObject, "")       
      		CreatureObject(bossObject):playEffect("clienteffect/mustafar/som_dark_jedi_laugh.cef", "")
	end

	if (((health <= (maxHealth * 0.7))) and readData("dath_discipleScreenplay:spawnState") == 2) then
      		writeData("dath_discipleScreenplay:spawnState",3)
			createEvent(0 * 1000, "dath_discipleScreenplay", "rockthrow", playerObject, "")
 			createEvent(5 * 1000, "dath_discipleScreenplay", "rockthrow", playerObject, "")
			createEvent(10 * 1000, "dath_discipleScreenplay", "rockthrow", playerObject, "")
			createEvent(15 * 1000, "dath_discipleScreenplay", "rockthrow", playerObject, "")
			createEvent(20 * 1000, "dath_discipleScreenplay", "rockthrow", playerObject, "")        
			self:spawnSupport(playerObject)
      			CreatureObject(playerObject):sendSystemMessage("The Disciple flings rocks at you using the Force.")
      			CreatureObject(bossObject):playEffect("clienteffect/mustafar/som_dark_jedi_laugh.cef", "")
	end

	if (((health <= (maxHealth * 0.5))) and readData("dath_discipleScreenplay:spawnState") == 3) then
      		spatialChat(bossObject, "My Ascendants will devour you.")
			writeData("dath_discipleScreenplay:spawnState",4)
			createEvent(0 * 1000, "dath_discipleScreenplay", "rockthrow_mid", playerObject, "")
 			createEvent(2 * 1000, "dath_discipleScreenplay", "rockthrow_mid", playerObject, "")
			createEvent(5 * 1000, "dath_discipleScreenplay", "rockthrow_mid", playerObject, "")
			createEvent(7 * 1000, "dath_discipleScreenplay", "rockthrow_mid", playerObject, "")
			createEvent(8 * 1000, "dath_discipleScreenplay", "rockthrow_mid", playerObject, "")     
			self:spawnSupport(playerObject)
      		CreatureObject(bossObject):playEffect("clienteffect/mustafar/som_dark_jedi_laugh.cef", "")
	end

	if (((health <= (maxHealth * 0.3))) and readData("dath_discipleScreenplay:spawnState") == 4) then
      		writeData("dath_discipleScreenplay:spawnState",5)
			createEvent(0 * 1000, "dath_discipleScreenplay", "rockthrow_last", playerObject, "")
			createEvent(2 * 1000, "dath_discipleScreenplay", "rockthrow_last", playerObject, "")
			createEvent(5 * 1000, "dath_discipleScreenplay", "rockthrow_last", playerObject, "")
			createEvent(7 * 1000, "dath_discipleScreenplay", "rockthrow_last", playerObject, "")
			createEvent(9 * 1000, "dath_discipleScreenplay", "rockthrow_last", playerObject, "")      
			self:spawnSupport(playerObject)
      		CreatureObject(playerObject):sendSystemMessage("A barrage of rocks heads your way.")
      		CreatureObject(bossObject):playEffect("clienteffect/mustafar/som_dark_jedi_laugh.cef", "")
	end

	if (((health <= (maxHealth * 0.1))) and readData("dath_discipleScreenplay:spawnState") == 5) then
				spatialChat(bossObject, "No .. I was shaped .. by the Masters...")
      			writeData("dath_discipleScreenplay:spawnState",6)
				createEvent(0 * 1000, "dath_discipleScreenplay", "finisher", playerObject, "")  		
      			CreatureObject(bossObject):playEffect("clienteffect/mustafar/som_dark_jedi_laugh.cef", "")
		end
	return 0

end

function dath_discipleScreenplay:rockthrow(playerObject)
if (CreatureObject(playerObject):isGrouped()) then
	local groupSize = CreatureObject(playerObject):getGroupSize()
	for i = 0, groupSize - 1, 1 do
			local pMember = CreatureObject(playerObject):getGroupMember(i)
			if pMember ~= nil and SceneObject(pMember):isInRangeWithObject(playerObject, 200) then
			local trapDmg = getRandomNumber(500, 700)
			CreatureObject(pMember):inflictDamage(pMember, 0, trapDmg, 1)
      		CreatureObject(playerObject):playEffect("clienteffect/mustafar/dark_jedi_rock_attack_1.cef", "")
		end
	end
else
	local trapDmg = getRandomNumber(500, 700)
		CreatureObject(playerObject):inflictDamage(playerObject, 0, trapDmg, 1)
      	CreatureObject(playerObject):playEffect("clienteffect/mustafar/dark_jedi_rock_attack_1.cef", "")
	end
end

function dath_discipleScreenplay:rockthrow_mid(playerObject)
if (CreatureObject(playerObject):isGrouped()) then
	local groupSize = CreatureObject(playerObject):getGroupSize()
	for i = 0, groupSize - 1, 1 do
			local pMember = CreatureObject(playerObject):getGroupMember(i)
			if pMember ~= nil and SceneObject(pMember):isInRangeWithObject(playerObject, 200) then
			local trapDmg = getRandomNumber(800, 900)
			CreatureObject(pMember):inflictDamage(pMember, 0, trapDmg, 1)
      		CreatureObject(playerObject):playEffect("clienteffect/mustafar/dark_jedi_rock_attack_1.cef", "")
		end
	end
else
	local trapDmg = getRandomNumber(800, 900)
		CreatureObject(playerObject):inflictDamage(playerObject, 0, trapDmg, 1)
      	CreatureObject(playerObject):playEffect("clienteffect/mustafar/dark_jedi_rock_attack_1.cef", "")
	end
end

function dath_discipleScreenplay:rockthrow_last(playerObject)
if (CreatureObject(playerObject):isGrouped()) then
	local groupSize = CreatureObject(playerObject):getGroupSize()
	for i = 0, groupSize - 1, 1 do
			local pMember = CreatureObject(playerObject):getGroupMember(i)
			if pMember ~= nil and SceneObject(pMember):isInRangeWithObject(playerObject, 200) then
			local trapDmg = getRandomNumber(900, 1100)
			CreatureObject(pMember):inflictDamage(pMember, 0, trapDmg, 1)
      		CreatureObject(playerObject):playEffect("clienteffect/mustafar/dark_jedi_rock_attack_1.cef", "")
		end
	end
else
	local trapDmg = getRandomNumber(900, 1100)
		CreatureObject(playerObject):inflictDamage(playerObject, 0, trapDmg, 1)
      	CreatureObject(playerObject):playEffect("clienteffect/mustafar/dark_jedi_rock_attack_1.cef", "")
	end
end


function dath_discipleScreenplay:finisher(playerObject)
	local trapDmg = getRandomNumber(2400, 3200)
		CreatureObject(playerObject):inflictDamage(playerObject, 0, trapDmg, 1)
      	CreatureObject(playerObject):playEffect("clienteffect/mustafar/som_force_crystal_drain.cef", "")
end

function dath_discipleScreenplay:spawnSupport(bossObject, playerObject)
	local boss = LuaCreatureObject(bossObject)
	local bossX = boss:getPositionX()
	local bossY = boss:getPositionY()
	local bossZ = boss:getPositionZ()
	local cell = boss:getParentID()

	local pGuard1 = spawnMobile("dathomir", "nightsister_ascendant", -1, bossX, bossZ, bossY, 93, cell) 
		CreatureObject(pGuard1):engageCombat(playerObject)
		spatialChat(pGuard1, "Our life for the new mother!")
	local pGuard2 = spawnMobile("dathomir", "nightsister_ascendant", -1, bossX, bossZ, bossY, 141, cell) 
		CreatureObject(pGuard2):engageCombat(playerObject)

end  

function dath_discipleScreenplay:bossDead(pBoss)
       -- local respawn = math.random(7200, 10800)
	   	writeData("dathBossSpawned", 2)
        createEvent(30 * 1000, "dath_discipleScreenplay", "KillBoss", pBoss, "") -- Corpse Despawn
       -- createEvent(respawn * 1000, "dath_discipleScreenplay", "spawnBoss", "") -- Respawn boss
    return 0
end

function dath_discipleScreenplay:KillSpawn()
		self.SpawnMobiles()
end

function dath_discipleScreenplay:KillBoss(pBoss)
      	writeData("dath_discipleScreenplay:spawnState",0)  
		writeData("dathBossSpawned", 0)
	dropObserver(pBoss, OBJECTDESTRUCTION)
	if SceneObject(pBoss) then
		SceneObject(pBoss):destroyObjectFromWorld()
	end
	return 0
end