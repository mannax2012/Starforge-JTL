/*
 * EntertainingData.h
 *
 *  Created on: 20/09/2010
 *      Author: victor
 */

#ifndef ENTERTAININGDATA_H_
#define ENTERTAININGDATA_H_

#include "engine/engine.h"

class EntertainingData : public Serializable {
	int duration;
	int strength;
	int timeStarted;
	int lastMessageTime;
	int lastMessageBucket;
public:
	EntertainingData() {
		duration = 0;
		strength = 0;
		timeStarted = time(0);
		lastMessageTime = 0;
		lastMessageBucket = 0;
		addSerializableVariables();
	}

	EntertainingData(const EntertainingData& d) : Object(), Serializable() {
		duration = d.duration;
		strength = d.strength;
		timeStarted = d.timeStarted;
		lastMessageTime = d.lastMessageTime;
		lastMessageBucket = d.lastMessageBucket;

		addSerializableVariables();
	}

	EntertainingData& operator=(const EntertainingData& d) {
		if (this == &d)
			return *this;

		duration = d.duration;
		strength = d.strength;
		timeStarted = d.timeStarted;
		lastMessageTime = d.lastMessageTime;
		lastMessageBucket = d.lastMessageBucket;

		return *this;
	}

	inline void addSerializableVariables() {
		addSerializableVariable("duration", &duration);
		addSerializableVariable("strength", &strength);
		addSerializableVariable("lastMessageTime", &lastMessageTime);
		addSerializableVariable("lastMessageBucket", &lastMessageBucket);
	}

	inline int getDuration() {
		return duration;
	}

	inline int getStrength() {
		return strength;
	}
	inline int getTimeStarted() {
		return timeStarted;
	}
	inline void setStrength(int str) {
		strength = str;
	}

	inline void incrementStrength(int incr) {
		strength += incr;
	}

	inline void setDuration(int dur) {
		duration = dur;
	}

	inline void incrementDuration(int incr) {
		duration += incr;
	}

	inline int getLastMessageTime() {
		return lastMessageTime;
	}

	inline void setLastMessageTime(int val) {
		lastMessageTime = val;
	}

	inline int getLastMessageBucket() {
		return lastMessageBucket;
	}

	inline void setLastMessageBucket(int val) {
		lastMessageBucket = val;
	}
};

#endif /* ENTERTAININGDATA_H_ */
