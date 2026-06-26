/*
 * LootSchematicMenuComponent.cpp
 *
 *  Created on: 10/30/2011
 *      Author: kyle
 */

#include "server/zone/objects/creature/CreatureObject.h"
#include "server/zone/objects/player/PlayerObject.h"
#include "LootSchematicMenuComponent.h"
#include "server/zone/objects/draftschematic/DraftSchematic.h"
#include "server/zone/packets/object/ObjectMenuResponse.h"
#include "server/zone/managers/stringid/StringIdManager.h"

#include "templates/tangible/LootSchematicTemplate.h"
#include "server/zone/managers/crafting/schematicmap/SchematicMap.h"

namespace {
	constexpr byte LEARN_SCHEMATIC_USE_ID = 20;
	constexpr byte LEARN_SCHEMATIC_RADIAL_ID = 50;
}

void LootSchematicMenuComponent::fillObjectMenuResponse(SceneObject* sceneObject, ObjectMenuResponse* menuResponse, CreatureObject* player) const {

	if (!sceneObject->isTangibleObject())
		return;

	TangibleObjectMenuComponent::fillObjectMenuResponse(sceneObject, menuResponse, player);

	LootSchematicTemplate* schematicData = cast<LootSchematicTemplate*>(sceneObject->getObjectTemplate());

	if (schematicData == nullptr) {
		error("No LootSchematicTemplate for: " + String::valueOf(sceneObject->getServerObjectCRC()));
		return;
	}

	String skillNeeded = schematicData->getRequiredSkill();

	if((skillNeeded.isEmpty() || player->hasSkill(skillNeeded))) {
		menuResponse->addRadialMenuItem(LEARN_SCHEMATIC_RADIAL_ID, 3, "@loot_schematic:use_schematic"); // Learn Schematic
	}
}

int LootSchematicMenuComponent::handleObjectMenuSelect(SceneObject* sceneObject, CreatureObject* player, byte selectedID) const {
	if (!sceneObject->isTangibleObject())
		return 0;

	if (!player->isPlayerCreature())
		return 0;

	if (selectedID != LEARN_SCHEMATIC_USE_ID && selectedID != LEARN_SCHEMATIC_RADIAL_ID)
		return TangibleObjectMenuComponent::handleObjectMenuSelect(sceneObject, player, selectedID);

	if (!sceneObject->isASubChildOf(player)) {
		player->sendSystemMessage("@loot_schematic:must_be_holding"); // You must be holding that in order to use it.
		return 0;
	}

	Reference<PlayerObject*> ghost = player->getSlottedObject("ghost").castTo<PlayerObject*>();

	if (ghost == nullptr)
		return 0;

	LootSchematicTemplate* schematicData = cast<LootSchematicTemplate*>(sceneObject->getObjectTemplate());

	if (schematicData == nullptr) {
		error("No LootSchematicTemplate for: " + String::valueOf(sceneObject->getServerObjectCRC()));
		return 0;
	}

	String skillNeeded = schematicData->getRequiredSkill();

	if((!skillNeeded.isEmpty() && !player->hasSkill(skillNeeded))) {
		StringIdManager* stringIdManager = StringIdManager::instance();
		UnicodeString localizedSkillName = stringIdManager->getStringId("@skl_n:" + skillNeeded);
		StringIdChatParameter noSkill("@loot_schematic:not_enough_skill"); // You must have %TO skill in order to understand this.
		noSkill.setTO(localizedSkillName);
		player->sendSystemMessage(noSkill);
		return 0;
	}

	ManagedReference<DraftSchematic* > schematic = SchematicMap::instance()->get(schematicData->getTargetDraftSchematic().hashCode());

	if (schematic == nullptr) {
		player->sendSystemMessage("Error learning schematic, try again later");
		error("Unable to create schematic: " + schematicData->getTargetDraftSchematic());
		return 0;
	}

	if(ghost->addRewardedSchematic(schematic, SchematicList::LOOT, schematicData->getTargetUseCount(), true)) {
		TangibleObject* tano = cast<TangibleObject*>(sceneObject);
		if(tano != nullptr)
			tano->decreaseUseCount();

		player->sendSystemMessage("@loot_schematic:schematic_learned"); // You acquire a new crafting schematic!
	}

	return 0;
}
