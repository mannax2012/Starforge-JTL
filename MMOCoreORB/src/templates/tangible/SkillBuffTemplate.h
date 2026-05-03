/*
 * SkillBuffTemplate.h
 *
 *  Created on: 9/21/2013
 *      Author: Klivian
 */

#ifndef SKILLBUFFTEMPLATE_H_
#define SKILLBUFFTEMPLATE_H_

#include "templates/SharedTangibleObjectTemplate.h"

class SkillBuffTemplate : public SharedTangibleObjectTemplate {
	int duration;
	int reuseTime;
	VectorMap<String, float> modifiers;
	String buffName;
	unsigned int buffCRC;

public:
	SkillBuffTemplate() : duration(0), reuseTime(0), buffCRC(0) {

	}

	~SkillBuffTemplate() {

	}

	void readObject(LuaObject* templateData) {
		SharedTangibleObjectTemplate::readObject(templateData);

		duration = templateData->getIntField("duration");
		reuseTime = templateData->getIntField("reuseTime");

		modifiers.removeAll();
		LuaObject mods = templateData->getObjectField("modifiers");

		for (int i = 1; i <= mods.getTableSize(); i += 2) {
			String attribute = mods.getStringAt(i);
			float value = mods.getFloatAt(i + 1);

			modifiers.put(attribute, value);
		}
		mods.pop();

		buffName = templateData->getStringField("buffName");

		buffCRC = templateData->getIntField("buffCRC");

    }

    inline String& getBuffName() {
		return buffName;
	}

    inline int getDuration() const {
		return duration;
	}

	inline int getReuseTime() const {
		return reuseTime;
	}

	VectorMap<String, float>* getModifiers() {
		return &modifiers;
	}

	bool isSkillBuffTemplate() {
		return true;
	}

	inline unsigned int getBuffCRC(){
		return buffCRC;
	}

};


#endif /* SKILLBUFFTEMPLATE_H_ */
