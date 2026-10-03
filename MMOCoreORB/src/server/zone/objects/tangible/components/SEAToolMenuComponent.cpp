/*
 * SEAToolMenuComponent.cpp
 */

#include "SEAToolMenuComponent.h"

#include "server/zone/ZoneServer.h"
#include "server/zone/managers/radial/RadialOptions.h"
#include "server/zone/managers/stringid/StringIdManager.h"
#include "server/zone/objects/creature/CreatureObject.h"
#include "server/zone/objects/player/PlayerObject.h"
#include "server/zone/objects/player/sui/SuiCallback.h"
#include "server/zone/objects/player/sui/listbox/SuiListBox.h"
#include "server/zone/objects/player/sui/messagebox/SuiMessageBox.h"
#include "server/zone/objects/tangible/attachment/Attachment.h"
#include "server/zone/objects/tangible/wearables/WearableObject.h"
#include "server/zone/packets/object/ObjectMenuResponse.h"

namespace {
enum SEAToolMenuPhase {
	MAIN_MENU,
	COMBINE_FIRST_MENU,
	COMBINE_SECOND_MENU,
	COMBINE_CONFIRM,
	SPLIT_ATTACHMENT_MENU,
	REMOVE_ITEM_MENU,
	REMOVE_ATTACHMENT_MENU
};

const char* const tailorSkills[] = {
	"crafting_tailor_novice",
	"crafting_tailor_casual_01", "crafting_tailor_casual_02", "crafting_tailor_casual_03", "crafting_tailor_casual_04",
	"crafting_tailor_field_01", "crafting_tailor_field_02", "crafting_tailor_field_03", "crafting_tailor_field_04",
	"crafting_tailor_formal_01", "crafting_tailor_formal_02", "crafting_tailor_formal_03", "crafting_tailor_formal_04",
	"crafting_tailor_production_01", "crafting_tailor_production_02", "crafting_tailor_production_03", "crafting_tailor_production_04",
	"crafting_tailor_master"
};

const char* const armorsmithSkills[] = {
	"crafting_armorsmith_novice",
	"crafting_armorsmith_personal_01", "crafting_armorsmith_personal_02", "crafting_armorsmith_personal_03", "crafting_armorsmith_personal_04",
	"crafting_armorsmith_heavy_01", "crafting_armorsmith_heavy_02", "crafting_armorsmith_heavy_03", "crafting_armorsmith_heavy_04",
	"crafting_armorsmith_deflectors_01", "crafting_armorsmith_deflectors_02", "crafting_armorsmith_deflectors_03", "crafting_armorsmith_deflectors_04",
	"crafting_armorsmith_complexity_01", "crafting_armorsmith_complexity_02", "crafting_armorsmith_complexity_03", "crafting_armorsmith_complexity_04",
	"crafting_armorsmith_master"
};

int countProfessionBoxes(CreatureObject* player, const char* const* skills, int skillCount) {
	int boxes = 0;

	for (int i = 0; i < skillCount; ++i) {
		if (player->hasSkill(skills[i]))
			boxes++;
	}

	return boxes;
}

int getTailorBoxes(CreatureObject* player) {
	return countProfessionBoxes(player, tailorSkills, sizeof(tailorSkills) / sizeof(tailorSkills[0]));
}

int getArmorsmithBoxes(CreatureObject* player) {
	return countProfessionBoxes(player, armorsmithSkills, sizeof(armorsmithSkills) / sizeof(armorsmithSkills[0]));
}

int getRemovalChance(int attachmentIndex, int professionBoxes) {
	if (attachmentIndex < 0 || attachmentIndex >= 4)
		return 0;

	const int baseChance = 25;
	int clampedBoxes = Math::max(0, Math::min(18, professionBoxes));

	// Scale linearly toward 100%, rounded to the nearest whole percent.
	return baseChance + (((100 - baseChance) * clampedBoxes) + 9) / 18;
}

bool hasInventorySpaceForResult(SceneObject* inventory, int outputCount, int consumedCount) {
	if (inventory == nullptr || outputCount < 0 || consumedCount < 0)
		return false;

	int finalObjectCount = inventory->getCountableObjectsRecursive() - consumedCount + outputCount;
	return finalObjectCount <= static_cast<int>(inventory->getContainerVolumeLimit());
}

bool validateTool(ZoneServer* server, CreatureObject* player, uint64 toolID) {
	if (server == nullptr || player == nullptr)
		return false;

	ManagedReference<SceneObject*> tool = server->getObject(toolID);
	return tool != nullptr && tool->isTangibleObject() && tool->isASubChildOf(player);
}

void showMainMenu(CreatureObject* player, uint64 toolID);
void showRemoveItemMenu(CreatureObject* player, uint64 toolID);
void showAttachmentMenu(CreatureObject* player, uint64 toolID, uint64 wearableID);
void attemptAttachmentRemoval(CreatureObject* player, uint64 toolID, uint64 wearableID, int attachmentIndex);
void showCombineFirstMenu(CreatureObject* player, uint64 toolID);
void showCombineSecondMenu(CreatureObject* player, uint64 toolID, uint64 firstAttachmentID);
void showCombineConfirmation(CreatureObject* player, uint64 toolID, uint64 firstAttachmentID, uint64 secondAttachmentID);
void combineAttachments(CreatureObject* player, uint64 toolID, uint64 firstAttachmentID, uint64 secondAttachmentID);
void showSplitMenu(CreatureObject* player, uint64 toolID);
void attemptSplitAttachment(CreatureObject* player, uint64 toolID, uint64 attachmentID);

class SEAToolSuiCallback : public SuiCallback {
private:
	int phase;
	uint64 toolID;
	uint64 primaryObjectID;
	uint64 secondaryObjectID;

public:
	SEAToolSuiCallback(ZoneServer* server, int menuPhase, uint64 toolObjectID, uint64 selectedPrimaryObjectID = 0, uint64 selectedSecondaryObjectID = 0)
		: SuiCallback(server), phase(menuPhase), toolID(toolObjectID), primaryObjectID(selectedPrimaryObjectID), secondaryObjectID(selectedSecondaryObjectID) {
	}

	void run(CreatureObject* player, SuiBox* suiBox, uint32 eventIndex, Vector<UnicodeString>* args) override {
		if (player == nullptr || suiBox == nullptr || eventIndex == 1)
			return;

		if (!validateTool(server, player, toolID)) {
			player->sendSystemMessage("The SEA tool must remain in your inventory.");
			return;
		}

		if (phase == COMBINE_CONFIRM) {
			if (suiBox->isMessageBox())
				combineAttachments(player, toolID, primaryObjectID, secondaryObjectID);

			return;
		}

		if (!suiBox->isListBox() || args == nullptr || args->size() == 0)
			return;

		SuiListBox* listBox = cast<SuiListBox*>(suiBox);
		int index = Integer::valueOf(args->get(0).toString());

		if (index < 0 || index >= listBox->getMenuSize())
			return;

		if (phase == MAIN_MENU) {
			if (index == 0)
				showCombineFirstMenu(player, toolID);
			else if (index == 1)
				showSplitMenu(player, toolID);
			else if (index == 2)
				showRemoveItemMenu(player, toolID);
			else
				player->sendSystemMessage("That SEA operation is not available yet.");
		} else if (phase == COMBINE_FIRST_MENU) {
			showCombineSecondMenu(player, toolID, listBox->getMenuObjectID(index));
		} else if (phase == COMBINE_SECOND_MENU) {
			showCombineConfirmation(player, toolID, primaryObjectID, listBox->getMenuObjectID(index));
		} else if (phase == SPLIT_ATTACHMENT_MENU) {
			attemptSplitAttachment(player, toolID, listBox->getMenuObjectID(index));
		} else if (phase == REMOVE_ITEM_MENU) {
			showAttachmentMenu(player, toolID, listBox->getMenuObjectID(index));
		} else if (phase == REMOVE_ATTACHMENT_MENU) {
			attemptAttachmentRemoval(player, toolID, primaryObjectID, index);
		}
	}
};

void showMainMenu(CreatureObject* player, uint64 toolID) {
	if (player == nullptr)
		return;

	ZoneServer* zoneServer = player->getZoneServer();
	ManagedReference<PlayerObject*> ghost = player->getPlayerObject();
	ManagedReference<SceneObject*> tool = zoneServer == nullptr ? nullptr : zoneServer->getObject(toolID);

	if (zoneServer == nullptr || ghost == nullptr || tool == nullptr || !validateTool(zoneServer, player, toolID))
		return;

	ManagedReference<SuiListBox*> menu = new SuiListBox(player, SuiWindowType::NONE, SuiListBox::HANDLETWOBUTTON);
	menu->setUsingObject(tool);
	menu->setPromptTitle("Special Enhancement Attachment Tool");
	menu->setPromptText("Select an attachment operation.");
	menu->addMenuItem("Combine Attachment");
	menu->addMenuItem("Split Attachment");
	menu->addMenuItem("Remove Attachment");
	menu->setCancelButton(true, "@cancel");
	menu->setOkButton(true, "@ok");
	menu->setCallback(new SEAToolSuiCallback(zoneServer, MAIN_MENU, toolID));

	ghost->addSuiBox(menu);
	player->sendMessage(menu->generateMessage());
}

bool isCombinableAttachment(Attachment* attachment) {
	if (attachment == nullptr)
		return false;

	VectorMap<String, int>* skillMods = attachment->getSkillMods();

	if (skillMods == nullptr || skillMods->size() == 0)
		return false;

	for (int i = 0; i < skillMods->size(); ++i) {
		int value = skillMods->elementAt(i).getValue();

		if (value <= 0 || value >= 25)
			return false;
	}

	return true;
}

bool areCompatibleAttachments(Attachment* first, Attachment* second) {
	if (!isCombinableAttachment(first) || !isCombinableAttachment(second) || first == second)
		return false;

	if (first->isArmorAttachment() != second->isArmorAttachment() || first->isClothingAttachment() != second->isClothingAttachment())
		return false;

	VectorMap<String, int>* firstMods = first->getSkillMods();
	VectorMap<String, int>* secondMods = second->getSkillMods();

	if (firstMods->size() != secondMods->size())
		return false;

	for (int i = 0; i < firstMods->size(); ++i) {
		if (!secondMods->contains(firstMods->elementAt(i).getKey()))
			return false;
	}

	return true;
}

String getSkillModDisplayName(const String& modName) {
	StringId statName("stat_n", modName);
	String localizedName = StringIdManager::instance()->getStringId(statName).toString();

	return localizedName.isEmpty() ? modName : localizedName;
}

String getAttachmentLabel(Attachment* attachment) {
	StringBuffer label;
	label << (attachment->isArmorAttachment() ? "[Armor] " : "[Clothing] ");

	VectorMap<String, int>* skillMods = attachment->getSkillMods();

	for (int i = 0; i < skillMods->size(); ++i) {
		if (i > 0)
			label << ", ";

		label << getSkillModDisplayName(skillMods->elementAt(i).getKey()) << " +" << skillMods->elementAt(i).getValue();
	}

	return label.toString();
}

void refreshAttachmentIdentity(Attachment* attachment) {
	if (attachment == nullptr)
		return;

	VectorMap<String, int>* skillMods = attachment->getSkillMods();

	if (skillMods == nullptr || skillMods->size() == 0)
		return;

	String highestModName;
	int highestModValue = 0;

	for (int i = 0; i < skillMods->size(); ++i) {
		const auto& mod = skillMods->elementAt(i);

		if (mod.getValue() > highestModValue) {
			highestModName = mod.getKey();
			highestModValue = mod.getValue();
		}
	}

	if (highestModName.isEmpty())
		return;

	StringId attachmentName("stat_n", highestModName);

	// getDisplayedName() prefers the current custom name. Clear it first so repeated
	// normalization always rebuilds from the localized stat name instead of appending
	// another attachment prefix and value.
	attachment->setCustomObjectName("", false);
	attachment->setObjectName(attachmentName, false);

	StringBuffer customName;
	customName << (attachment->isArmorAttachment() ? "[AA] " : "[CA] ")
		<< attachment->getDisplayedName() << " " << highestModValue;
	attachment->setCustomObjectName(customName.toString(), false);
	attachment->_setUpdated(true);
}

void addCombineCandidates(SceneObject* container, SuiListBox* menu, Attachment* requiredMatch, int& itemCount) {
	if (container == nullptr || menu == nullptr)
		return;

	for (int i = 0; i < container->getContainerObjectsSize(); ++i) {
		SceneObject* object = container->getContainerObject(i);

		if (object == nullptr)
			continue;

		if (object->isAttachment()) {
			Attachment* attachment = cast<Attachment*>(object);
			bool eligible = requiredMatch == nullptr ? isCombinableAttachment(attachment) : areCompatibleAttachments(requiredMatch, attachment);

			if (eligible) {
				menu->addMenuItem(getAttachmentLabel(attachment), attachment->getObjectID());
				itemCount++;
			}
		}

		if (object->isContainerObject())
			addCombineCandidates(object, menu, requiredMatch, itemCount);
	}
}

void showCombineFirstMenu(CreatureObject* player, uint64 toolID) {
	ZoneServer* zoneServer = player->getZoneServer();
	ManagedReference<PlayerObject*> ghost = player->getPlayerObject();
	ManagedReference<SceneObject*> inventory = player->getSlottedObject("inventory");

	if (zoneServer == nullptr || ghost == nullptr || inventory == nullptr)
		return;

	ManagedReference<SuiListBox*> menu = new SuiListBox(player, SuiWindowType::NONE, SuiListBox::HANDLETWOBUTTON);
	menu->setPromptTitle("Combine SEA - Select First");
	menu->setPromptText("Select the first SEA. Only attachments with all modifiers below +25 are shown.");
	menu->setCancelButton(true, "@cancel");
	menu->setOkButton(true, "@ok");

	int itemCount = 0;
	addCombineCandidates(inventory, menu, nullptr, itemCount);

	if (itemCount == 0) {
		player->sendSystemMessage("No SEAs below +25 were found in your inventory.");
		showMainMenu(player, toolID);
		return;
	}

	menu->setCallback(new SEAToolSuiCallback(zoneServer, COMBINE_FIRST_MENU, toolID));
	ghost->addSuiBox(menu);
	player->sendMessage(menu->generateMessage());
}

void showCombineSecondMenu(CreatureObject* player, uint64 toolID, uint64 firstAttachmentID) {
	ZoneServer* zoneServer = player->getZoneServer();
	ManagedReference<PlayerObject*> ghost = player->getPlayerObject();
	ManagedReference<SceneObject*> inventory = player->getSlottedObject("inventory");
	ManagedReference<Attachment*> first = zoneServer == nullptr ? nullptr : zoneServer->getObject(firstAttachmentID).castTo<Attachment*>();

	if (zoneServer == nullptr || ghost == nullptr || inventory == nullptr || first == nullptr || !first->isASubChildOf(inventory) || !isCombinableAttachment(first)) {
		player->sendSystemMessage("The selected SEA is no longer available or cannot be combined.");
		return;
	}

	ManagedReference<SuiListBox*> menu = new SuiListBox(player, SuiWindowType::NONE, SuiListBox::HANDLETWOBUTTON);
	StringBuffer prompt;
	prompt << "First SEA: " << getAttachmentLabel(first) << "\nSelect a matching SEA below +25.";
	menu->setPromptTitle("Combine SEA - Select Second");
	menu->setPromptText(prompt.toString());
	menu->setCancelButton(true, "@cancel");
	menu->setOkButton(true, "@ok");

	int itemCount = 0;
	addCombineCandidates(inventory, menu, first, itemCount);

	if (itemCount == 0) {
		player->sendSystemMessage("No matching SEA below +25 was found in your inventory.");
		showMainMenu(player, toolID);
		return;
	}

	menu->setCallback(new SEAToolSuiCallback(zoneServer, COMBINE_SECOND_MENU, toolID, firstAttachmentID));
	ghost->addSuiBox(menu);
	player->sendMessage(menu->generateMessage());
}

void showCombineConfirmation(CreatureObject* player, uint64 toolID, uint64 firstAttachmentID, uint64 secondAttachmentID) {
	ZoneServer* zoneServer = player->getZoneServer();
	ManagedReference<PlayerObject*> ghost = player->getPlayerObject();
	ManagedReference<SceneObject*> inventory = player->getSlottedObject("inventory");
	ManagedReference<Attachment*> first = zoneServer == nullptr ? nullptr : zoneServer->getObject(firstAttachmentID).castTo<Attachment*>();
	ManagedReference<Attachment*> second = zoneServer == nullptr ? nullptr : zoneServer->getObject(secondAttachmentID).castTo<Attachment*>();

	if (zoneServer == nullptr || ghost == nullptr || inventory == nullptr || first == nullptr || second == nullptr ||
		!first->isASubChildOf(inventory) || !second->isASubChildOf(inventory) || !areCompatibleAttachments(first, second)) {
		player->sendSystemMessage("Those SEAs are no longer available or compatible.");
		return;
	}

	StringBuffer preview;
	preview << "The following two SEAs will be consumed:\n" << getAttachmentLabel(first) << "\n" << getAttachmentLabel(second) << "\n\nResult:\n";
	VectorMap<String, int>* firstMods = first->getSkillMods();
	VectorMap<String, int>* secondMods = second->getSkillMods();
	int totalExcess = 0;

	for (int i = 0; i < firstMods->size(); ++i) {
		String modName = firstMods->elementAt(i).getKey();
		int firstValue = firstMods->elementAt(i).getValue();
		int secondValue = secondMods->get(modName);
		int combinedValue = Math::min(25, firstValue + secondValue);
		int excess = Math::max(0, firstValue + secondValue - 25);
		preview << getSkillModDisplayName(modName) << ": +" << firstValue << " + +" << secondValue << " = +" << combinedValue;

		if (excess > 0)
			preview << " (" << excess << " discarded)";

		preview << "\n";
		totalExcess += excess;
	}

	if (totalExcess > 0)
		preview << "\nTotal excess discarded: " << totalExcess << ".";

	ManagedReference<SuiMessageBox*> confirmation = new SuiMessageBox(player, SuiWindowType::NONE);
	confirmation->setPromptTitle("Confirm SEA Combination");
	confirmation->setPromptText(preview.toString());
	confirmation->setCancelButton(true, "@cancel");
	confirmation->setOkButton(true, "@ok");
	confirmation->setCallback(new SEAToolSuiCallback(zoneServer, COMBINE_CONFIRM, toolID, firstAttachmentID, secondAttachmentID));
	ghost->addSuiBox(confirmation);
	player->sendMessage(confirmation->generateMessage());
}

void combineAttachments(CreatureObject* player, uint64 toolID, uint64 firstAttachmentID, uint64 secondAttachmentID) {
	ZoneServer* zoneServer = player->getZoneServer();
	ManagedReference<SceneObject*> inventory = player->getSlottedObject("inventory");
	ManagedReference<Attachment*> first = zoneServer == nullptr ? nullptr : zoneServer->getObject(firstAttachmentID).castTo<Attachment*>();
	ManagedReference<Attachment*> second = zoneServer == nullptr ? nullptr : zoneServer->getObject(secondAttachmentID).castTo<Attachment*>();

	if (zoneServer == nullptr || inventory == nullptr || first == nullptr || second == nullptr ||
		!first->isASubChildOf(inventory) || !second->isASubChildOf(inventory) || !areCompatibleAttachments(first, second)) {
		player->sendSystemMessage("The SEA combination was cancelled because the inputs changed.");
		return;
	}

	ManagedReference<Attachment*> firstLockObject = first->getObjectID() < second->getObjectID() ? first : second;
	ManagedReference<Attachment*> secondLockObject = firstLockObject == first ? second : first;
	Locker firstLocker(firstLockObject, player);
	Locker secondLocker(secondLockObject, firstLockObject);

	if (!first->isASubChildOf(inventory) || !second->isASubChildOf(inventory) || !areCompatibleAttachments(first, second)) {
		player->sendSystemMessage("The SEA combination was cancelled because the inputs changed.");
		return;
	}

	VectorMap<String, int>* firstMods = first->getSkillMods();
	VectorMap<String, int>* secondMods = second->getSkillMods();

	if (!hasInventorySpaceForResult(inventory, 1, 2)) {
		player->sendSystemMessage("There is not enough inventory space to create the combined SEA. Nothing was consumed.");
		return;
	}

	String attachmentTemplate = first->isArmorAttachment() ? "object/tangible/gem/armor.iff" : "object/tangible/gem/clothing.iff";
	ManagedReference<Attachment*> combinedAttachment = zoneServer->createObject(attachmentTemplate.hashCode(), 1).castTo<Attachment*>();

	if (combinedAttachment == nullptr) {
		player->sendSystemMessage("The combined SEA could not be created. Nothing was consumed.");
		return;
	}

	VectorMap<String, int>* combinedMods = combinedAttachment->getSkillMods();

	for (int i = 0; i < firstMods->size(); ++i) {
		String modName = firstMods->elementAt(i).getKey();
		combinedMods->put(modName, Math::min(25, firstMods->get(modName) + secondMods->get(modName)));
	}

	refreshAttachmentIdentity(combinedAttachment);

	if (!inventory->transferObject(combinedAttachment, -1, true, true)) {
		combinedAttachment->destroyObjectFromDatabase(true);
		player->sendSystemMessage("The combined SEA could not be placed in your inventory. Nothing was consumed.");
		return;
	}

	inventory->broadcastObject(combinedAttachment, true);
	first->destroyObjectFromWorld(true);
	first->destroyObjectFromDatabase(true);
	second->destroyObjectFromWorld(true);
	second->destroyObjectFromDatabase(true);

	StringBuffer result;
	result << "SEA combination complete: " << getAttachmentLabel(combinedAttachment) << ".";
	player->sendSystemMessage(result.toString());

	secondLocker.release();
	firstLocker.release();
	showCombineFirstMenu(player, toolID);
}

bool isSplittableAttachment(Attachment* attachment) {
	if (attachment == nullptr || (!attachment->isArmorAttachment() && !attachment->isClothingAttachment()))
		return false;

	VectorMap<String, int>* skillMods = attachment->getSkillMods();
	return skillMods != nullptr && skillMods->size() > 1;
}

void addSplitCandidates(SceneObject* container, CreatureObject* player, SuiListBox* menu, int& itemCount) {
	if (container == nullptr || player == nullptr || menu == nullptr)
		return;

	for (int i = 0; i < container->getContainerObjectsSize(); ++i) {
		SceneObject* object = container->getContainerObject(i);

		if (object == nullptr)
			continue;

		if (object->isAttachment()) {
			Attachment* attachment = cast<Attachment*>(object);

			if (isSplittableAttachment(attachment)) {
				int professionBoxes = attachment->isArmorAttachment() ? getArmorsmithBoxes(player) : getTailorBoxes(player);
				StringBuffer label;
				label << getAttachmentLabel(attachment) << " - " << getRemovalChance(0, professionBoxes) << " percent success";
				menu->addMenuItem(label.toString(), attachment->getObjectID());
				itemCount++;
			}
		}

		if (object->isContainerObject())
			addSplitCandidates(object, player, menu, itemCount);
	}
}

void showSplitMenu(CreatureObject* player, uint64 toolID) {
	ZoneServer* zoneServer = player->getZoneServer();
	ManagedReference<PlayerObject*> ghost = player->getPlayerObject();
	ManagedReference<SceneObject*> inventory = player->getSlottedObject("inventory");

	if (zoneServer == nullptr || ghost == nullptr || inventory == nullptr)
		return;

	int tailorBoxes = getTailorBoxes(player);
	int armorsmithBoxes = getArmorsmithBoxes(player);
	ManagedReference<SuiListBox*> menu = new SuiListBox(player, SuiWindowType::NONE, SuiListBox::HANDLETWOBUTTON);
	StringBuffer prompt;
	prompt << "Select a multi-stat SEA to split. Failure destroys the original SEA.\n"
		<< "Tailor: " << tailorBoxes << "/18   Armorsmith: " << armorsmithBoxes << "/18";
	menu->setPromptTitle("Split SEA - Select Attachment");
	menu->setPromptText(prompt.toString());
	menu->setCancelButton(true, "@cancel");
	menu->setOkButton(true, "@ok");

	int itemCount = 0;
	addSplitCandidates(inventory, player, menu, itemCount);

	if (itemCount == 0) {
		player->sendSystemMessage("No multi-stat SEAs were found in your inventory.");
		showMainMenu(player, toolID);
		return;
	}

	menu->setCallback(new SEAToolSuiCallback(zoneServer, SPLIT_ATTACHMENT_MENU, toolID));
	ghost->addSuiBox(menu);
	player->sendMessage(menu->generateMessage());
}

void destroySplitOutputs(Vector<ManagedReference<Attachment*>>& outputs) {
	for (int i = 0; i < outputs.size(); ++i) {
		ManagedReference<Attachment*> output = outputs.get(i);

		if (output == nullptr)
			continue;

		if (output->getParent() != nullptr)
			output->destroyObjectFromWorld(true);

		output->destroyObjectFromDatabase(true);
	}
}

void attemptSplitAttachment(CreatureObject* player, uint64 toolID, uint64 attachmentID) {
	ZoneServer* zoneServer = player->getZoneServer();
	ManagedReference<SceneObject*> inventory = player->getSlottedObject("inventory");
	ManagedReference<Attachment*> source = zoneServer == nullptr ? nullptr : zoneServer->getObject(attachmentID).castTo<Attachment*>();

	if (zoneServer == nullptr || inventory == nullptr || source == nullptr || !source->isASubChildOf(inventory) || !isSplittableAttachment(source)) {
		player->sendSystemMessage("That SEA is no longer available or cannot be split.");
		return;
	}

	Locker sourceLocker(source, player);

	if (!source->isASubChildOf(inventory) || !isSplittableAttachment(source)) {
		player->sendSystemMessage("That SEA changed before the split could begin.");
		return;
	}

	VectorMap<String, int>* sourceMods = source->getSkillMods();

	if (!hasInventorySpaceForResult(inventory, sourceMods->size(), 1)) {
		StringBuffer noRoom;
		noRoom << "Splitting this SEA requires " << (sourceMods->size() - 1)
			<< " additional inventory slot" << (sourceMods->size() == 2 ? "." : "s.") << " Nothing was consumed.";
		player->sendSystemMessage(noRoom.toString());
		return;
	}

	bool armorAttachment = source->isArmorAttachment();
	int professionBoxes = armorAttachment ? getArmorsmithBoxes(player) : getTailorBoxes(player);
	int successChance = getRemovalChance(0, professionBoxes);
	bool success = System::random(99) < successChance;
	String sourceLabel = getAttachmentLabel(source);

	if (!success) {
		source->destroyObjectFromWorld(true);
		source->destroyObjectFromDatabase(true);
		StringBuffer failure;
		failure << "Split failed at " << successChance << " percent success chance. " << sourceLabel << " was destroyed.";
		player->sendSystemMessage(failure.toString());
		sourceLocker.release();
		showSplitMenu(player, toolID);
		return;
	}

	String attachmentTemplate = armorAttachment ? "object/tangible/gem/armor.iff" : "object/tangible/gem/clothing.iff";
	Vector<ManagedReference<Attachment*>> outputs;

	for (int i = 0; i < sourceMods->size(); ++i) {
		ManagedReference<Attachment*> output = zoneServer->createObject(attachmentTemplate.hashCode(), 1).castTo<Attachment*>();

		if (output == nullptr) {
			destroySplitOutputs(outputs);
			player->sendSystemMessage("The split outputs could not be created. The original SEA was not consumed.");
			return;
		}

		const auto& mod = sourceMods->elementAt(i);
		output->getSkillMods()->put(mod.getKey(), mod.getValue());
		refreshAttachmentIdentity(output);
		outputs.add(output);
	}

	for (int i = 0; i < outputs.size(); ++i) {
		if (!inventory->transferObject(outputs.get(i), -1, true, true)) {
			destroySplitOutputs(outputs);
			player->sendSystemMessage("The split outputs could not be placed in your inventory. The original SEA was not consumed.");
			return;
		}
	}

	for (int i = 0; i < outputs.size(); ++i)
		inventory->broadcastObject(outputs.get(i), true);

	source->destroyObjectFromWorld(true);
	source->destroyObjectFromDatabase(true);

	StringBuffer result;
	result << "Split succeeded at " << successChance << " percent chance. Created " << outputs.size()
		<< " single-stat " << (armorAttachment ? "armor" : "clothing") << " SEAs.";
	player->sendSystemMessage(result.toString());
	sourceLocker.release();
	showSplitMenu(player, toolID);
}

void addEligibleWearables(SceneObject* container, SuiListBox* menu, int& itemCount) {
	if (container == nullptr || menu == nullptr)
		return;

	for (int i = 0; i < container->getContainerObjectsSize(); ++i) {
		SceneObject* object = container->getContainerObject(i);

		if (object == nullptr)
			continue;

		if (object->isWearableObject()) {
			WearableObject* wearable = cast<WearableObject*>(object);

			if (wearable != nullptr && wearable->getAttachedSEAcount() > 0) {
				StringBuffer label;
				label << (wearable->isArmorObject() ? "[Armor] " : "[Clothing] ")
					<< wearable->getDisplayedName() << " (" << wearable->getAttachedSEAcount() << " SEA)";
				menu->addMenuItem(label.toString(), wearable->getObjectID());
				itemCount++;
			}
		}

		if (object->isContainerObject())
			addEligibleWearables(object, menu, itemCount);
	}
}

void showRemoveItemMenu(CreatureObject* player, uint64 toolID) {
	ZoneServer* zoneServer = player->getZoneServer();
	ManagedReference<PlayerObject*> ghost = player->getPlayerObject();
	ManagedReference<SceneObject*> inventory = player->getSlottedObject("inventory");

	if (zoneServer == nullptr || ghost == nullptr || inventory == nullptr)
		return;

	int tailorBoxes = getTailorBoxes(player);
	int armorsmithBoxes = getArmorsmithBoxes(player);
	ManagedReference<SuiListBox*> menu = new SuiListBox(player, SuiWindowType::NONE, SuiListBox::HANDLETWOBUTTON);

	StringBuffer prompt;
	prompt << "Select armor or clothing containing an SEA.\n"
		<< "Tailor: " << tailorBoxes << "/18 (" << ((tailorBoxes * 100) / 18) << " percent)"
		<< "   Armorsmith: " << armorsmithBoxes << "/18 (" << ((armorsmithBoxes * 100) / 18) << " percent)";

	menu->setPromptTitle("Remove SEA - Select Item");
	menu->setPromptText(prompt.toString());
	menu->setCancelButton(true, "@cancel");
	menu->setOkButton(true, "@ok");

	int itemCount = 0;
	addEligibleWearables(inventory, menu, itemCount);

	if (itemCount == 0) {
		player->sendSystemMessage("No armor or clothing with an attached SEA was found in your inventory.");
		showMainMenu(player, toolID);
		return;
	}

	menu->setCallback(new SEAToolSuiCallback(zoneServer, REMOVE_ITEM_MENU, toolID));
	ghost->addSuiBox(menu);
	player->sendMessage(menu->generateMessage());
}

void showAttachmentMenu(CreatureObject* player, uint64 toolID, uint64 wearableID) {
	ZoneServer* zoneServer = player->getZoneServer();
	ManagedReference<PlayerObject*> ghost = player->getPlayerObject();
	ManagedReference<SceneObject*> inventory = player->getSlottedObject("inventory");
	ManagedReference<WearableObject*> wearable = zoneServer == nullptr ? nullptr : zoneServer->getObject(wearableID).castTo<WearableObject*>();

	if (zoneServer == nullptr || ghost == nullptr || inventory == nullptr || wearable == nullptr || !wearable->isASubChildOf(inventory)) {
		player->sendSystemMessage("That item is no longer in your inventory.");
		return;
	}

	int attachmentCount = wearable->getAttachedSEAcount();
	VectorMap<String, int>* skillMods = wearable->getWearableSkillMods();

	if (attachmentCount < 1 || skillMods == nullptr) {
		player->sendSystemMessage("That item no longer has a removable SEA.");
		showMainMenu(player, toolID);
		return;
	}

	int professionBoxes = wearable->isArmorObject() ? getArmorsmithBoxes(player) : getTailorBoxes(player);
	ManagedReference<SuiListBox*> menu = new SuiListBox(player, SuiWindowType::NONE, SuiListBox::HANDLETWOBUTTON);

	StringBuffer prompt;
	prompt << wearable->getDisplayedName() << "\n"
		<< (wearable->isArmorObject() ? "Armorsmith" : "Tailor") << " progress: "
		<< professionBoxes << "/18\n\nSelect the SEA to remove. A failed attempt destroys that SEA.";

	menu->setPromptTitle("Remove SEA - Select Attachment");
	menu->setPromptText(prompt.toString());
	menu->setCancelButton(true, "@cancel");
	menu->setOkButton(true, "@ok");

	for (int i = 0; i < attachmentCount; ++i) {
		int modIndex = wearable->getAttachedSEAModIndex(i);

		if (modIndex < 0 || modIndex >= skillMods->size())
			continue;

		const auto& mod = skillMods->elementAt(modIndex);
		StringBuffer label;
		label << getSkillModDisplayName(mod.getKey()) << " +" << mod.getValue() << " - " << getRemovalChance(i, professionBoxes) << "% success";
		menu->addMenuItem(label.toString());
	}

	if (menu->getMenuSize() == 0) {
		player->sendSystemMessage("That item has no removable SEA data.");
		showMainMenu(player, toolID);
		return;
	}

	menu->setCallback(new SEAToolSuiCallback(zoneServer, REMOVE_ATTACHMENT_MENU, toolID, wearableID));
	ghost->addSuiBox(menu);
	player->sendMessage(menu->generateMessage());
}

void attemptAttachmentRemoval(CreatureObject* player, uint64 toolID, uint64 wearableID, int attachmentIndex) {
	ZoneServer* zoneServer = player->getZoneServer();
	ManagedReference<SceneObject*> inventory = player->getSlottedObject("inventory");
	ManagedReference<WearableObject*> wearable = zoneServer == nullptr ? nullptr : zoneServer->getObject(wearableID).castTo<WearableObject*>();

	if (zoneServer == nullptr || inventory == nullptr || wearable == nullptr || !wearable->isASubChildOf(inventory)) {
		player->sendSystemMessage("That item is no longer in your inventory.");
		return;
	}

	Locker locker(wearable, player);
	int modIndex = wearable->getAttachedSEAModIndex(attachmentIndex);
	VectorMap<String, int>* skillMods = wearable->getWearableSkillMods();

	if (modIndex < 0 || skillMods == nullptr || modIndex >= skillMods->size()) {
		player->sendSystemMessage("That SEA is no longer attached to the item.");
		return;
	}

	if (!hasInventorySpaceForResult(inventory, 1, 0)) {
		player->sendSystemMessage("You need at least one free inventory slot before attempting to remove an SEA.");
		return;
	}

	String modName = skillMods->elementAt(modIndex).getKey();
	int modValue = skillMods->elementAt(modIndex).getValue();
	int professionBoxes = wearable->isArmorObject() ? getArmorsmithBoxes(player) : getTailorBoxes(player);
	int successChance = getRemovalChance(attachmentIndex, professionBoxes);
	bool success = System::random(99) < successChance;
	ManagedReference<Attachment*> recoveredAttachment;

	if (success) {
		String attachmentTemplate = wearable->isArmorObject() ? "object/tangible/gem/armor.iff" : "object/tangible/gem/clothing.iff";
		recoveredAttachment = zoneServer->createObject(attachmentTemplate.hashCode(), 1).castTo<Attachment*>();

		if (recoveredAttachment == nullptr) {
			player->sendSystemMessage("The SEA could not be created. Nothing was removed.");
			return;
		}

		recoveredAttachment->getSkillMods()->put(modName, modValue);
		refreshAttachmentIdentity(recoveredAttachment);

		if (!inventory->transferObject(recoveredAttachment, -1, true)) {
			recoveredAttachment->destroyObjectFromDatabase(true);
			player->sendSystemMessage("There is not enough room in your inventory. Nothing was removed.");
			return;
		}

		inventory->broadcastObject(recoveredAttachment, true);
	}

	if (!wearable->removeAttachedSEA(player, attachmentIndex)) {
		if (recoveredAttachment != nullptr) {
			recoveredAttachment->destroyObjectFromWorld(true);
			recoveredAttachment->destroyObjectFromDatabase(true);
		}

		player->sendSystemMessage("The SEA could not be removed.");
		return;
	}

	StringBuffer result;

	if (success)
		result << "Success! " << getSkillModDisplayName(modName) << " +" << modValue << " was removed and placed in your inventory.";
	else
		result << "Removal failed at " << successChance << "% success chance. " << getSkillModDisplayName(modName) << " +" << modValue << " was destroyed.";

	player->sendSystemMessage(result.toString());
	locker.release();
	showRemoveItemMenu(player, toolID);
}
}

void SEAToolMenuComponent::fillObjectMenuResponse(SceneObject* sceneObject, ObjectMenuResponse* menuResponse, CreatureObject* player) const {
	if (sceneObject == nullptr || menuResponse == nullptr || player == nullptr)
		return;

	if (sceneObject->isASubChildOf(player))
		menuResponse->addRadialMenuItem(RadialOptions::ITEM_USE, 3, "@ui_radial:item_use");

	TangibleObjectMenuComponent::fillObjectMenuResponse(sceneObject, menuResponse, player);
}

int SEAToolMenuComponent::handleObjectMenuSelect(SceneObject* sceneObject, CreatureObject* player, byte selectedID) const {
	if (sceneObject == nullptr || player == nullptr)
		return 0;

	if (selectedID != RadialOptions::ITEM_USE)
		return TangibleObjectMenuComponent::handleObjectMenuSelect(sceneObject, player, selectedID);

	if (!sceneObject->isTangibleObject() || !sceneObject->isASubChildOf(player))
		return 0;

	ZoneServer* zoneServer = player->getZoneServer();
	ManagedReference<PlayerObject*> ghost = player->getPlayerObject();

	if (zoneServer == nullptr || ghost == nullptr)
		return 0;

	ManagedReference<SuiListBox*> menu = new SuiListBox(player, SuiWindowType::NONE, SuiListBox::HANDLETWOBUTTON);

	menu->setUsingObject(sceneObject);
	menu->setPromptTitle("Special Enhancement Attachment Tool");
	menu->setPromptText("Select an attachment operation.");
	menu->addMenuItem("Combine Attachment");
	menu->addMenuItem("Split Attachment");
	menu->addMenuItem("Remove Attachment");
	menu->setCancelButton(true, "@cancel");
	menu->setOkButton(true, "@ok");
	menu->setCallback(new SEAToolSuiCallback(zoneServer, MAIN_MENU, sceneObject->getObjectID()));

	ghost->addSuiBox(menu);
	player->sendMessage(menu->generateMessage());

	return 0;
}
