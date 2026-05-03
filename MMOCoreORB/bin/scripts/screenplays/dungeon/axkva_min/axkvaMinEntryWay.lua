axkvaMinEntryWay = ScreenPlay:new {
  numberOfActs = 1,

  screenplayName = "axkvaMinEntryWay"
}

registerScreenPlay("axkvaMinEntryWay", true)

function axkvaMinEntryWay:start()
  if (isZoneEnabled("dathomir")) then
    self:spawnSceneObjects()
  end
end

function axkvaMinEntryWay:spawnSceneObjects()
  local pTerminal = spawnSceneObject("dathomir", "object/tangible/item/axkva_min_entrance.iff", -90.5, -101, -102.2, 4115629, math.rad(0))

  if pTerminal ~= nil then
    SceneObject(pTerminal):setCustomObjectName("The Chamber of Banishment [Instance]")
    SceneObject(pTerminal):setObjectMenuComponent("axkvaMinEntryMenuComponent")
  end
end
