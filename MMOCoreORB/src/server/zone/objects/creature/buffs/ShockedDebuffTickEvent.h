/*
				Copyright <SWGEmu>
		See file COPYING for copying conditions.*/

#ifndef SHOCKEDDEBUFFTICKEVENT_H_
#define SHOCKEDDEBUFFTICKEVENT_H_

#include "server/zone/objects/creature/CreatureObject.h"
#include "server/zone/objects/creature/buffs/Buff.h"

namespace server {
 namespace zone {
  namespace objects {
   namespace creature {
    namespace buffs {

		class ShockedDebuffTickEvent : public Task {
			ManagedWeakReference<CreatureObject*> creatureObject;
			ManagedWeakReference<Buff*> buffObject;

		public:
			ShockedDebuffTickEvent(CreatureObject* creature, Buff* buff) : Task((int64) 5000) {
				creatureObject = creature;
				buffObject = buff;
			}

			void run() {
				ManagedReference<CreatureObject*> creature = creatureObject.get();
				ManagedReference<Buff*> buff = buffObject.get();

				if (creature == nullptr || buff == nullptr)
					return;

				Locker locker(creature);
				Locker clocker(buff, creature);

				buff->activate(false);
			}

			void setBuffObject(Buff* buff) {
				buffObject = buff;
			}
		};
    }
   }
  }
 }
}

using namespace server::zone::objects::creature::buffs;

#endif // SHOCKEDDEBUFFTICKEVENT_H_
