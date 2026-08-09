/*
 * PetDeedTemplate.h
 *
 *  Created on: August 17, 2013
 *      Author: washu
 */

#ifndef PETDEEDTEMPLATE_H_
#define PETDEEDTEMPLATE_H_

#include "templates/tangible/DeedTemplate.h"

class PetDeedTemplate : public DeedTemplate {
private:
	String controlDeviceObjectTemplate;
	String mobileTemplate;
	VectorMap<String, float> baseResistances;

public:
	PetDeedTemplate() {
		baseResistances.setNullValue(0.f);
	}

	~PetDeedTemplate() {

	}

	void readObject(LuaObject* templateData) {
		DeedTemplate::readObject(templateData);
		controlDeviceObjectTemplate = templateData->getStringField("controlDeviceObjectTemplate");
		mobileTemplate = templateData->getStringField("mobileTemplate");

		baseResistances.removeAll();
		LuaObject resists = templateData->getObjectField("baseResistances");

		if (resists.isValidTable()) {
			for (int i = 1; i < resists.getTableSize(); i += 2) {
				String resistanceType = resists.getStringAt(i);
				float resistanceValue = resists.getFloatAt(i + 1);

				baseResistances.put(resistanceType, resistanceValue);
			}
		}

		resists.pop();
    }

	String getControlDeviceObjectTemplate() {
		return controlDeviceObjectTemplate;
	}

	String getMobileTemplate() {
		return mobileTemplate;
	}

	const VectorMap<String, float>* getBaseResistances() const {
		return &baseResistances;
	}

	float getBaseResistance(const String& resistanceType) const {
		return baseResistances.get(resistanceType);
	}

};


#endif /* PETDEEDTEMPLATE_H_ */
