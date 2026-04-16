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

	local sui = SuiListBox.new("VillageGmSui", "mainCallback")
	sui.setTitle("Starforge Village Time")
	sui.setPrompt(suiPrompt)

	sui.sendTo(pPlayer)
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