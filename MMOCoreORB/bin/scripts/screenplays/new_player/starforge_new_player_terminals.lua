local ObjectManager = require("managers.object.object_manager")

StarforgeNewPlayerTerminals = ScreenPlay:new {
	numberOfActs = 1,

	screenplayName = "StarforgeNewPlayerTerminals",
    tatooine = "tatooine",
	naboo = "naboo",

}

registerScreenPlay("StarforgeNewPlayerTerminals", true)

function StarforgeNewPlayerTerminals:start()
	if (isZoneEnabled(self.tatooine)) then
		self:spawnTerminalsTat()
	end

	if (isZoneEnabled(self.naboo)) then
		--self:spawnMobilesNaboo()
	end
end

function StarforgeNewPlayerTerminals:spawnTerminalsTat()
    --Eisley
    spawnSceneObject("tatooine", "object/tangible/terminal/terminal_new_character.iff", 3510.3, 4.9, -4792.1, 0, math.rad(90) )
    --Bestine
	spawnSceneObject("tatooine", "object/tangible/terminal/terminal_new_character.iff", -1271.07, 12, -3590.22, 0, math.rad(-90))
    --Espa
    spawnSceneObject("tatooine", "object/tangible/terminal/terminal_new_character.iff", -2896.35, 5, 2130.87, 0, math.rad(-80))
    --Entha
    spawnSceneObject("tatooine", "object/tangible/terminal/terminal_new_character.iff", 1296.5, 7, 3147.6, 0, math.rad(-141))
end

