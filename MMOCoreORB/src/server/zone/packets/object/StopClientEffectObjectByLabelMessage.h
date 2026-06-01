/*
				Copyright <SWGEmu>
		See file COPYING for copying conditions.*/

#ifndef STOPCLIENTEFFECTOBJECTBYLABELMESSAGE_H_
#define STOPCLIENTEFFECTOBJECTBYLABELMESSAGE_H_

#include "engine/service/proto/BaseMessage.h"

#include "server/zone/objects/scene/SceneObject.h"

class StopClientEffectObjectByLabelMessage : public BaseMessage {
public:
	StopClientEffectObjectByLabelMessage(SceneObject* obj, const String& label) : BaseMessage() {
		insertShort(0x04);
		insertInt(0xAD6F6B26);
		insertLong(obj->getObjectID());
		insertAscii(label.toCharArray());
	}
};

#endif // STOPCLIENTEFFECTOBJECTBYLABELMESSAGE_H_
