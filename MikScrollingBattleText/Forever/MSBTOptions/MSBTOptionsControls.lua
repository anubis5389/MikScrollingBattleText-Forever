-------------------------------------------------------------------------------
-- Title: MSBT Options Controls
-- Author: Mikord
-------------------------------------------------------------------------------

local module = {}
local moduleName = "Controls"
MSBTOptions[moduleName] = module


-------------------------------------------------------------------------------
-- Private variables.
-------------------------------------------------------------------------------

-- Prevent tainting global _.
local _

-- Emphasis shown when a listbox entry is moused over.
local emphasizeFrame

-- Listbox used for dropdowns.
local dropdownListboxFrame

-- Used for correctly calculating string widths.
local calcFontString


-------------------------------------------------------------------------------
-- Theme: 1:1 ported from ../KeyHerald's GUI/Skin.lua + GUI/Widgets.lua design
-- system - flat BackdropTemplate surfaces, 1px black borders, a single
-- accent color, Blizzard's own STANDARD_TEXT_FONT wrapped in sized/shadowed
-- font objects rather than a bundled custom font. Every widget factory below
-- reads from this instead of Blizzard's default button/checkbox/slider
-- textures, so restyling the theme here restyles every tab and popup that
-- uses these widgets.
-------------------------------------------------------------------------------
local Theme = {}
MSBTOptions.Theme = Theme

-- A 1x1 white texture that ships with the client; tinted to make flat-
-- colored panels without needing custom art files (KeyHerald's S.color.white).
local FLAT_TEXTURE = "Interface\\Buttons\\WHITE8x8"
Theme.flatTexture = FLAT_TEXTURE

-- KeyHerald's GUI/Skin.lua S.color, renamed where MSBT's widget code below
-- already used a different field name for the same role.
Theme.background   = {0.067, 0.067, 0.082, 0.96}	-- window background (KeyHerald: window)
Theme.panel        = {0.14, 0.14, 0.17, 1.00}	-- generic button fill (KeyHerald: Button rest state)
Theme.panelHover   = {0.16, 0.16, 0.19, 1.00}	-- KeyHerald: panelHover
Theme.rail         = {0.086, 0.086, 0.10, 1.00}	-- sidebar background
Theme.fill         = {0.04, 0.04, 0.05, 1.00}	-- inset fields (checkbox/slider/dropdown/editbox)
Theme.border       = {0, 0, 0, 1}	-- hard black border, KeyHerald-style
Theme.borderSoft   = {1, 1, 1, 0.06}
Theme.text         = {0.90, 0.90, 0.92, 1.00}
Theme.mutedText    = {0.55, 0.55, 0.60, 1.00}	-- KeyHerald: textDim
Theme.disabledText = {0.40, 0.40, 0.44, 1.00}

-- Window/layout constants (KeyHerald: S.WINDOW_W/H, S.RAIL_W, S.PAD, S.ROW_H).
Theme.WINDOW_W = 680
Theme.WINDOW_H = 620
Theme.RAIL_W = 150
Theme.PAD = 16
Theme.ROW_H = 26

-- Default highlight/accent color; overridden by the saved one, if any, below.
-- KeyHerald defaults to a violet (0.71, 0.36, 1.00); kept here as the
-- fallback default, still fully user-changeable via the swatch. Exposed on
-- Theme so the Settings tab's "reset accent color" button can restore it.
Theme.DEFAULT_HIGHLIGHT = {0.71, 0.36, 1.00}
local highlight = {0.71, 0.36, 1.00}
local highlightListeners = {}

local function LoadSavedHighlightColor()
	local saved = MSBTProfiles_SavedVars and MSBTProfiles_SavedVars.optionsTheme
	if saved and saved.r and saved.g and saved.b then
		highlight[1], highlight[2], highlight[3] = saved.r, saved.g, saved.b
	end
end
LoadSavedHighlightColor()

-- ****************************************************************************
-- Returns the current highlight/accent color as r, g, b.
-- ****************************************************************************
function Theme:GetHighlightColor()
	return highlight[1], highlight[2], highlight[3]
end

-- ****************************************************************************
-- Sets and persists the highlight/accent color, and notifies every widget
-- that registered via OnHighlightColorChanged() (e.g. an already-visible
-- checked checkbox needs to re-tint immediately).
-- ****************************************************************************
function Theme:SetHighlightColor(r, g, b)
	highlight[1], highlight[2], highlight[3] = r, g, b
	if MSBTProfiles_SavedVars then
		local saved = MSBTProfiles_SavedVars.optionsTheme or {}
		saved.r, saved.g, saved.b = r, g, b
		MSBTProfiles_SavedVars.optionsTheme = saved
	end
	for _, listener in ipairs(highlightListeners) do
		listener(r, g, b)
	end
end

-- ****************************************************************************
-- Registers a callback invoked whenever the highlight color changes.
-- ****************************************************************************
function Theme:OnHighlightColorChanged(listener)
	highlightListeners[#highlightListeners + 1] = listener
end

-- ****************************************************************************
-- Font objects (KeyHerald's Skin.lua mkFont): Blizzard's own STANDARD_TEXT_FONT
-- wrapped at different sizes with a text shadow, rather than a bundled custom
-- font file - avoids any custom-font-loading/width-measurement timing issues
-- entirely, and matches KeyHerald exactly.
-- ****************************************************************************
local function mkFont(name, size, flags)
	local f = CreateFont("MSBTOptionsFont_" .. name)
	f:SetFont(STANDARD_TEXT_FONT, size, flags or "")
	f:SetTextColor(unpack(Theme.text))
	f:SetShadowColor(0, 0, 0, 1)
	f:SetShadowOffset(1, -1)
	return f
end
Theme.font = {
	title  = mkFont("Title", 15),
	normal = mkFont("Normal", 12),
	small  = mkFont("Small", 11),
	header = mkFont("Header", 11, "OUTLINE"),
}
do
	local r, g, b = Theme:GetHighlightColor()
	Theme.font.header:SetTextColor(r, g, b)
end
Theme:OnHighlightColorChanged(function(r, g, b)
	Theme.font.header:SetTextColor(r, g, b)
end)

-- ****************************************************************************
-- Creates a themed FontString using the normal font object.
-- ****************************************************************************
function Theme:FontString(parent, size, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	if size and size ~= 12 then
		fs:SetFont(STANDARD_TEXT_FONT, size, "")
		fs:SetShadowColor(0, 0, 0, 1)
		fs:SetShadowOffset(1, -1)
		fs:SetTextColor(unpack(Theme.text))
	else
		fs:SetFontObject(Theme.font.normal)
	end
	return fs
end

-- ****************************************************************************
-- Solid panel with a 1px black border (KeyHerald's S.Panel). frame must be
-- created with "BackdropTemplate" as its template arg.
-- ****************************************************************************
function Theme:Panel(frame, bgColor)
	frame:SetBackdrop({ bgFile = FLAT_TEXTURE, edgeFile = FLAT_TEXTURE, edgeSize = 1 })
	local c = bgColor or Theme.panel
	frame:SetBackdropColor(c[1], c[2], c[3], c[4] or 1)
	frame:SetBackdropBorderColor(unpack(Theme.border))
	return frame
end

-- ****************************************************************************
-- A 1px hairline divider (KeyHerald's S.Divider).
-- ****************************************************************************
function Theme:Divider(parent)
	local t = parent:CreateTexture(nil, "ARTWORK")
	t:SetTexture(FLAT_TEXTURE)
	t:SetVertexColor(1, 1, 1, 0.07)
	t:SetHeight(1)
	return t
end

-- ****************************************************************************
-- Attaches a GameTooltip (title + wrapped body) on hover.
-- ****************************************************************************
function Theme:Tooltip(frame, title, body)
	if not title and not body then return end
	frame._themeTipTitle, frame._themeTipBody = title, body
	frame:HookScript("OnEnter", function(self)
		if not self._themeTipTitle and not self._themeTipBody then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 8, 0)
		if self._themeTipTitle then GameTooltip:AddLine(self._themeTipTitle, 1, 1, 1) end
		if self._themeTipBody then GameTooltip:AddLine(self._themeTipBody, 0.7, 0.7, 0.72, true) end
		GameTooltip:Show()
	end)
	frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- ****************************************************************************
-- Minimal text "x" close button (KeyHerald's S.CloseButton) instead of
-- Blizzard's red round UIPanelCloseButton.
-- ****************************************************************************
function Theme:CloseButton(parent, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(20, 20)
	local x = b:CreateFontString(nil, "OVERLAY")
	x:SetFontObject(Theme.font.title)
	x:SetPoint("CENTER")
	x:SetText("x")
	x:SetTextColor(unpack(Theme.mutedText))
	b:SetScript("OnEnter", function()
		local r, g, b2 = Theme:GetHighlightColor()
		x:SetTextColor(r, g, b2)
	end)
	b:SetScript("OnLeave", function() x:SetTextColor(unpack(Theme.mutedText)) end)
	b:SetScript("OnClick", onClick or function() parent:Hide() end)
	return b
end

-- ****************************************************************************
-- Accent-colored horizontal gradient strip for the window's top edge
-- (KeyHerald's S.AccentBar).
-- ****************************************************************************
function Theme:AccentBar(parent, height)
	local t = parent:CreateTexture(nil, "OVERLAY")
	t:SetHeight(height or 2)
	local function paint()
		local r, g, b = Theme:GetHighlightColor()
		t:SetColorTexture(1, 1, 1, 1)
		t:SetGradient("HORIZONTAL", CreateColor(r * 0.35, g * 0.35, b * 0.35, 1), CreateColor(r, g, b, 1))
	end
	paint()
	Theme:OnHighlightColorChanged(paint)
	return t
end

-- ****************************************************************************
-- Section header: an uppercased label sitting above a hairline divider
-- (KeyHerald's W.Header) - lighter than a boxed card, no surrounding panel.
-- ****************************************************************************
function Theme:Header(parent, label)
	local f = CreateFrame("Frame", nil, parent)
	f:SetHeight(22)
	local t = f:CreateFontString(nil, "OVERLAY")
	t:SetFontObject(Theme.font.header)
	t:SetPoint("BOTTOMLEFT", 2, 4)
	t:SetText(string.upper(label))
	local line = Theme:Divider(f)
	line:SetPoint("BOTTOMLEFT", t, "BOTTOMRIGHT", 8, 3)
	line:SetPoint("BOTTOMRIGHT", -2, 3)
	return f
end

-- ****************************************************************************
-- Skins the shared GameTooltip to match the theme, but only while it's
-- anchored to one of MSBT's own controls (any frame in its owner's parent
-- chain has .msbtThemed set - the main window and every popup frame set
-- this). Every other tooltip in the game (items, other addons, Blizzard UI)
-- is left completely untouched, and is restored to its normal Blizzard skin
-- the moment it's no longer ours.
-- ****************************************************************************
local function IsMSBTOwned(frame)
	while frame do
		if frame.msbtThemed then return true end
		frame = frame.GetParent and frame:GetParent()
	end
	return false
end

-- GameTooltip:SetBackdrop() turned out to have no visible effect at all on
-- this client (BackdropTemplateMixin isn't actually driving its look), so
-- hiding NineSlice alone left plain text floating with nothing behind it.
-- A manually created texture, lazily built once and reused, works on any
-- frame regardless of that, so the fill no longer depends on SetBackdrop.
local ttBg, ttBorder

local function SkinTooltip(self)
	if self.NineSlice then self.NineSlice:Hide() end

	if not ttBg then
		-- Outer (border color, bigger) drawn first, inner (fill color,
		-- inset 1px) drawn on top of it via a higher BACKGROUND sublevel -
		-- a 1px border made of two flat rectangles instead of an edge file.
		ttBorder = self:CreateTexture(nil, "BACKGROUND", nil, 0)
		ttBorder:SetPoint("TOPLEFT", -5, 5)
		ttBorder:SetPoint("BOTTOMRIGHT", 5, -5)
		ttBorder:SetTexture(FLAT_TEXTURE)

		ttBg = self:CreateTexture(nil, "BACKGROUND", nil, 1)
		ttBg:SetPoint("TOPLEFT", ttBorder, "TOPLEFT", 1, -1)
		ttBg:SetPoint("BOTTOMRIGHT", ttBorder, "BOTTOMRIGHT", -1, 1)
		ttBg:SetTexture(FLAT_TEXTURE)
	end
	ttBg:SetVertexColor(unpack(Theme.background))
	ttBorder:SetVertexColor(unpack(Theme.border))
	ttBg:Show()
	ttBorder:Show()
end

local function UnskinTooltip(self)
	if self.NineSlice then self.NineSlice:Show() end
	if ttBg then ttBg:Hide() end
	if ttBorder then ttBorder:Hide() end
end

local ttSkinned
GameTooltip:HookScript("OnShow", function(self)
	if IsMSBTOwned(self:GetOwner()) then
		SkinTooltip(self)
		ttSkinned = true
	elseif ttSkinned then
		UnskinTooltip(self)
		ttSkinned = false
	end
end)
GameTooltip:HookScript("OnHide", function(self)
	if ttSkinned then
		UnskinTooltip(self)
		ttSkinned = false
	end
end)


-------------------------------------------------------------------------------
-- Listbox functions.
-------------------------------------------------------------------------------

-- ****************************************************************************
-- Shows the highlight frame over the passed line.
-- ****************************************************************************
local function Listbox_ShowHighlight(this, line)
	local highlight = this.highlightFrame
	highlight:ClearAllPoints()
	highlight:SetParent(line)
	-- A frame created with no parent (as highlightFrame is, in CreateListbox)
	-- defaults to "MEDIUM" strata and keeps it even after being reparented
	-- here, regardless of the listbox's own (possibly much higher) strata -
	-- so it needs to be matched explicitly every time it's placed.
	highlight:SetFrameStrata(this:GetFrameStrata())
	highlight:SetPoint("TOPLEFT")
	highlight:SetPoint("BOTTOMRIGHT")
	highlight:Show()

	if (emphasizeFrame:GetParent() == line) then emphasizeFrame:Hide() end
end


-- ****************************************************************************
-- Shows or hides the scroll bar and resizes the display area as necessary.
-- ****************************************************************************
local function Listbox_HandleScrollbar(this)
	-- Show or hide the scroll bar if there are more items than will fit on the page.
	local display = this.displayFrame
	local slider = this.sliderFrame
	if (#this.items <= #this.lines) then
		slider:Hide()
		display:SetPoint("BOTTOMRIGHT")
	else
		display:SetPoint("BOTTOMRIGHT", display:GetParent(), "BOTTOMRIGHT", -16, 0)
		slider:Show()
	end
end


-- ****************************************************************************
-- Returns whether the listbox is fully configured.
-- ****************************************************************************
local function Listbox_IsConfigured(this)
	return this.configured and this.lineHandler and this.displayHandler
end


-- ****************************************************************************
-- Returns the current offset.
-- ****************************************************************************
local function Listbox_GetOffset(this)
	return this.sliderFrame:GetValue()
end


-- ****************************************************************************
-- Returns the current offset.
-- ****************************************************************************
local function Listbox_SetOffset(this, offset)
	this.sliderFrame:SetValue(offset)
end


-- ****************************************************************************
-- Called when the listbox needs to be refreshed.
-- ****************************************************************************
local function Listbox_Refresh(this)
	-- Don't do anything if the listbox isn't configured.
	if (not Listbox_IsConfigured(this)) then return end

	-- Handle scroll bar showing / resizing.
	Listbox_HandleScrollbar(this)

	-- Hide the highlight.
	this.highlightFrame:Hide()

	-- Show or hide the correct lines depending on how many items there are and
	-- apply a highlight to the selected item.
	local selectedItem = this.selectedItem
	local isSelected
	for lineNum, line in ipairs(this.lines) do
		if (lineNum > #this.items) then
			line:Hide()
		else
			line.itemNumber = lineNum + Listbox_GetOffset(this)
			line:Show()

			-- Move the highlight to the selected line and show it.
			if (selectedItem == line.itemNumber) then
				Listbox_ShowHighlight(this, line)
		isSelected = true
			else
				isSelected = false
			end

			if (this.displayHandler) then this:displayHandler(line, this.items[line.itemNumber], isSelected) end
		end
	end
end


-- ****************************************************************************
-- Called when the listbox is scrolled up.
-- ****************************************************************************
local function Listbox_ScrollUp(this)
	local slider = this.sliderFrame
	slider:SetValue(slider:GetValue() - slider:GetValueStep())
end


-- ****************************************************************************
-- Called when the listbox is scrolled down.
-- ****************************************************************************
local function Listbox_ScrollDown(this)
	local slider = this.sliderFrame
	slider:SetValue(slider:GetValue() + slider:GetValueStep())
end


-- ****************************************************************************
-- Called when one of the lines in the listbox is clicked.
-- ****************************************************************************
local function Listbox_OnClickLine(this)
	local listbox = this:GetParent():GetParent()
	listbox.selectedItem = this.lineNumber + Listbox_GetOffset(listbox)

	Listbox_ShowHighlight(listbox, this)

	if (listbox.clickHandler) then listbox:clickHandler(this, listbox.items[listbox.selectedItem]) end
end


-- ****************************************************************************
-- Called when the mouse enters a line.
-- ****************************************************************************
local function Listbox_OnEnterLine(this)
	local listbox = this:GetParent():GetParent()
	if (this.itemNumber ~= listbox.selectedItem) then
		emphasizeFrame:ClearAllPoints()
		emphasizeFrame:SetParent(this)
		-- See the matching note in Listbox_ShowHighlight: emphasizeFrame has
		-- no parent at creation time, so its strata must be reasserted here.
		emphasizeFrame:SetFrameStrata(listbox:GetFrameStrata())
		emphasizeFrame:SetPoint("TOPLEFT")
		emphasizeFrame:SetPoint("BOTTOMRIGHT")
		emphasizeFrame:Show()
	end

	if (this.tooltip) then
		GameTooltip:SetOwner(this, this.tooltipAnchor or "ANCHOR_RIGHT")
		GameTooltip:SetText(this.tooltip, nil, nil, nil, nil, 1)
	end
end


-- ****************************************************************************
-- Called when the mouse leaves a line.
-- ****************************************************************************
local function Listbox_OnLeaveLine(this)
	emphasizeFrame:Hide()
	GameTooltip:Hide()
end


-- ****************************************************************************
-- Called when the scroll up button is pressed.
-- ****************************************************************************
local function Listbox_OnClickUp(this)
	local listbox = this:GetParent():GetParent()
	Listbox_ScrollUp(listbox)
	PlaySound(826)
end


-- ****************************************************************************
-- Called when the scroll down button is pressed.
-- ****************************************************************************
local function Listbox_OnClickDown(this)
	local listbox = this:GetParent():GetParent()
	Listbox_ScrollDown(listbox)
	PlaySound(827)
end


-- ****************************************************************************
-- Called when the mouse wheel is scrolled in the display frame.
-- ****************************************************************************
local function Listbox_OnMouseWheel(this, delta)
	local listbox = this:GetParent()
	if (delta < 0) then
		Listbox_ScrollDown(listbox)
	elseif (delta > 0) then
		Listbox_ScrollUp(listbox)
	end
end


-- ****************************************************************************
-- Called when the scroll bar slider is changed.
-- ****************************************************************************
local function Listbox_OnValueChanged(this, value)
	Listbox_Refresh(this:GetParent())
end


-- ****************************************************************************
-- Creates a new line using the register create line handler.
-- ****************************************************************************
local function Listbox_CreateLine(this)
	-- Get a line from cache if there are any otherwise call the registered line
	-- handler to create a new line.
	local lineCache = this.lineCache
	local line = (#lineCache > 0) and table.remove(lineCache) or this:lineHandler()

	line:SetParent(this.displayFrame)
	line:SetHeight(this.lineHeight)
	line:ClearAllPoints()
	line:SetScript("OnClick", Listbox_OnClickLine)
	line:SetScript("OnEnter", Listbox_OnEnterLine)
	line:SetScript("OnLeave", Listbox_OnLeaveLine)

	local lines = this.lines
	if (#lines == 0) then
		line:SetPoint("TOPLEFT")
		line:SetPoint("TOPRIGHT")
	else
		line:SetPoint("TOPLEFT", lines[#lines], "BOTTOMLEFT")
		line:SetPoint("TOPRIGHT", lines[#lines], "BOTTOMRIGHT")
	end

	lines[#lines+1] = line
	line.lineNumber = #lines
end


-- ****************************************************************************
-- Reconfigures the listbox if it was already configured.
-- ****************************************************************************
local function Listbox_Reconfigure(this, width, height, lineHeight)
	-- Don't allow negative widths.
	if (width < 0) then width = 0 end

	-- Setup container frame.
	this:SetWidth(width)
	this:SetHeight(height)

	-- Setup line calculations.
	this.lineHeight = lineHeight
	this.linesPerPage = math.floor(height / lineHeight)

	-- Resize the line height of existing lines.
	for _, line in ipairs(this.lines) do
		line:SetHeight(this.lineHeight)
	end

	-- Add lines if more will fit on the page and they are needed.
	local lines = this.lines
	if (#this.items > #lines) then
		while (#lines < this.linesPerPage and #this.items > #lines) do
			Listbox_CreateLine(this)
		end
	end

	-- Remove and cache lines that will no longer fit on the page.
	local lineCache = this.lineCache
	for x = this.linesPerPage+1, #lines do
		lines[#lines]:Hide()
		lineCache[#lineCache+1] = table.remove(lines)
	end

	-- Setup slider frame.
	local slider = this.sliderFrame
	slider:Hide()
	slider:SetMinMaxValues(0, math.max(#this.items - #this.lines, 0))
	slider:SetValue(0)

	Listbox_Refresh(this)
end


-- ****************************************************************************
-- Configures the listbox.
-- ****************************************************************************
local function Listbox_Configure(this, width, height, lineHeight)
	-- Don't do anything if required parameters are invalid.
	if (not width or not height or not lineHeight) then return end

	if (Listbox_IsConfigured(this)) then Listbox_Reconfigure(this, width, height, lineHeight) return end

	-- Don't allow negative widths.
	if (width < 0) then width = 0 end

	-- Setup container frame.
	this:SetWidth(width)
	this:SetHeight(height)

	-- Setup slider frame.
	local slider = this.sliderFrame
	slider:SetMinMaxValues(0, 0)
	slider:SetValue(0)

	-- Setup line calculations.
	this.lineHeight = lineHeight
	this.linesPerPage = math.floor(height / lineHeight)

	this.configured = true
end


-- ****************************************************************************
-- Set the function to be called when a new line needs to be created. The
-- called function must return a "Button" frame.
-- ****************************************************************************
local function Listbox_SetCreateLineHandler(this, handler)
	this.lineHandler = handler
end


-- ****************************************************************************
-- Set the function to be called when a line is being displayed.
-- It is passed the line frame to be populated, and the value associated
-- with that line.
-- ****************************************************************************
local function Listbox_SetDisplayHandler(this, handler)
	this.displayHandler = handler
end


-- ****************************************************************************
-- Set the function to be called when a line in the listbox is clicked.
-- It is passed the line frame, and the value associated with that line.
-- ****************************************************************************
local function Listbox_SetClickHandler(this, handler)
	this.clickHandler = handler
end


-- ****************************************************************************
-- Returns the passed item number from the listbox.
-- ****************************************************************************
local function Listbox_GetItem(this, itemNumber)
	return this.items[itemNumber]
end


-- ****************************************************************************
-- Adds the passed item to the listbox.
-- ****************************************************************************
local function Listbox_AddItem(this, key, forceVisible)
	-- Don't do anything if the listbox isn't configured.
	if (not Listbox_IsConfigured(this)) then return end

	-- Add the passed key to the items list.
	local items = this.items
	items[#items + 1] = key

	-- Create a new line if the max number allowed per page hasn't been reached.
	local lines = this.lines
	if (#lines < this.linesPerPage) then
		Listbox_CreateLine(this)
	end

	-- Set the new max offset value.
	local maxOffset = math.max(#items - #lines, 0)
	this.sliderFrame:SetMinMaxValues(0, maxOffset)

	-- Make sure the newly added item is visible if the force flag is set.
	if (forceVisible) then Listbox_SetOffset(this, maxOffset) end

	Listbox_Refresh(this)
end


-- ****************************************************************************
-- Removes the passed item number from the listbox.
-- ****************************************************************************
local function Listbox_RemoveItem(this, itemNumber)
	-- Don't do anything if the listbox isn't configured.
	if (not Listbox_IsConfigured(this)) then return end

	local items = this.items
	table.remove(items, itemNumber)

	-- Set the new max offset value.
	this.sliderFrame:SetMinMaxValues(0, math.max(#items - #this.lines, 0))

	Listbox_Refresh(this)
end


-- ****************************************************************************
-- Returns the number of items in the listbox.
-- ****************************************************************************
local function Listbox_GetNumItems(this)
	return #this.items
end


-- ****************************************************************************
-- Returns the selected item from the listbox.
-- ****************************************************************************
local function Listbox_GetSelectedItem(this)
	if (this.selectedItem ~= 0) then return this.items[this.selectedItem] end
end


-- ****************************************************************************
-- Sets the selected item for the listbox.
-- ****************************************************************************
local function Listbox_SetSelectedItem(this, itemNumber)
	-- Don't do anything if the listbox isn't configured.
	if (not Listbox_IsConfigured(this)) then return end

	this.selectedItem = itemNumber <= #this.items and itemNumber or 0

	-- Highlight the selected line if it's visible.
	local line = this.lines[this.selectedItem - this.sliderFrame:GetValue()]
	if (line) then Listbox_ShowHighlight(this, line) end
end


-- ****************************************************************************
-- Returns the line object from the listbox.
-- ****************************************************************************
local function Listbox_GetLine(this, lineNumber)
	local lines = this.lines
	if (lineNumber <= #lines) then return lines[lineNumber] end
end


-- ****************************************************************************
-- Returns the number of lines in the listbox.
-- ****************************************************************************
local function Listbox_GetNumLines(this)
	return math.min(#this.lines, #this.items)
end


-- ****************************************************************************
-- Clears the listbox contents.
-- ****************************************************************************
local function Listbox_Clear(this)
	-- Don't do anything if the listbox isn't configured.
	if (not Listbox_IsConfigured(this)) then return end

	local items = this.items
	for k, v in ipairs(items) do
		items[k] = nil
	end

	-- Set the new max offset value.
	this.sliderFrame:SetMinMaxValues(0, 0)

	this.selectedItem = 0

	Listbox_Refresh(this)
end


-- ****************************************************************************
-- Disables the listbox.
-- ****************************************************************************
local function Listbox_Disable(this)
	this.displayFrame:EnableMouseWheel(false)
	this.sliderFrame:EnableMouse(false)
	this.upButton:Disable()
	this.downButton:Disable()
end


-- ****************************************************************************
-- Enables the listbox.
-- ****************************************************************************
local function Listbox_Enable(this)
	this.displayFrame:EnableMouseWheel(true)
	this.sliderFrame:EnableMouse(true)
	this.upButton:Enable()
	this.downButton:Enable()
end


-- ****************************************************************************
-- Creates a flat scroll button with a procedural triangle caret, matching
-- the dropdown's own caret technique (see CreateDropdown) - not Blizzard's
-- UIPanelScrollUpButtonTemplate/DownButtonTemplate chrome.
-- ****************************************************************************
local function CreateScrollButton(parent, pointUp)
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(14, 14)
	local arrow = btn:CreateTexture(nil, "ARTWORK")
	arrow:SetTexture(FLAT_TEXTURE)
	arrow:SetVertexColor(unpack(Theme.mutedText))
	arrow:SetSize(8, 5)
	arrow:SetPoint("CENTER")
	arrow:SetTexCoord(0, 1, 0, 1)
	if (pointUp) then
		arrow:SetVertexOffset(1, 4, 0)  -- UPPER_LEFT  -> top centre
		arrow:SetVertexOffset(3, -4, 0) -- UPPER_RIGHT -> top centre
	else
		arrow:SetVertexOffset(2, 4, 0)  -- LOWER_LEFT  -> bottom centre
		arrow:SetVertexOffset(4, -4, 0) -- LOWER_RIGHT -> bottom centre
	end
	btn:SetScript("OnEnter", function() arrow:SetVertexColor(unpack(Theme.text)) end)
	btn:SetScript("OnLeave", function() arrow:SetVertexColor(unpack(Theme.mutedText)) end)
	return btn
end


-- ****************************************************************************
-- Creates and returns a listbox object ready to be configured.
-- ****************************************************************************
local function CreateListbox(parent)
	-- Create the frame used to emphasize the entry the mouse is over.
	if (not emphasizeFrame) then
		emphasizeFrame = CreateFrame("Frame")

		local texture = emphasizeFrame:CreateTexture(nil, "ARTWORK")
		texture:SetTexture(FLAT_TEXTURE)
		texture:SetVertexColor(1, 1, 1, 0.06)
		texture:SetPoint("TOPLEFT", emphasizeFrame, "TOPLEFT")
		texture:SetPoint("BOTTOMRIGHT", emphasizeFrame, "BOTTOMRIGHT")
	end

	-- Create container frame.
	local listbox = CreateFrame("Frame", nil, parent)

	-- Highlight frame (selected row) - tinted with the theme's highlight color.
	local highlightRow = CreateFrame("Frame")

	local texture = highlightRow:CreateTexture(nil, "ARTWORK")
	texture:SetTexture(FLAT_TEXTURE)
	do
		local r, g, b = Theme:GetHighlightColor()
		texture:SetVertexColor(r, g, b, 0.35)
	end
	texture:SetPoint("TOPLEFT", highlightRow, "TOPLEFT")
	texture:SetPoint("BOTTOMRIGHT", highlightRow, "BOTTOMRIGHT")
	Theme:OnHighlightColorChanged(function(r, g, b)
		texture:SetVertexColor(r, g, b, 0.35)
	end)

	-- Create display area.
	local display = CreateFrame("Frame", nil, listbox)
	display:SetPoint("TOPLEFT", listbox, "TOPLEFT")
	display:SetPoint("BOTTOMRIGHT", listbox, "BOTTOMRIGHT")


	-- Create slider to track the position: a flat track with a small
	-- accent-colored thumb, matching the main Slider widget, instead of
	-- Blizzard's UI-ScrollBar-Knob texture.
	local slider = CreateFrame("Slider", nil, listbox, BackdropTemplateMixin and "BackdropTemplate")
	slider:Hide()
	slider:SetWidth(14)
	slider:SetPoint("TOPRIGHT", listbox, "TOPRIGHT", 0, -16)
	slider:SetPoint("BOTTOMRIGHT", listbox, "BOTTOMRIGHT", 0, 16)
	slider:SetBackdrop({ bgFile = FLAT_TEXTURE, edgeFile = FLAT_TEXTURE, edgeSize = 1 })
	slider:SetBackdropColor(unpack(Theme.fill))
	slider:SetBackdropBorderColor(unpack(Theme.border))
	slider:SetThumbTexture(FLAT_TEXTURE)
	do
		local thumb = slider:GetThumbTexture()
		thumb:SetSize(10, 24)
		local r, g, b = Theme:GetHighlightColor()
		thumb:SetVertexColor(r, g, b)
		Theme:OnHighlightColorChanged(function(r2, g2, b2) thumb:SetVertexColor(r2, g2, b2) end)
	end
	slider:SetValueStep(1)
	slider:SetObeyStepOnDrag(true)
	slider:SetScript("OnValueChanged", Listbox_OnValueChanged)

	-- Up button.
	local upButton = CreateScrollButton(slider, true)
	upButton:SetPoint("BOTTOM", slider, "TOP")
	upButton:SetScript("OnClick", Listbox_OnClickUp)

	-- Down button.
	local downButton = CreateScrollButton(slider, false)
	downButton:SetPoint("TOP", slider, "BOTTOM")
	downButton:SetScript("OnClick", Listbox_OnClickDown)


	-- Make it work with the mouse wheel.
	display:EnableMouseWheel(true)
	display:SetScript("OnMouseWheel", Listbox_OnMouseWheel)


	-- Extension functions.
	listbox.Configure				= Listbox_Configure
	listbox.SetCreateLineHandler	= Listbox_SetCreateLineHandler
	listbox.SetDisplayHandler		= Listbox_SetDisplayHandler
	listbox.SetClickHandler		= Listbox_SetClickHandler
	listbox.GetOffset				= Listbox_GetOffset
	listbox.SetOffset				= Listbox_SetOffset
	listbox.GetItem				= Listbox_GetItem
	listbox.AddItem				= Listbox_AddItem
	listbox.RemoveItem				= Listbox_RemoveItem
	listbox.GetNumItems			= Listbox_GetNumItems
	listbox.GetSelectedItem		= Listbox_GetSelectedItem
	listbox.SetSelectedItem		= Listbox_SetSelectedItem
	listbox.GetLine				= Listbox_GetLine
	listbox.GetNumLines			= Listbox_GetNumLines
	listbox.Refresh				= Listbox_Refresh
	listbox.Clear					= Listbox_Clear
	listbox.Disable				= Listbox_Disable
	listbox.Enable					= Listbox_Enable

	-- Track internal values.
	listbox.displayFrame = display
	listbox.sliderFrame = slider
	listbox.upButton = upButton
	listbox.downButton = downButton
	listbox.highlightFrame = highlightRow
	listbox.items = {}
	listbox.lines = {}
	listbox.lineCache = {}
	listbox.selectedItem = 0
	return listbox
end


-------------------------------------------------------------------------------
-- Checkbox functions.
-------------------------------------------------------------------------------

-- ****************************************************************************
-- Called when the internal checkbutton is clicked.
-- ****************************************************************************
local function Checkbox_OnClick(this)
	local isChecked = this:GetChecked() and true or false
	if (isChecked) then PlaySound(856) else PlaySound(857) end

	local checkbox = this:GetParent()
	if (checkbox.clickHandler) then checkbox:clickHandler(isChecked) end
end


-- ****************************************************************************
-- Called when the mouse enters the internal checkbutton.
-- ****************************************************************************
local function Checkbox_OnEnter(this)
	if (this.tooltip) then
		GameTooltip:SetOwner(this, this.tooltipAnchor or "ANCHOR_RIGHT")
		GameTooltip:SetText(this.tooltip, nil, nil, nil, nil, 1)
	end
	local r, g, b = Theme:GetHighlightColor()
	this:SetBackdropBorderColor(r, g, b, 0.8)
end


-- ****************************************************************************
-- Called when the mouse leaves the internal checkbutton.
-- ****************************************************************************
local function Checkbox_OnLeave(this)
	GameTooltip:Hide()
	this:SetBackdropBorderColor(unpack(Theme.border))
end


-- ****************************************************************************
-- Sets the label for the checkbox.
-- ****************************************************************************
local function Checkbox_SetLabel(this, label)
	local fontString = this.fontString
	fontString:SetText(label or "")
	calcFontString:SetText(label or "")
	local width = this.checkFrame:GetWidth() + calcFontString:GetStringWidth() + 6
	this:SetWidth(math.ceil(width))
end


-- ****************************************************************************
-- Sets the tooltip for the checkbox.
-- ****************************************************************************
local function Checkbox_SetTooltip(this, tooltip)
	this.checkFrame.tooltip = tooltip
end


-- ****************************************************************************
-- Configures the checkbox.
-- ****************************************************************************
local function Checkbox_Configure(this, size, label, tooltip)
	-- Don't do anything if required parameters are invalid.
	if (not size) then return end

	-- Setup the container frame.
	this:SetHeight(size)

	-- Setup the checkbox dimensions.
	local check = this.checkFrame
	check:SetWidth(size)
	check:SetHeight(size)

	-- Setup the label and tooltip.
	Checkbox_SetLabel(this, label)
	Checkbox_SetTooltip(this, tooltip)

	this.configured = true
end


-- ****************************************************************************
-- Sets the function to be called when the checkbox is clicked.
-- It is passed the checkbox and whether or not it's checked.
-- ****************************************************************************
local function Checkbox_SetClickHandler(this, handler)
	this.clickHandler = handler
end


-- ****************************************************************************
-- Returns whether or not the checkbox is checked.
-- ****************************************************************************
local function Checkbox_GetChecked(this)
	return this.checkFrame:GetChecked() and true or false
end


-- ****************************************************************************
-- Sets the checked state.
-- ****************************************************************************
local function Checkbox_SetChecked(this, isChecked)
	this.checkFrame:SetChecked(isChecked)
end


-- ****************************************************************************
-- Disables the checkbox.
-- ****************************************************************************
local function Checkbox_Disable(this)
	this.checkFrame:Disable()
	this.fontString:SetTextColor(unpack(Theme.disabledText))
end


-- ****************************************************************************
-- Enables the checkbox.
-- ****************************************************************************
local function Checkbox_Enable(this)
	this.checkFrame:Enable()
	this.fontString:SetTextColor(unpack(Theme.text))
end


-- ****************************************************************************
-- Creates and returns a checkbox object ready to be configured.
-- ****************************************************************************
local function CreateCheckbox(parent)
	-- XXX Hack to work around apparent WoW API bug not returning correct string width.
	if (not calcFontString) then
		calcFontString = Theme:FontString(UIParent, 12, "ARTWORK")
	end

	-- Create container frame.
	local checkbox = CreateFrame("Frame", nil, parent)

	-- Create check button: a flat bordered box, filled with the accent
	-- color when checked, instead of Blizzard's checkbox texture set
	-- (../KeyHerald's GUI/Widgets.lua W.CheckBox).
	local checkbutton = CreateFrame("CheckButton", nil, checkbox, BackdropTemplateMixin and "BackdropTemplate")
	checkbutton:SetPoint("TOPLEFT")
	checkbutton:SetBackdrop({ bgFile = FLAT_TEXTURE, edgeFile = FLAT_TEXTURE, edgeSize = 1 })
	checkbutton:SetBackdropColor(unpack(Theme.fill))
	checkbutton:SetBackdropBorderColor(unpack(Theme.border))

	checkbutton:SetCheckedTexture(FLAT_TEXTURE)
	local checkedTexture = checkbutton:GetCheckedTexture()
	checkedTexture:SetPoint("TOPLEFT", 3, -3)
	checkedTexture:SetPoint("BOTTOMRIGHT", -3, 3)
	do
		local r, g, b = Theme:GetHighlightColor()
		checkedTexture:SetVertexColor(r, g, b)
	end
	Theme:OnHighlightColorChanged(function(r, g, b)
		checkedTexture:SetVertexColor(r, g, b)
	end)

	checkbutton:SetDisabledCheckedTexture(FLAT_TEXTURE)
	local disabledCheckedTexture = checkbutton:GetDisabledCheckedTexture()
	disabledCheckedTexture:SetPoint("TOPLEFT", 3, -3)
	disabledCheckedTexture:SetPoint("BOTTOMRIGHT", -3, 3)
	disabledCheckedTexture:SetVertexColor(unpack(Theme.disabledText))

	checkbutton:SetScript("OnClick", Checkbox_OnClick)
	checkbutton:SetScript("OnEnter", Checkbox_OnEnter)
	checkbutton:SetScript("OnLeave", Checkbox_OnLeave)

	-- Label.
	local fontString = Theme:FontString(checkbox, 12)
	fontString:SetPoint("LEFT", checkbutton, "RIGHT", 6, 0)
	fontString:SetPoint("RIGHT", checkbox, "RIGHT", 0, 0)
	fontString:SetJustifyH("LEFT")
	fontString:SetTextColor(unpack(Theme.text))


	-- Extension functions.
	checkbox.Configure			= Checkbox_Configure
	checkbox.SetLabel			= Checkbox_SetLabel
	checkbox.SetTooltip		= Checkbox_SetTooltip
	checkbox.SetClickHandler	= Checkbox_SetClickHandler
	checkbox.GetChecked		= Checkbox_GetChecked
	checkbox.SetChecked		= Checkbox_SetChecked
	checkbox.Disable			= Checkbox_Disable
	checkbox.Enable			= Checkbox_Enable

	-- Track internal values.
	checkbox.checkFrame = checkbutton
	checkbox.fontString = fontString
	return checkbox
end



-------------------------------------------------------------------------------
-- Button functions.
-------------------------------------------------------------------------------

-- ****************************************************************************
-- Called when the button is clicked.
-- ****************************************************************************
local function Button_OnClick(this)
	PlaySound(856)
	if (this.clickHandler) then this:clickHandler() end
end


-- ****************************************************************************
-- Called when the mouse enters the button.
-- ****************************************************************************
local function Button_OnEnter(this)
	if (this.tooltip) then
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetText(this.tooltip, nil, nil, nil, nil, 1)
	end
	if (this.isPanelButton) then
		local r, g, b = Theme:GetHighlightColor()
		this:SetBackdropColor(r * 0.5, g * 0.5, b * 0.5, 1)
		this:SetBackdropBorderColor(r, g, b, 0.9)
	end
end


-- ****************************************************************************
-- Called when the mouse leaves the button.
-- ****************************************************************************
local function Button_OnLeave(this)
	GameTooltip:Hide()
	if (this.isPanelButton) then
		this:SetBackdropColor(0.14, 0.14, 0.17, 1)
		this:SetBackdropBorderColor(unpack(Theme.border))
	end
end


-- ****************************************************************************
-- Sets the tooltip for the button.
-- ****************************************************************************
local function Button_SetTooltip(this, tooltip)
	this.tooltip = tooltip
end


-- ****************************************************************************
-- Sets the function to be called when the button is clicked.
-- ****************************************************************************
local function Button_SetClickHandler(this, handler)
	this.clickHandler = handler
end



-- ****************************************************************************
-- Creates and returns a generic button object. Only used internally.
-- ****************************************************************************
local function CreateButton(parent)
	-- Create button frame.
	local button = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
	button:SetScript("OnClick", Button_OnClick)
	button:SetScript("OnEnter", Button_OnEnter)
	button:SetScript("OnLeave", Button_OnLeave)

	-- Extension functions.
	button.SetClickHandler	= Button_SetClickHandler
	button.SetTooltip	= Button_SetTooltip

	return button
end


-------------------------------------------------------------------------------
-- OptionButton functions.
-------------------------------------------------------------------------------

-- ****************************************************************************
-- Set the label for the option button.
-- ****************************************************************************
local function OptionButton_SetLabel(this, label)
	this:SetText(label or "")
	this:SetWidth(this:GetFontString():GetStringWidth() + 50)
end


-- ****************************************************************************
-- Configures the option button.
-- ****************************************************************************
local function OptionButton_Configure(this, height, label, tooltip)
	this:SetHeight(height)
	OptionButton_SetLabel(this, label)
	Button_SetTooltip(this, tooltip)
end


-- ****************************************************************************
-- Creates and returns a push button object ready to be configured.
-- ****************************************************************************
local function CreateOptionButton(parent)
	-- Create generic button, flat-skinned to match ../KeyHerald's
	-- GUI/Widgets.lua W.Button instead of Blizzard's panel button set.
	local button = CreateButton(parent)
	button.isPanelButton = true
	button:SetBackdrop({ bgFile = FLAT_TEXTURE, edgeFile = FLAT_TEXTURE, edgeSize = 1 })
	button:SetBackdropColor(0.14, 0.14, 0.17, 1)
	button:SetBackdropBorderColor(unpack(Theme.border))

	local fontString = button:CreateFontString(nil, "OVERLAY")
	fontString:SetPoint("CENTER")
	fontString:SetFontObject(Theme.font.normal)
	button:SetFontString(fontString)

	-- Slightly dim/brighten instead of a highlight texture (there is none).
	button:SetPushedTextOffset(0, -1)


	-- Extension functions.
	button.SetLabel			= OptionButton_SetLabel
	button.Configure		= OptionButton_Configure

	return button
end


-------------------------------------------------------------------------------
-- IconButton functions.
-------------------------------------------------------------------------------

-- ****************************************************************************
-- Creates and returns an icon button object ready to be configured.
-- ****************************************************************************
local function CreateIconButton(parent, buttonType)
	-- Create generic button.
	local button = CreateButton(parent)
	button:SetWidth(24)
	button:SetHeight(24)
	button:SetNormalTexture("Interface\\Addons\\MikScrollingBattleText\\Forever\\MSBTOptions\\Artwork\\" .. buttonType .. "Icon")
	button:SetDisabledTexture("Interface\\Addons\\MikScrollingBattleText\\Forever\\MSBTOptions\\Artwork\\" .. buttonType .. "IconDisable")
	button:SetHighlightTexture("Interface\\Addons\\MikScrollingBattleText\\Forever\\MSBTOptions\\Artwork\\" .. buttonType .. "IconHighlight")

	return button
end


-------------------------------------------------------------------------------
-- Slider functions.
-------------------------------------------------------------------------------

-- ****************************************************************************
-- Called when the value of the slider changes.
-- ****************************************************************************
local function Slider_OnValueChanged(this, value)
	local slider = this:GetParent()
	if (slider.labelText ~= "") then
		slider.labelFontString:SetText(slider.labelText .. ": " .. value)
	else
		slider.labelFontString:SetText(value)
	end

	-- Fill the track up to the current value (../KeyHerald's W.Slider).
	local minValue, maxValue = this:GetMinMaxValues()
	if maxValue > minValue then
		local pct = (value - minValue) / (maxValue - minValue)
		this.fill:SetWidth(math.max(1, pct * (this:GetWidth() - 2)))
	end

	if (slider.valueChangedHandler) then slider:valueChangedHandler(value) end
end


-- ****************************************************************************
-- Called when the mouse enters the slider.
-- ****************************************************************************
local function Slider_OnEnter(this)
	if (this.tooltip) then
		GameTooltip:SetOwner(this, this.tooltipAnchor or "ANCHOR_RIGHT")
		GameTooltip:SetText(this.tooltip, nil, nil, nil, nil, 1)
	end
end


-- ****************************************************************************
-- Called when the mouse leaves the slider.
-- ****************************************************************************
local function Slider_OnLeave(this)
	GameTooltip:Hide()
end


-- ****************************************************************************
-- Sets the label for the slider.
-- ****************************************************************************
local function Slider_SetLabel(this, label)
	this.labelText = label or ""
	if (this.labelText ~= "") then
		this.labelFontString:SetText(this.labelText .. ": " .. this:GetValue())
	else
		this.labelFontString:SetText(this:GetValue())
	end
end


-- ****************************************************************************
-- Sets the tooltip for the slider.
-- ****************************************************************************
local function Slider_SetTooltip(this, tooltip)
	this.sliderFrame.tooltip = tooltip
end


-- ****************************************************************************
-- Configures the slider.
-- ****************************************************************************
local function Slider_Configure(this, width, label, tooltip)
	this:SetWidth(width)
	Slider_SetLabel(this, label)
	Slider_SetTooltip(this, tooltip)
end


-- ****************************************************************************
-- Sets the function to be called when the value of the slider is changed.
-- It is passed the slider and the new value.
-- ****************************************************************************
local function Slider_SetValueChangedHandler(this, handler)
	this.valueChangedHandler = handler
end


-- ****************************************************************************
-- Sets the minimum and maximum values for the slider.
-- ****************************************************************************
local function Slider_SetMinMaxValues(this, minValue, maxValue)
	this.sliderFrame:SetMinMaxValues(minValue, maxValue)
end


-- ****************************************************************************
-- Sets how far the slider moves with each "tick."
-- ****************************************************************************
local function Slider_SetValueStep(this, value)
	this.sliderFrame:SetValueStep(value)
end


-- ****************************************************************************
-- Sets the current value of the slider.
-- ****************************************************************************
local function Slider_GetValue(this)
	return this.sliderFrame:GetValue()
end


-- ****************************************************************************
-- Sets the current value of the slider.
-- ****************************************************************************
local function Slider_SetValue(this, value)
	this.sliderFrame:SetValue(value)
end


-- ****************************************************************************
-- Disables the slider.
-- ****************************************************************************
local function Slider_Disable(this)
	this.sliderFrame:EnableMouse(false)
	this.labelFontString:SetTextColor(unpack(Theme.disabledText))
end


-- ****************************************************************************
-- Enables the slider.
-- ****************************************************************************
local function Slider_Enable(this)
	this.sliderFrame:EnableMouse(true)
	this.labelFontString:SetTextColor(unpack(Theme.text))
end


-- ****************************************************************************
-- Creates and returns a slider object ready to be configured.
-- ****************************************************************************
local function CreateSlider(parent)
	-- Create container frame. Tall enough for the label above the track to
	-- fit inside the container's own bounds instead of poking above it into
	-- whatever was stacked before this slider (the track is anchored to the
	-- bottom, leaving the top ~18px for the label).
	local slider = CreateFrame("Frame", nil, parent)
	slider:SetHeight(34)

	-- Create slider: a flat filled track with a small colored thumb instead
	-- of Blizzard's slider bar texture set (../KeyHerald's GUI/Widgets.lua
	-- W.Slider).
	local sliderFrame = CreateFrame("Slider", nil, slider, BackdropTemplateMixin and "BackdropTemplate")
	sliderFrame:SetOrientation("HORIZONTAL")
	sliderFrame:SetPoint("BOTTOMLEFT")
	sliderFrame:SetPoint("BOTTOMRIGHT")
	sliderFrame:SetHeight(12)
	sliderFrame:SetBackdrop({ bgFile = FLAT_TEXTURE, edgeFile = FLAT_TEXTURE, edgeSize = 1 })
	sliderFrame:SetBackdropColor(unpack(Theme.fill))
	sliderFrame:SetBackdropBorderColor(unpack(Theme.border))

	local fill = sliderFrame:CreateTexture(nil, "ARTWORK")
	fill:SetPoint("TOPLEFT", 1, -1)
	fill:SetPoint("BOTTOMLEFT", 1, 1)
	sliderFrame.fill = fill

	sliderFrame:SetThumbTexture(FLAT_TEXTURE)
	local thumb = sliderFrame:GetThumbTexture()
	thumb:SetSize(6, 16)
	do
		local r, g, b = Theme:GetHighlightColor()
		fill:SetVertexColor(r, g, b, 0.55)
		thumb:SetVertexColor(r, g, b)
	end
	Theme:OnHighlightColorChanged(function(r, g, b)
		fill:SetVertexColor(r, g, b, 0.55)
		thumb:SetVertexColor(r, g, b)
	end)
	sliderFrame:SetObeyStepOnDrag(true)
	sliderFrame:SetScript("OnValueChanged", Slider_OnValueChanged)
	sliderFrame:SetScript("OnEnter", Slider_OnEnter)
	sliderFrame:SetScript("OnLeave", Slider_OnLeave)


	-- Label.
	local label = Theme:FontString(slider, 12)
	label:SetPoint("BOTTOM", sliderFrame, "TOP", 0, 6)

	-- Extension functions.
	slider.Configure				= Slider_Configure
	slider.SetLabel				= Slider_SetLabel
	slider.SetTooltip				= Slider_SetTooltip
	slider.SetValueChangedHandler	= Slider_SetValueChangedHandler
	slider.SetMinMaxValues			= Slider_SetMinMaxValues
	slider.SetValueStep			= Slider_SetValueStep
	slider.GetValue				= Slider_GetValue
	slider.SetValue				= Slider_SetValue
	slider.Enable					= Slider_Enable
	slider.Disable					= Slider_Disable


	-- Track internal values.
	slider.sliderFrame = sliderFrame
	slider.labelFontString = label
	slider.labelText = ""
	return slider
end


-------------------------------------------------------------------------------
-- Dropdown functions.
-------------------------------------------------------------------------------

-- ****************************************************************************
-- Hides the dropdown listbox frame that holds the selections.
-- ****************************************************************************
local function Dropdown_HideSelections(this)
	if (dropdownListboxFrame:IsShown() and dropdownListboxFrame.dropdown == this) then
		dropdownListboxFrame:Hide()
	end
end

-- ****************************************************************************
-- Called when the mouse enters the dropdown's box. "this" is the box itself
-- (not the taller container, which also covers the label above it) so the
-- hover highlight only lights up while the mouse is exactly over the
-- visible field, not anywhere in the label's space above it.
-- ****************************************************************************
local function Dropdown_OnEnter(this)
	local dropdown = this:GetParent()
	if (dropdown.tooltip) then
		GameTooltip:SetOwner(this, dropdown.tooltipAnchor or "ANCHOR_RIGHT")
		GameTooltip:SetText(dropdown.tooltip, nil, nil, nil, nil, 1)
	end
	local r, g, b = Theme:GetHighlightColor()
	this:SetBackdropBorderColor(r, g, b, 0.8)
end


-- ****************************************************************************
-- Called when the mouse leaves the dropdown's box.
-- ****************************************************************************
local function Dropdown_OnLeave(this)
	GameTooltip:Hide()
	this:SetBackdropBorderColor(unpack(Theme.border))
end


-- ****************************************************************************
-- Called when the dropdown is hidden.
-- ****************************************************************************
local function Dropdown_OnHide(this)
	Dropdown_HideSelections(this)
end


-- ****************************************************************************
-- Called when the button for the dropdown is pressed.
-- ****************************************************************************
local function Dropdown_OnClick(this)
	-- Close the listbox and exit if it's already open for the dropdown.
	local dropdown = this:GetParent()
	if (dropdownListboxFrame:IsShown() and dropdownListboxFrame.dropdown == dropdown) then
		dropdownListboxFrame:Hide()
		return
	end

	-- Resize and move the dropdown listbox frame for the clicked dropdown.
	local height = #dropdown.items * 20
	local listboxHeight = dropdown.listboxHeight or 140
	local listboxWidth = dropdown.listboxWidth or dropdown:GetWidth() + 20
	height = math.max(math.min(height, listboxHeight), 20)
	-- Parented directly to UIParent (not the dropdown's own tab/popup) and
	-- re-asserted to "FULLSCREEN_DIALOG" every time it opens, so it always
	-- draws above the options window and any popup, regardless of where the
	-- dropdown that opened it lives.
	dropdownListboxFrame:SetParent(UIParent)
	dropdownListboxFrame:SetFrameStrata("FULLSCREEN_DIALOG")
	dropdownListboxFrame:SetHeight(height + 24)
	dropdownListboxFrame:SetWidth(listboxWidth)
	dropdownListboxFrame:ClearAllPoints()
	dropdownListboxFrame:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT")
	dropdownListboxFrame.dropdown = dropdown

	-- Setup the listbox.
	local listbox = dropdownListboxFrame.listbox
	Listbox_Clear(listbox)
	listbox:SetPoint("TOPLEFT", dropdownListboxFrame, "TOPLEFT", 8, -12)
	listbox:SetPoint("BOTTOMRIGHT", dropdownListboxFrame, "BOTTOMRIGHT", -12, 12)
	Listbox_Configure(listbox, 0, height, 20)
	for itemNum in ipairs(dropdown.items) do
		Listbox_AddItem(listbox, itemNum)
	end
	Listbox_SetSelectedItem(listbox, dropdown.selectedItem)
	Listbox_SetOffset(listbox, dropdown.selectedItem - 1)

	dropdownListboxFrame:Show()
	dropdownListboxFrame:Raise()
end


-- ****************************************************************************
-- Called by listbox to create a line.
-- ****************************************************************************
local function Dropdown_CreateLine(this)
	local frame = CreateFrame("Button", nil, this)

	local fontString = Theme:FontString(frame, 12)
	fontString:SetPoint("LEFT", frame, "LEFT", 6, 0)
	fontString:SetPoint("RIGHT", frame, "RIGHT")

	frame.fontString = fontString
	return frame
end


-- ****************************************************************************
-- Called by listbox to display a line.
-- ****************************************************************************
local function Dropdown_DisplayLine(this, line, key, isSelected)
	line.fontString:SetText(dropdownListboxFrame.dropdown.items[key])
	if isSelected then
		local r, g, b = Theme:GetHighlightColor()
		line.fontString:SetTextColor(r, g, b)
	else
		line.fontString:SetTextColor(unpack(Theme.text))
	end
end


-- ****************************************************************************
-- Called when a line is clicked.
-- ****************************************************************************
local function Dropdown_OnClickLine(this, line, value)
	local dropdown = dropdownListboxFrame.dropdown
	dropdown.selectedFontString:SetText(dropdown.items[value])
	dropdown.selectedItem = value
	dropdownListboxFrame:Hide()

	-- Call the registered change handler for the dropdown.
	if (dropdown.changeHandler) then dropdown:changeHandler(dropdown.itemIDs[value]) end
end


-- ****************************************************************************
-- Sets the label for the dropdown.
-- ****************************************************************************
local function Dropdown_SetLabel(this, label)
	this.labelFontString:SetText(label or "")
end


-- ****************************************************************************
-- Sets the tooltip for the dropdown.
-- ****************************************************************************
local function Dropdown_SetTooltip(this, tooltip)
	this.tooltip = tooltip
end


-- ****************************************************************************
-- Configures the dropdown.
-- ****************************************************************************
local function Dropdown_Configure(this, width, label, tooltip)
	-- Don't do anything if required parameters are invalid.
	if (not width) then return end

	-- Set the width of the dropdown and the max height of the listbox is shown.
	this:SetWidth(width)

	Dropdown_SetLabel(this, label)
	Dropdown_SetTooltip(this, tooltip)
end


-- ****************************************************************************
-- Sets the max height the listbox frame can be for the dropdown.
-- ****************************************************************************
local function Dropdown_SetListboxHeight(this, height)
	this.listboxHeight = height
end

-- ****************************************************************************
-- Sets the width of the listbox frame for the dropdown.
-- ****************************************************************************
local function Dropdown_SetListboxWidth(this, width)
	this.listboxWidth = width
end


-- ****************************************************************************
-- Sets the function to be called when one of the dropdown's options is
-- selected. It is passed the ID for the selected item.
-- ****************************************************************************
local function Dropdown_SetChangeHandler(this, handler)
	this.changeHandler = handler
end


-- ****************************************************************************
-- Adds the passed text and id to the dropdown.
-- ****************************************************************************
local function Dropdown_AddItem(this, text, id)
	this.items[#this.items+1] = text
	this.itemIDs[#this.items] = id
end


-- ****************************************************************************
-- Remove the passed item id from the dropdown.
-- ****************************************************************************
local function Dropdown_RemoveItem(this, id)
	for itemNum, itemID in ipairs(this.itemIDs) do
		if (itemID == id) then
			-- Hide dropdown if it is shown.
			Dropdown_HideSelections(this)

			-- Clear the selected item if it's the item being removed.
			if (itemNum == this.selectedItem) then
				this.selectedItem = 0
	this.selectedFontString:SetText("")
			end

			table.remove(this.items, itemNum)
			table.remove(this.itemIDs, itemNum)
			return
		end
	end
end


-- ****************************************************************************
-- Clears the dropdown.
-- ****************************************************************************
local function Dropdown_Clear(this)
	local items = this.items
	for k, v in ipairs(items) do
		items[k] = nil
	end

	local itemIDs = this.itemIDs
	for k, v in ipairs(itemIDs) do
		itemIDs[k] = nil
	end

	this.selectedFontString:SetText(nil)
end


-- ****************************************************************************
-- Gets the selected text from the dropdown.
-- ****************************************************************************
local function Dropdown_GetSelectedText(this)
	return this.selectedFontString:GetText()
end


-- ****************************************************************************
-- Gets the selected id from the dropdown.
-- ****************************************************************************
local function Dropdown_GetSelectedID(this)
	if (this.selectedItem) then return this.itemIDs[this.selectedItem] end
end


-- ****************************************************************************
-- Sets the selected item for the listbox.
-- ****************************************************************************
local function Dropdown_SetSelectedID(this, id)
	for itemNum, itemID in ipairs(this.itemIDs) do
		if (itemID == id) then
			this.selectedFontString:SetText(this.items[itemNum])
			this.selectedItem = itemNum
			return
		end
	end
end


-- ****************************************************************************
-- Sorts the contents of the dropdown.
-- ****************************************************************************
local function Dropdown_Sort(this)
	local selectedID = Dropdown_GetSelectedID(this)

	-- Sort the dropdown items and associated IDs using an insertion sort.
	local items = this.items
	local itemIDs = this.itemIDs
	local tempItem, tempID, j
	for i = 2, #items do
		tempItem = items[i]
		tempID = itemIDs[i]
		j = i - 1
		while (j > 0 and items[j] > tempItem) do
			items[j + 1] = items[j]
			itemIDs[j + 1] = itemIDs[j]
			j = j - 1
		end
		items[j + 1] = tempItem
		itemIDs[j + 1] = tempID
	end

	Dropdown_SetSelectedID(this, selectedID)
end


-- ****************************************************************************
-- Disables the dropdown.
-- ****************************************************************************
local function Dropdown_Disable(this)
	Dropdown_HideSelections(this)
	this.buttonFrame:Disable()
	this.box:Disable()
	this.labelFontString:SetTextColor(unpack(Theme.disabledText))
	this.selectedFontString:SetTextColor(unpack(Theme.disabledText))
end


-- ****************************************************************************
-- Enables the dropdown.
-- ****************************************************************************
local function Dropdown_Enable(this)
	this.buttonFrame:Enable()
	this.box:Enable()
	this.labelFontString:SetTextColor(unpack(Theme.mutedText))
	local r, g, b = Theme:GetHighlightColor()
	this.selectedFontString:SetTextColor(r, g, b)
end


-- ****************************************************************************
-- Creates the listbox frame that dropdowns use.
-- ****************************************************************************
local function Dropdown_CreateListboxFrame(parent)
	dropdownListboxFrame = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
	dropdownListboxFrame:EnableMouse(true)
	dropdownListboxFrame:SetToplevel(true)
	dropdownListboxFrame:SetFrameStrata("FULLSCREEN_DIALOG")
	Theme:Panel(dropdownListboxFrame, Theme.panel)
	dropdownListboxFrame:Hide()
	dropdownListboxFrame.msbtThemed = true

	local listbox = CreateListbox(dropdownListboxFrame)
	listbox:SetToplevel(true)
	listbox:SetFrameStrata("FULLSCREEN_DIALOG")
	listbox:SetCreateLineHandler(Dropdown_CreateLine)
	listbox:SetDisplayHandler(Dropdown_DisplayLine)
	listbox:SetClickHandler(Dropdown_OnClickLine)

	dropdownListboxFrame.listbox = listbox
end


-- ****************************************************************************
-- Creates and returns a dropdown object ready to be configured.
-- ****************************************************************************
local function CreateDropdown(parent)
	-- Create dropdown listbox if it hasn't already been.
	if (not dropdownListboxFrame) then Dropdown_CreateListboxFrame(parent) end


	-- Create container frame. Tall enough that the label above the box fits
	-- inside the container's own bounds instead of poking above it into
	-- whatever was stacked before this dropdown.
	local dropdown = CreateFrame("Frame", nil, parent)
	dropdown:SetHeight(42)
	dropdown:SetScript("OnHide", Dropdown_OnHide)


	-- Flat bordered box instead of Blizzard's 3-piece label-frame border
	-- (../KeyHerald's GUI/Widgets.lua W.Dropdown). A Button (not a plain
	-- Frame) so clicking anywhere on it opens the list, not just the small
	-- arrow to its right.
	local box = CreateFrame("Button", nil, dropdown, BackdropTemplateMixin and "BackdropTemplate")
	box:SetHeight(25)
	box:SetPoint("BOTTOMLEFT")
	box:SetPoint("BOTTOMRIGHT")
	box:SetBackdrop({ bgFile = FLAT_TEXTURE, edgeFile = FLAT_TEXTURE, edgeSize = 1 })
	box:SetBackdropColor(unpack(Theme.fill))
	box:SetBackdropBorderColor(unpack(Theme.border))
	box:SetScript("OnClick", Dropdown_OnClick)
	box:SetScript("OnEnter", Dropdown_OnEnter)
	box:SetScript("OnLeave", Dropdown_OnLeave)
	dropdown.box = box

	-- Label.
	local label = Theme:FontString(dropdown, 12)
	label:SetPoint("BOTTOMLEFT", box, "TOPLEFT", 2, 2)
	label:SetTextColor(unpack(Theme.mutedText))


	-- Dropdown button: a flat triangular caret drawn by collapsing two quad
	-- corners of a plain texture (../Nucleus's Widgets.lua shapeCaret) - not
	-- a text glyph, so it can't come out as a "tofu" box if the bundled font
	-- doesn't happen to include a triangle character.
	local button = CreateFrame("Button", nil, dropdown)
	button:SetWidth(24)
	button:SetHeight(24)
	button:SetPoint("BOTTOMRIGHT")
	local arrow = button:CreateTexture(nil, "ARTWORK")
	arrow:SetTexture(FLAT_TEXTURE)
	arrow:SetVertexColor(unpack(Theme.mutedText))
	arrow:SetSize(8, 5)
	arrow:SetPoint("CENTER")
	arrow:SetTexCoord(0, 1, 0, 1)
	arrow:SetVertexOffset(2, 4, 0)  -- LOWER_LEFT  -> bottom centre
	arrow:SetVertexOffset(4, -4, 0) -- LOWER_RIGHT -> bottom centre
	button.arrow = arrow
	button:SetScript("OnClick", Dropdown_OnClick)


		-- Selected text. Parented to box (not dropdown) so it draws as part
	-- of box's own layer stack above its backdrop - a FontString parented
	-- to dropdown would be occluded by box, a child frame drawn on top of
	-- dropdown's own regions regardless of the FontString's OVERLAY layer.
	local selected = Theme:FontString(box, 12)
	selected:SetPoint("LEFT", box, "LEFT", 6, 0)
	selected:SetPoint("RIGHT", button, "LEFT")
	selected:SetJustifyH("LEFT")
	do
		local r, g, b = Theme:GetHighlightColor()
		selected:SetTextColor(r, g, b)
	end
	Theme:OnHighlightColorChanged(function(r, g, b)
		selected:SetTextColor(r, g, b)
	end)


	-- Extension functions.
	dropdown.Configure			= Dropdown_Configure
	dropdown.SetListboxHeight	= Dropdown_SetListboxHeight
	dropdown.SetListboxWidth	= Dropdown_SetListboxWidth
	dropdown.SetLabel			= Dropdown_SetLabel
	dropdown.SetTooltip		= Dropdown_SetTooltip
	dropdown.SetChangeHandler	= Dropdown_SetChangeHandler
	dropdown.HideSelections	= Dropdown_HideSelections
	dropdown.AddItem			= Dropdown_AddItem
	dropdown.RemoveItem		= Dropdown_RemoveItem
	dropdown.Clear				= Dropdown_Clear
	dropdown.GetSelectedText	= Dropdown_GetSelectedText
	dropdown.GetSelectedID		= Dropdown_GetSelectedID
	dropdown.SetSelectedID		= Dropdown_SetSelectedID
	dropdown.Sort				= Dropdown_Sort
	dropdown.Disable			= Dropdown_Disable
	dropdown.Enable			= Dropdown_Enable

	-- Track internal values.
	dropdown.selectedFontString = selected
	dropdown.buttonFrame = button
	dropdown.labelFontString = label
	dropdown.items = {}
	dropdown.itemIDs = {}
	dropdown.selectedItem = 0
	return dropdown
end


-------------------------------------------------------------------------------
-- Editbox functions.
-------------------------------------------------------------------------------

-- ****************************************************************************
-- Called when the editbox has focus and escape is pressed.
-- ****************************************************************************
local function Editbox_OnEscape(this)
	this:ClearFocus()
	local editbox = this:GetParent()
	if (editbox.escapeHandler) then editbox:escapeHandler() end
end


-- ****************************************************************************
-- Called when the editbox loses focus.
-- ****************************************************************************
local function Editbox_OnFocusLost(this)
	this:HighlightText(0, 0)
	this:SetBackdropBorderColor(unpack(Theme.border))
end


-- ****************************************************************************
-- Called when the editbox gains focus.
-- ****************************************************************************
local function Editbox_OnFocusGained(this)
	this:HighlightText()
	local r, g, b = Theme:GetHighlightColor()
	this:SetBackdropBorderColor(r, g, b, 0.8)
end


-- ****************************************************************************
-- Called when the text in the editbox changes.
-- ****************************************************************************
local function Editbox_OnTextChanged(this)
	local editbox = this:GetParent()
	if (editbox.textChangedHandler) then editbox:textChangedHandler() end
end


-- ****************************************************************************
-- Called when the mouse enters the editbox.
-- ****************************************************************************
local function Editbox_OnEnter(this)
	if (this.tooltip) then
		GameTooltip:SetOwner(this, this.tooltipAnchor or "ANCHOR_RIGHT")
		GameTooltip:SetText(this.tooltip, nil, nil, nil, nil, 1)
	end
end


-- ****************************************************************************
-- Called when the mouse leaves the editbox.
-- ****************************************************************************
local function Editbox_OnLeave(this)
	GameTooltip:Hide()
end


-- ****************************************************************************
-- Sets the label for the editbox.
-- ****************************************************************************
local function Editbox_SetLabel(this, label)
	this.labelFontString:SetText(label)
end


-- ****************************************************************************
-- Sets the tooltip for the editbox.
-- ****************************************************************************
local function Editbox_SetTooltip(this, tooltip)
	this.editboxFrame.tooltip = tooltip
end


-- ****************************************************************************
-- Configures the editbox.
-- ****************************************************************************
local function Editbox_Configure(this, width, label, tooltip)
	-- Don't do anything if required parameters are invalid.
	if (not width) then return end

	this:SetWidth(width)
	Editbox_SetLabel(this, label)
	Editbox_SetTooltip(this, tooltip)
end


-- ****************************************************************************
-- Sets the handler to be called when the enter button is pressed.
-- ****************************************************************************
local function Editbox_SetEnterHandler(this, handler)
	this.editboxFrame:SetScript("OnEnterPressed", handler)
end


-- ****************************************************************************
-- Sets the handler to be called when the escape button is pressed.
-- ****************************************************************************
local function Editbox_SetEscapeHandler(this, handler)
	this.escapeHandler = handler
end


-- ****************************************************************************
-- Sets the handler to be called when the text in the editbox changes.
-- ****************************************************************************
local function Editbox_SetTextChangedHandler(this, handler)
	this.textChangedHandler = handler
end


-- ****************************************************************************
-- Sets the focus to the editbox.
-- ****************************************************************************
local function Editbox_SetFocus(this)
	this.editboxFrame:SetFocus()
end


-- ****************************************************************************
-- Gets the text entered in the editbox.
-- ****************************************************************************
local function Editbox_GetText(this)
	return this.editboxFrame:GetText()
end


-- ****************************************************************************
-- Sets the text entered in the editbox.
-- ****************************************************************************
local function Editbox_SetText(this, text)
	return this.editboxFrame:SetText(text or "")
end


-- ****************************************************************************
-- Disables the editbox.
-- ****************************************************************************
local function Editbox_Disable(this)
	this.editboxFrame:EnableMouse(false)
	this.labelFontString:SetTextColor(unpack(Theme.disabledText))
end

-- ****************************************************************************
-- Enables the editbox.
-- ****************************************************************************
local function Editbox_Enable(this)
	this.editboxFrame:EnableMouse(true)
	this.labelFontString:SetTextColor(unpack(Theme.mutedText))
end


-- ****************************************************************************
-- Creates and returns an editbox object ready to be configured.
-- ****************************************************************************
local function CreateEditbox(parent)
	-- Create container frame.
	local editbox = CreateFrame("Frame", nil, parent)
	editbox:SetHeight(32)

	-- Create editbox frame: a flat bordered box instead of Blizzard's
	-- Common-Input-Border texture set (../KeyHerald's GUI/Widgets.lua
	-- W.EditBox).
	local editboxFrame = CreateFrame("Editbox", nil, editbox, BackdropTemplateMixin and "BackdropTemplate")
	editboxFrame:SetHeight(20)
	editboxFrame:SetPoint("BOTTOMLEFT", editbox, "BOTTOMLEFT", 5, 0)
	editboxFrame:SetPoint("BOTTOMRIGHT")
	editboxFrame:SetAutoFocus(false)
	editboxFrame:SetFontObject(Theme.font.small)
	editboxFrame:SetTextInsets(8, 8, 0, 0)
	editboxFrame:SetBackdrop({ bgFile = FLAT_TEXTURE, edgeFile = FLAT_TEXTURE, edgeSize = 1 })
	editboxFrame:SetBackdropColor(unpack(Theme.fill))
	editboxFrame:SetBackdropBorderColor(unpack(Theme.border))
	editboxFrame:SetScript("OnEscapePressed", Editbox_OnEscape)
	editboxFrame:SetScript("OnEditFocusLost", Editbox_OnFocusLost)
	editboxFrame:SetScript("OnEditFocusGained", Editbox_OnFocusGained)
	editboxFrame:SetScript("OnTextChanged", Editbox_OnTextChanged)
	editboxFrame:SetScript("OnEnter", Editbox_OnEnter)
	editboxFrame:SetScript("OnLeave", Editbox_OnLeave)

	-- Label.
	local label = Theme:FontString(editbox, 12)
	label:SetPoint("TOPLEFT")
	label:SetPoint("TOPRIGHT")
	label:SetJustifyH("LEFT")
	label:SetTextColor(unpack(Theme.mutedText))


	-- Extension functions.
	editbox.Configure				= Editbox_Configure
	editbox.SetLabel				= Editbox_SetLabel
	editbox.SetTooltip				= Editbox_SetTooltip
	editbox.SetEnterHandler		= Editbox_SetEnterHandler
	editbox.SetEscapeHandler		= Editbox_SetEscapeHandler
	editbox.SetTextChangedHandler	= Editbox_SetTextChangedHandler
	editbox.SetFocus				= Editbox_SetFocus
	editbox.GetText				= Editbox_GetText
	editbox.SetText				= Editbox_SetText
	editbox.Disable				= Editbox_Disable
	editbox.Enable					= Editbox_Enable


	-- Track internal values.
	editbox.editboxFrame = editboxFrame
	editbox.labelFontString = label
	return editbox
end


-------------------------------------------------------------------------------
-- Custom color picker: 1:1 ported from ../KeyHerald's GUI/ColorPicker.lua -
-- a saturation/value square, a hue strip, a hex field, preset swatches and a
-- live preview - replacing Blizzard's ColorPickerFrame entirely.
-------------------------------------------------------------------------------
local MSBTColorPicker = {}

local function ColorPicker_Clamp01(x) return x < 0 and 0 or x > 1 and 1 or x end

local function ColorPicker_RGBToHSV(r, g, b)
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	local d, h, s, v = mx - mn, 0, 0, mx
	if mx > 0 then s = d / mx end
	if d > 0 then
		if mx == r then h = ((g - b) / d) % 6
		elseif mx == g then h = (b - r) / d + 2
		else h = (r - g) / d + 4 end
		h = h / 6
		if h < 0 then h = h + 1 end
	end
	return h, s, v
end

local function ColorPicker_HSVToRGB(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i = i % 6
	if i == 0 then return v, t, p
	elseif i == 1 then return q, v, p
	elseif i == 2 then return p, v, t
	elseif i == 3 then return p, q, v
	elseif i == 4 then return t, p, v
	else return v, p, q end
end

local function ColorPicker_ToHex(r, g, b)
	return ("%02X%02X%02X"):format(
		math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function ColorPicker_FromHex(str)
	str = tostring(str):gsub("[^%x]", "")
	if #str ~= 6 then return nil end
	return tonumber(str:sub(1, 2), 16) / 255,
	       tonumber(str:sub(3, 4), 16) / 255,
	       tonumber(str:sub(5, 6), 16) / 255
end

local COLOR_PICKER_PRESETS = {
	"B55CFF", "7A5CFF", "3D8BFF", "22C1C3", "3FCF5C",
	"F2C14E", "FF7A45", "FF5C8A", "E0E0E0", "9AA0A6",
}

local colorPickerFrame

local function ColorPicker_ScaledCursor()
	local x, y = GetCursorPosition()
	local s = UIParent:GetEffectiveScale()
	return x / s, y / s
end

local function ColorPicker_Build()
	if colorPickerFrame then return colorPickerFrame end

	local frame = CreateFrame("Frame", "MSBTColorPickerFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
	colorPickerFrame = frame
	frame:SetSize(268, 284)
	frame:SetPoint("CENTER", 0, 60)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	Theme:Panel(frame, Theme.background)
	frame:Hide()
	frame.msbtThemed = true

	local bar = Theme:AccentBar(frame, 2)
	bar:SetPoint("TOPLEFT", 1, -1); bar:SetPoint("TOPRIGHT", -1, -1)

	local title = frame:CreateFontString(nil, "OVERLAY")
	title:SetFontObject(Theme.font.header)
	title:SetPoint("TOPLEFT", 12, -10)
	do
		local r, g, b = Theme:GetHighlightColor()
		title:SetTextColor(r, g, b)
	end
	Theme:OnHighlightColorChanged(function(r, g, b) title:SetTextColor(r, g, b) end)
	frame.title = title

	frame.h, frame.s, frame.v = 0, 0, 1

	local function currentRGB() return ColorPicker_HSVToRGB(frame.h, frame.s, frame.v) end

	-- SV square.
	local sv = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate")
	sv:SetSize(168, 128)
	sv:SetPoint("TOPLEFT", 12, -30)
	sv:SetBackdrop({ edgeFile = FLAT_TEXTURE, edgeSize = 1 })
	sv:SetBackdropBorderColor(unpack(Theme.border))

	local hueTex = sv:CreateTexture(nil, "BACKGROUND")
	hueTex:SetPoint("TOPLEFT", 1, -1); hueTex:SetPoint("BOTTOMRIGHT", -1, 1)
	hueTex:SetColorTexture(1, 1, 1, 1)

	local whiteGrad = sv:CreateTexture(nil, "ARTWORK")
	whiteGrad:SetPoint("TOPLEFT", 1, -1); whiteGrad:SetPoint("BOTTOMRIGHT", -1, 1)
	whiteGrad:SetColorTexture(1, 1, 1, 1)
	whiteGrad:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 0))

	local blackGrad = sv:CreateTexture(nil, "OVERLAY")
	blackGrad:SetPoint("TOPLEFT", 1, -1); blackGrad:SetPoint("BOTTOMRIGHT", -1, 1)
	blackGrad:SetColorTexture(0, 0, 0, 1)
	blackGrad:SetGradient("VERTICAL", CreateColor(0, 0, 0, 1), CreateColor(0, 0, 0, 0))

	local svDot = sv:CreateTexture(nil, "OVERLAY", nil, 7)
	svDot:SetSize(9, 9)
	svDot:SetColorTexture(1, 1, 1, 1)

	-- Hue strip.
	local hue = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate")
	hue:SetSize(18, 128)
	hue:SetPoint("TOPLEFT", sv, "TOPRIGHT", 10, 0)
	hue:SetBackdrop({ edgeFile = FLAT_TEXTURE, edgeSize = 1 })
	hue:SetBackdropBorderColor(unpack(Theme.border))

	local hueStops = { {1,0,0}, {1,1,0}, {0,1,0}, {0,1,1}, {0,0,1}, {1,0,1}, {1,0,0} }
	for i = 1, 6 do
		local seg = hue:CreateTexture(nil, "BACKGROUND")
		seg:SetPoint("TOPLEFT", 1, -1 - (i - 1) * 21)
		seg:SetPoint("TOPRIGHT", -1, 0)
		seg:SetHeight(21)
		seg:SetColorTexture(1, 1, 1, 1)
		local a, b = hueStops[i], hueStops[i + 1]
		seg:SetGradient("VERTICAL", CreateColor(b[1], b[2], b[3], 1), CreateColor(a[1], a[2], a[3], 1))
	end

	local hueDot = hue:CreateTexture(nil, "OVERLAY")
	hueDot:SetSize(22, 3)
	hueDot:SetColorTexture(1, 1, 1, 1)

	-- Preview + hex field.
	local prev = frame:CreateTexture(nil, "ARTWORK")
	prev:SetSize(40, 18)
	prev:SetPoint("TOPLEFT", sv, "BOTTOMLEFT", 0, -10)
	local prevBorder = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate")
	prevBorder:SetPoint("TOPLEFT", prev, -1, 1)
	prevBorder:SetPoint("BOTTOMRIGHT", prev, 1, -1)
	prevBorder:SetBackdrop({ edgeFile = FLAT_TEXTURE, edgeSize = 1 })
	prevBorder:SetBackdropBorderColor(unpack(Theme.border))

	local hexLabel = frame:CreateFontString(nil, "OVERLAY")
	hexLabel:SetFontObject(Theme.font.small)
	hexLabel:SetPoint("LEFT", prev, "RIGHT", 10, 0)
	hexLabel:SetText("#")
	hexLabel:SetTextColor(unpack(Theme.mutedText))

	local hex = CreateFrame("EditBox", nil, frame, BackdropTemplateMixin and "BackdropTemplate")
	hex:SetSize(66, 18)
	hex:SetPoint("LEFT", hexLabel, "RIGHT", 3, 0)
	hex:SetAutoFocus(false)
	hex:SetFontObject(Theme.font.small)
	hex:SetTextInsets(5, 5, 0, 0)
	hex:SetMaxLetters(6)
	hex:SetBackdrop({ bgFile = FLAT_TEXTURE, edgeFile = FLAT_TEXTURE, edgeSize = 1 })
	hex:SetBackdropColor(unpack(Theme.fill))
	hex:SetBackdropBorderColor(unpack(Theme.border))

	-- Preset swatches.
	for i, hexStr in ipairs(COLOR_PICKER_PRESETS) do
		local pr, pg, pb = ColorPicker_FromHex(hexStr)
		local col = (i - 1) % 5
		local row = math.floor((i - 1) / 5)
		local b = CreateFrame("Button", nil, frame, BackdropTemplateMixin and "BackdropTemplate")
		b:SetSize(24, 14)
		b:SetPoint("TOPLEFT", sv, "BOTTOMLEFT", col * 28, -36 - row * 18)
		b:SetBackdrop({ bgFile = FLAT_TEXTURE, edgeFile = FLAT_TEXTURE, edgeSize = 1 })
		b:SetBackdropColor(pr, pg, pb, 1)
		b:SetBackdropBorderColor(unpack(Theme.border))
		b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(1, 1, 1, 0.5) end)
		b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(Theme.border)) end)
		b:SetScript("OnClick", function()
			frame.h, frame.s, frame.v = ColorPicker_RGBToHSV(pr, pg, pb)
			frame:Sync()
		end)
	end

	-- OK / Cancel.
	local function mkBtn(label)
		local b = CreateFrame("Button", nil, frame, BackdropTemplateMixin and "BackdropTemplate")
		b:SetSize(84, 20)
		b:SetBackdrop({ bgFile = FLAT_TEXTURE, edgeFile = FLAT_TEXTURE, edgeSize = 1 })
		b:SetBackdropColor(unpack(Theme.panel))
		b:SetBackdropBorderColor(unpack(Theme.border))
		b.text = b:CreateFontString(nil, "OVERLAY")
		b.text:SetFontObject(Theme.font.small); b.text:SetPoint("CENTER"); b.text:SetText(label)
		b:SetScript("OnEnter", function(self)
			local r, g, bl = Theme:GetHighlightColor()
			self:SetBackdropColor(r * 0.5, g * 0.5, bl * 0.5, 1)
			self:SetBackdropBorderColor(r, g, bl, 0.9)
		end)
		b:SetScript("OnLeave", function(self)
			self:SetBackdropColor(unpack(Theme.panel))
			self:SetBackdropBorderColor(unpack(Theme.border))
		end)
		return b
	end
	local ok = mkBtn(OKAY)
	ok:SetPoint("BOTTOMRIGHT", -12, 12)
	local cancel = mkBtn(CANCEL)
	cancel:SetPoint("BOTTOMRIGHT", ok, "BOTTOMLEFT", -6, 0)

	-- Syncs visuals from h,s,v.
	function frame:Sync()
		local hr, hg, hb = ColorPicker_HSVToRGB(self.h, 1, 1)
		hueTex:SetColorTexture(hr, hg, hb, 1)
		local r, g, b = currentRGB()
		prev:SetColorTexture(r, g, b, 1)
		svDot:ClearAllPoints()
		svDot:SetPoint("CENTER", sv, "TOPLEFT", 1 + self.s * (sv:GetWidth() - 2),
			-(1 + (1 - self.v) * (sv:GetHeight() - 2)))
		svDot:SetColorTexture(self.v > 0.5 and 0 or 1, self.v > 0.5 and 0 or 1, self.v > 0.5 and 0 or 1, 1)
		hueDot:ClearAllPoints()
		hueDot:SetPoint("CENTER", hue, "TOP", 0, -(1 + self.h * (hue:GetHeight() - 2)))
		if not hex:HasFocus() then hex:SetText(ColorPicker_ToHex(r, g, b)) end
		if self._onChange then self._onChange(r, g, b) end
	end

	-- Drag handling for the SV square and hue strip.
	local function updateSV()
		local x, y = ColorPicker_ScaledCursor()
		frame.s = ColorPicker_Clamp01((x - sv:GetLeft()) / sv:GetWidth())
		frame.v = ColorPicker_Clamp01(1 - (sv:GetTop() - y) / sv:GetHeight())
		frame:Sync()
	end
	local function updateHue()
		local _, y = ColorPicker_ScaledCursor()
		frame.h = ColorPicker_Clamp01((hue:GetTop() - y) / hue:GetHeight())
		frame:Sync()
	end

	frame:SetScript("OnUpdate", function()
		if (frame.dragSV or frame.dragHue) and not IsMouseButtonDown("LeftButton") then
			frame.dragSV, frame.dragHue = false, false
		end
		if frame.dragSV then updateSV() end
		if frame.dragHue then updateHue() end
	end)
	sv:EnableMouse(true)
	sv:SetScript("OnMouseDown", function() frame.dragSV = true; updateSV() end)
	sv:SetScript("OnMouseUp", function() frame.dragSV = false end)
	hue:EnableMouse(true)
	hue:SetScript("OnMouseDown", function() frame.dragHue = true; updateHue() end)
	hue:SetScript("OnMouseUp", function() frame.dragHue = false end)

	hex:SetScript("OnEnterPressed", function(self)
		local r, g, b = ColorPicker_FromHex(self:GetText())
		if r then frame.h, frame.s, frame.v = ColorPicker_RGBToHSV(r, g, b) end
		self:ClearFocus(); frame:Sync()
	end)
	hex:SetScript("OnEscapePressed", function(self) self:ClearFocus(); frame:Sync() end)

	ok:SetScript("OnClick", function()
		frame:Hide()
		if frame._onAccept then frame._onAccept(currentRGB()) end
	end)
	cancel:SetScript("OnClick", function()
		frame:Hide()
		if frame._onCancel then frame._onCancel() end
	end)
	frame:SetScript("OnKeyDown", function(self, key)
		if key == "ESCAPE" then cancel:Click() end
	end)
	frame:SetScript("OnShow", function(self) self:SetPropagateKeyboardInput(false) end)
	frame:EnableKeyboard(true)

	return frame
end

-- Opens the color picker. opts = { r, g, b, title, onAccept(r,g,b), onCancel(), onChange(r,g,b) }.
function MSBTColorPicker:Open(opts)
	local f = ColorPicker_Build()
	f.title:SetText(opts.title or "")
	f.h, f.s, f.v = ColorPicker_RGBToHSV(opts.r or 1, opts.g or 1, opts.b or 1)
	f._onAccept = opts.onAccept
	f._onCancel = opts.onCancel
	f._onChange = opts.onChange
	f:Show()
	f:Sync()
	if f.Raise then f:Raise() end
end

MSBTOptions.ColorPicker = MSBTColorPicker


-------------------------------------------------------------------------------
-- Colorswatch functions.
-------------------------------------------------------------------------------

-- ****************************************************************************
-- Sets the color of the colorswatch.
-- ****************************************************************************
local function Colorswatch_SetColor(this, r, g, b)
	this.r = r
	this.g = g
	this.b = b
	this:SetBackdropColor(r, g, b, 1)
end


-- ****************************************************************************
-- Called when the colorswatch is clicked. Opens the custom color picker
-- (../KeyHerald's GUI/ColorPicker.lua) instead of Blizzard's ColorPickerFrame.
-- ****************************************************************************
local function Colorswatch_OnClick(this)
	local tempR = this.r or 1
	local tempG = this.g or 1
	local tempB = this.b or 1

	MSBTColorPicker:Open{
		r = tempR, g = tempG, b = tempB,
		title = this.tooltip,
		onChange = function(r, g, b)
			Colorswatch_SetColor(this, r, g, b)
			if this.colorChangedHandler then this:colorChangedHandler() end
		end,
		onCancel = function()
			Colorswatch_SetColor(this, tempR, tempG, tempB)
			if this.colorChangedHandler then this:colorChangedHandler() end
		end,
	}
end


-- ****************************************************************************
-- Called when the mouse enters the colorswatch.
-- ****************************************************************************
local function Colorswatch_OnEnter(this)
	if (this.tooltip) then
		GameTooltip:SetOwner(this, this.tooltipAnchor or "ANCHOR_RIGHT")
		GameTooltip:SetText(this.tooltip, nil, nil, nil, nil, 1)
	end
	local r, g, b = Theme:GetHighlightColor()
	this:SetBackdropBorderColor(r, g, b, 0.9)
end


-- ****************************************************************************
-- Called when the mouse leaves the colorswatch.
-- ****************************************************************************
local function Colorswatch_OnLeave(this)
	GameTooltip:Hide()
	this:SetBackdropBorderColor(unpack(Theme.border))
end


-- ****************************************************************************
-- Sets the handler to be called when the color changes.
-- ****************************************************************************
local function Colorswatch_SetColorChangedHandler(this, handler)
	this.colorChangedHandler = handler
end


-- ****************************************************************************
-- Sets the tooltip for the colorswatch.
-- ****************************************************************************
local function Colorswatch_SetTooltip(this, tooltip)
	this.tooltip = tooltip
end


-- ****************************************************************************
-- Disables the colorswatch.
-- ****************************************************************************
local function Colorswatch_Disable(this)
	this:SetBackdropColor(0.5, 0.5, 0.5, 1)
	this:oldDisableHandler()
end


-- ****************************************************************************
-- Enables the colorswatch.
-- ****************************************************************************
local function Colorswatch_Enable(this)
	this:oldEnableHandler()
	this:SetBackdropColor(this.r or 1, this.g or 1, this.b or 1, 1)
end


-- ****************************************************************************
-- Creates and returns a colorswatch object ready to be configured. Flat
-- color fill with a 1px border instead of Blizzard's chat-color-icon
-- texture (../KeyHerald's GUI/Widgets.lua W.ColorSwatch).
-- ****************************************************************************
local function CreateColorswatch(parent)
	-- Create button frame.
	local colorswatch = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
	colorswatch:SetWidth(16)
	colorswatch:SetHeight(16)
	colorswatch:SetBackdrop({ bgFile = FLAT_TEXTURE, edgeFile = FLAT_TEXTURE, edgeSize = 1 })
	colorswatch:SetBackdropBorderColor(unpack(Theme.border))
	colorswatch:SetScript("OnClick", Colorswatch_OnClick)
	colorswatch:SetScript("OnEnter", Colorswatch_OnEnter)
	colorswatch:SetScript("OnLeave", Colorswatch_OnLeave)

	-- Save old disable/enable handlers.
	colorswatch.oldDisableHandler = colorswatch.Disable
	colorswatch.oldEnableHandler = colorswatch.Enable

	-- Extension functions.
	colorswatch.SetColorChangedHandler	= Colorswatch_SetColorChangedHandler
	colorswatch.SetTooltip				= Colorswatch_SetTooltip
	colorswatch.SetColor				= Colorswatch_SetColor
	colorswatch.Disable				= Colorswatch_Disable
	colorswatch.Enable					= Colorswatch_Enable

	return colorswatch
end




-------------------------------------------------------------------------------
-- Module interface.
-------------------------------------------------------------------------------

-- Protected Functions.
module.CreateListbox			= CreateListbox
module.CreateCheckbox			= CreateCheckbox
module.CreateOptionButton		= CreateOptionButton
module.CreateIconButton			= CreateIconButton
module.CreateSlider				= CreateSlider
module.CreateDropdown			= CreateDropdown
module.CreateEditbox			= CreateEditbox
module.CreateColorswatch		= CreateColorswatch
