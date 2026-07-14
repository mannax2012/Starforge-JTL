/*
 * CustomizationIdManager.cpp
 *
 *  Created on: 29/03/2012
 *      Author: victor
 */

#include "CustomizationIdManager.h"
#include "templates/datatables/DataTableIff.h"

CustomizationIdManager::CustomizationIdManager() {
	setLoggingName("CustomizationIdManager");
}

void CustomizationIdManager::loadHairAssetsSkillMods(IffStream* iffStream) {
	DataTableIff dataTable;
	dataTable.readObject(iffStream);

	auto normalizeTemplatePath = [](String templatePath) {
		return templatePath.replaceAll("shared_", "");
	};

	auto extractSpeciesGenderToken = [&](String templatePath) {
		templatePath = normalizeTemplatePath(templatePath);

		int slashIndex = templatePath.lastIndexOf("/");
		if (slashIndex == -1)
			return templatePath;

		String fileName = templatePath.subString(slashIndex + 1);

		if (fileName.endsWith(".iff"))
			fileName = fileName.subString(0, fileName.length() - 4);

		if (fileName.indexOf("hair_") == 0) {
			int styleIndex = fileName.lastIndexOf("_s");
			if (styleIndex != -1)
				return fileName.subString(5, styleIndex);
		}

		return fileName;
	};

	for (int i = 0; i < dataTable.getTotalRows(); ++i) {
		HairAssetData* data = new HairAssetData();
		data->readObject(dataTable.getRow(i));

		if (!hairAssetSkillMods.containsKey(data->getServerTemplate()))
			hairAssetSkillMods.put(data->getServerTemplate(), new Vector<Reference<HairAssetData*> >());

		Vector<Reference<HairAssetData*> >* hairRows = hairAssetSkillMods.get(data->getServerTemplate());

		if (hairRows != nullptr)
			hairRows->add(data);

		String hairSpeciesGender = extractSpeciesGenderToken(data->getServerTemplate());
		String playerSpeciesGender = extractSpeciesGenderToken(data->getPlayerTemplate());
		String serverPlayerSpeciesGender = extractSpeciesGenderToken(data->getServerPlayerTemplate());

		if (playerSpeciesGender != serverPlayerSpeciesGender) {
			error() << "Hair asset player template mismatch for hairTemplate=" << data->getServerTemplate()
					<< " sharedTemplate=" << data->getSharedTemplate()
					<< " playerTemplate=" << data->getPlayerTemplate()
					<< " serverPlayerTemplate=" << data->getServerPlayerTemplate()
					<< " normalizedPlayerTemplate=" << normalizeTemplatePath(data->getPlayerTemplate())
					<< " normalizedServerPlayerTemplate=" << normalizeTemplatePath(data->getServerPlayerTemplate());
		}

		// Shared hairstyles intentionally reuse the same hair template across multiple species rows.
		if (hairSpeciesGender != playerSpeciesGender || hairSpeciesGender != serverPlayerSpeciesGender) {
			info() << "Hair asset shared across species for hairTemplate=" << data->getServerTemplate()
					<< " sharedTemplate=" << data->getSharedTemplate()
					<< " hairSpeciesGender=" << hairSpeciesGender
					<< " playerTemplate=" << data->getPlayerTemplate()
					<< " playerSpeciesGender=" << playerSpeciesGender
					<< " serverPlayerTemplate=" << data->getServerPlayerTemplate()
					<< " serverPlayerSpeciesGender=" << serverPlayerSpeciesGender
					<< " skillModValue=" << data->getSkillModValue()
					<< " availableAtCreation=" << data->isAvailableAtCreation();
		}

		if (hairRows != nullptr && hairRows->size() > 1) {
			info() << "Hair asset template has multiple species mappings for hairTemplate=" << data->getServerTemplate()
					<< " mappingsLoaded=" << hairRows->size()
					<< " latestPlayerTemplate=" << data->getPlayerTemplate()
					<< " latestServerPlayerTemplate=" << data->getServerPlayerTemplate();
		}

		debug() << "adding " << data->getServerTemplate();
	}

	info() << "loaded " << dataTable.getTotalRows() << " hair asset rows across " << hairAssetSkillMods.size() << " unique hair templates";
}

void CustomizationIdManager::loadAllowBald(IffStream* iffStream) {
	DataTableIff dataTable;
	dataTable.readObject(iffStream);

	for (int i = 0; i < dataTable.getTotalRows(); ++i) {
		String species;
		bool val;

		DataTableRow* row = dataTable.getRow(i);

		row->getValue(0, species);
		row->getValue(1, val);

		allowBald.put(String::hashCode("object/creature/player/" + species + ".iff"), val);
	}

	info() << "loaded " << allowBald.size() << " allow bald species data";
}

void CustomizationIdManager::loadPaletteColumns(IffStream* iffStream) {
	DataTableIff dataTable;
	dataTable.readObject(iffStream);

	for (int i = 0; i < dataTable.getTotalRows(); ++i) {
		PaletteData* data = new PaletteData();
		data->readObject(dataTable.getRow(i));

		paletteColumns.put(data->getName(), data);

		debug() << "adding " << data->getName();
	}

	info() << "loaded " << paletteColumns.size() << " palette columns";
}

void CustomizationIdManager::readObject(IffStream* iffStream) {
	iffStream->openForm('CIDM');
	iffStream->openForm('0001');

	Chunk* data = iffStream->openChunk('DATA');

	while (data->hasData()) {
		int id = data->readShort();
		String var;
		data->readString(var);

		customizationIds.put(var, id);
		reverseIds.put(id, var);
	}

	iffStream->closeChunk('DATA');

	iffStream->closeForm('0001');
	iffStream->closeForm('CIDM');

	info() << "loaded " << customizationIds.size() << " customization ids";
}
