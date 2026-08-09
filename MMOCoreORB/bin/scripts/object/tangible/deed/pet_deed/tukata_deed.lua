object_tangible_deed_pet_deed_tukata_deed = object_tangible_deed_pet_deed_shared_tukata_deed:new {

	templateType = PETDEED,
	-- The current shared_tukata_deed.iff derives from shared_tangible_base.iff.
	-- Force the pet-deed object class until the shared IFF is rebuilt with
	-- shared_pet_deed_base.iff as its DERV parent.
	gameObjectType = 8388611,
	clientGameObjectType = 8388611,
	numberExperimentalProperties = {1, 1},
	experimentalProperties = {"XX", "XX"},
	experimentalWeights = {1, 1},
	experimentalGroupTitles = {"null", "null"},
	experimentalSubGroupTitles = {"null", "null"},
	experimentalMin = {0, 0},
	experimentalMax = {0, 0},
	experimentalPrecision = {0, 0},
	experimentalCombineType = {0, 0},
	generatedObjectTemplate = "mobile/pet/tukata_be.iff",
	controlDeviceObjectTemplate = "object/intangible/pet/bio_tukata_hue.iff",
	mobileTemplate = "tukata_be",
	baseResistances = {"lightsaber", 30},
}

ObjectTemplates:addTemplate(object_tangible_deed_pet_deed_tukata_deed, "object/tangible/deed/pet_deed/tukata_deed.iff")
