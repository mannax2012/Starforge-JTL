/*
				Copyright <SWGEmu>
		See file COPYING for copying conditions.*/

#ifndef REGRANTSKILLSCOMMAND_H_
#define REGRANTSKILLSCOMMAND_H_

#include "server/zone/objects/scene/SceneObject.h"
#include "server/zone/managers/frs/FrsManager.h"
#include "server/zone/managers/mission/MissionManager.h"
#include "server/zone/managers/skill/SkillManager.h"

class RegrantSkillsCommand : public QueueCommand {
public:

	RegrantSkillsCommand(const String& name, ZoneProcessServer* server)
		: QueueCommand(name, server) {
	}

	int doQueueCommand(CreatureObject* creature, const uint64& target, const UnicodeString& arguments) const {
		if (!checkStateMask(creature))
			return INVALIDSTATE;

		if (!checkInvalidLocomotions(creature))
			return INVALIDLOCOMOTION;

		ManagedReference<PlayerObject*> ghost = creature->getPlayerObject();
		SkillManager* skillManager = SkillManager::instance();
		const SkillList* skillList = creature->getSkillList();
		FrsManager* frsManager = creature->getZoneServer()->getFrsManager();
		MissionManager* missionManager = creature->getZoneServer()->getMissionManager();

		if (ghost == nullptr || skillList == nullptr || skillManager == nullptr)
			return GENERALERROR;

		if (!creature->checkCooldownRecovery("regrantSkills")) {
			creature->sendSystemMessage("You cannot have your skill regranted more than once per 12 hours.");
			return GENERALERROR;
		}

		Vector<String> listOfNames;
		skillList->getStringList(listOfNames);
		SkillList copyOfList;
		copyOfList.loadFromNames(listOfNames);

		Vector<String> skillsToRegrant;
		int councilType = ghost->getFrsData()->getCouncilType();

		for (int i = 0; i < copyOfList.size(); i++) {
			Skill* skill = copyOfList.get(i);
			String skillName = skill->getSkillName();

			if (skillName.beginsWith("admin") || skillName.beginsWith("pilot_"))
				continue;

			if (skillName == "force_title_jedi_rank_04" || skillName == "force_title_jedi_master")
				continue;

			if (frsManager != nullptr && councilType != 0 && frsManager->getSkillRank(skillName, councilType) >= 0)
				continue;

			if (skill->getSkillPointsRequired() > 0 || skillName.beginsWith("force_"))
				skillsToRegrant.add(skillName);
		}

		skillManager->surrenderAllSkills(creature, true, true, false);

		Vector<String> failedSkills;
		bool madeProgress = true;

		while (skillsToRegrant.size() > 0 && madeProgress) {
			madeProgress = false;
			failedSkills.removeAll();

			for (int i = 0; i < skillsToRegrant.size(); i++) {
				String skillName = skillsToRegrant.get(i);

				if (creature->hasSkill(skillName)) {
					madeProgress = true;
					continue;
				}

				if (!skillManager->awardSkill(skillName, creature, true, true, true)) {
					failedSkills.add(skillName);
				} else {
					creature->sendSystemMessage("Regranting Skill: " + skillName);
					madeProgress = true;
				}
			}

			skillsToRegrant.removeAll();

			for (int i = 0; i < failedSkills.size(); i++) {
				String skillName = failedSkills.get(i);

				if (!creature->hasSkill(skillName))
					skillsToRegrant.add(skillName);
			}
		}

		if (frsManager != nullptr && councilType != 0) {
			Locker locker(creature);
			frsManager->updatePlayerSkills(creature);
		}

		if (missionManager != nullptr && creature->hasSkill("force_title_jedi_rank_02")) {
			uint64 id = creature->getObjectID();
			int reward = ghost->calculateBhReward();

			if (!missionManager->hasPlayerBountyTargetInList(id))
				missionManager->addPlayerToBountyList(id, reward);
			else {
				missionManager->updatePlayerBountyReward(id, reward);
				missionManager->updatePlayerBountyOnlineStatus(id, true);
			}
		}

		if (skillsToRegrant.size() > 0) {
			creature->sendSystemMessage("Skill regrant failed for " + String::valueOf(skillsToRegrant.size()) + " skill(s). First failure: " + skillsToRegrant.get(0));
			return GENERALERROR;
		}

		creature->updateCooldownTimer("regrantSkills", 43200000);
		creature->sendSystemMessage("Completed.");

		return SUCCESS;
	}
};

#endif // REGRANTSKILLSCOMMAND_H_
