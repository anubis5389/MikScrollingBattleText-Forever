-------------------------------------------------------------------------------
-- Title: MSBT Options Main
-- Author: Mikord
-------------------------------------------------------------------------------

local module = {}
local moduleName = "Main"
MSBTOptions[moduleName] = module

local IsClassic = MikSBT.Client.isClassicContent


-------------------------------------------------------------------------------
-- Imports.
-------------------------------------------------------------------------------

-- Local references to various modules for faster access.
local Theme = MSBTOptions.Theme
local L = MikSBT.translations


-------------------------------------------------------------------------------
-- Constants.
-------------------------------------------------------------------------------

local WINDOW_TITLE = "Mik's Scrolling Battle Text " .. MikSBT.VERSION_STRING
local ADDON_NAME = "MikScrollingBattleText"

-- Resource read-out APIs (ported from ../Nucleus's UI/OptionsFrame.lua):
-- C_AddOnProfiler is always on (no scriptProfiling CVar needed), and both
-- it and the memory functions are looked up defensively since neither is
-- guaranteed to exist on every client.
local Prof = _G.C_AddOnProfiler
local CPU_METRIC = Enum and Enum.AddOnProfilerMetric and Enum.AddOnProfilerMetric.RecentAverageTime
local GetMem = _G.GetAddOnMemoryUsage or (C_AddOns and C_AddOns.GetAddOnMemoryUsage)
local UpdMem = _G.UpdateAddOnMemoryUsage or (C_AddOns and C_AddOns.UpdateAddOnMemoryUsage)


-------------------------------------------------------------------------------
-- Private variables.
-------------------------------------------------------------------------------

-- Prevent tainting global _.
local _

-- The main options frame.
local mainFrame

-- Holds all registered popup frames.
local popupFrames = {}

-- Tab info: { tabKey, frame, button, searchText }, 1:1 with ../KeyHerald's
-- GUI.tabs. Populated at file-load time by AddTab(); InitTab() resolves
-- label/tooltip/search text from L fresh once CreateMainFrame() runs,
-- since that's the earliest point the language override is known.
local tabData = {}
local rail
local indicator
local activeIndex
local searchInput

-- Set by Tabs.lua, which owns the per-tab search keyword data.
local searchTextBuilder

-- Resource read-out (bottom-right corner).
local statsText
local statsTicker

-- Scheduling variables.
local waitTable = {}
local waitFrame = nil


-------------------------------------------------------------------------------
-- Tab functions.
-------------------------------------------------------------------------------

local SelectTab

-- ****************************************************************************
-- Initializes the nav button and content frame for one tab
-- (../KeyHerald's GUI:AddTab).
-- ****************************************************************************
local function InitTab(tabInfo, index)
	-- Resolved fresh from L here, not at AddTab() time: each localization
	-- file replaces L.TABS[key] with a brand new table, so a reference
	-- captured earlier would go stale once the language is re-resolved.
	local objLocale = L.TABS[tabInfo.tabKey]
	tabInfo.searchText = searchTextBuilder and searchTextBuilder(tabInfo.tabKey)

	-- Nav button in the rail.
	local btn = CreateFrame("Button", nil, rail)
	btn:SetHeight(Theme.ROW_H)
	btn:SetPoint("TOPLEFT", 1, -6 - (index - 1) * Theme.ROW_H)
	btn:SetPoint("TOPRIGHT", -1, 0)

	local hl = btn:CreateTexture(nil, "BACKGROUND")
	hl:SetAllPoints()
	do
		local r, g, b = Theme:GetHighlightColor()
		hl:SetColorTexture(r, g, b, 0)
	end

	local t = Theme:FontString(btn, 12)
	t:SetPoint("LEFT", 12, 0)
	t:SetText(objLocale.label)
	btn.text = t
	btn.hl = hl
	btn.tabIndex = index

	btn:SetScript("OnEnter", function()
		if activeIndex ~= index then
			local r, g, b = Theme:GetHighlightColor()
			hl:SetColorTexture(r, g, b, 0.08)
		end
		if objLocale.tooltip then
			GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
			GameTooltip:SetText(objLocale.tooltip, nil, nil, nil, nil, 1)
		end
	end)
	btn:SetScript("OnLeave", function()
		if activeIndex ~= index then hl:SetColorTexture(0, 0, 0, 0) end
		GameTooltip:Hide()
	end)
	btn:SetScript("OnClick", function() SelectTab(index) end)
	tabInfo.button = btn

	-- Content frame, filling the area to the right of the rail. Bottom edge
	-- leaves a thin strip clear for the resource read-out (see
	-- CreateMainFrame's statsText) so tab content never sits under it.
	local frame = tabInfo.frame
	frame:SetParent(mainFrame)
	frame:SetPoint("TOPLEFT", rail, "TOPRIGHT", 12, 0)
	frame:SetPoint("BOTTOMRIGHT", -Theme.PAD, Theme.PAD + 14)
	frame:Hide()
end


-- ****************************************************************************
-- Adds a new tab to the main options frame that will show the passed frame
-- when selected.
-- ****************************************************************************
local function AddTab(frame, tabKey)
	local tabInfo = {}
	tabInfo.tabKey = tabKey
	tabInfo.frame = frame

	tabData[#tabData + 1] = tabInfo

	if (rail) then
		InitTab(tabInfo, #tabData)
	end
end


-- ****************************************************************************
-- Selects a tab by index: shows its content frame, hides the others, and
-- slides the accent indicator to the selected nav button
-- (../KeyHerald's GUI:Select).
-- ****************************************************************************
function SelectTab(index)
	activeIndex = index

	-- Clicking into a tab is done with the search box no longer relevant;
	-- an EditBox doesn't lose keyboard focus on its own just because
	-- something else was clicked, so its blinking cursor would otherwise
	-- keep showing indefinitely while browsing the tab it helped find.
	if (searchInput and searchInput:HasFocus()) then
		searchInput:ClearFocus()
	end

	-- Hide the registered popup frames.
	for frame in pairs(popupFrames) do
		frame:Hide()
	end

	for i, info in ipairs(tabData) do
		local on = i == index
		info.frame:SetShown(on)
		local r, g, b = Theme:GetHighlightColor()
		info.button.hl:SetColorTexture(r, g, b, on and 0.14 or 0)
		if on then
			info.button.text:SetTextColor(unpack(Theme.text))
			indicator:ClearAllPoints()
			indicator:SetPoint("TOPLEFT", info.button, "TOPLEFT", 0, 0)
			indicator:SetPoint("BOTTOMLEFT", info.button, "BOTTOMLEFT", 0, 0)
			indicator:Show()
		else
			info.button.text:SetTextColor(unpack(Theme.mutedText))
		end
	end
end


-- ****************************************************************************
-- Filters the nav rail down to tabs whose name or any setting in them
-- (see MSBTOptionsTabs.lua's TAB_SEARCH_KEYS) matches the query. Matching
-- tabs keep their fixed slot in the rail; non-matching ones are simply
-- hidden from it - their content and selection state are untouched, so
-- clearing the search instantly restores the full list.
-- ****************************************************************************
local function FilterTabs(query)
	query = string.lower(query or "")
	for i, info in ipairs(tabData) do
		local visible = (query == "") or (info.searchText and string.find(info.searchText, query, 1, true))
		info.button:SetShown(visible)
		if (i == activeIndex and not visible) then
			indicator:Hide()
		elseif (i == activeIndex and visible) then
			indicator:Show()
		end
	end
end


-------------------------------------------------------------------------------
-- Main options frame functions.
-------------------------------------------------------------------------------

-- ****************************************************************************
-- Called when the main options frame is hidden.
-- ****************************************************************************
local function OnHideMainFrame(this)
	PlaySound(799)
	if (searchInput and searchInput:HasFocus()) then searchInput:ClearFocus() end
	-- Hide the registered popup frames.
	for frame in pairs(popupFrames) do
		frame:Hide()
	end
	if (statsTicker) then
		statsTicker:Cancel()
		statsTicker = nil
	end
end


-- ****************************************************************************
-- Updates the CPU/memory read-out in the bottom-right corner.
-- ****************************************************************************
local function UpdateStats()
	if (not statsText) then return end
	local parts = {}

	if (Prof and Prof.GetAddOnMetric and CPU_METRIC) then
		-- pcall'd: a metric/API mismatch on a given client should drop just
		-- this one reading, not silently abort the whole update (which
		-- would leave the corner permanently blank with no indication why).
		local ok, ms = pcall(Prof.GetAddOnMetric, ADDON_NAME, CPU_METRIC)
		if (ok and ms) then
			local fps = GetFramerate and GetFramerate() or 0
			local pct = fps > 0 and (ms / (1000 / fps) * 100) or 0
			parts[#parts + 1] = string.format("%.3f ms (%.2f%%)", ms, pct)
		end
	end

	if (UpdMem and GetMem) then
		local ok, kb = pcall(function()
			UpdMem()
			return GetMem(ADDON_NAME)
		end)
		if (ok and kb) then
			parts[#parts + 1] = kb >= 1024 and string.format("%.1f MB", kb / 1024) or string.format("%.0f KB", kb)
		end
	end

	if (#parts == 0) then
		-- Neither metric is available on this client at all (seemingly the
		-- case for every Classic flavor this addon targets) - hide the
		-- read-out and stop polling instead of leaving a permanently
		-- blank/broken-looking corner or wasting a timer on retries that
		-- will never succeed this session.
		statsText:Hide()
		if (statsTicker) then
			statsTicker:Cancel()
			statsTicker = nil
		end
		return
	end

	statsText:Show()
	statsText:SetText(table.concat(parts, "   \194\183   "))
end


-- ****************************************************************************
-- Sets and persists the options window's scale. Applied to every registered
-- popup too (see RegisterPopupFrame), not just the main window, so a popup
-- doesn't look mismatched in size the moment it opens.
-- ****************************************************************************
local function SetWindowScale(scale)
	if (MSBTProfiles_SavedVars) then MSBTProfiles_SavedVars.optionsScale = scale end
	if (mainFrame) then mainFrame:SetScale(scale) end
	for frame in pairs(popupFrames) do frame:SetScale(scale) end
end

-- ****************************************************************************
-- Returns the saved window scale, or the default if none is saved yet.
-- ****************************************************************************
local function GetWindowScale()
	return (MSBTProfiles_SavedVars and MSBTProfiles_SavedVars.optionsScale) or 1
end

-- ****************************************************************************
-- Sets and persists the options window's background opacity. Only the flat
-- panel fill's alpha changes (frame:SetAlpha() would fade the text/buttons/
-- borders too, making the whole window harder to read instead of just
-- letting the background show through). Applied to every registered popup
-- too, for the same reason as SetWindowScale above.
-- ****************************************************************************
local function SetWindowAlpha(alpha)
	if (MSBTProfiles_SavedVars) then MSBTProfiles_SavedVars.optionsAlpha = alpha end
	local bg = Theme.background
	if (mainFrame) then mainFrame:SetBackdropColor(bg[1], bg[2], bg[3], alpha) end
	for frame in pairs(popupFrames) do frame:SetBackdropColor(bg[1], bg[2], bg[3], alpha) end
end

-- ****************************************************************************
-- Returns the saved window opacity, or the default if none is saved yet.
-- ****************************************************************************
local function GetWindowAlpha()
	return (MSBTProfiles_SavedVars and MSBTProfiles_SavedVars.optionsAlpha) or 1
end


-- ****************************************************************************
-- Creates the main options frame.
-- ****************************************************************************
local function CreateMainFrame()
	-- Resolve the Settings tab's language override here: this is the
	-- earliest point MSBTProfiles_SavedVars is readable, since it's still
	-- nil during every file's own load-time execution (including every
	-- localization.*.lua). Reset to English first, since a non-English
	-- pack only overwrites the keys it translates.
	if (MikSBT.localePacks) then
		if (MikSBT.localePacks["enUS"]) then MikSBT.localePacks["enUS"]() end
		local override = MSBTProfiles_SavedVars and MSBTProfiles_SavedVars.uiLanguage
		local effective = (override and override ~= "auto") and override or GetLocale()
		if (effective ~= "enUS" and MikSBT.localePacks[effective]) then
			MikSBT.localePacks[effective]()
		end
	end

	-- 1:1 ported from ../KeyHerald's GUI/MainFrame.lua buildWindow(): flat
	-- panel window, accent bar top edge, left nav rail with a sliding accent
	-- indicator, stacked content per tab - instead of the old parchment/
	-- paperdoll character-sheet border textures and a tab listbox.
	mainFrame = CreateFrame("Frame", "MSBTMainOptionsFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
	mainFrame:SetSize(Theme.WINDOW_W, Theme.WINDOW_H)
	mainFrame:SetPoint("CENTER")
	mainFrame:SetScale(GetWindowScale())
	mainFrame:SetFrameStrata("HIGH")
	mainFrame:SetToplevel(true)
	mainFrame:SetClampedToScreen(true)
	mainFrame:EnableMouse(true)
	mainFrame:SetMovable(true)
	mainFrame:RegisterForDrag("LeftButton")
	mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
	mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
	-- Clicking the window's own background (not any particular control)
	-- should also drop the search box's focus/blinking cursor, the same as
	-- switching tabs does (see SelectTab).
	mainFrame:HookScript("OnMouseDown", function()
		if (searchInput and searchInput:HasFocus()) then searchInput:ClearFocus() end
	end)
	Theme:Panel(mainFrame, Theme.background)
	do
		local bg = Theme.background
		mainFrame:SetBackdropColor(bg[1], bg[2], bg[3], GetWindowAlpha())
	end
	mainFrame.msbtThemed = true
	mainFrame:SetScript("OnHide", OnHideMainFrame)
	mainFrame:SetScript("OnShow", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
		UpdateStats()
		statsTicker = C_Timer.NewTicker(2, UpdateStats)
	end)

	local bar = Theme:AccentBar(mainFrame, 2)
	bar:SetPoint("TOPLEFT", 1, -1)
	bar:SetPoint("TOPRIGHT", -1, -1)

	local title = mainFrame:CreateFontString(nil, "OVERLAY")
	title:SetFontObject(Theme.font.title)
	title:SetPoint("TOPLEFT", Theme.PAD, -12)
	title:SetText(WINDOW_TITLE)

	local close = Theme:CloseButton(mainFrame, function() mainFrame:Hide() end)
	close:SetPoint("TOPRIGHT", -12, -12)

	local hd = Theme:Divider(mainFrame)
	hd:SetPoint("TOPLEFT", Theme.PAD, -42)
	hd:SetPoint("TOPRIGHT", -Theme.PAD, -42)

	-- Search box: filters the nav rail down to tabs whose name or any
	-- setting in them matches, so a specific option can be found without
	-- knowing which of the 9 tabs it lives in.
	local searchBox = CreateFrame("Frame", nil, mainFrame, BackdropTemplateMixin and "BackdropTemplate")
	searchBox:SetHeight(24)
	searchBox:SetPoint("TOPLEFT", Theme.PAD, -52)
	searchBox:SetPoint("TOPRIGHT", -Theme.PAD, -52)
	Theme:Panel(searchBox, Theme.fill)

	searchInput = CreateFrame("EditBox", nil, searchBox)
	searchInput:SetAutoFocus(false)
	searchInput:SetFontObject(Theme.font.small)
	searchInput:SetTextInsets(8, 8, 0, 0)
	searchInput:SetTextColor(unpack(Theme.text))
	searchInput:SetAllPoints(searchBox)
	searchInput:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
	end)
	searchInput:SetScript("OnEnterPressed", searchInput.ClearFocus)

	local searchPlaceholder = searchBox:CreateFontString(nil, "OVERLAY")
	searchPlaceholder:SetFontObject(Theme.font.small)
	searchPlaceholder:SetPoint("LEFT", 8, 0)
	searchPlaceholder:SetTextColor(unpack(Theme.mutedText))
	searchPlaceholder:SetText(L.MSG_SEARCH_TABS)

	searchInput:SetScript("OnTextChanged", function(self)
		local text = self:GetText()
		searchPlaceholder:SetShown(text == "")
		FilterTabs(text)
	end)

	rail = CreateFrame("Frame", nil, mainFrame, BackdropTemplateMixin and "BackdropTemplate")
	Theme:Panel(rail, Theme.rail)
	rail:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -6)
	rail:SetPoint("BOTTOMLEFT", Theme.PAD, Theme.PAD)
	rail:SetWidth(Theme.RAIL_W)

	indicator = rail:CreateTexture(nil, "OVERLAY")
	indicator:SetSize(2, Theme.ROW_H)
	do
		local r, g, b = Theme:GetHighlightColor()
		indicator:SetColorTexture(r, g, b)
	end
	Theme:OnHighlightColorChanged(function(r, g, b) indicator:SetColorTexture(r, g, b) end)
	indicator:Hide()

	-- Resource read-out (bottom-right corner, ../Nucleus's OptionsFrame.lua
	-- style): this addon's own CPU time per frame and memory footprint.
	statsText = mainFrame:CreateFontString(nil, "OVERLAY")
	statsText:SetFontObject(Theme.font.small)
	statsText:SetPoint("BOTTOMRIGHT", -Theme.PAD, Theme.PAD / 2)
	statsText:SetJustifyH("RIGHT")
	statsText:SetTextColor(unpack(Theme.mutedText))

	-- Realize every tab registered so far via AddTab() (Tabs.lua calls it at
	-- file-load time, before this frame exists).
	for index, tabInfo in ipairs(tabData) do
		InitTab(tabInfo, index)
	end

	SelectTab(2)   -- General tab

	-- Insert the frame name into the UISpecialFrames array so it closes when
	-- the escape key is pressed.
	--table.insert(UISpecialFrames, mainFrame:GetName())
end


-- ****************************************************************************
-- Shows the main options frame after creating it (if it hasn't already been).
-- ****************************************************************************
local function ShowMainFrame()
	if (not mainFrame) then CreateMainFrame() end
	if (not MSBTScrollAreasConfigFrame or not MSBTScrollAreasConfigFrame:IsShown()) then
		mainFrame:Show()
	end
end


-- ****************************************************************************
-- Hides the main options frame.
-- ****************************************************************************
local function HideMainFrame()
	mainFrame:Hide()
end


-- ****************************************************************************
-- Registers frames that float above the main options window.
-- These frames will be hidden when a tab is selected or the main options
-- window is hidden.
-- ****************************************************************************
local function RegisterPopupFrame(frame)
	if (not popupFrames[frame]) then
		popupFrames[frame] = true
		-- Popups are created lazily on first use, potentially long after the
		-- window scale/opacity sliders were last touched - apply the saved
		-- values immediately instead of leaving it at the default until the
		-- user happens to move a slider again.
		frame:SetScale(GetWindowScale())
		local bg = Theme.background
		frame:SetBackdropColor(bg[1], bg[2], bg[3], GetWindowAlpha())
	end
end


-------------------------------------------------------------------------------
-- Scheduling functions.
-------------------------------------------------------------------------------

-- ****************************************************************************
-- Registers frames that float above the main options window.
-- These frames will be hidden when a tab is selected or the main options
-- window is hidden.
-- ****************************************************************************
local function ScheduleCallback(delay, func, ...)
	if (waitFrame == nil) then
		waitFrame = CreateFrame("Frame", nil, UIParent)
		waitFrame:SetScript("OnUpdate",function (self, elapsed)
			local count = #waitTable
			local i = 1
			while (i <= count) do
				local waitRecord = tremove(waitTable, i)
				local duration = tremove(waitRecord, 1)
				local func = tremove(waitRecord, 1)
				local params = tremove(waitRecord, 1)
				if (duration > elapsed) then
					tinsert(waitTable, i, {duration - elapsed, func, params})
					i = i + 1
				else
					count = count - 1
					func(unpack(params))
				end
			end
		end)
	end
	tinsert(waitTable, {delay, func, {...}})
	return true
end


-------------------------------------------------------------------------------
-- Layout function.
-------------------------------------------------------------------------------

local STACK_GAP = 8

-- ****************************************************************************
-- Places widget in page, full width, below whatever came before
-- (../KeyHerald's GUI/MainFrame.lua GUI:Stack). page._y tracks the running
-- vertical offset; reset to 0 by the tab-specific *_OnShow the first time a
-- tab is built, matching MSBT's existing lazy tabFrame.created pattern.
-- ****************************************************************************
local function Stack(page, widget, extraGap)
	page._y = page._y or 0
	widget:SetParent(page)
	widget:ClearAllPoints()
	widget:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -page._y)
	widget:SetPoint("RIGHT", page, "RIGHT", 0, 0)
	page._y = page._y + (widget:GetHeight() or Theme.ROW_H) + STACK_GAP + (extraGap or 0)
	return widget
end


-------------------------------------------------------------------------------
-- Module interface.
-------------------------------------------------------------------------------

-- Protected Functions.
module.ShowMainFrame		= ShowMainFrame
module.HideMainFrame		= HideMainFrame
module.RegisterPopupFrame	= RegisterPopupFrame
module.AddTab				= AddTab
module.SetSearchTextBuilder	= function(fn) searchTextBuilder = fn end
module.Stack				= Stack
module.ScheduleCallback		= ScheduleCallback
module.SetWindowScale		= SetWindowScale
module.GetWindowScale		= GetWindowScale
module.SetWindowAlpha		= SetWindowAlpha
module.GetWindowAlpha		= GetWindowAlpha
