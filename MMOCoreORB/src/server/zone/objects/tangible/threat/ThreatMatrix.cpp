/*
 * ThreatMatrix.cpp
 *
 *  Created on: 1/23/2012
 *      Author: Kyle
 */

#include "ThreatMatrix.h"
#include "ThreatMap.h"
#include "ThreatStates.h"
#include "server/zone/objects/tangible/TangibleObject.h"

namespace {
uint64 composeThreatKey(uint32 magnitude, TangibleObject* threat) {
	uint64 objectID = threat != nullptr ? threat->getObjectID() : 0;
	uint64 tieBreaker = (uint32)(objectID ^ (objectID >> 32));

	return (((uint64)magnitude) << 32) | tieBreaker;
}

uint32 extractThreatMagnitude(uint64 key) {
	return (uint32)(key >> 32);
}
}

ThreatMatrix::ThreatMatrix() : damageMap(1, 0), aggroMap(1, 0), healMap(1, 0) {
	tauntThreat = nullptr;
	focusedThreat = nullptr;
}

ThreatMatrix::~ThreatMatrix() {
}

ThreatMatrix::ThreatMatrix(const ThreatMatrix& e)
	: tauntThreat(e.tauntThreat), focusedThreat(e.focusedThreat), damageMap(e.damageMap), aggroMap(e.aggroMap), healMap(e.healMap) {
}

ThreatMatrix& ThreatMatrix::operator=(const ThreatMatrix& e) {
	if (this == &e)
		return *this;

	tauntThreat = e.tauntThreat;
	focusedThreat = e.focusedThreat;

	damageMap = e.damageMap;
	aggroMap = e.aggroMap;
	healMap = e.healMap;

	return *this;
}

void ThreatMatrix::clear() {
	tauntThreat = nullptr;
	focusedThreat = nullptr;

	if (damageMap.size() > 0)
		damageMap.removeAll();

	if (aggroMap.size() > 0)
		aggroMap.removeAll();

	if (healMap.size() > 0)
		healMap.removeAll();
}

void ThreatMatrix::add(TangibleObject* threat, ThreatMapEntry* entry) {
	// Get Total Damage
	uint32 totalDamage = entry->getEffectiveDamageThreat();

	/// We don't want to add someone who hasn't done
	/// and damage to this
	if (totalDamage > 0)
		damageMap.put(composeThreatKey(totalDamage, threat), threat);

	/// Anyone with an entry should be in this map
	uint32 effectiveAggro = entry->getEffectiveAggroMod();
	if (effectiveAggro > 0)
		aggroMap.put(composeThreatKey(effectiveAggro, threat), threat);

	/// Only healers should be in this map
	uint32 effectiveHeal = entry->getEffectiveHeal();
	if (effectiveHeal > 0)
		healMap.put(composeThreatKey(effectiveHeal, threat), threat);

	if (entry->hasState(ThreatStates::TAUNTED)) {
		tauntThreat = threat;
	}

	if (entry->hasState(ThreatStates::FOCUSED)) {
		focusedThreat = threat;
	}
}

TangibleObject* ThreatMatrix::getLargestThreat() {
	TangibleObject* returnThreat = nullptr;

	if (tauntThreat != nullptr) {
		returnThreat = tauntThreat;

	} else if (focusedThreat != nullptr) {
		returnThreat = focusedThreat;

	} else {
		VectorMap<uint64, int> candidateScores;
		VectorMap<uint64, ManagedReference<TangibleObject*>> candidates;

		auto scoreCandidate = [&candidateScores, &candidates](TangibleObject* target, int weight) {
			if (target == nullptr)
				return;

			uint64 objectID = target->getObjectID();
			int idx = candidateScores.find(objectID);

			if (idx == -1) {
				candidateScores.put(objectID, weight);
				candidates.put(objectID, target);
			} else {
				candidateScores.get(idx) += weight;
			}
		};

		if (damageMap.size() > 0)
			scoreCandidate(damageMap.elementAt(damageMap.size() - 1).getValue(), 6);

		if (aggroMap.size() > 0)
			scoreCandidate(aggroMap.elementAt(aggroMap.size() - 1).getValue(), 5);

		if (healMap.size() > 0)
			scoreCandidate(healMap.elementAt(healMap.size() - 1).getValue(), 3);

		int bestScore = -1;

		for (int i = 0; i < candidateScores.size(); ++i) {
			int score = candidateScores.elementAt(i).getValue();

			if (score > bestScore) {
				bestScore = score;
				returnThreat = candidates.get(i);
			}
		}
	}

#ifdef DEBUG
	print();

	if (returnThreat != nullptr)
		System::out << "Targeting " << returnThreat->getObjectID() << endl;
	else
		System::out << "Targeting Nothing" << endl;
#endif
	clear();
	return returnThreat;
}

void ThreatMatrix::print() {
	System::out << "************* Targets *****************" << endl;
	System::out << "Taunted by: ";
	if (tauntThreat != nullptr)
		System::out << tauntThreat->getObjectID() << endl;
	else
		System::out << "nullptr" << endl;

	System::out << "Focused on: ";
	if (focusedThreat != nullptr)
		System::out << focusedThreat->getObjectID() << endl;
	else
		System::out << "nullptr" << endl;

	System::out << "************* DamageMap ***************" << endl;
	for (int i = 0; i < damageMap.size(); ++i) {
		System::out << "DamageMap[" << i << "] " << damageMap.elementAt(i).getValue()->getObjectID() << " " << extractThreatMagnitude(damageMap.elementAt(i).getKey()) << endl;
	}

	System::out << "************* AggroMap ***************" << endl;
	for (int i = 0; i < aggroMap.size(); ++i) {
		System::out << "AggroMap[" << i << "] " << aggroMap.elementAt(i).getValue()->getObjectID() << " " << extractThreatMagnitude(aggroMap.elementAt(i).getKey()) << endl;
	}

	System::out << "************* HealMap ***************" << endl;
	for (int i = 0; i < healMap.size(); ++i) {
		System::out << "HealMap[" << i << "] " << healMap.elementAt(i).getValue()->getObjectID() << " " << extractThreatMagnitude(healMap.elementAt(i).getKey()) << endl;
	}
	System::out << "*************************************" << endl;
}
