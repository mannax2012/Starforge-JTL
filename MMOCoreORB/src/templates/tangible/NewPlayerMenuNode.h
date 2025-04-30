/*
 * NewPlayerMenuNode.h
 *
 *  Created on: Jun 6, 2010
 *      Author: crush
 */

#ifndef NEWPLAYERMENUNODE_H_
#define NEWPLAYERMENUNODE_H_

#include "engine/lua/LuaObject.h"

class NewPlayerMenuNode : public Object {
	WeakReference<NewPlayerMenuNode*> parentNode;

	String displayName;
	String templatePath;
	uint32 templateCRC;

	SortedVector<Reference<NewPlayerMenuNode*> > childNodes;

public:
	NewPlayerMenuNode(const String& name) {
		displayName = name;
		parentNode = nullptr;
		templateCRC = 0;
		childNodes.setInsertPlan(SortedVector<NewPlayerMenuNode*>::NO_DUPLICATE);
	}

	NewPlayerMenuNode(const String& name, const String& tplPath) {
		parentNode = nullptr;
		displayName = name;
		templatePath = tplPath;
		templateCRC = tplPath.hashCode();
		childNodes.setInsertPlan(SortedVector<NewPlayerMenuNode*>::NO_DUPLICATE);
	}

	int readLuaObject(LuaObject& luaObject, bool recursive) {
		int tableSize = luaObject.getTableSize();

		if (tableSize % 2 != 0)
			return 0;

		for (int i = 1; i <= tableSize; i += 2) {
			String title = luaObject.getStringAt(i);

			lua_State* L = luaObject.getLuaState();
			lua_rawgeti(L, -1, i + 1);
			LuaObject a(L);

			NewPlayerMenuNode* node = new NewPlayerMenuNode(title);
			node->setParentNode(this);

			if (a.isValidTable()) {
				node->readLuaObject(a, true);
				a.pop();
			} else {
				a.pop();
				node->setTemplatePath(luaObject.getStringAt(i + 1));
			}

			childNodes.put(node);
		}

		return 0;
	}

	int compareTo(NewPlayerMenuNode* obj) {
		return displayName.compareTo(obj->getDisplayName());
	}

	inline void setTemplatePath(const String& tplPath) {
		templatePath = tplPath;
		templateCRC = tplPath.hashCode();
	}

	inline void setParentNode(NewPlayerMenuNode* parent) {
		parentNode = parent;
	}

	inline NewPlayerMenuNode* getParentNode() {
		return parentNode.get().get();
	}

	inline const NewPlayerMenuNode* getParentNode() const {
		return parentNode.get().get();
	}

	inline bool hasParentNode() const {
		return parentNode.get() != nullptr;
	}

	inline bool hasChildNodes() const {
		return childNodes.size() > 0;
	}

	inline const String& getDisplayName() const {
		return displayName;
	}

	inline const String& getTemplatePath() const {
		return templatePath;
	}

	inline uint32 getTemplateCRC() const {
		return templateCRC;
	}

	inline int getChildNodeSize() const {
		return childNodes.size();
	}

	inline const NewPlayerMenuNode* getChildNodeAt(int index) const {
		if (childNodes.size() < index + 1 || index < 0)
			return nullptr;

		return childNodes.get(index);
	}

	inline NewPlayerMenuNode* getChildNodeAt(int index) {
		if (childNodes.size() < index + 1 || index < 0)
			return nullptr;

		return childNodes.get(index);
	}
};

#endif /* NEWPLAYERMENUNODE_H_ */
