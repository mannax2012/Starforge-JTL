/*
 * CooldownBuffObjectMenuComponent.cpp
 *
 *  Created on: 5/1/2026
 */

#include "server/zone/objects/creature/CreatureObject.h"
#include "server/zone/objects/creature/buffs/Buff.h"
#include "server/zone/objects/player/PlayerObject.h"
#include "server/zone/objects/player/sui/messagebox/SuiMessageBox.h"
#include "server/zone/objects/player/sui/callbacks/CooldownBuffBindSuiCallback.h"
#include "server/zone/packets/object/ObjectMenuResponse.h"
#include "templates/params/creature/CreatureAttribute.h"
#include "templates/tangible/SkillBuffTemplate.h"
#include "CooldownBuffObjectMenuComponent.h"

void CooldownBuffObjectMenuComponent::fillObjectMenuResponse(SceneObject* sceneObject, ObjectMenuResponse* menuResponse, CreatureObject* player) const {
	if (!sceneObject->isTangibleObject())
		return;

	TangibleObject* tano = cast<TangibleObject*>(sceneObject);
	if (tano == nullptr)
		return;

	TangibleObjectMenuComponent::fillObjectMenuResponse(sceneObject, menuResponse, player);
}

int CooldownBuffObjectMenuComponent::handleObjectMenuSelect(SceneObject* sceneObject, CreatureObject* player, byte selectedID) const {
	if (!sceneObject->isASubChildOf(player))
		return 0;

	if (selectedID != 20)
		return TangibleObjectMenuComponent::handleObjectMenuSelect(sceneObject, player, selectedID);

	if (!sceneObject->isTangibleObject() || player->isDead() || player->isIncapacitated())
		return 0;

	ManagedReference<TangibleObject*> tano = cast<TangibleObject*>(sceneObject);
	if (tano == nullptr)
		return 0;

	String ownerIdString = tano->getLuaStringData(getOwnerIdKey());
	if (ownerIdString.isEmpty()) {
		String activeBuffKey = getActiveBuffKey(sceneObject);
		String cooldownKey = getCooldownKey(sceneObject);

		if (!player->checkCooldownRecovery(activeBuffKey) || !player->checkCooldownRecovery(cooldownKey))
			return applyBuff(sceneObject, player);

		Reference<PlayerObject*> ghost = player->getSlottedObject("ghost").castTo<PlayerObject*>();
		if (ghost == nullptr)
			return 0;

		ManagedReference<SuiMessageBox*> suiMessageBox = new SuiMessageBox(player, SuiWindowType::NONE);
		suiMessageBox->setPromptTitle("Bind On Use");
		suiMessageBox->setPromptText("Warning: using this item will bind it to you permanently and make it no-trade. Continue?");
		suiMessageBox->setCancelButton(true, "Cancel");
		suiMessageBox->setUsingObject(sceneObject);
		suiMessageBox->setCallback(new CooldownBuffBindSuiCallback(player->getZoneServer()));

		ghost->addSuiBox(suiMessageBox);
		player->sendMessage(suiMessageBox->generateMessage());
		return 0;
	}

	return applyBuff(sceneObject, player);
}

int CooldownBuffObjectMenuComponent::applyBuff(SceneObject* sceneObject, CreatureObject* player) {
	if (!sceneObject->isASubChildOf(player))
		return 0;

	if (player->isDead() || player->isIncapacitated() || !sceneObject->isTangibleObject())
		return 0;

	ManagedReference<TangibleObject*> tano = cast<TangibleObject*>(sceneObject);
	if (tano == nullptr)
		return 0;

	Reference<SkillBuffTemplate*> skillBuff = cast<SkillBuffTemplate*>(sceneObject->getObjectTemplate());
	if (skillBuff == nullptr) {
		player->sendSystemMessage("This item is not configured correctly.");
		return 1;
	}

	VectorMap<String, float>* modifiers = skillBuff->getModifiers();
	if (modifiers == nullptr || modifiers->size() == 0) {
		player->sendSystemMessage("This item has no buff modifiers configured.");
		return 0;
	}

	String ownerIdString = tano->getLuaStringData(getOwnerIdKey());
	String ownerName = tano->getLuaStringData(getOwnerNameKey());

	if (!ownerIdString.isEmpty()) {
		uint64 ownerID = UnsignedLong::valueOf(ownerIdString);

		if (ownerID != 0 && ownerID != player->getObjectID()) {
			String message = "You cannot use this item. It is bound to ";

			if (!ownerName.isEmpty())
				message += ownerName;
			else
				message += "another player";

			message += ".";

			player->sendSystemMessage(message);
			sceneObject->sendAttributeListTo(player);
			return 0;
		}
	}

	String activeBuffKey = getActiveBuffKey(sceneObject);
	if (!player->checkCooldownRecovery(activeBuffKey)) {
		const Time* activeBuffTime = player->getCooldownTime(activeBuffKey);
		uint64 remaining = activeBuffTime != nullptr ? static_cast<uint64>(activeBuffTime->miliDifference() * -1) : 0;

		player->sendSystemMessage("You already have this item's buff active. Time remaining: " + formatTime(remaining) + ".");
		sceneObject->sendAttributeListTo(player);
		return 0;
	}

	String cooldownKey = getCooldownKey(sceneObject);

	if (skillBuff->getReuseTime() > 0 && !player->checkCooldownRecovery(cooldownKey)) {
		const Time* cooldownTime = player->getCooldownTime(cooldownKey);
		uint64 remaining = cooldownTime != nullptr ? static_cast<uint64>(cooldownTime->miliDifference() * -1) : 0;

		player->sendSystemMessage("This item is still recharging. Cooldown remaining: " + formatTime(remaining) + ".");
		sceneObject->sendAttributeListTo(player);
		return 0;
	}

	bool hasAttributeModifier = false;
	for (int i = 0; i < modifiers->size(); ++i) {
		uint8 creatureAttribute = CreatureAttribute::getAttribute(modifiers->elementAt(i).getKey());
		if (creatureAttribute != CreatureAttribute::UNKNOWN) {
			hasAttributeModifier = true;
			break;
		}
	}

	unsigned int buffCRC = skillBuff->getBuffCRC();

	if (buffCRC == 0) {
		if (!skillBuff->getBuffName().isEmpty())
			buffCRC = skillBuff->getBuffName().hashCode();
		else
			buffCRC = sceneObject->getServerObjectCRC();
	}

	if (!hasAttributeModifier && player->hasBuff(buffCRC)) {
		player->sendSystemMessage("@skill_buff_n:already_have");
		return 0;
	}

	ManagedReference<Buff*> buff = new Buff(player, buffCRC, skillBuff->getDuration(),
		hasAttributeModifier ? BuffType::FOOD : BuffType::SKILL);

	Locker locker(buff);

	for (int i = 0; i < modifiers->size(); ++i) {
		String attributeName = modifiers->elementAt(i).getKey();
		int value = static_cast<int>(modifiers->elementAt(i).getValue());
		uint8 creatureAttribute = CreatureAttribute::getAttribute(attributeName);

		if (creatureAttribute != CreatureAttribute::UNKNOWN)
			buff->setAttributeModifier(creatureAttribute, value);
		else
			buff->setSkillModifier(attributeName, value);
	}

	if (ownerIdString.isEmpty()) {
		tano->setLuaStringData(getOwnerIdKey(), String::valueOf(player->getObjectID()));
		tano->setLuaStringData(getOwnerNameKey(), player->getDisplayedName());
		tano->setForceNoTrade(true);
	}

	player->addBuff(buff);

	player->addCooldown(activeBuffKey, static_cast<uint64>(skillBuff->getDuration()) * 1000);

	if (skillBuff->getReuseTime() > 0)
		player->addCooldown(cooldownKey, skillBuff->getReuseTime());

	StringIdChatParameter stringId("skill_buff_d", "consume");
	player->sendSystemMessage(stringId);
	sceneObject->sendAttributeListTo(player);

	return 0;
}

String CooldownBuffObjectMenuComponent::getCooldownKey(SceneObject* sceneObject) {
	Reference<SkillBuffTemplate*> skillBuff = cast<SkillBuffTemplate*>(sceneObject->getObjectTemplate());
	if (skillBuff != nullptr && !skillBuff->getBuffName().isEmpty())
		return "cooldown_buff_item_" + skillBuff->getBuffName();

	return "cooldown_buff_item_" + String::valueOf(sceneObject->getServerObjectCRC());
}

String CooldownBuffObjectMenuComponent::getActiveBuffKey(SceneObject* sceneObject) {
	Reference<SkillBuffTemplate*> skillBuff = cast<SkillBuffTemplate*>(sceneObject->getObjectTemplate());
	if (skillBuff != nullptr && !skillBuff->getBuffName().isEmpty())
		return "active_buff_item_" + skillBuff->getBuffName();

	return "active_buff_item_" + String::valueOf(sceneObject->getServerObjectCRC());
}

String CooldownBuffObjectMenuComponent::formatTime(uint64 milliseconds) {
	uint64 totalSeconds = milliseconds / 1000;
	uint64 hours = totalSeconds / 3600;
	totalSeconds -= hours * 3600;

	uint64 minutes = totalSeconds / 60;
	totalSeconds -= minutes * 60;

	StringBuffer buffer;
	buffer << hours << "h " << minutes << "m " << totalSeconds << "s";

	return buffer.toString();
}

String CooldownBuffObjectMenuComponent::getOwnerIdKey() {
	return "boundOwnerID";
}

String CooldownBuffObjectMenuComponent::getOwnerNameKey() {
	return "boundOwnerName";
}
