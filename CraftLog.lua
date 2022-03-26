-- get reference to main frame
local f = CraftLogFrame

-- settings
local debugToggle = false
local filterCreated, filterUsed, filter1d, filter7d, filter30d, filterAll = true, true, true, true, true, true

-- temp storage for current castGUID
local castGUID, delayedSpell, delayedTimestamp
-- bool to store match/no match of castGUID from UNIT_SPELLCAST_SUCCEEDED to BAG_UPDATE_DELAYED
local castGUIDmatched = false

-- mass prospecting/milling craft IDs for special handling and temp storage for product inventory
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
	[173170] = 0	-- Essence of Rebirth
	--[175788] = 0,	-- Tranquil Pigment
	--[173057] = 0,	-- Luminous Pigment
	--[173056] = 0	-- Umbral Pigment
}

-- optional reagents with ilvl effect and temp storage for current inventory
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

-- register additional events
f:RegisterEvent("UNIT_SPELLCAST_START")
f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
f:RegisterEvent("BAG_UPDATE_DELAYED")

-- handle additional events
f:SetScript("OnEvent", function(self, event, ...)
	self[event](self, ...)
end)

function f:UNIT_SPELLCAST_START(...)
	if (debugToggle) then print("UNIT_SPELLCAST_START handler start") end
	if (debugToggle) then print(...) end
	
	OnUnitSpellcastStart(...)
	
	if (debugToggle) then print("UNIT_SPELLCAST_START handler end") end
end

function f:UNIT_SPELLCAST_SUCCEEDED(...)
	if (debugToggle) then print("UNIT_SPELLCAST_SUCCEEDED handler start") end
	if (debugToggle) then print(...) end
	OnUnitSpellcastSucceeded(...)
	if (debugToggle) then print("UNIT_SPELLCAST_SUCCEEDED handler end") end
end

function f:BAG_UPDATE_DELAYED(...)
	if (debugToggle) then print("BAG_UPDATE_DELAYED handler start") end	
	if (debugToggle) then print(...) end
	OnBagUpdateDelayed(...)
	if (debugToggle) then print("BAG_UPDATE_DELAYED handler end") end
end

-- event handler UNIT_SPELLCAST_START
function OnUnitSpellcastStart(...)
	local unit, cast, spell = ...
	
	-- only run if caster is the player and tradeskillUI is open
	if (unit == "player" and C_TradeSkillUI.IsTradeSkillReady()) then
		--print start of cast event details
		if (debugToggle) then print("starting craft with spell "..spell.." and id "..cast) end
		
		--set castGUID to check if UNIT_SPELLCAST_SUCCEEDED matches
		castGUID = cast
		
		--check if optional reagents are usable
		if not (C_TradeSkillUI.GetOptionalReagentInfo(spell)[1] == nil) then
			if (debugToggle) then print("available optional reagents:") end
			--add inventory of optional reagents
			for k, v in pairs(optionalReagentsInventory) do
				optionalReagentsInventory[k] = GetItemCount(k, true, false, true)
				local _, itemLink = GetItemInfo(k)
				if (debugToggle) then print(optionalReagentsInventory[k].." x "..itemLink) end
			end
		end
		
		--check if we are prospecting/milling
		if not (prospectingSpellIDs[spell] == nil) then
			if (debugToggle) then print("prospecting / milling...") end
			for k, v in pairs(prospectingInventory) do
				prospectingInventory[k] = GetItemCount(k, true, false, true)
				local _, itemLink = GetItemInfo(k)
				if (debugToggle) then print(prospectingInventory[k].." x "..itemLink) end
			end
		end
	end
end

-- event handler UNIT_SPELLCAST_SUCCEEDED
function OnUnitSpellcastSucceeded(...)
	local unit, cast, spell = ...
	local timestamp = date('%Y-%m-%d')
	
	-- only run if caster is player and castGUID matches
	if (unit == "player" and cast == castGUID) then
		-- confirm castGUID match
		castGUIDmatched = true
		--store spell and timestamp for retrieval after OnBagUpdateDelayed(event, ...) fires
		if (debugToggle) then print("finished craft with spell "..spell.." and id "..cast) end
		delayedSpell = spell
		delayedTimestamp = timestamp
	else
		delayedSpell = nil
		delayedTimestamp = nil
	end
end

-- event handler BAG_UPDATE_DELAYED
function OnBagUpdateDelayed(...)
	if not (delayedSpell == nil) and not (delayedTimestamp == nil) and (castGUIDmatched) then
		-- reset castGUIDmatched
		castGUIDmatched = nil

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
				addItemToCraftLog(timestamp, spell, itemused, ilvlused, "-", numitemused)
			end
			
			-- TODO: work out the prospecting results, current solution is buggy af
			if (debugToggle) then print("prospecting results:") end
			for k, v in pairs(prospectingInventory) do
				local cur = GetItemCount(k, true, false, true)
				local amount = cur - prospectingInventory[k]
				local _, itemLink, _, ilvlproduced = GetItemInfo(k)
				if (debugToggle) then print(prospectingInventory[k].." - "..cur.." = "..amount.." x "..itemLink) end
				addItemToCraftLog(timestamp, spell, itemLink, ilvlproduced, "+", amount)
			end
		else
			--default crafting
			if (debugToggle) then print("using default crafting logic") end
			itemproduced = C_TradeSkillUI.GetRecipeItemLink(spell)
		end

		--only continue if itemproduced exists aka tradeskill used
		if not (itemproduced == nil) then
			local numitemproduced = C_TradeSkillUI.GetRecipeNumItemsProduced(spell)
			local _, _, _, ilvlproduced = GetItemInfo(itemproduced)
			
			--check if optional reagents are usable
			if not (C_TradeSkillUI.GetOptionalReagentInfo(spell)[1] == nil) then
				--remove inventory of optional reagents
				for k, v in pairs(optionalReagentsInventory) do
					local cur = GetItemCount(k, true, false, true)
					local amount = optionalReagentsInventory[k] - cur
					local _, itemLink = GetItemInfo(k)
					if (debugToggle) then print(cur.. " - "..optionalReagentsInventory[k].." = "..amount.." x "..itemLink) end
					optionalReagentsInventory[k] = cur
					
					--if optional reagent is still > 0 it was used -> adjust ilvlproduced accordingly
					if (amount>0) then
						local optionalReagent, optionalReagentIlvl
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
						addItemToCraftLog(timestamp, spell, optionalReagent, optionalReagentIlvl, "-", amount)
					end
				end
			end
			
			--iterate through reagents to log items used
			for i = 1, C_TradeSkillUI.GetRecipeNumReagents(spell) do
				local itemused = C_TradeSkillUI.GetRecipeReagentItemLink(spell,i)
				local _, _, _, ilvlused = GetItemInfo(itemused)
				local _, _, numitemused, _ = C_TradeSkillUI.GetRecipeReagentInfo(spell,i)
				--log used items
				addItemToCraftLog(timestamp, spell, itemused, ilvlused, "-", numitemused)
			end
			--log produced item
			addItemToCraftLog(timestamp, spell, itemproduced, ilvlproduced, "+", numitemproduced)
		end
		
		--reset delayed spell and timestamp
		delayedSpell = nil
		delayedTimestamp = nil
	end
end

-- adds item to the CraftLog table
function addItemToCraftLog(timestamp, spell, link, ilvl, dir, amount)
	-- structure of CraftLog table
	--CraftLog {
	--	[date] = {
	--		[craftid] = {
	--			[itemlink] = {
	--				[ilvl] = {
	--					[-] = numused,
	--					[+] = numproduced
	--				}
	--			}
	--		}
	--	}
	--}

	
	--first entry for the day
	if (CraftLog[timestamp] == nil) then CraftLog[timestamp] = {} end
	-- first entry for day -> spellid
	if (CraftLog[timestamp][spell] == nil) then CraftLog[timestamp][spell] = {} end
	--first craft of the day using/producing optional reagent
	if (CraftLog[timestamp][spell][link] == nil) then CraftLog[timestamp][spell][link] = {} end
	--first craft of the day using/producing optional reagent @ ilvl
	if (CraftLog[timestamp][spell][link][ilvl] == nil) then CraftLog[timestamp][spell][link][ilvl] = {} end
	--first craft of the day using optional reagent
	if (CraftLog[timestamp][spell][link][ilvl][dir] == nil) then
		CraftLog[timestamp][spell][link][ilvl][dir] = amount
	else
		CraftLog[timestamp][spell][link][ilvl][dir] = CraftLog[timestamp][spell][link][ilvl][dir] + amount
	end
	if (debugToggle) then print(timestamp.." "..dir.." "..amount.." "..link.." via "..spell) end
end

-- event handlers
function cbCreated_OnShow(cb)
	cb:SetChecked(filterCreated)
end

function cbCreated_OnClick(cb)
	filterCreated = cb:GetChecked()
end

function cbUsed_OnShow(cb)
	cb:SetChecked(filterUsed)
end

function cbUsed_OnClick( cb )
	filterUsed = cb:GetChecked()
end

function cbTimeframe1day_OnShow(cb)
	cb:SetChecked(filter1d)
end

function cbTimeframe1day_OnClick( cb )
	filter1d = cb:GetChecked()
end

function cbTimeframe7day_OnShow(cb)
	cb:SetChecked(filter1d)
end

function cbTimeframe7day_OnClick( cb )
	filter1d = cb:GetChecked()
end

function cbTimeframe30day_OnShow(cb)
	cb:SetChecked(filter1d)
end

function cbTimeframe30day_OnClick( cb )
	filter1d = cb:GetChecked()
end

function cbTimeframeTotal_OnShow(cb)
	cb:SetChecked(filter1d)
end

function cbTimeframeTotal_OnClick( cb )
	filter1d = cb:GetChecked()
end

function cbDebugToggle_OnShow(cb)
	cb:SetChecked(debugToggle)
end

function cbDebugToggle_OnClick( cb )
	debugToggle = cb:GetChecked()
end

-- event handler ADDON_LOADED
function InitializeSavedVariables(...)
	local arg1 = ...
	if (arg1 == "CraftLog") then
		if (CraftLog == nil) then
			CraftLog = {}
		end
	end
end

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
		--f:ShowData()
	end
end

-- register slash commands
SLASH_CRAFTLOG1 = "/cl"
SLASH_CRAFTLOG2 = "/craftlog"
SlashCmdList["CRAFTLOG"] = SlashCraftLog