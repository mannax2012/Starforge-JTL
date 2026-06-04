/*
				Copyright <SWGEmu>
		See file COPYING for copying conditions.*/

#ifndef CENTEROFBEINGBUFFDURATIONEVENT_H_
#define CENTEROFBEINGBUFFDURATIONEVENT_H_

#include "server/zone/objects/creature/CreatureObject.h"
#include "server/zone/objects/creature/buffs/Buff.h"
#include "server/zone/objects/creature/buffs/BuffDurationEvent.h"
#include "server/zone/objects/creature/buffs/CenterOfBeingBuff.h"
#include "server/zone/objects/tangible/weapon/WeaponObject.h"
#include "server/chat/StringIdChatParameter.h"

namespace server {
 namespace zone {
  namespace objects {
   namespace creature {
    namespace buffs {

		class CenterOfBeingBuffDurationEvent : public BuffDurationEvent {
		private:
			static bool getCenterOfBeingValues(CreatureObject* creature, int& duration, int& efficacy) {
				duration = 0;
				efficacy = 0;

				if (creature == nullptr)
					return false;

				WeaponObject* weapon = creature->getWeapon();

				if (weapon == nullptr)
					return false;

				if (weapon->isUnarmedWeapon()) {
					duration = creature->getSkillMod("center_of_being_duration_unarmed");
					efficacy = creature->getSkillMod("unarmed_center_of_being_efficacy");
				} else if (weapon->isOneHandMeleeWeapon()) {
					duration = creature->getSkillMod("center_of_being_duration_onehandmelee");
					efficacy = creature->getSkillMod("onehandmelee_center_of_being_efficacy");
				} else if (weapon->isTwoHandMeleeWeapon()) {
					duration = creature->getSkillMod("center_of_being_duration_twohandmelee");
					efficacy = creature->getSkillMod("twohandmelee_center_of_being_efficacy");
				} else if (weapon->isPolearmWeaponObject()) {
					duration = creature->getSkillMod("center_of_being_duration_polearm");
					efficacy = creature->getSkillMod("polearm_center_of_being_efficacy");
				}

				return duration > 0 && efficacy > 0;
			}

			static void configureCenterBuff(Buff* centered, int efficacy) {
				Locker locker(centered);

				centered->setSkillModifier("private_center_of_being", efficacy);

				StringIdChatParameter startMsg("combat_effects", "center_start");
				StringIdChatParameter endMsg("combat_effects", "center_stop");
				centered->setStartMessage(startMsg);
				centered->setEndMessage(endMsg);

				centered->setStartFlyText("combat_effects", "center_start_fly", 0, 255, 0);
				centered->setEndFlyText("combat_effects", "center_stop_fly", 255, 0, 0);
			}

		public:
			CenterOfBeingBuffDurationEvent(CreatureObject* creature, Buff* buff) : BuffDurationEvent(creature, buff) {
			}

			void run() override {
				ManagedReference<CreatureObject*> creature = creatureObject.get();
				ManagedReference<Buff*> buff = buffObject.get();

				if (creature == nullptr || buff == nullptr)
					return;

				Locker locker(creature);
				Locker clocker(buff, creature);

				const bool shouldRefresh = buff->checkRenew();
				const uint32 buffCRC = buff->getBuffCRC();

				int duration = 0;
				int efficacy = 0;

				if (shouldRefresh)
					getCenterOfBeingValues(creature, duration, efficacy);

				creature->removeBuff(buff);

				if (!shouldRefresh || duration <= 0 || efficacy <= 0)
					return;

				ManagedReference<Buff*> centered = new CenterOfBeingBuff(creature, buffCRC, duration);
				configureCenterBuff(centered, efficacy);
				creature->addBuff(centered);

				if (creature->isInCombat())
					creature->notifyObservers(ObserverEventType::ABILITYUSED, nullptr, buffCRC);
			}
		};

    }
   }
  }
 }
}

using namespace server::zone::objects::creature::buffs;

#endif /* CENTEROFBEINGBUFFDURATIONEVENT_H_ */
