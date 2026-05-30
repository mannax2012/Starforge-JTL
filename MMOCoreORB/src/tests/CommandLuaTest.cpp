/*
 * CommandLuaTest.cpp
 *
 *  Created on: 20/10/2013
 *      Author: victor
 */

#include "gtest/gtest.h"
#include "gmock/gmock.h"

#include "templates/manager/DataArchiveStore.h"
#include "server/zone/managers/objectcontroller/command/CommandConfigManager.h"
#include "server/zone/managers/objectcontroller/command/CommandList.h"
#include "conf/ConfigManager.h"
#include "server/zone/objects/creature/commands/CombatQueueCommand.h"

class CommandLuaTest : public ::testing::Test {
public:
	Vector<uint32> animList;
	Logger logger;
	CommandConfigManager* man;
	CommandList* list;

	CommandLuaTest() : logger("CommandLuaTest") {
		// Perform creation setup here.
		ConfigManager::instance()->loadConfigData();
		DataArchiveStore::instance()->loadTres(ConfigManager::instance()->getTrePath(), ConfigManager::instance()->getTreFiles());
		man = new CommandConfigManager(nullptr);
		list = new CommandList();
	}

	~CommandLuaTest() {
		delete man;
		delete list;
	}

	void SetUp() {
		// Perform setup of common constructs here.
	}

	void TearDown() {
		// Perform clean up of common constructs here.
	}

	void loadAnimList();
};

TEST_F(CommandLuaTest, LoadCommandLuas) {
	man->registerSpecialCommands(list);
	man->loadSlashCommandsFile();

	ASSERT_EQ(CommandConfigManager::ERROR_CODE, 0);
}

// This ensures that nobody inserts an invalid animation name, or uses an invalid generation type
TEST_F(CommandLuaTest, CheckAnimationCRCS) {
	loadAnimList();

	HashTableIterator<uint32, Reference<QueueCommand*> > iter = list->iterator();

	while (iter.hasNext()) {
		Reference<QueueCommand*> command = iter.getNextValue();

		if (command->isCombatCommand()) {
			CombatQueueCommand* combatCommand = command.castTo<CombatQueueCommand*>();
			uint8 animType = combatCommand->getAnimType();
			String commandName = combatCommand->getQueueCommandName();

			if (animType == CombatQueueCommand::GENERATE_NONE) {
				String anim = combatCommand->getAnimationString();
				if(!anim.isEmpty()) {
					ASSERT_TRUE(animList.contains(anim.hashCode()));
				}
			} else if (animType == CombatQueueCommand::GENERATE_RANGED) {
				String anim = combatCommand->generateAnimation(CombatManager::HIT_HEAD, 50, 25);
				ASSERT_TRUE(anim.endsWith("_light_face"));
				ASSERT_TRUE(animList.contains(anim.hashCode()));

				anim = combatCommand->generateAnimation(CombatManager::HIT_HEAD, 50, 200);
				ASSERT_TRUE(anim.endsWith("_medium_face"));
				ASSERT_TRUE(animList.contains(anim.hashCode()));

				anim = combatCommand->generateAnimation(CombatManager::HIT_BODY, 50, 25);
				ASSERT_TRUE(anim.endsWith("_light"));
				ASSERT_FALSE(anim.contains("_face"));
				ASSERT_TRUE(animList.contains(anim.hashCode()));

				anim = combatCommand->generateAnimation(CombatManager::HIT_BODY, 50, 200);
				ASSERT_TRUE(anim.endsWith("_medium"));
				ASSERT_FALSE(anim.contains("_face"));
				ASSERT_TRUE(animList.contains(anim.hashCode()));
			} else if (animType == CombatQueueCommand::GENERATE_INTENSITY) {
				String anim = combatCommand->generateAnimation(CombatManager::HIT_BODY, 50, 25);
				ASSERT_TRUE(anim.endsWith("_light"));
				ASSERT_FALSE(anim.contains("_face"));
				ASSERT_TRUE(animList.contains(anim.hashCode()));

				anim = combatCommand->generateAnimation(CombatManager::HIT_BODY, 50, 200);
				ASSERT_TRUE(anim.endsWith("_medium"));
				ASSERT_FALSE(anim.contains("_face"));
				ASSERT_TRUE(animList.contains(anim.hashCode()));
			}
		}
	}
}

TEST_F(CommandLuaTest, SaberCommandsLoadPositiveActionCostMultiplier) {
	man->registerSpecialCommands(list);
	man->loadSlashCommandsFile();

	HashTableIterator<uint32, Reference<QueueCommand*> > iter = list->iterator();
	int saberCommandCount = 0;

	while (iter.hasNext()) {
		Reference<QueueCommand*> command = iter.getNextValue();
		String commandName = command->getQueueCommandName();

		if (!commandName.beginsWith("saber") || !command->isJediCombatCommand())
			continue;

		CombatQueueCommand* combatCommand = command.castTo<CombatQueueCommand*>();

		ASSERT_NE(combatCommand, nullptr);
		EXPECT_GT(combatCommand->getActionCostMultiplier(), 0.f) << commandName.toCharArray();
		++saberCommandCount;
	}

	EXPECT_GT(saberCommandCount, 0);
}

TEST_F(CommandLuaTest, SaberWeaponTreesLoadExpectedActionCostMultiplier) {
	man->registerSpecialCommands(list);
	man->loadSlashCommandsFile();

	struct ExpectedActionCost {
		const char* name;
		float cost;
	};

	const ExpectedActionCost expected[] = {
		{"saber1hcombohit1", 2.0f},
		{"saber1hcombohit2", 1.75f},
		{"saber1hcombohit3", 2.0f},
		{"saber1hflurry", 1.5f},
		{"saber1hflurry2", 2.0f},
		{"saber1hheadhit1", 1.5f},
		{"saber1hheadhit2", 1.75f},
		{"saber1hheadhit3", 2.0f},
		{"saber1hhit1", 1.5f},
		{"saber1hhit2", 2.0f},
		{"saber1hhit3", 2.25f},
		{"saber2hbodyhit1", 1.5f},
		{"saber2hbodyhit2", 2.5f},
		{"saber2hbodyhit3", 2.0f},
		{"saber2hfrenzy", 2.5f},
		{"saber2hhit1", 2.0f},
		{"saber2hhit2", 1.75f},
		{"saber2hhit3", 2.1f},
		{"saber2hphantom", 2.5f},
		{"saber2hsweep1", 1.5f},
		{"saber2hsweep2", 2.25f},
		{"saber2hsweep3", 2.5f},
		{"saberpolearmdervish", 1.5f},
		{"saberpolearmdervish2", 2.5f},
		{"saberpolearmhit1", 1.5f},
		{"saberpolearmhit2", 2.0f},
		{"saberpolearmhit3", 2.5f},
		{"saberpolearmleghit1", 1.5f},
		{"saberpolearmleghit2", 2.0f},
		{"saberpolearmleghit3", 2.5f},
		{"saberpolearmspinattack1", 2.0f},
		{"saberpolearmspinattack2", 2.0f},
		{"saberpolearmspinattack3", 2.5f},
	};

	for (const auto& entry : expected) {
		QueueCommand* command = list->getSlashCommand(String(entry.name));

		ASSERT_NE(command, nullptr) << entry.name;
		ASSERT_TRUE(command->isJediCombatCommand()) << entry.name;

		CombatQueueCommand* combatCommand = dynamic_cast<CombatQueueCommand*>(command);
		ASSERT_NE(combatCommand, nullptr) << entry.name;
		EXPECT_FLOAT_EQ(combatCommand->getActionCostMultiplier(), entry.cost) << entry.name;
	}
}

void CommandLuaTest::loadAnimList() {

	IffStream *stream = DataArchiveStore::instance()->openIffFile("combat/combat_manager.iff");

	ASSERT_TRUE(stream != nullptr);

	stream->openForm('CBTM');
	stream->openForm('0002');
	Chunk *form = nullptr;
	try {
		while((form = stream->openForm('ENTR'))) {
			String str;
			form->getChunk(0)->readString(str);
			animList.add(str.hashCode());
			stream->closeForm('ENTR');
		}
	} catch (...) {
		// end of list throws exception
	}

	stream->closeForm('0002');
	stream->closeForm('CBTM');
	delete stream;
}
