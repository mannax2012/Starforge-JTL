VillageSui = ScreenPlay:new {
	productionServer = false
}

function VillageSui:showMainPage(pPlayer)
	if (pPlayer == nil) then
		return
	end

	local curPhase = VillageJediManagerTownship:getCurrentPhase()
	local phaseID = VillageJediManagerTownship:getCurrentPhaseID()
	local nextPhaseChange = VillageJediManagerTownship:getNextPhaseChangeTime()
	local phaseTimeLeft = self:getPhaseDuration()

	local suiPrompt = " \\#pcontrast1 Current Phase: \\#pcontrast2 " .. curPhase .. " (id " .. phaseID .. ")\n" ..
					  " \\#pcontrast1 Current Server Time: \\#pcontrast2 " .. os.date("%c") .. "\n"

	if (nextPhaseChange ~= nil) then
		suiPrompt = suiPrompt .. " \\#pcontrast1 Next Phase Change: \\#pcontrast2 " .. os.date("%c", nextPhaseChange) .. "\n"
	else
		suiPrompt = suiPrompt .. " \\#pcontrast1 Next Phase Change: \\#pcontrast2 unknown\n"
	end

	suiPrompt = suiPrompt .. " \\#pcontrast1 Phase Time Left: \\#pcontrast2 " .. phaseTimeLeft
	suiPrompt = self:appendVillageStageTimers(pPlayer, suiPrompt)

	local sui = SuiListBox.new("VillageGmSui", "mainCallback")
	sui.setTitle("Starforge Village Time")
	sui.setPrompt(suiPrompt)

	sui.sendTo(pPlayer)
end

function VillageSui:appendVillageStageTimers(pPlayer, suiPrompt)
	if (FsIntro ~= nil and FsIntro:isOnIntro(pPlayer)) then
		local curStep = FsIntro:getCurrentStep(pPlayer)

		suiPrompt = suiPrompt .. "\n \\#pcontrast1 Village Progression: \\#pcontrast2 Intro"

		if (curStep == FsIntro.OLDMANWAIT) then
			suiPrompt = suiPrompt .. "\n \\#pcontrast1 Old Man Intro: \\#pcontrast2 " .. self:getDelayTimerString(readScreenPlayData(pPlayer, "VillageJediProgression", "FsIntroDelay"))
			suiPrompt = suiPrompt .. "\n \\#pcontrast1 Sith Attack: \\#pcontrast2 Locked until Old Man intro completes"
		elseif (curStep == FsIntro.OLDMANMEET) then
			suiPrompt = suiPrompt .. "\n \\#pcontrast1 Old Man Intro: \\#pcontrast2 Active"
			suiPrompt = suiPrompt .. "\n \\#pcontrast1 Sith Attack: \\#pcontrast2 Locked until Old Man intro completes"
		elseif (curStep == FsIntro.SITHWAIT) then
			suiPrompt = suiPrompt .. "\n \\#pcontrast1 Old Man Intro: \\#pcontrast2 Completed"
			suiPrompt = suiPrompt .. "\n \\#pcontrast1 Sith Attack: \\#pcontrast2 " .. self:getDelayTimerString(readScreenPlayData(pPlayer, "VillageJediProgression", "FsIntroDelay"))
		elseif (curStep == FsIntro.SITHATTACK) then
			suiPrompt = suiPrompt .. "\n \\#pcontrast1 Old Man Intro: \\#pcontrast2 Completed"
			suiPrompt = suiPrompt .. "\n \\#pcontrast1 Sith Attack: \\#pcontrast2 Active"
		else
			suiPrompt = suiPrompt .. "\n \\#pcontrast1 Old Man Intro: \\#pcontrast2 Completed"
			suiPrompt = suiPrompt .. "\n \\#pcontrast1 Sith Attack: \\#pcontrast2 Completed"
		end
	elseif (FsOutro ~= nil and FsOutro:isOnOutro(pPlayer)) then
		local curStep = FsOutro:getCurrentStep(pPlayer)

		suiPrompt = suiPrompt .. "\n \\#pcontrast1 Village Progression: \\#pcontrast2 Outro"

		if (curStep == FsOutro.OLDMANWAIT) then
			suiPrompt = suiPrompt .. "\n \\#pcontrast1 Old Man Outro: \\#pcontrast2 " .. self:getDelayTimerString(readScreenPlayData(pPlayer, "VillageJediProgression", "FsOutroDelay"))
		elseif (curStep == FsOutro.OLDMANMEET) then
			suiPrompt = suiPrompt .. "\n \\#pcontrast1 Old Man Outro: \\#pcontrast2 Active"
		else
			suiPrompt = suiPrompt .. "\n \\#pcontrast1 Old Man Outro: \\#pcontrast2 Completed"
		end
	end

	return suiPrompt
end

function VillageSui:getDelayTimerString(delayTimestamp)
	if (delayTimestamp == nil or delayTimestamp == "") then
		return "unknown"
	end

	local delayValue = tonumber(delayTimestamp)

	if (delayValue == nil) then
		return "unknown"
	end

	local timeLeft = delayValue - os.time()

	if (timeLeft <= 0) then
		return "Soon"
	end

	return self:getTimeString(timeLeft * 1000)
end

function VillageSui:getPhaseDuration()
	local nextPhaseChange = VillageJediManagerTownship:getNextPhaseChangeTime()

	if (nextPhaseChange == nil) then
		return "unknown"
	end

	local timeLeft = nextPhaseChange - os.time()

	if (timeLeft < 0) then
		timeLeft = 0
	end

	return self:getTimeString(timeLeft * 1000)
end

function VillageSui:getTimeString(miliTime)
	if (miliTime == nil) then
		return "unknown"
	end

	if (miliTime < 0) then
		miliTime = 0
	end

	local timeLeft = math.floor(miliTime / 1000)
	local daysLeft = math.floor(timeLeft / (24 * 60 * 60))
	local hoursLeft = math.floor((timeLeft / 3600) % 24)
	local minutesLeft = math.floor((timeLeft / 60) % 60)
	local secondsLeft = math.floor(timeLeft % 60)

	return daysLeft .. "d " .. hoursLeft .. "h " .. minutesLeft .. "m " .. secondsLeft .. "s"
end
