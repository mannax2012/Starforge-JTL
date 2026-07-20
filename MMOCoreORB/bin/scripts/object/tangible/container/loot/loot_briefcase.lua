-- Unlocked briefcase container created after a locked briefcase is sliced.

object_tangible_container_loot_loot_briefcase = object_tangible_container_loot_shared_loot_briefcase:new {
	containerComponent = "ContainerComponent",
}

ObjectTemplates:addTemplate(object_tangible_container_loot_loot_briefcase, "object/tangible/container/loot/loot_briefcase.iff")
