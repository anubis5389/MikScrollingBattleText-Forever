-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text
-- Author: Mikord
-------------------------------------------------------------------------------

local mod = {}
local modName = "MikSBT"
_G[modName] = mod

-- WOW_PROJECT_ID reports MAINLINE on the "Forever" client despite it being
-- Classic content, so Classic-vs-Retail decisions key off the interface
-- number instead.
local isForever = tonumber((select(4, GetBuildInfo()))) == 16001
mod.Client = {
	isForever = isForever,
	isClassicContent = isForever or WOW_PROJECT_ID >= WOW_PROJECT_CLASSIC,
	isVanillaContent = isForever or WOW_PROJECT_ID == WOW_PROJECT_CLASSIC,
}


-------------------------------------------------------------------------------
-- Imports.
-------------------------------------------------------------------------------

-- Local references to various functions for faster access.
local string_find = string.find
local string_sub = string.sub
local string_gsub = string.gsub
local string_match = string.match
local math_floor = math.floor

-- This client reports WOW_PROJECT_MAINLINE, so C_Spell calls in combat can
-- return patch 12.0 "Secret Values" - reading one directly throws instead
-- of returning a wrong result. issecretvalue()/canaccessvalue() predict
-- that safely (ported from the "Midnight" MSBT fork's API/RestrictedValue.lua).
local function IsAccessible(value)
	if (type(issecretvalue) == "function") then
		local ok, isSecret = pcall(issecretvalue, value)
		return ok and not isSecret
	end
	if (type(canaccessvalue) == "function") then
		local ok, canAccess = pcall(canaccessvalue, value)
		return ok and canAccess == true
	end
	return true
end

local function SafeNumber(value)
	if (IsAccessible(value) and type(value) == "number") then return value end
end

local function SafeString(value)
	if (IsAccessible(value) and type(value) == "string") then return value end
end

local function _GetSpellInfo(...)
	local ok, info = pcall(C_Spell.GetSpellInfo, ...)
	if (not ok or not info or not IsAccessible(info)) then return nil end
	local name = SafeString(info.name)
	if (not name) then return nil end
	return name, nil, SafeNumber(info.iconID), SafeNumber(info.castTime),
		SafeNumber(info.minRange), SafeNumber(info.maxRange), SafeNumber(info.spellID), SafeNumber(info.originalIconID)
end

local function _GetSpellCooldown(...)
	local ok, info = pcall(C_Spell.GetSpellCooldown, ...)
	if (not ok or not info or not IsAccessible(info)) then return nil end
	local startTime, duration = SafeNumber(info.startTime), SafeNumber(info.duration)
	if (not startTime or not duration) then return nil end
	return startTime, duration, info.isEnabled, SafeNumber(info.modRate)
end

local function _GetSpellTexture(...)
	local ok, texture = pcall(C_Spell.GetSpellTexture, ...)
	if (not ok) then return nil end
	return SafeNumber(texture)
end

local GetSpellCooldown = (C_Spell and C_Spell.GetSpellCooldown) and _GetSpellCooldown or GetSpellCooldown
local GetSpellInfo = (C_Spell and C_Spell.GetSpellInfo) and _GetSpellInfo or GetSpellInfo
local GetSpellTexture = (C_Spell and C_Spell.GetSpellTexture) and _GetSpellTexture or GetSpellTexture


-------------------------------------------------------------------------------
-- Mod constants
-------------------------------------------------------------------------------

local TOC_VERSION = string_gsub(C_AddOns.GetAddOnMetadata("MikScrollingBattleText", "Version"), "wowi:revision", 0)
mod.VERSION = tonumber(select(3, string_find(TOC_VERSION, "(%d+%.%d+)")))
mod.VERSION_STRING = "v" .. TOC_VERSION
mod.SVN_REVISION = tonumber(select(3, string_find(TOC_VERSION, "%d+%.%d+.(%d+)")))
mod.CLIENT_VERSION = tonumber((select(4, GetBuildInfo())))

mod.COMMAND = "/msbt"

-------------------------------------------------------------------------------
-- Localization.
-------------------------------------------------------------------------------

local translations = {}


-------------------------------------------------------------------------------
-- Imports.
-------------------------------------------------------------------------------

-- Local references to various functions for faster access.
local string_format = string.format
local string_reverse = string.reverse


-------------------------------------------------------------------------------
-- Utility Constants.
-------------------------------------------------------------------------------

-- Use standard SI suffixes at the end of shortened numbers.
--local SI_SUFFIXES = { "k", "M", "G", "T" }

-- Use Blizzard localized value to separate numbers if available.
--[[local LARGE_NUMBER_SEPERATOR = LARGE_NUMBER_SEPERATOR

if not LARGE_NUMBER_SEPERATOR or LARGE_NUMBER_SEPERATOR == "" then
	LARGE_NUMBER_SEPERATOR = ","
end

local SEPARATOR_REPLACE_PATTERN = "%1"..(LARGE_NUMBER_SEPERATOR or ",").."%2"--]]


-------------------------------------------------------------------------------
-- Utility functions.
-------------------------------------------------------------------------------

-- ****************************************************************************
-- Copies the passed table and all its subtables.
-- ****************************************************************************
local function CopyTable(srcTable)
	local newTable = {}

	for key, value in pairs(srcTable) do
		if (type(value) == "table") then value = CopyTable(value) end

		newTable[key] = value
	end

	return newTable
end


-- ****************************************************************************
-- Erases the passed table. Subtables are NOT erased.
-- ****************************************************************************
local function EraseTable(t)
	for key in next, t do
		t[key] = nil
	end
end


-- ****************************************************************************
-- Splits a string into the passed table using the delimeter.
-- ****************************************************************************
local function SplitString(text, delimeter, splitTable)
	local start = 1
	local splitStart, splitEnd = string_find(text, delimeter, start)
	while splitStart do
		splitTable[#splitTable + 1] = string_sub(text, start, splitStart - 1)
		start = splitEnd + 1
		splitStart, splitEnd = string_find(text, delimeter, start)
	end
	splitTable[#splitTable + 1] = string_sub(text, start)
end


-- ****************************************************************************
-- Prints out the passed message to the default chat frame.
-- ****************************************************************************
local function Print(msg, r, g, b)
	DEFAULT_CHAT_FRAME:AddMessage("MSBT: " .. tostring(msg), r, g, b)
end


-- ****************************************************************************
-- Returns a skill name for the passed id or unknown if the id invalid.
-- ****************************************************************************
local function GetSkillName(skillID)
	local skillName = GetSpellInfo(skillID)
	if not skillName then
		Print("Skill ID " .. tostring(skillID) .. " has been removed by Blizzard.")
	end
	return skillName or UNKNOWN
end


-- ****************************************************************************
-- Returns an SI formatted value given a number and a precision.
-- ****************************************************************************
local function ShortenNumber(number, precision)
	local formatter = ("%%.%df"):format(precision or 0)
	if type(number) ~= "number" then
		number = tonumber(number)
	end
	if not number then
		return 0
	elseif number >= 1e12 then
		return formatter:format(number / 1e12).."T"
	elseif number >= 1e9 then
		return formatter:format(number / 1e9).."G"
	elseif number >= 1e6 then
		return formatter:format(number / 1e6).."M"
	elseif number >= 1e3 then
		return formatter:format(number / 1e3).."k"
	else
		return number
	end
	return number
end


-- ****************************************************************************
-- Returns a number separated into groups of 3 according to the current
-- locale's separator.
-- ****************************************************************************

--[[local function SeparateNumber(number)
	if (type(number) ~= "number") then number = tonumber(number) end
	if (not number) then return 0 end

	local formatted = number
	while true do
		local k
		formatted, k = string_gsub(formatted, "^(-?%d+)(%d%d%d)", SEPARATOR_REPLACE_PATTERN)
		if (k == 0) then break end
	end
	return formatted
end--]]


-------------------------------------------------------------------------------
-- Combat log registration gate (Retail taint safety).
-------------------------------------------------------------------------------
-- Frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") is refused when called
-- from a *tainted* execution path - but that's a Retail-only restriction
-- (patch 12.0's Secret Values/taint rules), which Retail isn't even
-- supported on anymore (see README). Classic clients have never restricted
-- this, and issecure() isn't a reliable signal there either - other addons
-- commonly taint the global execution state for reasons that have nothing
-- to do with combat log access, which was producing false "blocked"
-- positives on Classic. So none of this gating runs there at all: the event
-- registers immediately and combatLogBlocked stays false for the session.
-- (Gate mechanics ported from Parrot3's Code/Parrot.lua.)
local IsRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE

-- Also gate on Forever explicitly (interface check, plus the CAMELOT project ID
-- in case a build reports that instead of MAINLINE).
local NeedsCombatLogGate = IsRetail or isForever or (WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT)

local combatLogGateReady = not NeedsCombatLogGate
local combatLogCallbacks = {}

local function ResolveCombatLogGate()
	if combatLogGateReady then return end
	combatLogGateReady = true

	-- issecure() reflects whether THIS call stack is currently tainted; since
	-- we're inside the clean PLAYER_LOGIN/PLAYER_ENTERING_WORLD dispatch, a
	-- true here means every callback below can safely register the event
	-- from this same synchronous stack.
	mod.combatLogBlocked = not issecure()

	for _, callback in ipairs(combatLogCallbacks) do
		callback()
	end
	combatLogCallbacks = nil
end

if NeedsCombatLogGate then
	local combatLogGateFrame = CreateFrame("Frame")
	combatLogGateFrame:SetScript("OnEvent", function(_, event)
		combatLogGateFrame:UnregisterEvent(event)
		ResolveCombatLogGate()
	end)
	combatLogGateFrame:RegisterEvent("PLAYER_LOGIN")
	combatLogGateFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
end

-- ****************************************************************************
-- Registers frame for COMBAT_LOG_EVENT_UNFILTERED as soon as it's safe to do
-- so (immediately if the gate already resolved and access is available), and
-- calls onBlocked() instead if combat log access turns out to be blocked
-- this session. Safe to call from multiple modules; each gets its own
-- independent registration attempt.
-- ****************************************************************************
local function RegisterCombatLogEvent(frame, onBlocked)
	local function attempt()
		if mod.combatLogBlocked then
			if (onBlocked) then onBlocked() end
		else
			frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			-- Belt-and-suspenders: fall back to the blocked path if the
			-- registration didn't actually take despite issecure() saying
			-- it should have.
			if not frame:IsEventRegistered("COMBAT_LOG_EVENT_UNFILTERED") then
				if (onBlocked) then onBlocked() end
			end
		end
	end

	if combatLogGateReady then
		attempt()
	else
		combatLogCallbacks[#combatLogCallbacks + 1] = attempt
	end
end


-------------------------------------------------------------------------------
-- Serialization (profile export/import).
-------------------------------------------------------------------------------
-- A small hand-rolled serializer/deserializer, deliberately NOT based on
-- loadstring()/load() - an imported string may have been pasted from
-- someone else, and running arbitrary Lua from that would be a real risk.
-- Only numbers, strings, booleans and (arbitrarily nested) tables round-
-- trip; every other value type is silently skipped during serialization.
--
-- Format: numbers are "d<value>;", strings are length-prefixed
-- "s<len>:<bytes>" (so embedded ":"/";" in the string can't desync the
-- parser), booleans are "b1"/"b0", and tables are "t<pairCount>:" followed
-- by that many serialized (key, value) pairs. Deserializing caps recursion
-- depth so a maliciously deep/garbled string can't overflow the Lua call
-- stack instead of just failing cleanly.
-------------------------------------------------------------------------------

local string_byte = string.byte
local string_char = string.char

local MAX_SERIALIZE_DEPTH = 64

local function SerializeValue(value, parts, depth)
	if (depth > MAX_SERIALIZE_DEPTH) then return end
	local t = type(value)
	if (t == "string") then
		parts[#parts + 1] = "s" .. #value .. ":" .. value
	elseif (t == "number") then
		parts[#parts + 1] = "d" .. string.format("%.14g", value) .. ";"
	elseif (t == "boolean") then
		parts[#parts + 1] = value and "b1" or "b0"
	elseif (t == "table") then
		local keys = {}
		for k, v in pairs(value) do
			local kt, vt = type(k), type(v)
			if (kt == "string" or kt == "number") and
				(vt == "string" or vt == "number" or vt == "boolean" or vt == "table") then
				keys[#keys + 1] = k
			end
		end
		parts[#parts + 1] = "t" .. #keys .. ":"
		for _, k in ipairs(keys) do
			SerializeValue(k, parts, depth + 1)
			SerializeValue(value[k], parts, depth + 1)
		end
	end
	-- Any other type (function, userdata, nil, thread) is silently skipped.
end

-- ****************************************************************************
-- Serializes a value (typically a profile table) into a safe, loadstring-
-- free string.
-- ****************************************************************************
local function Serialize(value)
	local parts = {}
	SerializeValue(value, parts, 1)
	return table.concat(parts)
end

local function DeserializeAt(str, pos, depth)
	if (depth > MAX_SERIALIZE_DEPTH) then return nil, pos end
	local tag = string_sub(str, pos, pos)
	if (tag == "s") then
		local colon = string_find(str, ":", pos, true)
		if (not colon) then return nil, pos end
		local len = tonumber(string_sub(str, pos + 1, colon - 1))
		if (not len) then return nil, pos end
		return string_sub(str, colon + 1, colon + len), colon + len + 1
	elseif (tag == "d") then
		local semi = string_find(str, ";", pos, true)
		if (not semi) then return nil, pos end
		return tonumber(string_sub(str, pos + 1, semi - 1)), semi + 1
	elseif (tag == "b") then
		return string_sub(str, pos + 1, pos + 1) == "1", pos + 2
	elseif (tag == "t") then
		local colon = string_find(str, ":", pos, true)
		if (not colon) then return nil, pos end
		local count = tonumber(string_sub(str, pos + 1, colon - 1))
		if (not count) then return nil, pos end
		local result = {}
		local cursor = colon + 1
		for i = 1, count do
			local key
			key, cursor = DeserializeAt(str, cursor, depth + 1)
			if (key == nil) then return nil, pos end
			local value
			value, cursor = DeserializeAt(str, cursor, depth + 1)
			result[key] = value
		end
		return result, cursor
	end
	return nil, pos
end

-- ****************************************************************************
-- Deserializes a string produced by Serialize() back into its original
-- value. Returns nil for anything malformed instead of erroring.
-- ****************************************************************************
local function Deserialize(str)
	if (type(str) ~= "string" or str == "") then return nil end
	local ok, value = pcall(DeserializeAt, str, 1, 1)
	if (ok) then return value end
	return nil
end

local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_LOOKUP

-- ****************************************************************************
-- Encodes a raw string as base64 - keeps exported strings limited to plain
-- alphanumerics, safe to paste into an EditBox without WoW's font renderer
-- misreading a stray "|" as a color/texture escape sequence.
-- ****************************************************************************
local function Base64Encode(data)
	local result = {}
	local len = #data
	for i = 1, len, 3 do
		local a, b, c = string_byte(data, i, i + 2)
		b = b or 0
		local n = a * 65536 + b * 256 + (c or 0)
		local c1 = math_floor(n / 262144) % 64
		local c2 = math_floor(n / 4096) % 64
		local c3 = math_floor(n / 64) % 64
		local c4 = n % 64
		result[#result + 1] = string_sub(B64_CHARS, c1 + 1, c1 + 1)
		result[#result + 1] = string_sub(B64_CHARS, c2 + 1, c2 + 1)
		result[#result + 1] = (i + 1 <= len) and string_sub(B64_CHARS, c3 + 1, c3 + 1) or "="
		result[#result + 1] = (i + 2 <= len) and string_sub(B64_CHARS, c4 + 1, c4 + 1) or "="
	end
	return table.concat(result)
end

-- ****************************************************************************
-- Decodes a base64 string back to raw bytes. Strips anything that isn't a
-- base64 character first, so copy/paste whitespace or line breaks in the
-- pasted text don't need to be cleaned up by the caller.
-- ****************************************************************************
local function Base64Decode(data)
	if (not B64_LOOKUP) then
		B64_LOOKUP = {}
		for i = 1, #B64_CHARS do B64_LOOKUP[string_sub(B64_CHARS, i, i)] = i - 1 end
	end
	data = string_gsub(data, "[^%w%+%/%=]", "")
	local bytes = {}
	local i = 1
	local len = #data
	while i <= len do
		local c1 = B64_LOOKUP[string_sub(data, i, i)]
		local c2 = B64_LOOKUP[string_sub(data, i + 1, i + 1)]
		local s3 = string_sub(data, i + 2, i + 2)
		local s4 = string_sub(data, i + 3, i + 3)
		local c3 = B64_LOOKUP[s3]
		local c4 = B64_LOOKUP[s4]
		if (not c1 or not c2) then break end
		local n = c1 * 262144 + c2 * 4096 + (c3 or 0) * 64 + (c4 or 0)
		bytes[#bytes + 1] = string_char(math_floor(n / 65536) % 256)
		if (s3 ~= "=" and c3) then bytes[#bytes + 1] = string_char(math_floor(n / 256) % 256) end
		if (s4 ~= "=" and c4) then bytes[#bytes + 1] = string_char(n % 256) end
		i = i + 4
	end
	return table.concat(bytes)
end

local EXPORT_PREFIX = "MSBT1:"

-- ****************************************************************************
-- Serializes a value and wraps it into a printable, versioned string ready
-- to show the user for copying.
-- ****************************************************************************
local function ExportString(value)
	return EXPORT_PREFIX .. Base64Encode(Serialize(value))
end

-- ****************************************************************************
-- Reverses ExportString(). Returns nil if the string isn't a validly
-- formatted/tagged export string, or a nil/non-table would result.
-- ****************************************************************************
local function ImportString(str)
	if (type(str) ~= "string") then return nil end
	str = string_gsub(str, "%s", "")
	if (string_sub(str, 1, #EXPORT_PREFIX) ~= EXPORT_PREFIX) then return nil end
	local value = Deserialize(Base64Decode(string_sub(str, #EXPORT_PREFIX + 1)))
	if (type(value) ~= "table") then return nil end
	return value
end



-------------------------------------------------------------------------------
-- Mod utility interface.
-------------------------------------------------------------------------------

-- Protected Variables.
mod.translations = translations
mod.combatLogBlocked = false

-- Protected Functions.
mod.CopyTable			= CopyTable
mod.EraseTable			= EraseTable
mod.SplitString			= SplitString
mod.Print				= Print
mod.GetSkillName		= GetSkillName
mod.ShortenNumber		= ShortenNumber
mod.GetSpellInfo		= GetSpellInfo
mod.GetSpellTexture		= GetSpellTexture
mod.GetSpellCooldown	= GetSpellCooldown
mod.RegisterCombatLogEvent	= RegisterCombatLogEvent
mod.ExportString			= ExportString
mod.ImportString			= ImportString
--mod.SeparateNumber		= SeparateNumber
