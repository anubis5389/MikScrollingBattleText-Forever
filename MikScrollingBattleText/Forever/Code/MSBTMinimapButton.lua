-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text Minimap Button
-- Author: Mikord
-------------------------------------------------------------------------------

local module = {}
local moduleName = "MinimapButton"
MikSBT[moduleName] = module


-------------------------------------------------------------------------------
-- Imports.
-------------------------------------------------------------------------------

local L = MikSBT.translations


-------------------------------------------------------------------------------
-- Private constants.
-------------------------------------------------------------------------------

local ICON_PATH = "Interface\\AddOns\\MikScrollingBattleText\\Artwork\\MinimapIcon"
local DEFAULT_ANGLE = 225
local RADIUS_PADDING = 6


-------------------------------------------------------------------------------
-- Private variables.
-------------------------------------------------------------------------------

local button
local isDragging = false


-- ****************************************************************************
-- Returns the saved minimap button settings, creating them if necessary.
-- ****************************************************************************
local function GetSavedSettings()
	MSBTProfiles_SavedVars.minimapButton = MSBTProfiles_SavedVars.minimapButton or {}
	return MSBTProfiles_SavedVars.minimapButton
end


-- ****************************************************************************
-- Repositions the button around the minimap based on its saved angle.
-- ****************************************************************************
local function UpdatePosition()
	local angle = math.rad(GetSavedSettings().angle or DEFAULT_ANGLE)
	local radius = (Minimap:GetWidth() / 2) + RADIUS_PADDING
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", radius * math.cos(angle), radius * math.sin(angle))
end


-- ****************************************************************************
-- Called continuously while the button is being dragged.
-- ****************************************************************************
local function OnUpdate()
	if (not isDragging) then return end

	local mx, my = Minimap:GetCenter()
	local px, py = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	px, py = px / scale, py / scale

	GetSavedSettings().angle = math.deg(math.atan2(py - my, px - mx))
	UpdatePosition()
end


-- ****************************************************************************
-- Toggles the main options frame when the button is clicked.
-- ****************************************************************************
local function OnClick(this, mouseButton)
	if (MSBTMainOptionsFrame and MSBTMainOptionsFrame:IsShown()) then
		MSBTOptions.Main.HideMainFrame()
	else
		MSBTOptions.Main.ShowMainFrame()
	end
end


-- ****************************************************************************
-- Shows a themed tooltip for the button.
-- ****************************************************************************
local function OnEnter(this)
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	GameTooltip:AddLine("Mik's Scrolling Battle Text")
	GameTooltip:AddLine(L.MSG_MINIMAP_BUTTON_TOOLTIP, 0.7, 0.7, 0.72, true)
	GameTooltip:Show()
end


local function OnLeave()
	GameTooltip:Hide()
end


-- ****************************************************************************
-- Creates the minimap button.
-- ****************************************************************************
local function CreateButton()
	button = CreateFrame("Button", "MSBTMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")

	-- Same frame this addon's own tooltip skin looks for on the owner's
	-- parent chain (see MSBTOptionsControls.lua's IsMSBTOwned/SkinTooltip),
	-- so the minimap button's tooltip matches the rest of the interface too.
	button.msbtThemed = true

	local icon = button:CreateTexture(nil, "BACKGROUND")
	icon:SetTexture(ICON_PATH)
	icon:SetSize(20, 20)
	-- The tracking-border ring art isn't actually centered within its own
	-- 54x54 texture (it's thicker on some sides), so centering the icon on
	-- the button itself looks visibly off - this offset instead of CENTER
	-- is the standard fix every minimap-button addon uses for that texture.
	icon:SetPoint("TOPLEFT", 7, -6)

	-- Mask the square icon into a circle to match the minimap's own
	-- rounded buttons instead of showing square corners.
	local mask = button:CreateMaskTexture()
	mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(icon)
	icon:AddMaskTexture(mask)

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(54, 54)
	border:SetPoint("TOPLEFT")

	button:SetScript("OnClick", OnClick)
	button:SetScript("OnEnter", OnEnter)
	button:SetScript("OnLeave", OnLeave)
	button:SetScript("OnDragStart", function() isDragging = true end)
	button:SetScript("OnDragStop", function() isDragging = false end)
	button:SetScript("OnUpdate", OnUpdate)

	UpdatePosition()
	button:SetShown(not GetSavedSettings().hide)
end


-------------------------------------------------------------------------------
-- Module interface.
-------------------------------------------------------------------------------

-- ****************************************************************************
-- Shows or hides the minimap button and persists the choice.
-- ****************************************************************************
local function SetShown(shown)
	if (not button) then CreateButton() end
	GetSavedSettings().hide = not shown
	button:SetShown(shown)
end


-- ****************************************************************************
-- Returns whether the minimap button is currently shown.
-- ****************************************************************************
local function IsShown()
	return button and button:IsShown() or false
end


-- Protected functions.
module.SetShown	= SetShown
module.IsShown	= IsShown


-------------------------------------------------------------------------------
-- Initialization.
-------------------------------------------------------------------------------

-- Deferred to ADDON_LOADED (and, importantly, registered after
-- MSBTProfiles.lua so its handler runs first) instead of running directly
-- at file scope, since MSBTProfiles_SavedVars doesn't exist yet on a fresh
-- install until MSBTProfiles.lua's own ADDON_LOADED handler creates it -
-- touching it any earlier would pre-empt that setup.
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(this, event, arg1)
	if (arg1 ~= "MikScrollingBattleText") then return end
	this:UnregisterEvent("ADDON_LOADED")
	if (not GetSavedSettings().hide) then CreateButton() end
end)
