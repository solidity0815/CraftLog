-- create local variables

-- setup frame to register events and for output
local f = CreateFrame("Frame", "CraftLogFrame", UIParent, "BasicFrameTemplateWithInset")

-- temp storage for current castGUID
local castGUID, delayedSpell, delayedTimestamp

-- settings
local debugToggle = false
local filterCreated, filterUsed, filter1d, filter7d, filter30d, filterAll = true, true, true, true, true, true

-- optional reagents ilvl effect and temp storage for current inventory
local optionalReagentsIlvl = {
	[185960] = { [190] = 225, [210] = 235, [225] = 249, [235] = 262 },  --VoO    ->  +2
	[187784] = { [190] = 235, [210] = 249, [225] = 262, [235] = 291 },  --VotE   ->  +3
	[183942] = 87,  --NCM    ->  87
	[173381] = 117, --CM1    -> 117
	[173382] = 168, --CM2    -> 168
	[173383] = 200, --CM3    -> 200
	[173384] = 230, --CMotCI -> 230
	[187741] = 233,	--CM4    -> 233
	[187742] = 262  --CMotFO -> 262
}
local optionalReagentsInventory = {
	[185960] = 0, --VoO    ->  +2
	[187784] = 0, --VotE   ->  +3
	[183942] = 0, --NCM    ->  87
	[173381] = 0, --CM1    -> 117
	[173382] = 0, --CM2    -> 168
	[173383] = 0, --CM3    -> 200
	[173384] = 0, --CMotCI -> 230
	[187741] = 0, --CM4    -> 233
	[187742] = 0  --CMotFO -> 262
}

-- mass prospecting craft IDs for special handling and temp storage for product inventory
local prospectingSpellIDs = {
	[359492] = true, -- Progenium
	[311953] = true, -- Elethium
	[311948] = true, -- Laestrite
	[311950] = true, -- Oxxein
	[311951] = true, -- Phaedrum
	[311952] = true, -- Sinvyr
	[311949] = true  -- Solenium
}
local prospectingInventory = {
	[173110] = 0,	-- Umbryl
	[173108] = 0,	-- Oriblase
	[173109] = 0,	-- Angerseye
	[173172] = 0,	-- Essence of Servitude
	[173173] = 0,	-- Essence of Valor
	[173171] = 0,	-- Essence of Torment
	[173170] = 0,	-- Essence of Rebirth
	[175788] = 0,	-- Tranquil Pigment
	[173057] = 0,	-- Luminous Pigment
	[173056] = 0	-- Umbral Pigment
}


-- structure of CraftLog table
--CraftLog {
--	[date] = {
--		[itemlink] = {
--			[ilvl] = {
--				[-] = numused,
--				[+] = numproduced
--			}
--		}
--	}
--}

-- register events
f:RegisterEvent("UNIT_SPELLCAST_START")
f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("ADDON_LOADED")

-- slash command handler
function SlashCraftLog(arg1)
	if (arg1 == "help") or (arg1 == "?") then
		print("use /craftlog debug to toggle debug mode")
	
	--toggle debug mode
	elseif (arg1 == "debug") then
		debugToggle =  not debugToggle
		if (debugToggle) then
			print("CraftLog: Debug Mode is now on")
		else
			print("CraftLog: Debug Mode is now off")
		end
	
	-- show main window
	elseif (arg1 == "") then
		if (debugToggle) then print("CraftLog: showing Frame") end
		f:Show()
		f:ShowData()
	end
end

-- output frame handling
function f:Setup ()
	f:SetPoint("CENTER")
	f:SetSize(800, 600)
	f:SetMinResize(300, 200)

	-- close on ESC
	_G["CraftLogFrame"] = f
	tinsert(UISpecialFrames, "CraftLogFrame")

	-- make movable/resizable
	f:SetMovable(true)
	f:SetResizable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	
	--moving
	f:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)

	--resizing
	local br = CreateFrame("Button", nil, f)
	br:EnableMouse(true)
	br:SetPoint("BOTTOMRIGHT")
	br:SetSize(16,16)
	br:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	br:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	br:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	br:SetScript("OnMouseDown", function(self)
		self:GetParent():StartSizing("BOTTOMRIGHT")
	end)
	br:SetScript("OnMouseUp", function(self)
		self:GetParent():StopMovingOrSizing()
	end)

	-- fill the frame

	--filter area

	local filterHeader = f:CreateFontString(f, "ARTWORK", "GameFontNormal")
	filterHeader:SetPoint("TOPLEFT", 20, -40)
	filterHeader:SetText("Filter:")

	local cbCreated = CreateFrame("CheckButton", nil, f, "InterfaceOptionsCheckButtonTemplate")
	cbCreated:SetPoint("TOPLEFT", 20, -60)
	cbCreated.Text:SetText("crafted items")
	cbCreated:SetChecked(filterCreated)
	cbCreated.SetValue = function(_, value)
		filterCreated = (value == "1")
	end

	local cbUsed = CreateFrame("CheckButton", nil, f, "InterfaceOptionsCheckButtonTemplate")
	cbUsed:SetPoint("TOPLEFT", 20, -80)
	cbUsed.Text:SetText("used items")
	 cbUsed:SetChecked(filterUsed)
	cbUsed.SetValue = function(_, value)
		filterUsed = (value == "1")
	end

	local timeframeHeader = f:CreateFontString(f, "ARTWORK", "GameFontNormal")
	timeframeHeader:SetPoint("TOPLEFT", 20, -120)
	timeframeHeader:SetText("Timeframes:")

	local cbTimeframe1d = CreateFrame("CheckButton", nil, f, "InterfaceOptionsCheckButtonTemplate")
	cbTimeframe1d:SetPoint("TOPLEFT", 20, -140)
	cbTimeframe1d.Text:SetText("1 day")
	cbTimeframe1d:SetChecked(filter1d)
	cbTimeframe1d.SetValue = function(_, value)
		filter1d = (value == "1")
	end
	
	local cbTimeframe7d = CreateFrame("CheckButton", nil, f, "InterfaceOptionsCheckButtonTemplate")
	cbTimeframe7d:SetPoint("TOPLEFT", 20, -160)
	cbTimeframe7d.Text:SetText("7 days")
	cbTimeframe7d:SetChecked(filter7d)
	cbTimeframe7d.SetValue = function(_, value)
		filter7d = (value == "1")
	end

	local cbTimeframe30d = CreateFrame("CheckButton", nil, f, "InterfaceOptionsCheckButtonTemplate")
	cbTimeframe30d:SetPoint("TOPLEFT", 20, -180)
	cbTimeframe30d.Text:SetText("30 days")
	cbTimeframe30d:SetChecked(filter30d)
	cbTimeframe30d.SetValue = function(_, value)
		filter30d = (value == "1")
	end

	local cbTimeframeAll = CreateFrame("CheckButton", nil, f, "InterfaceOptionsCheckButtonTemplate")
	cbTimeframeAll:SetPoint("TOPLEFT", 20, -200)
	cbTimeframeAll.Text:SetText("all time")
	cbTimeframeAll:SetChecked(filterAll)
	cbTimeframeAll.SetValue = function(_, value)
		filterAll = (value == "1")
	end

	--settings
	local cb = CreateFrame("CheckButton", nil, f, "InterfaceOptionsCheckButtonTemplate")
	cb:SetPoint("BOTTOMLEFT", 20, 20)
	cb.Text:SetText("debugToggle")
	cb.SetValue = function(_, value)
		debugToggle = (value == "1")
	end
end

function f:ShowData()
	-- headers for Timeframes
	local header1d = f:CreateFontString(f, "ARTWORK", "GameFontNormal")
	header1d:SetPoint("TOPLEFT", 350, -40)
	header1d:SetText("1 day")

	local header7d = f:CreateFontString(f, "ARTWORK", "GameFontNormal")
	header7d:SetPoint("TOPLEFT", 450, -40)
	header7d:SetText("7 days")

	local header30d = f:CreateFontString(f, "ARTWORK", "GameFontNormal")
	header30d:SetPoint("TOPLEFT", 550, -40)
	header30d:SetText("30 days")

	local headerAll = f:CreateFontString(f, "ARTWORK", "GameFontNormal")
	headerAll:SetPoint("TOPLEFT", 650, -40)
	headerAll:SetText("total")

	-- scrollable itemlist
	local dataScroll = CreateFrame("Scrollframe", "CraftLogDataScroll", f, "UIPanelScrollFrameTemplate")
	dataScroll:SetPoint("TOPLEFT", 150, -60)
	dataScroll:SetPoint("BOTTOMRIGHT", -20, 20)
	
	local scrollChild = CreateFrame("Frame")
	dataScroll:SetScrollChild(scrollChild)
	scrollChild:SetWidth(InterfaceOptionsFramePanelContainer:GetWidth()-20)
	scrollChild:SetHeight(1)

	local itemTable = GetDistinctItems()
	local yOffset = 40
	local n = 0
	for itemkey, itemvalue in pairs(itemTable) do
		local itemName = scrollChild:CreateFontString(scrollChild, "ARTWORK", "GameFontNormal")
		itemName:SetPoint("TOPLEFT", 20, -20-n*yOffset)
		if (itemvalue.itemlvl>25) then
			itemName:SetText(itemvalue.itemlink.." ("..itemvalue.itemlvl..")")
		else
			itemName:SetText(itemvalue.itemlink)
		end
		n = n + 1
	end
end

function GetDistinctItems()
	local t = {}
	for datekey, datevalue in pairs(CraftLog) do
		for itemkey, itemvalue in pairs(datevalue) do
			--if (t[itemkey] == nil) then t[itemkey] = {} end
			for ilvlkey, ilvlvalue in pairs(itemvalue) do
				--if(t[itemkey][ilvlkey] == nil) then t[itemkey][ilvlkey] = ilvlvalue end
				table.insert(t, {itemlink=itemkey, itemlvl=ilvlkey})
			end
		end
	end
	table.sort(t, function(a,b) return a.itemlink<b.itemlink end)
	return t
end

function FilterByTimeframe(timeframe)
	local t = {}	
	for datekey, datevalue in pairs(CraftLog) do
		local year, month, day = datekey:match("(%d+)-(%d+)-(%d+)")
		local age = floor((time() - time({day=day, month=month, year=year}))/86400)
		if (timeframe == -1) or (age<=timeframe) then
			for itemkey, itemvalue in pairs(datevalue) do
				print(datekey..": "..itemkey)
			end
		end
	end
end

-- event handler base
f:SetScript("OnEvent", function(self, event, ...)
	if (event == "UNIT_SPELLCAST_START") then
		OnUnitSpellcastStart(event, ...)
	elseif (event == "UNIT_SPELLCAST_SUCCEEDED") then
		OnUnitSpellcastSucceeded(event, ...)
	elseif (event == "BAG_UPDATE_DELAYED") then	
		OnBagUpdateDelayed(event, ...)
	elseif (event == "ADDON_LOADED") then
		InitializeSavedVariables(...)
		f:Setup()
	end
end)

-- event handler ADDON_LOADED
function InitializeSavedVariables(...)
	local arg1 = ...
	if (arg1 == "CraftLog") then
		if (CraftLog == nil) then
			CraftLog = {}
		end
	end
end

-- event handler UNIT_SPELLCAST_START
function OnUnitSpellcastStart(event, ...)
	local unit, cast, spell = ...
	
	-- only run if caster is the player and tradeskillUI is open
	if (unit == "player" and C_TradeSkillUI.IsTradeSkillReady()) then
		--print start of cast event details
		if (debugToggle) then print(event.." "..cast.." "..spell) end
		
		--set castGUID to check if UNIT_SPELLCAST_SUCCEEDED matches
		castGUID = cast
		
		--check if optional reagents are available
		if not (C_TradeSkillUI.GetOptionalReagentInfo(spell)[1] == nil) then
			if (debugToggle) then print("optional reagents:") end
			--add inventory of optional reagents
			for k, v in pairs(optionalReagentsInventory) do
				optionalReagentsInventory[k] = GetItemCount(k, true, false, true)
				if (debugToggle) then print(optionalReagentsInventory[k].." x "..k) end
			end
		end
		
		--check if we are prospecting
		if not (prospectingSpellIDs[spell] == nil) then
			if (debugToggle) then print("prospecting...") end
			for k, v in pairs(prospectingInventory) do
				prospectingInventory[k] = GetItemCount(k, true, false, true)
				if (debugToggle) then print(prospectingInventory[k].." x "..k) end
			end
		end
	end
end

-- event handler UNIT_SPELLCAST_SUCCEEDED
function OnUnitSpellcastSucceeded(event, ...)
	local unit, cast, spell = ...
	local timestamp = date('%Y-%m-%d')
	
	-- only run if caster is player and castGUID matches
	if (unit == "player" and cast == castGUID) then
		--store spell and timestamp for retrieval after OnBagUpdateDelayed(event, ...) fires
		if (debugToggle) then print(event.." "..cast.." "..spell) end
		delayedSpell = spell
		delayedTimestamp = timestamp
	else
		delayedSpell = nil
		delayedTimestamp = nil
	end
end

-- event handler BAG_UPDATE_DELAYED
function OnBagUpdateDelayed(event, ...)
	if (debugToggle) then print(event) end
	if not (delayedSpell == nil) and not (delayedTimestamp == nil) then
		--retrieve stored spell and timestamp
		local spell = delayedSpell
		local timestamp = delayedTimestamp
		local itemproduced
	
		-- log item produced
		if not (prospectingSpellIDs[spell] == nil) then
			--prospecting
			if (debugToggle) then print("using prospecing/milling logic (WIP)") end
			for i = 1, C_TradeSkillUI.GetRecipeNumReagents(spell) do
				local itemused = C_TradeSkillUI.GetRecipeReagentItemLink(spell,i)
				local _, _, _, ilvlused = GetItemInfo(itemused)
				local _, _, numitemused, _ = C_TradeSkillUI.GetRecipeReagentInfo(spell,i)
				--log used items
				addItemToCraftLog(timestamp, itemused, ilvlused, "-", numitemused)
			end
			
			-- TODO: work out the prospecting results, current solution is buggy af
			-- if (debugToggle) then print("prospecting results:") end
			-- for k, v in pairs(prospectingInventory) do
				-- local amount = GetItemCount(k, true, false, true) - prospectingInventory[k]
				-- local _, itemLink, _, ilvlproduced = GetItemInfo(k)
				-- if (debugToggle) then print(amount.." x "..k) end
				-- addItemToCraftLog(timestamp, itemLink, ilvlproduced, "+", amount)
			-- end
			
		else
			--default crafting
			if (debugToggle) then print("using default crafting logic") end
			itemproduced = C_TradeSkillUI.GetRecipeItemLink(spell)
		end
		--only continue if itemproduced exists aka tradeskill used
		if not (itemproduced == nil) then
			local numitemproduced = C_TradeSkillUI.GetRecipeNumItemsProduced(spell)
			local _, _, _, ilvlproduced = GetItemInfo(itemproduced)
			
			--check if optional reagents are available
			if not (C_TradeSkillUI.GetOptionalReagentInfo(spell)[1] == nil) then
				--remove inventory of optional reagents
				for k, v in pairs(optionalReagentsInventory) do
					local optionalReagent, optionalReagentIlvl
					local amount = optionalReagentsInventory[k] - GetItemCount(k, true, false, true)
					optionalReagentsInventory[k] = GetItemCount(k, true, false, true)
					--if optional reagent is still > 0 it was used -> adjust ilvlproduced accordingly
					if (amount>0) then
						--set used optional reagent
						_, optionalReagent, _, optionalReagentIlvl = GetItemInfo(k)
						
						--crafted a legendary?
						if (ilvlproduced >= 190) then
							ilvlproduced = optionalReagentsIlvl[k][ilvlproduced]
						--crafted something else?
						else
							ilvlproduced = optionalReagentsIlvl[k]
						end
						if (debugToggle) then print(optionalReagent.." used to change ilvl to "..ilvlproduced) end
										
						--add optional reagent to CraftLog
						addItemToCraftLog(timestamp, optionalReagent, optionalReagentIlvl, "-", amount)
					end
				end
			end
			
			--iterate through reagents to log items used
			for i = 1, C_TradeSkillUI.GetRecipeNumReagents(spell) do
				local itemused = C_TradeSkillUI.GetRecipeReagentItemLink(spell,i)
				local _, _, _, ilvlused = GetItemInfo(itemused)
				local _, _, numitemused, _ = C_TradeSkillUI.GetRecipeReagentInfo(spell,i)
				--log used items
				addItemToCraftLog(timestamp, itemused, ilvlused, "-", numitemused)
			end
			--log produced item
			addItemToCraftLog(timestamp, itemproduced, ilvlproduced, "+", numitemproduced)
		end
		
		--reset delayed spell and timestamp
		delayedSpell = nil
		delayedTimestamp = nil
	end
end

-- utility functions

-- adds item to the CraftLog table
function addItemToCraftLog(timestamp, link, ilvl, dir, amount)
	--first craft for the day
	if (CraftLog[timestamp] == nil) then CraftLog[timestamp] = {} end
	--first craft of the day using/producing optional reagent
	if (CraftLog[timestamp][link] == nil) then CraftLog[timestamp][link] = {} end
	--first craft of the day using/producing optional reagent @ ilvl
	if (CraftLog[timestamp][link][ilvl] == nil) then CraftLog[timestamp][link][ilvl] = {} end
	--first craft of the day using optional reagent
	if (CraftLog[timestamp][link][ilvl][dir] == nil) then
		CraftLog[timestamp][link][ilvl][dir] = amount
	else
		CraftLog[timestamp][link][ilvl][dir] = CraftLog[timestamp][link][ilvl][dir] + amount
	end
	if (debugToggle) then print(timestamp.." "..dir.." "..amount.." "..link) end
end

-- register slash commands
SLASH_CRAFTLOG1 = "/cl"
SLASH_CRAFTLOG2 = "/craftlog"
SlashCmdList["CRAFTLOG"] = SlashCraftLog