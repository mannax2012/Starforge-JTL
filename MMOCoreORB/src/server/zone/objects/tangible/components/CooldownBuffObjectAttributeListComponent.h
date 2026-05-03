/*
 * CooldownBuffObjectAttributeListComponent.h
 *
 *  Created on: 5/1/2026
 */

#ifndef COOLDOWNBUFFOBJECTATTRIBUTELISTCOMPONENT_H_
#define COOLDOWNBUFFOBJECTATTRIBUTELISTCOMPONENT_H_

#include "server/zone/objects/scene/components/AttributeListComponent.h"
#include "templates/params/creature/CreatureAttribute.h"
#include "templates/tangible/SkillBuffTemplate.h"
#include "CooldownBuffObjectMenuComponent.h"

class CooldownBuffObjectAttributeListComponent : public AttributeListComponent {
public:
	void fillAttributeList(AttributeListMessage* alm, CreatureObject* creature, SceneObject* object) const {
		Reference<SkillBuffTemplate*> skillBuff = cast<SkillBuffTemplate*>(object->getObjectTemplate());
		if (skillBuff == nullptr) {
			error("No SkillBuffTemplate for: " + String::valueOf(object->getServerObjectCRC()));
			return;
		}

		if (!object->isTangibleObject())
			return;

		AttributeListComponent::fillAttributeList(alm, creature, object);

		ManagedReference<TangibleObject*> tano = cast<TangibleObject*>(object);
		if (tano != nullptr) {
			String ownerName = tano->getLuaStringData(CooldownBuffObjectMenuComponent::getOwnerNameKey());
			if (!ownerName.isEmpty())
				alm->insertAttribute("owner", ownerName);
		}

		VectorMap<String, float>* modifiers = skillBuff->getModifiers();
		if (modifiers != nullptr) {
			for (int i = 0; i < modifiers->size(); ++i) {
				VectorMapEntry<String, float>* entry = &modifiers->elementAt(i);
				uint8 creatureAttribute = CreatureAttribute::getAttribute(entry->getKey());

				if (creatureAttribute != CreatureAttribute::UNKNOWN) {
					alm->insertAttribute("examine_dot_attribute", CreatureAttribute::getName(creatureAttribute, true));
					alm->insertAttribute("potency", static_cast<int>(entry->getValue()));
				} else {
					alm->insertAttribute("cat_skill_mod_bonus.@stat_n:" + entry->getKey(), static_cast<int>(entry->getValue()));
				}
			}
		}

		alm->insertAttribute("duration", CooldownBuffObjectMenuComponent::formatTime(static_cast<uint64>(skillBuff->getDuration()) * 1000));

		if (creature != nullptr && skillBuff->getReuseTime() > 0) {
			String cooldownKey = CooldownBuffObjectMenuComponent::getCooldownKey(object);

			if (!creature->checkCooldownRecovery(cooldownKey)) {
				const Time* cooldownTime = creature->getCooldownTime(cooldownKey);
				uint64 remaining = cooldownTime != nullptr ? static_cast<uint64>(cooldownTime->miliDifference() * -1) : 0;
				alm->insertAttribute("reuse_time", CooldownBuffObjectMenuComponent::formatTime(remaining));
			} else {
				alm->insertAttribute("reuse_time", CooldownBuffObjectMenuComponent::formatTime(0));
			}
		}
	}
};

#endif /* COOLDOWNBUFFOBJECTATTRIBUTELISTCOMPONENT_H_ */
