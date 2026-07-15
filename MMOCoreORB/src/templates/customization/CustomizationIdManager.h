/*
 * CustomizationIdManager.h
 *
 *  Created on: 28/03/2012
 *      Author: victor
 */

#ifndef CUSTOMIZATIONIDMANAGER_H_
#define CUSTOMIZATIONIDMANAGER_H_

#include "engine/log/Logger.h"
#include "engine/util/Singleton.h"
#include "templates/customization/PaletteData.h"
#include "templates/customization/HairAssetData.h"

class CustomizationIdManager : public Object, public Logger, public Singleton<CustomizationIdManager> {
	HashTable<String, int> customizationIds;
	HashTable<int, String> reverseIds;
	HashTable<String, Reference<PaletteData*> > paletteColumns;
	HashTable<String, Reference<Vector<Reference<HairAssetData*> >*> > hairAssetSkillMods;
	HashTable<int, bool> allowBald;

public:
	CustomizationIdManager();

	void loadPaletteColumns(IffStream* iffStream);
	void loadHairAssetsSkillMods(IffStream* iffStream);
	void loadAllowBald(IffStream* iffStream);
	void readObject(IffStream* iffStream);

	int getCustomizationId(const String& var) {
		return customizationIds.get(var);
	}

	String getCustomizationVariable(int id) {
		return reverseIds.get(id);
	}

	PaletteData* getPaletteData(const String& palette) {
		return paletteColumns.get(palette);
	}

	HairAssetData* getHairAssetData(const String& hairServerTemplate) {
		Vector<Reference<HairAssetData*> >* hairAssetData = hairAssetSkillMods.get(hairServerTemplate);

		if (hairAssetData == nullptr || hairAssetData->size() == 0)
			return nullptr;

		return hairAssetData->get(0);
	}

	HairAssetData* getHairAssetData(const String& hairServerTemplate, const String& targetServerTemplate, const String& targetClientTemplate = "") {
		Vector<Reference<HairAssetData*> >* hairAssetData = hairAssetSkillMods.get(hairServerTemplate);

		if (hairAssetData == nullptr || hairAssetData->size() == 0)
			return nullptr;

		auto normalizeTemplatePath = [](String templatePath) {
			return templatePath.replaceAll("shared_", "");
		};

		auto matchesTemplate = [&](const String& assetTemplate, const String& targetTemplate) {
			if (assetTemplate.isEmpty() || targetTemplate.isEmpty())
				return false;

			return normalizeTemplatePath(assetTemplate) == normalizeTemplatePath(targetTemplate);
		};

		HairAssetData* normalizedServerMatch = nullptr;
		HairAssetData* normalizedClientMatch = nullptr;

		for (int i = 0; i < hairAssetData->size(); ++i) {
			HairAssetData* data = hairAssetData->get(i);

			if (data == nullptr)
				continue;

			if (!targetServerTemplate.isEmpty() && data->getServerPlayerTemplate() == targetServerTemplate)
				return data;

			if (!targetClientTemplate.isEmpty() && data->getPlayerTemplate() == targetClientTemplate)
				return data;

			if (normalizedServerMatch == nullptr && matchesTemplate(data->getServerPlayerTemplate(), targetServerTemplate))
				normalizedServerMatch = data;

			if (normalizedClientMatch == nullptr && matchesTemplate(data->getPlayerTemplate(), targetClientTemplate))
				normalizedClientMatch = data;
		}

		if (normalizedServerMatch != nullptr)
			return normalizedServerMatch;

		if (normalizedClientMatch != nullptr)
			return normalizedClientMatch;

		return hairAssetData->get(0);
	}

	bool canBeBald(const int objectCRC) {
		return allowBald.get(objectCRC);
	}
};

#endif /* CUSTOMIZATIONIDMANAGER_H_ */
