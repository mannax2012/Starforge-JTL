/*
 * GeneticLabratory.cpp
 *
 *  Created on: Aug 7, 2013
 *      Author: swgemu
 */

#include "GeneticLabratory.h"
#include "server/zone/objects/tangible/component/genetic/GeneticComponent.h"
#include "server/zone/objects/tangible/component/dna/DnaComponent.h"
#include "Genetics.h"
#include "server/zone/objects/draftschematic/DraftSchematic.h"
#include "server/zone/objects/manufactureschematic/ingredientslots/ComponentSlot.h"
#include "server/zone/managers/crafting/CraftingManager.h"

// #define DEBUG_GENETIC_LAB

namespace {
constexpr float CRAFTED_RESISTANCE_CAP = 80.f;

float applyFortitudeResistanceProgress(float resistance, float fortitudeExperimentPercent) {
	if (resistance > CRAFTED_RESISTANCE_CAP)
		return resistance;

	float assemblyBonus = Math::max(0.f, Math::min(fortitudeExperimentPercent, 1.f)) * CRAFTED_RESISTANCE_CAP;
	return Math::min(resistance + assemblyBonus, CRAFTED_RESISTANCE_CAP);
}
}

GeneticLabratory::GeneticLabratory() {
	setLoggingName("GeneticLaboratory");
}

GeneticLabratory::~GeneticLabratory() {
}

void GeneticLabratory::initialize(ZoneServer* server) {
	SharedLabratory::initialize(server);
}

String GeneticLabratory::pickSpecialAttack(const String candidates[], int candidateCount, float quality, const String& otherSpecial) {
	int eligibleCount = 0;

	for (int i = 0; i < candidateCount; ++i) {
		const String& candidate = candidates[i];

		if (!Genetics::isCraftableSpecialAttack(candidate) || candidate == otherSpecial)
			continue;

		bool duplicate = false;

		for (int j = 0; j < i; ++j) {
			if (candidates[j] == candidate) {
				duplicate = true;
				break;
			}
		}

		if (!duplicate)
			++eligibleCount;
	}

	if (eligibleCount == 0)
		return "defaultattack";

	// Quality is inverse (1 is VHQ, 7 is VLQ).  Keep the quality benefit while
	// raising special retention from the old 87%-7% range to 100%-40%.
	const int chanceToKeep = Math::max(40, 100 - (int)((quality - 1.f) * 10.f));

	if (System::random(100) >= chanceToKeep)
		return "defaultattack";

	int selected = System::random(eligibleCount);

	for (int i = 0; i < candidateCount; ++i) {
		const String& candidate = candidates[i];

		if (!Genetics::isCraftableSpecialAttack(candidate) || candidate == otherSpecial)
			continue;

		bool duplicate = false;

		for (int j = 0; j < i; ++j) {
			if (candidates[j] == candidate) {
				duplicate = true;
				break;
			}
		}

		if (!duplicate && selected-- == 0)
			return candidate;
	}

	return "defaultattack";
}

void GeneticLabratory::recalculateResistances(CraftingValues* craftingValues, float fortDiff) {
	if (craftingValues == nullptr)
		return;

#ifdef DEBUG_GENETIC_LAB
	info(true) << "---------- recalculateResistancess ----------";
#endif

	float newValue = 0.f;

	// Fortitude experimentation converts directly into ordinary resistances.
	// Make this a meaningful crafting choice while preserving each resistance's
	// existing hard cap below.
	// A complete 0-100% Fortitude profile contributes at most 80 resistance
	// points. Assembly receives its proportional share below; each further 1%
	// of Fortitude experimentation contributes the remaining 0.8 points.
	constexpr float FORTITUDE_RESIST_EXPERIMENT_MULTIPLIER = 0.08f;
	float effectivenessBonus = fortDiff * FORTITUDE_RESIST_EXPERIMENT_MULTIPLIER;

#ifdef DEBUG_GENETIC_LAB
	info(true) << "Added Effectiveness: " << effectivenessBonus;
#endif

	{
		float currentValue = craftingValues->getCurrentValue("dna_comp_armor_kinetic");
		newValue = currentValue > 80.f ? currentValue : Math::min(currentValue + effectivenessBonus, 80.f);

#ifdef DEBUG_GENETIC_LAB
		info(true) << "Kinetic Current: " << craftingValues->getCurrentValue("dna_comp_armor_kinetic") << " Kinetic New: " << newValue;
#endif

		craftingValues->setCurrentValue("dna_comp_armor_kinetic", newValue);
	}

	{
		float currentValue = craftingValues->getCurrentValue("dna_comp_armor_energy");
		newValue = currentValue > 80.f ? currentValue : Math::min(currentValue + effectivenessBonus, 80.f);

#ifdef DEBUG_GENETIC_LAB
		info(true) << "Energy Current: " << craftingValues->getCurrentValue("dna_comp_armor_energy") << " Energy New: " << newValue;
#endif

		craftingValues->setCurrentValue("dna_comp_armor_energy", newValue);
	}

	{
		float currentValue = craftingValues->getCurrentValue("dna_comp_armor_blast");
		newValue = currentValue > 80.f ? currentValue : Math::min(currentValue + effectivenessBonus, 80.f);

#ifdef DEBUG_GENETIC_LAB
		info(true) << "Blast Current: " << craftingValues->getCurrentValue("dna_comp_armor_blast") << " Blast New: " << newValue;
#endif

		craftingValues->setCurrentValue("dna_comp_armor_blast", newValue);
	}

	{
		float currentValue = craftingValues->getCurrentValue("dna_comp_armor_heat");
		newValue = currentValue > 80.f ? currentValue : Math::min(currentValue + effectivenessBonus, 80.f);

#ifdef DEBUG_GENETIC_LAB
		info(true) << "Heat Current: " << craftingValues->getCurrentValue("dna_comp_armor_heat") << " Heat New: " << newValue;
#endif

		craftingValues->setCurrentValue("dna_comp_armor_heat", newValue);
	}

	{
		float currentValue = craftingValues->getCurrentValue("dna_comp_armor_cold");
		newValue = currentValue > 80.f ? currentValue : Math::min(currentValue + effectivenessBonus, 80.f);

#ifdef DEBUG_GENETIC_LAB
		info(true) << "Cold Current: " << craftingValues->getCurrentValue("dna_comp_armor_cold") << " Cold New: " << newValue;
#endif

		craftingValues->setCurrentValue("dna_comp_armor_cold", newValue);
	}

	{
		float currentValue = craftingValues->getCurrentValue("dna_comp_armor_electric");
		newValue = currentValue > 80.f ? currentValue : Math::min(currentValue + effectivenessBonus, 80.f);

#ifdef DEBUG_GENETIC_LAB
		info(true) << "Electricity Current: " << craftingValues->getCurrentValue("dna_comp_armor_electric") << " Electricity New: " << newValue;
#endif

		craftingValues->setCurrentValue("dna_comp_armor_electric", newValue);
	}

	{
		float currentValue = craftingValues->getCurrentValue("dna_comp_armor_acid");
		newValue = currentValue > 80.f ? currentValue : Math::min(currentValue + effectivenessBonus, 80.f);

#ifdef DEBUG_GENETIC_LAB
		info(true) << "Acid Current: " << craftingValues->getCurrentValue("dna_comp_armor_acid") << " Acid New: " << newValue;
#endif

		craftingValues->setCurrentValue("dna_comp_armor_acid", newValue);
	}

	{
		float currentValue = craftingValues->getCurrentValue("dna_comp_armor_stun");
		newValue = currentValue > 80.f ? currentValue : Math::min(currentValue + effectivenessBonus, 80.f);

#ifdef DEBUG_GENETIC_LAB
		info(true) << "Stun Current: " << craftingValues->getCurrentValue("dna_comp_armor_stun") << " Stun New: " << newValue;
#endif

		craftingValues->setCurrentValue("dna_comp_armor_stun", newValue);
	}

	{
		float currentValue = craftingValues->getCurrentValue("dna_comp_armor_saber");
		newValue = Math::min(currentValue + effectivenessBonus, 80.f);
		craftingValues->setCurrentValue("dna_comp_armor_saber", newValue);
	}

#ifdef DEBUG_GENETIC_LAB
	info(true) << "---------- END recalculateResist ----------";
#endif
}

void GeneticLabratory::setInitialCraftingValues(TangibleObject* prototype, ManufactureSchematic* manufactureSchematic, int assemblySuccess) {
	if (prototype == nullptr || manufactureSchematic == nullptr)
		return;

	ManagedReference<DraftSchematic*> draftSchematic = manufactureSchematic->getDraftSchematic();

	if (draftSchematic == nullptr)
		return;

#ifdef DEBUG_GENETIC_LAB
	info(true) << "---------- setInitialCraftingValues ----------";
#endif
	CraftingValues* craftingValues = manufactureSchematic->getCraftingValues();

	if (craftingValues == nullptr)
		return;

	// These 2 values are pretty standard, adding these
	float value = float(draftSchematic->getXpAmount());
	craftingValues->addExperimentalAttribute("xp", "", value, value, 0, true, AttributesMap::OVERRIDECOMBINE);

	value = manufactureSchematic->getComplexity();
	craftingValues->addExperimentalAttribute("complexity", "", value, value, 0, true, AttributesMap::OVERRIDECOMBINE);

	float modifier = calculateAssemblyValueModifier(assemblySuccess);

	// Cast component to genetic component
	if (prototype->getGameObjectType() != SceneObjectType::GENETICCOMPONENT)
		return;

	GeneticComponent* genetic = cast<GeneticComponent*>(prototype);

	if (genetic == nullptr)
		return;

#ifdef DEBUG_GENETIC_LAB
	info(true) << "Genetic Manufacturing Schematic Slot Count = " << manufactureSchematic->getSlotCount();
#endif

	// Get all of the DNA Components by their slot
	ManagedReference<DnaComponent*> physique = nullptr;
	ManagedReference<DnaComponent*> prowess = nullptr;
	ManagedReference<DnaComponent*> mental = nullptr;
	ManagedReference<DnaComponent*> psychological = nullptr;
	ManagedReference<DnaComponent*> aggression = nullptr;

	for (int i = 0; i < manufactureSchematic->getSlotCount(); ++i) {
		// Dna Component Slots
		Reference<IngredientSlot*> ingredientSlot = manufactureSchematic->getSlot(i);

		if (ingredientSlot == nullptr || !ingredientSlot->isComponentSlot())
			continue;

		ComponentSlot* componentSlot = ingredientSlot.castTo<ComponentSlot*>();

		if (componentSlot == nullptr)
			continue;

		ManagedReference<TangibleObject*> tano = componentSlot->getPrototype();

		if (tano == nullptr || (tano->getGameObjectType() != SceneObjectType::DNACOMPONENT))
			continue;

		ManagedReference<DnaComponent*> component = tano.castTo<DnaComponent*>();

		if (component == nullptr)
			continue;

		String slotName = componentSlot->getSlotName();

#ifdef DEBUG_GENETIC_LAB
		info(true) << "Retrieving Component from slot: " << componentSlot->getSlotName();
#endif

		if (slotName == "physique_profile") {
			physique = component.get();
		} else if (slotName == "prowess_profile") {
			prowess = component.get();
		} else if (slotName == "mental_profile") {
			mental = component.get();
		} else if (slotName == "psychological_profile") {
			psychological = component.get();
		} else if (slotName == "aggression_profile") {
			aggression = component.get();
		}
	}

	// Ensure none of the components have a nullptr
	if (physique == nullptr || prowess == nullptr || mental == nullptr || psychological == nullptr || aggression == nullptr)
		return;

	/*

	 1. Calculate the Attribute Max Values

	*/

	// Physique: Fortitude and Hardiness
	float fortitudeMax = Genetics::physiqueFormula(physique->getFortitude(), prowess->getFortitude(), mental->getFortitude(), psychological->getFortitude(), aggression->getFortitude()) * modifier;
	float hardinessMax = Genetics::physiqueFormula(physique->getHardiness(), prowess->getHardiness(), mental->getHardiness(), psychological->getHardiness(), aggression->getHardiness()) * modifier;

	// Prowess: Endurance and Dexterity
	float dexterityMax = Genetics::prowessFormula(physique->getDexterity(), prowess->getDexterity(), mental->getDexterity(), psychological->getDexterity(), aggression->getDexterity()) * modifier;
	float enduranceMax = Genetics::prowessFormula(physique->getEndurance(), prowess->getEndurance(), mental->getEndurance(), psychological->getEndurance(), aggression->getEndurance()) * modifier;

	// Mental: Intellect and Cleverness
	float intellectMax = Genetics::mentalFormula(physique->getIntellect(), prowess->getIntellect(), mental->getIntellect(), psychological->getIntellect(), aggression->getIntellect()) * modifier;
	float clevernessMax = Genetics::mentalFormula(physique->getCleverness(), prowess->getCleverness(), mental->getCleverness(), psychological->getCleverness(), aggression->getCleverness()) * modifier;

	// Physiological: Dependability and Coursage
	float dependabilityMax = Genetics::physchologicalFormula(physique->getDependability(), prowess->getDependability(), mental->getDependability(), psychological->getDependability(), aggression->getDependability()) * modifier;
	float courageMax = Genetics::physchologicalFormula(physique->getCourage(), prowess->getCourage(), mental->getCourage(), psychological->getCourage(), aggression->getCourage()) * modifier;

	// Aggression: Ferocity and Power
	float fiercenessMax = Genetics::aggressionFormula(physique->getFierceness(), prowess->getFierceness(), mental->getFierceness(), psychological->getFierceness(), aggression->getFierceness()) * modifier;
	float powerMax = Genetics::aggressionFormula(physique->getPower(), prowess->getPower(), mental->getPower(), psychological->getPower(), aggression->getPower()) * modifier;

#ifdef DEBUG_GENETIC_LAB
	info(true) << "===== Calculate Attribute Max Values =====";

	info(true) << "PHYSIQUE -- Fortitude Max: " << fortitudeMax << " Hardiness Max: " << hardinessMax;
	info(true) << "PROWESS -- Dexterity Max: " << dexterityMax << " Endurance Max: " << enduranceMax;
	info(true) << "MENTAL -- Intellect Max: " << intellectMax << " Cleverness Max: " << clevernessMax;
	info(true) << "PHYSIOLOGICAL -- Dependability Max: " << dependabilityMax << " Courage Max: " << courageMax;
	info(true) << "AGGRESSION -- Fierceness Max: " << fiercenessMax << " Power Max: " << powerMax;

	info(true) << "===== END Calculate Attribute Max Values =====";
#endif

	// Add Attribute and set the max and min values.
	craftingValues->addExperimentalAttribute("fortitude", "expPhysiqueProfile", 1.0f, 1000.f, 0, false, AttributesMap::LINEARCOMBINE);
	craftingValues->setCapValue("fortitude", fortitudeMax);

	craftingValues->addExperimentalAttribute("hardiness", "expPhysiqueProfile", 1.0f, 1000.f, 0, false, AttributesMap::LINEARCOMBINE);
	craftingValues->setCapValue("hardiness", hardinessMax);

	craftingValues->addExperimentalAttribute("dexterity", "expProwessProfile", 1.0f, 1000.f, 0, false, AttributesMap::LINEARCOMBINE);
	craftingValues->setCapValue("dexterity", dexterityMax);

	craftingValues->addExperimentalAttribute("endurance", "expProwessProfile",  1.0f, 1000.f, 0, false, AttributesMap::LINEARCOMBINE);
	craftingValues->setCapValue("endurance", enduranceMax);

	craftingValues->addExperimentalAttribute("intellect", "expMentalProfile", 1.0f, 1000.f, 0, false, AttributesMap::LINEARCOMBINE);
	craftingValues->setCapValue("intellect", intellectMax);

	craftingValues->addExperimentalAttribute("cleverness", "expMentalProfile", 1.0f, 1000.f, 0, false, AttributesMap::LINEARCOMBINE);
	craftingValues->setCapValue("cleverness", clevernessMax);

	craftingValues->addExperimentalAttribute("dependability", "expPsychologicalProfile", 1.0f, 1000.f, 0, false, AttributesMap::LINEARCOMBINE);
	craftingValues->setCapValue("dependability", dependabilityMax);

	craftingValues->addExperimentalAttribute("courage", "expPsychologicalProfile", 1.0f, 1000.f, 0, false, AttributesMap::LINEARCOMBINE);
	craftingValues->setCapValue("courage", courageMax);

	craftingValues->addExperimentalAttribute("fierceness", "expAggressionProfile", 1.0f, 1000.f, 0, false, AttributesMap::LINEARCOMBINE);
	craftingValues->setCapValue("fierceness", fiercenessMax);

	craftingValues->addExperimentalAttribute("power", "expAggressionProfile", 1.0f, 1000.f, 0, false, AttributesMap::LINEARCOMBINE);
	craftingValues->setCapValue("power", powerMax);


	/*

	 3. Update attribute initial values and percentages

	*/

#ifdef DEBUG_GENETIC_LAB
	info(true) << "Total Crafting Values: " << craftingValues->getTotalExperimentalAttributes();
#endif

	float currentPercentage = 0.0f, maxPercentage = 0.0f, capValue = 0.0f, initialValue = 0.0f, rangeValue = 0.0f, fortitude = 0.0f;
	bool hidden = false;

	for (int i = 0; i < craftingValues->getTotalExperimentalAttributes(); i++) {
		String attribute = craftingValues->getAttribute(i);
		String group = craftingValues->getAttributeGroup(attribute);

#ifdef DEBUG_GENETIC_LAB
		info(true) << " ==== Updating Attribute: " << attribute << " ====";
#endif
		if (craftingValues->isHidden(attribute))
			continue;

		// Get attribute cap value, update max value for experimentation and get max percentage
		capValue = craftingValues->getCapValue(attribute);
		craftingValues->setMaxValue(attribute, 1000.f);

		maxPercentage = (capValue / 1000.f);

		// Get initial assembled value
		initialValue = Genetics::initialValue(capValue);

		// Set current percentage based on assembly value
		currentPercentage = (initialValue / 1000.f);
		craftingValues->setCurrentPercentage(attribute, currentPercentage, maxPercentage);

#ifdef DEBUG_GENETIC_LAB
		info(true) << "Current Percentage: " << currentPercentage << " Max Percentage: " << 100.f;
		info(true) << "Setting Attribute Value: " << initialValue << " with Cap Value: " << capValue <<  " Group: " << group;
#endif

		if (attribute == "fortitude" && initialValue >= 500.f) {
			fortitude = initialValue;

#ifdef DEBUG_GENETIC_LAB
			info(true) << "Fortitude is over 500: " << fortitude;
#endif
		}
#ifdef DEBUG_GENETIC_LAB
		info(true) << " ==== End Updating Attribute: " << attribute << " ====";
#endif
	}

	craftingValues->recalculateValues(true);

	/*

		4. Calculate and Add Resistance Values

	*/

	// Check for Special Protections. They will not be overwritten by fortitude breaking 500.
	bool kineticSpecial = Genetics::hasSpecialResist(physique, prowess, mental, psychological, aggression, SharedWeaponObjectTemplate::KINETIC);
	bool energySpecial = Genetics::hasSpecialResist(physique, prowess, mental, psychological, aggression, SharedWeaponObjectTemplate::ENERGY);
	bool blastSpecial = Genetics::hasSpecialResist(physique, prowess, mental, psychological, aggression, SharedWeaponObjectTemplate::BLAST);
	bool heatSpecial = Genetics::hasSpecialResist(physique, prowess, mental, psychological, aggression, SharedWeaponObjectTemplate::HEAT);
	bool coldSpecial = Genetics::hasSpecialResist(physique, prowess, mental, psychological, aggression, SharedWeaponObjectTemplate::COLD);
	bool electricSpecial = Genetics::hasSpecialResist(physique, prowess, mental, psychological, aggression, SharedWeaponObjectTemplate::ELECTRICITY);
	bool acidSpecial = Genetics::hasSpecialResist(physique, prowess, mental, psychological, aggression, SharedWeaponObjectTemplate::ACID);
	bool stunSpecial = Genetics::hasSpecialResist(physique, prowess, mental, psychological, aggression, SharedWeaponObjectTemplate::STUN);
	bool lightsaberSpecial = Genetics::hasSpecialResist(physique, prowess, mental, psychological, aggression, SharedWeaponObjectTemplate::LIGHTSABER);

#ifdef DEBUG_GENETIC_LAB
	info(true) << "===== Special Protections =====";

	info(true) << "Kinetic Special Protection: " << (kineticSpecial ? "True" : "False");
	info(true) << "Energy Special Protection: " << (energySpecial ? "True" : "False");
	info(true) << "Blast Special Protection: " << (blastSpecial ? "True" : "False");
	info(true) << "Heat Special Protection: " << (heatSpecial ? "True" : "False");
	info(true) << "Cold Special Protection: " << (coldSpecial ? "True" : "False");
	info(true) << "Electricity Special Protection: " << (electricSpecial ? "True" : "False");
	info(true) << "Acid Special Protection: " << (acidSpecial ? "True" : "False");
	info(true) << "Stun Special Protection: " << (stunSpecial ? "True" : "False");
	//info(true) << "Lightsaber Special Protection: " << (lightsaberSpecial ? "True" : "False");

	info(true) << "===== END Special Protections =====";
#endif

	float blast = 0.f, kinetic = 0.f, energy = 0.f, heat = 0.f, cold = 0.f, electric = 0.f, acid = 0.f, stun = 0.f, lightsaber = 0.f;

	// Calculate Resistances
	kinetic = Genetics::resistanceFormula(physique, prowess, mental, psychological, aggression, SharedWeaponObjectTemplate::KINETIC, Genetics::KINETIC_MAX);
	energy = Genetics::resistanceFormula(physique, prowess, mental, psychological, aggression, SharedWeaponObjectTemplate::ENERGY, Genetics::ENERGY_MAX);
	blast = Genetics::resistanceFormula(physique, prowess, mental, psychological, aggression, SharedWeaponObjectTemplate::BLAST, Genetics::BLAST_MAX);
	heat = Genetics::resistanceFormula(physique, prowess, mental, psychological, aggression, SharedWeaponObjectTemplate::HEAT, Genetics::HEAT_MAX);
	cold = Genetics::resistanceFormula(physique, prowess, mental, psychological, aggression, SharedWeaponObjectTemplate::COLD, Genetics::COLD_MAX);
	electric = Genetics::resistanceFormula(physique, prowess, mental, psychological, aggression, SharedWeaponObjectTemplate::ELECTRICITY, Genetics::ELECTRICITY_MAX);
	acid = Genetics::resistanceFormula(physique, prowess, mental, psychological, aggression, SharedWeaponObjectTemplate::ACID, Genetics::ACID_MAX);
	stun = Genetics::resistanceFormula(physique, prowess, mental, psychological, aggression, SharedWeaponObjectTemplate::STUN, Genetics::STUN_MAX);
	lightsaber = Genetics::resistanceFormula(physique, prowess, mental, psychological, aggression, SharedWeaponObjectTemplate::LIGHTSABER, Genetics::LIGHTSABER_MAX);

	// Assembly already establishes part of the Fortitude experimentation profile.
	// Apply that percentage immediately so high-quality DNA starts with its share
	// of the 0-80 resistance budget before any remaining points are spent.
	float fortitudeExperimentPercent = craftingValues->getCurrentPercentage("fortitude");
	kinetic = applyFortitudeResistanceProgress(kinetic, fortitudeExperimentPercent);
	energy = applyFortitudeResistanceProgress(energy, fortitudeExperimentPercent);
	blast = applyFortitudeResistanceProgress(blast, fortitudeExperimentPercent);
	heat = applyFortitudeResistanceProgress(heat, fortitudeExperimentPercent);
	cold = applyFortitudeResistanceProgress(cold, fortitudeExperimentPercent);
	electric = applyFortitudeResistanceProgress(electric, fortitudeExperimentPercent);
	acid = applyFortitudeResistanceProgress(acid, fortitudeExperimentPercent);
	stun = applyFortitudeResistanceProgress(stun, fortitudeExperimentPercent);
	lightsaber = applyFortitudeResistanceProgress(lightsaber, fortitudeExperimentPercent);

#ifdef DEBUG_GENETIC_LAB
	info(true) << "===== Calculate Resistances =====";

	info(true) << "Kinetic Resistance: " << kinetic;
	info(true) << "Energy Resistance: " << energy;
	info(true) << "Blast Resistance: " << blast;
	info(true) << "Heat Resistance: " << heat;
	info(true) << "Cold Resistance: " << cold;
	info(true) << "Electric Resistance: " << electric;
	info(true) << "Acid Resistance: " << acid;
	info(true) << "Stun Resistance: " << stun;
	//info(true) << "Lightsaber Resistance: " << lightsaber;

	info(true) << "===== END Calculate Resistances =====";
#endif

	// Add Resistance Values
	craftingValues->addExperimentalAttribute("dna_comp_armor_kinetic", "resists", -99.f, Genetics::KINETIC_MAX, 0, true, AttributesMap::OVERRIDECOMBINE);
	craftingValues->setCurrentValue("dna_comp_armor_kinetic", kinetic);

	craftingValues->addExperimentalAttribute("dna_comp_armor_blast", "resists", -99.f, Genetics::BLAST_MAX, 0, true, AttributesMap::OVERRIDECOMBINE);
	craftingValues->setCurrentValue("dna_comp_armor_blast", blast);

	craftingValues->addExperimentalAttribute("dna_comp_armor_energy", "resists", -99.f, Genetics::ENERGY_MAX, 0, true, AttributesMap::OVERRIDECOMBINE);
	craftingValues->setCurrentValue("dna_comp_armor_energy", energy);

	craftingValues->addExperimentalAttribute("dna_comp_armor_heat", "resists", -99.f, Genetics::HEAT_MAX, 0, true, AttributesMap::OVERRIDECOMBINE);
	craftingValues->setCurrentValue("dna_comp_armor_heat", heat);

	craftingValues->addExperimentalAttribute("dna_comp_armor_cold", "resists", -99.f, Genetics::COLD_MAX, 0, true, AttributesMap::OVERRIDECOMBINE);
	craftingValues->setCurrentValue("dna_comp_armor_cold", cold);

	craftingValues->addExperimentalAttribute("dna_comp_armor_electric", "resists", -99.f, Genetics::ELECTRICITY_MAX, 0, true, AttributesMap::OVERRIDECOMBINE);
	craftingValues->setCurrentValue("dna_comp_armor_electric", electric);

	craftingValues->addExperimentalAttribute("dna_comp_armor_acid", "resists", -99.f, Genetics::ACID_MAX, 0, true, AttributesMap::OVERRIDECOMBINE);
	craftingValues->setCurrentValue("dna_comp_armor_acid", acid);

	craftingValues->addExperimentalAttribute("dna_comp_armor_stun", "resists", -99.f, Genetics::STUN_MAX, 0, true, AttributesMap::OVERRIDECOMBINE);
	craftingValues->setCurrentValue("dna_comp_armor_stun", stun);

	craftingValues->addExperimentalAttribute("dna_comp_armor_saber", "resists", -99.f, Genetics::LIGHTSABER_MAX, 0, true, AttributesMap::OVERRIDECOMBINE);
	craftingValues->setCurrentValue("dna_comp_armor_saber", lightsaber);

	// Store Special Resistances
	craftingValues->addExperimentalAttribute("kineticeffectiveness", "specials", (kineticSpecial ? 1 : 0), 1, 0, true, AttributesMap::OVERRIDECOMBINE);
	craftingValues->addExperimentalAttribute("energyeffectiveness", "specials", (energySpecial ? 1 : 0), 1, 0, true, AttributesMap::OVERRIDECOMBINE);
	craftingValues->addExperimentalAttribute("blasteffectiveness", "specials", (blastSpecial ? 1 : 0), 1, 0, true, AttributesMap::OVERRIDECOMBINE);
	craftingValues->addExperimentalAttribute("heateffectiveness", "specials", (heatSpecial ? 1 : 0), 1, 0, true, AttributesMap::OVERRIDECOMBINE);
	craftingValues->addExperimentalAttribute("coldeffectiveness", "specials", (coldSpecial ? 1 : 0), 1, 0, true, AttributesMap::OVERRIDECOMBINE);
	craftingValues->addExperimentalAttribute("electricityeffectiveness", "specials", (electricSpecial ? 1 : 0), 1, 0, true, AttributesMap::OVERRIDECOMBINE);
	craftingValues->addExperimentalAttribute("acideffectiveness", "specials", (acidSpecial ? 1 : 0), 1, 0, true, AttributesMap::OVERRIDECOMBINE);
	craftingValues->addExperimentalAttribute("stuneffectiveness", "specials", (stunSpecial ? 1 : 0), 1, 0, true, AttributesMap::OVERRIDECOMBINE);
	craftingValues->addExperimentalAttribute("lightsabereffectiveness", "specials", lightsaberSpecial ? 1 : 0, 1, 0, true, AttributesMap::OVERRIDECOMBINE);

	/*

		5. Determine Quality, Ranged, Special Attacks and Level

	*/

	// Determine Quality
	float quality = (physique->getQuality() * 0.2f) + (prowess->getQuality() * 0.2f) + (mental->getQuality() * 0.2f) + (psychological->getQuality() * 0.2f) + (aggression->getQuality() * 0.2f);

	// Ranged Attack
	bool ranged = false;

	float menQual = mental->getQuality() - 1;
	float psyQual = psychological->getQuality() - 1;

	if (mental->isRanged() || psychological->isRanged()) {
		int chance = System::random(100 - (assemblySuccess * 10)); // so amazing success 100, critical falure is 20

		// did you roll exceed (7 - Quality) * 10 (VHQ is 0) so always works
		if (chance >= (menQual * 10) || chance >= (psyQual * 10))
			ranged = true;
	}

	// Special attacks are selected from both attack slots of every DNA sample.
	// A creature can carry two unique specials, so both output slots draw from
	// this complete pool rather than being restricted to matching input slots.
	const String specialCandidates[] = {
		physique->getSpecialAttackOne(),
		physique->getSpecialAttackTwo(),
		prowess->getSpecialAttackOne(),
		prowess->getSpecialAttackTwo(),
		mental->getSpecialAttackOne(),
		mental->getSpecialAttackTwo(),
		psychological->getSpecialAttackOne(),
		psychological->getSpecialAttackTwo(),
		aggression->getSpecialAttackOne(),
		aggression->getSpecialAttackTwo()
	};

	const int specialCandidateCount = sizeof(specialCandidates) / sizeof(specialCandidates[0]);
	String special1 = pickSpecialAttack(specialCandidates, specialCandidateCount, quality, "defaultattack");
	String special2 = pickSpecialAttack(specialCandidates, specialCandidateCount, quality, special1);

	genetic->setSpecialAttackOne(special1);
	genetic->setSpecialAttackTwo(special2);
	genetic->setRanged(ranged);
	genetic->setQuality(quality);

	// determine avg sample levels to choose a level of this template for output generation
	int level = Genetics::physchologicalFormula(physique->getLevel(), prowess->getLevel(), mental->getLevel(), psychological->getLevel(), aggression->getLevel());
	genetic->setLevel(level);
}

int GeneticLabratory::getCreationCount(ManufactureSchematic* manufactureSchematic) {
	return 1;
}

void GeneticLabratory::experimentRow(CraftingValues* craftingValues,int rowEffected, int pointsAttempted, float failure, int experimentationResult) {
#ifdef DEBUG_GENETIC_LAB
	info(true) << "---------- Experiment Row ----------";
	info(true) << "Row Effected: " << rowEffected << " Points Attempted: " << pointsAttempted << " Experimental Result: " << experimentationResult << " Failure: " << failure;
#endif

	if (craftingValues == nullptr)
		return;

	/*

		1. Get the Two Modified Attributes and values, based on their group.

	*/

	String attribute1, attribute2;

	String experimentedGroup = craftingValues->getVisibleAttributeGroup(rowEffected);
	int totalAttributes = craftingValues->getTotalExperimentalAttributes();
	Vector<String> randomFailed;

#ifdef DEBUG_GENETIC_LAB
	info(true) << "Experimened Group: " << experimentedGroup;
#endif

	for (int i = 0; i < totalAttributes; ++i) {
		String attribute = craftingValues->getAttribute(i);
		String group = craftingValues->getAttributeGroup(attribute);

		if (group != experimentedGroup) {
			// Build a list for pote
			if (experimentationResult == CraftingManager::CRITICALFAILURE && group.contains("exp")) {
#ifdef DEBUG_GENETIC_LAB
				info(true) << "Added Attribute for Failure Roll: " << attribute;
#endif
				randomFailed.add(attribute);
			}

			continue;
		}

		if (attribute1 == "") {
			attribute1 = attribute;

#ifdef DEBUG_GENETIC_LAB
			info(true) << "Attribute 1: " << attribute1;
#endif
		} else if (attribute2 == "") {
			attribute2 = attribute;

#ifdef DEBUG_GENETIC_LAB
			info(true) << "Attribute 2: " << attribute2;
#endif
		}
	}

	/*

		2. Calculate modifier and calculate the modified percentage for the two affected attributes

	*/

	float newValue = 0.f, capValue = 0.f, fortDiff = 0.f;

	float modifier = calculateExperimentationValueModifier(experimentationResult, pointsAttempted) * 2000.f;

	float attValue1 = craftingValues->getCurrentValue(attribute1);
	float attValue2 = craftingValues->getCurrentValue(attribute2);

	// In the case of a failure only one attribute should go down from the primary group
	float signSwap = -1.f;
	bool swap1 = false, swap2 = false;

	if (experimentationResult == CraftingManager::CRITICALFAILURE) {
		if (System::random(100) > 50) {
			// Attribute1 will decrease
			swap2 = true;
		} else {
			// Attribute 2 will decrease
			swap1 = true;
		}
	}

	// Attribute 1
	capValue = craftingValues->getCapValue(attribute1);
	float att1Mod = (swap1 ? (modifier * signSwap) : modifier);

	newValue = attValue1 + (attValue2 / (attValue1 + attValue2) * att1Mod);

	if (newValue > capValue) {
		newValue = capValue;
	}

	craftingValues->setCurrentPercentage(attribute1, (newValue / 1000.f));

	if (attribute1 == "fortitude")
		fortDiff = newValue - attValue1;

#ifdef DEBUG_GENETIC_LAB
	info(true) << "Attribute 1 Experimentation --  " << attribute1 << " Starting Value: " << attValue1 << " Cap Value: " << capValue << " New Value: " << newValue << " Att1 Modifier: " << att1Mod;
#endif

	// Attribute 2
	capValue = craftingValues->getCapValue(attribute2);
	float att2Mod = (swap2 ? (modifier * signSwap) : modifier);

	newValue = attValue2 + (attValue1 / (attValue1 + attValue2) * att2Mod);

	if (newValue > capValue) {
		newValue = capValue;
	}

	craftingValues->setCurrentPercentage(attribute2, (newValue / 1000.f));

#ifdef DEBUG_GENETIC_LAB
	info(true) << "Attribute 2 Experimentation --  " << attribute2 << " Starting Value: " << attValue2 << " Cap Value: " << capValue << " New Value: " << newValue << " Att2 Modifier: " << att2Mod;
#endif

	/*

		4. Handle Critical Failure Chance for Alternate attribute

	*/

	// Choose Random Attribute that is not from the current experminted group
	if (experimentationResult == CraftingManager::CRITICALFAILURE && randomFailed.size() && System::random(100) > 50) {
#ifdef DEBUG_GENETIC_LAB
		info(true) << "Experimental Critical Failure -- ";
#endif
		int roll = System::random(randomFailed.size());

		String failedAttribute = craftingValues->getAttribute(roll);
		float currentPercent = craftingValues->getCurrentPercentage(failedAttribute);

		newValue = Math::max(0.f, (modifier + currentPercent));

		// Reduce attribute
		craftingValues->setCurrentPercentage(failedAttribute, newValue);

#ifdef DEBUG_GENETIC_LAB
		info(true) << "END Experimental Critical Failure -- Attribute Chosen: " << failedAttribute << " Old Percent: " << currentPercent << " New Percent: " << newValue << " Roll: " << roll;
#endif
	}

	/*

		5. Update Armor Resistances

	*/

	if (attribute1 == "fortitude") {
		// Pass old percentage value to use to fin increase
		recalculateResistances(craftingValues, fortDiff);
	}

#ifdef DEBUG_GENETIC_LAB
	info(true) << "---------- END Experiment Row ----------";
#endif
}
