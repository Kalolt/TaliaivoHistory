-- If this value is too low, your character model might not be in the screenshot.
-- Setting this to a wrong value might mean that your character blinks right when the screenshot is taken.
local SCREENSHOT_DELAY = 0.1

BINDING_HEADER_TALIAIVO_HISTORY = "TaliaivoHistory"

local _G = _G
local UIParent = UIParent
local TH_ScreenshotFrame = TH_ScreenshotFrame
local CLASS, CLASS_COLOR, RACESEX
local pendingScreenshot = false
local currentPlayed, pastPlayed, playedUpdate
local level -- UnitLevel is unpredictable shortly after PLAYER_LEVEL_UP

local function GetPlayedText(time)
	local s, m, h, d
	s = mod(time, 60)
	m = mod((time - s) / 60, 60)
	h = mod((time - 60 * m - s) / 3600, 24)
	d = floor(time / 86400)

	s = (s == 0) and "" or (s == 1) and "1 second"  or format("%d seconds",  s)
	m = (m == 0) and "" or (m == 1) and "1 minute " or format("%d minutes ", m)
	h = (h == 0) and "" or (h == 1) and "1 hour "   or format("%d hours ",   h)
	d = (d == 0) and "" or (d == 1) and "1 day "    or format("%d days ",    d)

	return d .. h .. m .. s
end

local Sets = {}
local function HandleSet(tt, quality)
	for line = 1, 30 do
		local text = tt.left[line]:GetText()
		if not text then return end
		local _, _, setName, num = strfind(text, "(.+) %((%d)/%d%)")
		if setName then
			if num ~= "1" then
				if not Sets[setName] then
					-- Set found for the first time
					Sets[setName] = {active = true, quality = quality, tt = tt, line = line}
				elseif not Sets[setName].active then
					-- Set found during previous scan, update information
					Sets[setName].active = true
					Sets[setName].quality = quality
					Sets[setName].tt = tt
					Sets[setName].line = line
				else
					-- Set found earlier this scan, update highest quality
					Sets[setName].quality = max(Sets[setName].quality, quality)
				end
			end
			-- Hide set from the item tooltip
			for i = line - 1, 30 do
				tt.left[i]:Hide()
			end
		end
	end
end

local ItemTooltip = {
	TH_Item1,
	TH_Item2,
	TH_Item3,
	TH_Item4,
	TH_Item5,
	TH_Item6,
	TH_Item7,
	TH_Item8,
	TH_Item9,
	TH_Item10,
	TH_Item11,
	TH_Item12,
	TH_Item13,
	TH_Item14,
	TH_Item15,
	TH_Item16,
	TH_Item17,
	TH_Item18,
	TH_Item19,
	TH_Item20,
	TH_Item21,
	TH_Item22,
	TH_Item23,
	TH_Item24,
	TH_Item25,
	TH_Item26,
	TH_Item27,
	TH_Item28,
	TH_Item29,
	TH_Item30,
}

-- 2 = male, 3 = female
local ModelPosition = setmetatable({
	["Default"] = {x = -1.0, y = -1.0, z =  0.0},
	-- Player races
	["Gnome2"]  = {x = -0.6, y = -0.5, z =  0.0},
	["Gnome3"]  = {x = -0.6, y = -0.5, z =  0.0},
	["Dwarf2"]  = {x = -0.8, y = -0.8, z =  0.0},
	["Dwarf3"]  = {x = -0.8, y = -0.8, z =  0.0},
	["Troll2"]  = {x = -1.6, y = -1.2, z = -0.2},
	["Troll3"]  = {x = -1.4, y = -1.4, z = -0.1},
}, {
	__index = function(self)
		return self.Default
	end	
})

local ProfessionTextures = {
	-- Professions
	["Alchemy"] = "Interface\\Icons\\Trade_Alchemy",
	["Blacksmithing"] = "Interface\\Icons\\Trade_Blacksmithing",
	["Enchanting"] = "Interface\\Icons\\Trade_Engraving",
	["Engineering"] = "Interface\\Icons\\Trade_Engineering",
	["Herbalism"] = "Interface\\Icons\\Trade_Herbalism",
	--["Inscription"] = "Interface\\Icons\\inv_inscription_tradeskill01",
	["Jewelcrafting"] = "Interface\\Icons\\inv_misc_gem_01",
	["Leatherworking"] = "Interface\\Icons\\inv_misc_armorkit_17",
	["Mining"] = "Interface\\Icons\\Trade_Mining",
	["Skinning"] = "Interface\\Icons\\inv_misc_pelt_wolf_01",
	["Tailoring"] = "Interface\\Icons\\Trade_Tailoring",
	-- Secondary skills
	["Cooking"] = "Interface\\Icons\\inv_misc_food_15",
	["First Aid"] = "Interface\\Icons\\spell_holy_sealofsacrifice",
	["Fishing"] = "Interface\\Icons\\Trade_Fishing",
	["Riding"] = "Interface\\Icons\\spell_nature_swiftness",
}

local ProfessionIcons = setmetatable({}, {
	__index = function(table, key)
		table[key] = CreateFrame("Frame", format("TH_SSF_ProfessionIcon%d", key), TH_ScreenshotFrame, "ProfessionIconTemplate")
		return table[key]
	end
})
local TalentIcons = {}

TH_ScreenshotFrame:SetScript("OnHide", function()
	for i = 1, 30 do
		ItemTooltip[i]:Hide()
	end
	for i, v in pairs(ProfessionIcons) do
		v:Hide()
	end
end)

local function GetInventoryItemID(unit, slotID)
	local link = GetInventoryItemLink(unit, slotID)
	return link and tonumber(link:match("item:(%d+)")) 
end

function TH_ScreenshotFrame:Toggle(force)
	if InCombatLockdown() then return end
	if self:IsShown() and not force then
		self:Hide()
		UIParent:Show()
		return
	end

	local n, tt

	UIParent:Hide()
	WorldMapFrame:Hide()
	self:Show()

	-------------------
	-- Pixel perfect --
	-------------------

	local yRes = tonumber(GetCVar("gxResolution"):match("%d+x(%d+)"))
	local realScale = 768 / yRes -- / GetCVar("uiscale")
	self:SetScale(realScale)

	-----------------
	-- Text fields --
	-----------------

	-- Name/Guild
	local name, guild = UnitName("player"), GetGuildInfo("player")
	TH_SSF_NameText:SetText(guild and (name .. "\n|cffffffff<" .. guild .. ">|r") or name)

	-- Level
	TH_SSF_LevelText:SetText(format("Level %d", level))

	-- Gold
	local money = GetMoney()
	local g, s, c = floor(money / 10000), mod(floor(money / 100), 100), mod(money, 100)
	if g > 0 then
		TH_SSF_GoldText:SetText(format("%d|cffFFD700g|r %d|cffC0C0C0s|r %d|cffB87333c|r", g, s, c))
	elseif s > 0 then
		TH_SSF_GoldText:SetText(format("%d|cffC0C0C0s|r %d|cffB87333c|r", s, c))
	else
		TH_SSF_GoldText:SetText(format("%d|cffB87333c|r", c))
	end

	-- Played
	local currentPlayed = floor(GetTime() - playedUpdate + currentPlayed)
	TH_SSF_CurrentPlayedText:SetText(GetPlayedText(currentPlayed - pastPlayed))
	TH_SSF_TotalPlayedText:SetText(GetPlayedText(currentPlayed))

	-- Rank
	TH_SSF_RankText:SetText(GetPVPRankInfo(UnitPVPRank("player")))

	-----------------
	-- Professions --
	-----------------

	n = 0
	local isProfession = false
	for i = 1, GetNumSkillLines() do
		local skill, isHeader, _, skillRank, tempPoints, skillModifier, maxRank = GetSkillLineInfo(i)
		if isProfession then
			if isHeader then
				if skill ~= "Secondary Skills" then break end
			else
				n = n + 1
				ProfessionIcons[n]:SetTexture(ProfessionTextures[skill])
				ProfessionIcons[n]:SetText(skillRank)
			end
		elseif isHeader and (skill == "Professions" or skill == "Secondary Skills") then
			isProfession = true
		end
	end
	local offset = -49 - n * 25
	for i = 1, n do
		ProfessionIcons[i]:SetPoint("TOPLEFT", self, "TOP", offset + i * 50, -100)
		ProfessionIcons[i]:Show()
	end

	-------------------
	-- Item tooltips --
	-------------------

	n = 0
	for slotID = 0, 23 do
		local quality = GetInventoryItemQuality("player", slotID)
		if quality then
			n = n + 1
			tt = ItemTooltip[n]

			tt:SetOwner(self, "ANCHOR_NONE")
			tt:SetInventoryItem("player", slotID)
			HandleSet(tt, quality)

			for line = 1, 30 do
				local fontString = tt.left[line]
				local text = fontString:GetText()
				if text and strsub(text, 1, 8) == "Cooldown" then
					fontString:Hide()
				end
			end

			tt:Show()

			local c = ITEM_QUALITY_COLORS[quality]
			tt:SetBackdropBorderColor(c.r, c.g, c.b)
		end
	end

	------------------
	-- Set tooltips --
	------------------

	for setName, set in pairs(Sets) do
		if set.active then
			n = n + 1
			tt = ItemTooltip[n]

			tt:SetOwner(self, "ANCHOR_NONE")

			local setLines = set.tt.left
			for line = set.line, 30 do
				local r, g, b = setLines[line]:GetTextColor()
				tt:AddLine(setLines[line]:GetText(), r, g, b, true)
			end
			tt:Show()

			local c = ITEM_QUALITY_COLORS[set.quality]
			tt:SetBackdropBorderColor(c.r, c.g, c.b)

			set.active = false
		end
	end

	---------------------------
	-- Set tooltip positions --
	---------------------------

	local OFFSET = 3
	local minWidth
	local columnHeight = 0
	local bottomIndex = 1
	for i = 1, n do
		tt = ItemTooltip[i]
		if i == 1 then
			-- First tooltip goes to bottomright corner
			tt:SetPoint("BOTTOMRIGHT", -10, 10)
			columnHeight = 10 + tt:GetHeight()
			minWidth = tt:GetWidth()
		elseif (tt:GetHeight() + OFFSET + columnHeight + 490) <= yRes then
			-- If there's room above the previous tooltip, place the new tooltip above
			columnHeight = columnHeight + OFFSET + tt:GetHeight()
			tt:SetPoint("BOTTOM", ItemTooltip[i - 1], "TOP", 0, OFFSET)
			minWidth = max(minWidth, tt:GetWidth())
		else
			-- Start a new column from the bottom
			tt:SetPoint("BOTTOMRIGHT", ItemTooltip[bottomIndex], "BOTTOMLEFT", -OFFSET, 0)
			columnHeight = 10 + tt:GetHeight()
			-- Equalize the width of all tooltips in the previous column
			for k = bottomIndex, i - 1 do
				ItemTooltip[k]:SetMinimumWidth(minWidth)
				ItemTooltip[k]:Show()
			end
			minWidth = tt:GetWidth()
			bottomIndex = i
		end
	end
	-- Equalize the width of tooltips in the last column
	for k = bottomIndex, n do
		ItemTooltip[k]:SetMinimumWidth(minWidth)
		ItemTooltip[k]:Show()
	end

	-------------
	-- Talents --
	-------------

	local ntalents = 0
	for tab = 1, GetNumTalentTabs() do
		local numTalents = GetNumTalents(tab)
		for i = 1, numTalents do
			ntalents = ntalents + 1
			local t = TalentIcons[ntalents]
			local talentName, icon, tier, column, currRank, maxRank = GetTalentInfo(tab, i)

			if currRank > 0 then
				t:SetBackdropBorderColor(CLASS_COLOR.r, CLASS_COLOR.g, CLASS_COLOR.b)
				t:SetDesaturated(false)
			else
				t:SetBackdropBorderColor(0.3, 0.3, 0.3)
				t:SetDesaturated(true)
			end

			t:SetText(format("%d/%d", currRank, maxRank))
		end
	end

	------------------
	-- Player model --
	------------------

	TH_Model:SetScale(1 / realScale) -- Fixes particle effect size
	TH_Model:SetPosition(0, 0, 0) -- Reset position, because otherwise updated model starts from offset
	TH_Model:SetUnit("player")
	local pos = ModelPosition[RACESEX]
	TH_Model:SetPosition(pos.x, pos.y, pos.z)
	TH_Model:SetRotation(PI / 5)

	-- TryOn weapon to have it unsheathed
	if CLASS ~= "HUNTER" then
		-- Try a random 2H to get dual wielded 1H weapons right
		TH_Model:TryOn(12282)
		TH_Model:TryOn(GetInventoryItemID("player", 16))
		TH_Model:TryOn(GetInventoryItemID("player", 17))
	else
		-- Show ranged weapon for Hunters
		TH_Model:TryOn(GetInventoryItemID("player", 18))
	end
end

local function SetupTalents()
	local F_SetBackdropBorderColor = TH_ScreenshotFrame.SetBackdropBorderColor
	local ntalents = 0
	for tab = 1, GetNumTalentTabs() do
		local numTalents = GetNumTalents(tab)
		for i = 1, numTalents do
			ntalents = ntalents + 1
			local talentName, icon, tier, column, currRank, maxRank = GetTalentInfo(tab, i)
			local t = CreateFrame("Frame", format("TH_SSF_TalentIcon%d", ntalents), TH_ScreenshotFrame, "TalentIconTemplate")
			t:SetPoint("TOPRIGHT", -878 + tab * 220 + column * 52, 42 - 52 * tier)
			t:SetTexture(icon)

			local ptier, pcolumn, learnable = GetTalentPrereqs(tab, i)
			if ptier then
				local line = t:CreateTexture()
				if ptier ~= tier and pcolumn ~= column then
					line:SetHeight(30)
					line:SetWidth(4)
					line:SetPoint("BOTTOM", t, "TOP")
					local vertLine = t:CreateTexture()
					vertLine:SetHeight(4)
					vertLine:SetWidth(30)
					vertLine:SetPoint("TOPRIGHT", t, "TOP", 2, 30)
					function t:SetBackdropBorderColor(r, g, b, a)
						F_SetBackdropBorderColor(t, r, g, b, a)
						line:SetTexture(r, g, b, a)
						vertLine:SetTexture(r, g, b, a)
					end
				else
					if ptier == tier then
						-- Prereq on the same row
						line:SetHeight(4)
						line:SetWidth(4)
						if pcolumn < column then
							line:SetPoint("RIGHT", t, "LEFT")
						else
							line:SetPoint("LEFT", t, "RIGHT")
						end
					elseif pcolumn == column then
						-- Prereq on the same column
						line:SetHeight(-48 + (tier - ptier) * 52)
						line:SetWidth(4)
						line:SetPoint("BOTTOM", t, "TOP")
					end
					function t:SetBackdropBorderColor(r, g, b, a)
						F_SetBackdropBorderColor(t, r, g, b, a)
						line:SetTexture(r, g, b, a)
					end
				end
			end

			TalentIcons[ntalents] = t
		end
	end
end

TH_ScreenshotFrame:RegisterEvent("PLAYER_LOGIN")
TH_ScreenshotFrame["PLAYER_LOGIN"] = function(self)
	local _
	_, CLASS = UnitClass("player")
	CLASS_COLOR = RAID_CLASS_COLORS[CLASS]
	TH_SSF_NameText:SetTextColor(CLASS_COLOR.r, CLASS_COLOR.g, CLASS_COLOR.b)
	local _, RACE = UnitRace("player")
	RACESEX = format("%s%d", RACE, UnitSex("player"))

	-- Talent data isn't ready immediately
	self:SetScript("OnShow", function()
		if GetTalentInfo(1, 1) then
			SetupTalents()
			GetItemInfo(12282)
			self:SetScript("OnShow", nil)
		end
	end)

	level = UnitLevel("player")
	RequestTimePlayed()
end

local delayTimer
local function DelayScreenshot(self, elapsed)
	delayTimer = delayTimer - elapsed
	if delayTimer <= 0 then
		TakeScreenshot()
		self:SetScript("OnUpdate", nil)
	end
end

TH_ScreenshotFrame:RegisterEvent("TIME_PLAYED_MSG")
TH_ScreenshotFrame["TIME_PLAYED_MSG"] = function(self, current, total)
	currentPlayed = current
	playedUpdate = GetTime()
	if pendingScreenshot then
		pendingScreenshot = false
		self:Toggle(true)
		self:RegisterEvent("SCREENSHOT_SUCCEEDED")
		delayTimer = SCREENSHOT_DELAY
		self:SetScript("OnUpdate", DelayScreenshot)
	end
	pastPlayed = current - total
end

TH_ScreenshotFrame["SCREENSHOT_SUCCEEDED"] = function(self)
	UIParent:Show()
	self:Hide()
	self:UnregisterEvent("SCREENSHOT_SUCCEEDED")
end

function TH_ScreenshotFrame:QueueScreenshot()
	if not InCombatLockdown() then
		pendingScreenshot = true
		RequestTimePlayed()
	else
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
	end
end

TH_ScreenshotFrame:RegisterEvent("PLAYER_LEVEL_UP")
TH_ScreenshotFrame["PLAYER_LEVEL_UP"] = function(self, newLevel)
	level = newLevel
	self:QueueScreenshot()
end

TH_ScreenshotFrame["PLAYER_REGEN_ENABLED"] = function(self)
	pendingScreenshot = true
	RequestTimePlayed()
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
end

TH_ScreenshotFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
TH_ScreenshotFrame["PLAYER_REGEN_DISABLED"] = function(self)
	if self:IsShown() then
		UIParent:Show()
		self:Hide()
	end
end

TH_ScreenshotFrame:SetScript("OnEvent", function(self, event, ...)
	self[event](self, ...)
end)