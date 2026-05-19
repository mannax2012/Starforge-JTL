StarforgeNewPlayerTerminals = ScreenPlay:new {
	numberOfActs = 1,
	screenplayName = "StarforgeNewPlayerTerminals"
}

local STARFORGE_GALAXY_NAME = "starforge"
local CHARACTER_BUILDER_TEMPLATE = "object/tangible/terminal/terminal_character_builder.iff"
local NEW_PLAYER_TEMPLATE = "object/tangible/terminal/terminal_new_character.iff"

local TERMINAL_LOCATIONS = {
	{ zone = "corellia", x = -133.192, z = 28, y = -4711.16, ow = 0.747476, ox = 0, oy = -0.664289, oz = 0 },
	{ zone = "corellia", x = -5049.64, z = 21, y = -2304.52, ow = 0.937972, ox = 0, oy = 0.346712, oz = 0 },
	{ zone = "corellia", x = 3330.38, z = 308, y = 5517.14, ow = 0.956783, ox = 0, oy = 0.290803, oz = 0 },
	{ zone = "corellia", x = -136.437, z = 28, y = -4730.23, ow = 0.745701, ox = 0, oy = -0.666281, oz = 0 },
	{ zone = "lok", x = 464.677, z = 8.75806, y = 5506.49, ow = 0.015506, ox = 0, oy = 0.999879, oz = 0 },
	{ zone = "naboo", x = 4824.53, z = 4.17, y = -4704.9, ow = -0.698509, ox = 0, oy = 0.715602, oz = 0 },
	{ zone = "naboo", x = -4876.99, z = 6, y = 4142.12, ow = 0.950873, ox = 0, oy = 0.309582, oz = 0 },
	{ zone = "naboo", x = 5193.14, z = -192, y = 6680.25, ow = 0.999932, ox = 0, oy = -0.0116238, oz = 0 },
	{ zone = "naboo", x = 1445.8, z = 13, y = 2771.98, ow = -0.686427, ox = 0, oy = -0.0116238, oz = 0 },
	{ zone = "rori", x = -5307.37, z = 80.1274, y = -2216.91, ow = 0.994961, ox = 0, oy = -0.100263, oz = 0 },
	{ zone = "rori", x = 5370.22, z = 80, y = 5666.04, ow = 0.721974, ox = 0, oy = -0.69192, oz = 0 },
	{ zone = "rori", x = 3672.91, z = 96, y = -6441.07, ow = 0.999623, ox = 0, oy = -0.0274543, oz = 0 },
	{ zone = "talus", x = 4447.08, z = 2, y = 5286.96, ow = -0.0851417, ox = 0, oy = 0.996369, oz = 0 },
	{ zone = "talus", x = 329.666, z = 6, y = -2924.69, ow = 0.721282, ox = 0, oy = 0.692641, oz = 0 },
	{ zone = "tatooine", x = 3510.3, z = 4.9, y = -4792.1, heading = math.rad(90), isMosEisley = true },
	{ zone = "tatooine", x = -1271.07, z = 12, y = -3590.22, heading = math.rad(-90) },
	{ zone = "tatooine", x = -2896.35, z = 5, y = 2130.87, heading = math.rad(-80) },
	{ zone = "tatooine", x = 1296.5, z = 7, y = 3147.6, heading = math.rad(-141) },
--	{ zone = "dantooine", x = 1585.68, z = 4, y = -6368.95, ow = 0.718174, ox = 0, oy = 0.695864, oz = 0 },
--	{ zone = "dantooine", x = -629.417, z = 3, y = 2481.24, ow = -0.687696, ox = 0, oy = 0.725999, oz = 0 },
--	{ zone = "dathomir", x = 592.612, z = 6, y = 3089.84, ow = 0.712705, ox = 0, oy = 0.701463, oz = 0 },
--	{ zone = "dathomir", x = -67.6585, z = 18, y = -1595.3, ow = 0.949123, ox = 0, oy = 0.314904, oz = 0 },
--	{ zone = "dathomir", x = 5289.6, z = 78.5, y = -4146.1, ow = 0.949123, ox = 0, oy = 0.314904, oz = 0 },
--	{ zone = "endor", x = -963.537, z = 73, y = 1556.86, ow = -0.360002, ox = 0, oy = 0.932952, oz = 0 },
--	{ zone = "endor", x = 3240.5, z = 24, y = -3484.79, ow = -0.690367, ox = 0, oy = 0.723459, oz = 0 },
--	{ zone = "yavin4", x = -6917.18, z = 73, y = -5732.25, ow = 0.708587, ox = 0, oy = -0.705623, oz = 0 },
--	{ zone = "yavin4", x = 4057.69, z = 37, y = -6217.54, ow = -0.690493, ox = 0, oy = 0.723339, oz = 0 },
--	{ zone = "yavin4", x = -293.367, z = 35, y = 4854.52, ow = 0.999974, ox = 0, oy = 0.00721678, oz = 0 }
}

registerScreenPlay("StarforgeNewPlayerTerminals", true)

function StarforgeNewPlayerTerminals:start()
	local galaxyName = string.lower(getGalaxyName() or "")
	local isStarforge = galaxyName == STARFORGE_GALAXY_NAME

	for _, location in ipairs(TERMINAL_LOCATIONS) do
		if isZoneEnabled(location.zone) and (isStarforge or not location.isMosEisley) then
			self:spawnTerminal(location, isStarforge and NEW_PLAYER_TEMPLATE or CHARACTER_BUILDER_TEMPLATE)
		end
	end
end

function StarforgeNewPlayerTerminals:spawnTerminal(location, template)
	if location.heading ~= nil then
		spawnSceneObject(location.zone, template, location.x, location.z, location.y, 0, location.heading)
		return
	end

	spawnSceneObject(
		location.zone,
		template,
		location.x,
		location.z,
		location.y,
		0,
		location.ow,
		location.ox,
		location.oy,
		location.oz
	)
end
