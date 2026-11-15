-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text Main
-- Author: Mikord
-------------------------------------------------------------------------------

-- Create module and set its name.
local module = {}
local moduleName = "Main"
MikSBT[moduleName] = module


-------------------------------------------------------------------------------
-- Imports.
-------------------------------------------------------------------------------

-- Local references to various modules for faster access.
local MSBTAnimations = MikSBT.Animations
local MSBTMedia = MikSBT.Media
local MSBTParser = MikSBT.Parser
local MSBTTriggers = MikSBT.Triggers
local MSBTProfiles = MikSBT.Profiles
local L = MikSBT.translations

-- Local references to various functions for faster access.
local table_remove = table.remove
local string_find = string.find
local string_gsub = string.gsub
local string_format = string.format
local string_sub = string.sub
local math_abs = math.abs
local bit_bor = bit.bor
local FormatLargeNumber = FormatLargeNumber
local GetTime = GetTime

local EraseTable = MikSBT.EraseTable
local GetSkillName = MikSBT.GetSkillName
local GetSpellInfo = MikSBT.GetSpellInfo
local ShortenNumber = MikSBT.ShortenNumber
local DisplayEvent = MSBTAnimations.DisplayEvent
local IsScrollAreaActive = MSBTAnimations.IsScrollAreaActive
local IsScrollAreaIconShown = MSBTAnimations.IsScrollAreaIconShown
local TestFlagsAll = MSBTParser.TestFlagsAll

-- Local references to various variables for faster access.
local triggerSuppressions = MSBTTriggers.triggerSuppressions
local powerTypes = MSBTTriggers.powerTypes
local classMap = MSBTParser.classMap

local IsRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE


-------------------------------------------------------------------------------
-- Constants.
-------------------------------------------------------------------------------

-- How long to wait before showing events so that merges may happen.
local MERGE_DELAY_TIME = 0.3

-- How long to wait between throttle window checking.
local THROTTLE_UPDATE_TIME = 0.5

-- Amount of time to hold recent monster emotes and enemy buffs in cache.
local EMOTE_HOLD_TIME = 1
local ENEMY_BUFF_HOLD_TIME = 5

-- Damage types.
local DAMAGETYPE_PHYSICAL = 0x1
local DAMAGETYPE_HOLY = 0x2
local DAMAGETYPE_FIRE = 0x4
local DAMAGETYPE_NATURE = 0x8
local DAMAGETYPE_FROST = 0x10
local DAMAGETYPE_SHADOW = 0x20
local DAMAGETYPE_ARCANE = 0x40

-- Physical + Magic Damage types.
local DAMAGETYPE_SPELLSTRIKE = DAMAGETYPE_PHYSICAL + DAMAGETYPE_ARCANE
local DAMAGETYPE_FLAMESTRIKE = DAMAGETYPE_PHYSICAL + DAMAGETYPE_FIRE
local DAMAGETYPE_FROSTSTRIKE = DAMAGETYPE_PHYSICAL + DAMAGETYPE_FROST
local DAMAGETYPE_STORMSTRIKE = DAMAGETYPE_PHYSICAL + DAMAGETYPE_NATURE
local DAMAGETYPE_SHADOWSTRIKE = DAMAGETYPE_PHYSICAL + DAMAGETYPE_SHADOW
local DAMAGETYPE_HOLYSTRIKE = DAMAGETYPE_PHYSICAL + DAMAGETYPE_HOLY

-- Two magic damage types.
local DAMAGETYPE_SPELLFIRE = DAMAGETYPE_FIRE + DAMAGETYPE_ARCANE
local DAMAGETYPE_SPELLFROST = DAMAGETYPE_FROST + DAMAGETYPE_ARCANE
local DAMAGETYPE_DIVINE = DAMAGETYPE_HOLY + DAMAGETYPE_ARCANE
local DAMAGETYPE_SPELLSTORM = DAMAGETYPE_NATURE + DAMAGETYPE_ARCANE
local DAMAGETYPE_SPELLSHADOW = DAMAGETYPE_SHADOW + DAMAGETYPE_ARCANE
local DAMAGETYPE_HOLYFIRE = DAMAGETYPE_HOLY + DAMAGETYPE_FIRE
local DAMAGETYPE_HOLYSTORM = DAMAGETYPE_HOLY + DAMAGETYPE_NATURE
local DAMAGETYPE_HOLYFROST = DAMAGETYPE_HOLY + DAMAGETYPE_FROST
local DAMAGETYPE_FIRESTORM = DAMAGETYPE_FIRE + DAMAGETYPE_NATURE
local DAMAGETYPE_SHADOWFLAME = DAMAGETYPE_FIRE + DAMAGETYPE_SHADOW
local DAMAGETYPE_FROSTFIRE = DAMAGETYPE_FIRE + DAMAGETYPE_FROST
local DAMAGETYPE_FROSTSTORM = DAMAGETYPE_NATURE + DAMAGETYPE_FROST
local DAMAGETYPE_SHADOWFROST = DAMAGETYPE_FROST + DAMAGETYPE_SHADOW
local DAMAGETYPE_SHADOWHOLY = DAMAGETYPE_HOLY + DAMAGETYPE_SHADOW
local DAMAGETYPE_SHADOWSTORM = DAMAGETYPE_NATURE + DAMAGETYPE_SHADOW

-- Three or more damage types.
local DAMAGETYPE_ELEMENTAL = DAMAGETYPE_FIRE + DAMAGETYPE_NATURE + DAMAGETYPE_FROST
local DAMAGETYPE_COSMIC = DAMAGETYPE_HOLY + DAMAGETYPE_NATURE + DAMAGETYPE_SHADOW + DAMAGETYPE_ARCANE
local DAMAGETYPE_CHROMATIC = DAMAGETYPE_FIRE + DAMAGETYPE_NATURE + DAMAGETYPE_FROST + DAMAGETYPE_SHADOW + DAMAGETYPE_ARCANE
local DAMAGETYPE_MAGIC = DAMAGETYPE_ARCANE + DAMAGETYPE_FIRE + DAMAGETYPE_FROST + DAMAGETYPE_NATURE + DAMAGETYPE_SHADOW + DAMAGETYPE_HOLY
local DAMAGETYPE_CHAOS = DAMAGETYPE_PHYSICAL + DAMAGETYPE_HOLY + DAMAGETYPE_FIRE + DAMAGETYPE_NATURE + DAMAGETYPE_FROST + DAMAGETYPE_SHADOW + DAMAGETYPE_ARCANE

-- Spell IDs.
local SPELLID_AUTOSHOT = 75

-- Spell names.
local SPELL_BLINK					= GetSkillName(1953)
--local SPELL_BLIZZARD				= GetSkillName(10)
local SPELL_BLOOD_STRIKE			= not MikSBT.Client.isClassicContent and GetSkillName(60945)
--local SPELL_BLOOD_STRIKE_OFF_HAND	= GetSkillName(66215)
--local SPELL_HELLFIRE				= GetSkillName(1949)
--local SPELL_HURRICANE				= GetSkillName(16914)
local SPELL_RAIN_OF_FIRE			= GetSkillName(5740)


-------------------------------------------------------------------------------
-- Private variables.
-------------------------------------------------------------------------------

-- Prevent tainting global _.
local _

-- Dynamically created frames for receiving events.
local eventFrame = CreateFrame("Frame")
local throttleFrame = CreateFrame("Frame")

-- Player's class.
local playerClass

-- Pool of dynamically created combat events that are reused.
local combatEventCache = {}

-- Lookup tables.
local eventHandlers = {}

-- Set once a real combat log event involving the player has been parsed, so
-- the Forever-only Solo Combat Feed stands down (the real combat log wins
-- where it works).
local incomingLogSeen, outgoingLogSeen = false, false
local damageTypeMap = {}
local damageColorProfileEntries = {}
local powerTokens = {}
local uniquePowerTypes = {}

-- Throttled ability info.
local throttledAbilities = {}

-- Holds unmerged and merged combat events.
local unmergedEvents = {}
local mergedEvents = {}

-- Used for timing between updates.
local lastMergeUpdate = 0
local lastThrottleUpdate = 0

-- Spam control info.
local isEnglish
local lastPowerAmounts = {}
local finisherShown
local recentEmotes = {}
local recentEnemyBuffs = {}
local ignoreAuras = {}

-- Localized off-hand info to allow merging of off-hand strikes.
local offHandTrailer
local offHandPattern


-------------------------------------------------------------------------------
-- Utility functions.
-------------------------------------------------------------------------------

-- ****************************************************************************
-- Creates damage type and damage color profile maps.
-- ****************************************************************************
local function CreateDamageMaps()
	-- Create the damage type lookup map.
	damageTypeMap[DAMAGETYPE_PHYSICAL] = STRING_SCHOOL_PHYSICAL
	damageTypeMap[DAMAGETYPE_HOLY] = STRING_SCHOOL_HOLY
	damageTypeMap[DAMAGETYPE_FIRE] = STRING_SCHOOL_FIRE
	damageTypeMap[DAMAGETYPE_NATURE] = STRING_SCHOOL_NATURE
	damageTypeMap[DAMAGETYPE_FROST] = STRING_SCHOOL_FROST
	damageTypeMap[DAMAGETYPE_SHADOW] = STRING_SCHOOL_SHADOW
	damageTypeMap[DAMAGETYPE_ARCANE] = STRING_SCHOOL_ARCANE
	damageTypeMap[DAMAGETYPE_HOLYSTRIKE] = STRING_SCHOOL_HOLYSTRIKE
	damageTypeMap[DAMAGETYPE_FLAMESTRIKE] = STRING_SCHOOL_FLAMESTRIKE
	damageTypeMap[DAMAGETYPE_STORMSTRIKE] = STRING_SCHOOL_STORMSTRIKE
	damageTypeMap[DAMAGETYPE_SHADOWSTRIKE] = STRING_SCHOOL_SHADOWSTRIKE
	damageTypeMap[DAMAGETYPE_FROSTSTRIKE] = STRING_SCHOOL_FROSTSTRIKE
	damageTypeMap[DAMAGETYPE_SPELLSTRIKE] = STRING_SCHOOL_SPELLSTRIKE
	damageTypeMap[DAMAGETYPE_HOLYFIRE] = STRING_SCHOOL_HOLYFIRE
	damageTypeMap[DAMAGETYPE_SHADOWHOLY] = STRING_SCHOOL_SHADOWHOLY
	damageTypeMap[DAMAGETYPE_DIVINE] = STRING_SCHOOL_DIVINE
	damageTypeMap[DAMAGETYPE_HOLYSTORM] = STRING_SCHOOL_HOLYSTORM
	damageTypeMap[DAMAGETYPE_HOLYFROST] = STRING_SCHOOL_HOLYFROST
	damageTypeMap[DAMAGETYPE_FIRESTORM] = STRING_SCHOOL_FIRESTORM
	damageTypeMap[DAMAGETYPE_FROSTFIRE] = STRING_SCHOOL_FROSTFIRE
	damageTypeMap[DAMAGETYPE_SHADOWFLAME] = STRING_SCHOOL_SHADOWFLAME
	damageTypeMap[DAMAGETYPE_SPELLFIRE] = STRING_SCHOOL_SPELLFIRE
	damageTypeMap[DAMAGETYPE_FROSTSTORM] = STRING_SCHOOL_FROSTSTORM
	damageTypeMap[DAMAGETYPE_SHADOWSTORM] = STRING_SCHOOL_SHADOWSTORM
	damageTypeMap[DAMAGETYPE_SPELLSTORM] = STRING_SCHOOL_SPELLSTORM
	damageTypeMap[DAMAGETYPE_SHADOWFROST] = STRING_SCHOOL_SHADOWFROST
	damageTypeMap[DAMAGETYPE_SPELLFROST] = STRING_SCHOOL_SPELLFROST
	damageTypeMap[DAMAGETYPE_SPELLSHADOW] = STRING_SCHOOL_SPELLSHADOW
	damageTypeMap[DAMAGETYPE_ELEMENTAL] = STRING_SCHOOL_ELEMENTAL
	damageTypeMap[DAMAGETYPE_COSMIC] = STRING_SCHOOL_COSMIC or L.COSMIC
	damageTypeMap[DAMAGETYPE_CHROMATIC] = STRING_SCHOOL_CHROMATIC
	damageTypeMap[DAMAGETYPE_MAGIC] = STRING_SCHOOL_MAGIC
	damageTypeMap[DAMAGETYPE_CHAOS] = STRING_SCHOOL_CHAOS


	-- Create the damage color profile entries lookup map.
	damageColorProfileEntries[DAMAGETYPE_PHYSICAL] = "physical"
	damageColorProfileEntries[DAMAGETYPE_HOLY] = "holy"
	damageColorProfileEntries[DAMAGETYPE_FIRE] = "fire"
	damageColorProfileEntries[DAMAGETYPE_NATURE] = "nature"
	damageColorProfileEntries[DAMAGETYPE_FROST] = "frost"
	damageColorProfileEntries[DAMAGETYPE_SHADOW] = "shadow"
	damageColorProfileEntries[DAMAGETYPE_ARCANE] = "arcane"
	damageColorProfileEntries[DAMAGETYPE_HOLYSTRIKE] = "holystrike"
	damageColorProfileEntries[DAMAGETYPE_FLAMESTRIKE] = "flamestrike"
	damageColorProfileEntries[DAMAGETYPE_STORMSTRIKE] = "stormstrike"
	damageColorProfileEntries[DAMAGETYPE_FROSTSTRIKE] = "froststrike"
	damageColorProfileEntries[DAMAGETYPE_SHADOWSTRIKE] = "shadowstrike"
	damageColorProfileEntries[DAMAGETYPE_SPELLSTRIKE] = "spellstrike"
	damageColorProfileEntries[DAMAGETYPE_HOLYFIRE] = "radiant"
	damageColorProfileEntries[DAMAGETYPE_SHADOWHOLY] = "twilight"
	damageColorProfileEntries[DAMAGETYPE_DIVINE] = "divine"
	damageColorProfileEntries[DAMAGETYPE_HOLYSTORM] = "holystorm"
	damageColorProfileEntries[DAMAGETYPE_HOLYFROST] = "holyfrost"
	damageColorProfileEntries[DAMAGETYPE_FIRESTORM] = "volcanic"
	damageColorProfileEntries[DAMAGETYPE_FROSTFIRE] = "frostfire"
	damageColorProfileEntries[DAMAGETYPE_SHADOWFLAME] = "shadowflame"
	damageColorProfileEntries[DAMAGETYPE_SPELLFIRE] = "spellfire"
	damageColorProfileEntries[DAMAGETYPE_FROSTSTORM] = "froststorm"
	damageColorProfileEntries[DAMAGETYPE_SHADOWSTORM] = "plague"
	damageColorProfileEntries[DAMAGETYPE_SPELLSTORM] = "astral"
	damageColorProfileEntries[DAMAGETYPE_SHADOWFROST] = "shadowfrost"
	damageColorProfileEntries[DAMAGETYPE_SPELLFROST] = "spellfrost"
	damageColorProfileEntries[DAMAGETYPE_SPELLSHADOW] = "spellshadow"
	damageColorProfileEntries[DAMAGETYPE_ELEMENTAL] = "elemental"
	damageColorProfileEntries[DAMAGETYPE_COSMIC] = "cosmic"
	damageColorProfileEntries[DAMAGETYPE_CHROMATIC] = "chromatic"
	damageColorProfileEntries[DAMAGETYPE_MAGIC] = "magic"
	damageColorProfileEntries[DAMAGETYPE_CHAOS] = "chaos"
end


-- ****************************************************************************
-- Returns an abbreviated form of the passed skill name.
-- ****************************************************************************
local function AbbreviateSkillName(skillName)
	if (string_find(skillName, "[%s%-]")) then
		skillName = string_gsub(skillName, "(%a)[%l%p]*[%s%-]*", "%1")
	end

	return skillName
end


-- ****************************************************************************
-- Returns a formatted partial effects trailer using the passed parameters.
-- ****************************************************************************
local function FormatPartialEffects(absorbAmount, blockAmount, resistAmount, isGlancing, isCrushing)
	-- Get a local reference to the current profile.
	local currentProfile = MSBTProfiles.currentProfile

	local effectSettings, amount
	local partialEffectText = ""

	-- Partial Absorb
	if absorbAmount then
		effectSettings = currentProfile.absorb
		amount = absorbAmount

	-- Partial Block
	elseif blockAmount then
		effectSettings = currentProfile.block
		amount = blockAmount

	-- Partial Resist
	elseif resistAmount then
		effectSettings = currentProfile.resist
		amount = resistAmount
	end

	-- Set the partial effect text if there are settings for it, it's enabled, and it's valid.
	local trailer = effectSettings and effectSettings.trailer
	if trailer and not effectSettings.disabled then
		-- Shorten amount with SI suffixes or separate into digit groups depending on options.
		local formattedAmount = amount
		if currentProfile.shortenNumbers then
			formattedAmount = ShortenNumber(formattedAmount, currentProfile.shortenNumberPrecision)
		elseif currentProfile.groupNumbers then
			formattedAmount = FormatLargeNumber(formattedAmount)
		end

		-- Substitute the amount into the trailer.
		trailer = string_gsub(trailer, "%%a", formattedAmount)

		-- Color the text if coloring isn't disabled.
		if not currentProfile.partialColoringDisabled then
			partialEffectText = string_format("|cFF%02x%02x%02x%s|r", effectSettings.colorR * 255, effectSettings.colorG * 255, effectSettings.colorB * 255, trailer)
		else
			partialEffectText = trailer
		end
	end


	-- Clear the effect settings and trailer.
	effectSettings = nil
	trailer = nil

	-- Glancing hit
	if isGlancing then
		effectSettings = currentProfile.glancing

	-- Crushing blow
	elseif isCrushing then
		effectSettings = currentProfile.crushing
	end

	-- Append the crushing/glancing text if there are settings for it, it's enabled, and it's valid.
	trailer = effectSettings and effectSettings.trailer
	if trailer and not effectSettings.disabled then
		-- Color the text if coloring isn't disabled.
		if not currentProfile.partialColoringDisabled then
			partialEffectText = partialEffectText .. string_format("|cFF%02x%02x%02x%s|r", effectSettings.colorR * 255, effectSettings.colorG * 255, effectSettings.colorB * 255, trailer)
		else
			partialEffectText = partialEffectText .. trailer
		end
	end

	return partialEffectText
end


-- ****************************************************************************
-- Formats an event with the parameters.
-- ****************************************************************************
local function FormatEvent(message, amount, damageType, overhealAmount, overkillAmount, powerType, name, class, effectName, partialEffects, mergeTrailer, ignoreDamageColoring, hideSkills, hideNames)
	-- Get a local reference to the current profile.
	local currentProfile = MSBTProfiles.currentProfile
	local checkParens

	-- Forever: a secret amount turns the message into a secret string, which
	-- none of the pattern-based substitutions below can operate on. When the
	-- amount is secret it is spliced into the message at the very end of this
	-- function instead (see the pendingSecretAmount logic at the bottom).
	local pendingSecretAmount

	-- Substitute amount.
	if amount and string_find(message, "%a", 1, true) then
		-- Check if there is overheal information and displaying it is enabled.
		-- Forever: overheal/overkill amounts can be secret values; arithmetic and
		-- comparisons on them throw, so skip the partial effect logic for those.
		local partialAmount = ""
		local isSecretAmount = issecretvalue and issecretvalue(amount)
		if overhealAmount and not (issecretvalue and issecretvalue(overhealAmount)) and overhealAmount > 0 and not currentProfile.overheal.disabled then
			-- Deduct the overheal amount from the total amount healed.
			amount = amount - overhealAmount

			-- Shorten overheal amount with SI suffixes or separate into digit groups depending on options.
			partialAmount = overhealAmount
			if currentProfile.shortenNumbers then
				partialAmount = ShortenNumber(partialAmount, currentProfile.shortenNumberPrecision)
			elseif currentProfile.groupNumbers then
				partialAmount = FormatLargeNumber(partialAmount)
			end

			-- Color it with the correct color if coloring is enabled.
			local overhealSettings = currentProfile.overheal
			partialAmount = string_gsub(overhealSettings.trailer, "%%a", partialAmount)
			if not currentProfile.partialColoringDisabled then
				partialAmount = string_format("|cFF%02x%02x%02x%s|r", overhealSettings.colorR * 255, overhealSettings.colorG * 255, overhealSettings.colorB * 255, partialAmount)
			end

		-- No overheal so check if there is overkill information and displaying it is enabled.
		elseif overkillAmount and not (issecretvalue and issecretvalue(overkillAmount)) and overkillAmount > 0 and not currentProfile.overkill.disabled then
			-- Deduct the overkill amount from the total amount of damage done.
			amount = amount - overkillAmount

			-- Shorten overkill amount with SI suffixes or separate into digit groups depending on options.
			partialAmount = overkillAmount
			if currentProfile.shortenNumbers then
				partialAmount = ShortenNumber(partialAmount, currentProfile.shortenNumberPrecision)
			elseif currentProfile.groupNumbers then
				partialAmount = FormatLargeNumber(partialAmount)
			end

			-- Color it with the correct color if coloring is enabled.
			local overkillSettings = currentProfile.overkill
			partialAmount = string_gsub(overkillSettings.trailer, "%%a", partialAmount)
			if not currentProfile.partialColoringDisabled then
				partialAmount = string_format("|cFF%02x%02x%02x%s|r", overkillSettings.colorR * 255, overkillSettings.colorG * 255, overkillSettings.colorB * 255, partialAmount)
			end
		end


		-- Make sure to show positive amounts for eclipse energy since it can be negative.
		local formattedAmount = amount
		--if (powerType == powerTypes["ECLIPSE"]) then formattedAmount = math_abs(amount) end

		-- Shorten amount with SI suffixes or separate into digit groups depending on options.
		-- Forever: secret amounts can't be shortened or grouped; pass them through raw.
		if not (isSecretAmount or (issecretvalue and issecretvalue(formattedAmount))) then
			if currentProfile.shortenNumbers then
				formattedAmount = ShortenNumber(formattedAmount, currentProfile.shortenNumberPrecision)
			elseif currentProfile.groupNumbers then
				formattedAmount = FormatLargeNumber(formattedAmount)
			end
		end

		-- Get the hex color for the damage type if there is one and coloring is enabled.
		if damageType and not ignoreDamageColoring and not currentProfile.damageColoringDisabled then
			-- Color the amount according to the damage type if there is one and it's enabled.
			local damageSettings = currentProfile[damageColorProfileEntries[damageType]]
			if damageSettings and not damageSettings.disabled then
				formattedAmount = string_format("|cFF%02x%02x%02x%s|r", damageSettings.colorR * 255, damageSettings.colorG * 255, damageSettings.colorB * 255, formattedAmount)
			end
		end -- Damage type and damage coloring is enabled.

		-- Substitute all %a event codes with the amount.
		-- Forever: string.gsub refuses secret values, and once a secret is
		-- spliced into the message no pattern work is possible on it. Defer the
		-- splice to the end of this function for secret amounts.
		if isSecretAmount or (issecretvalue and issecretvalue(formattedAmount)) then
			pendingSecretAmount = formattedAmount .. partialAmount
		else
			message = string_gsub(message, "%%a", formattedAmount .. partialAmount)
		end
	end -- Substitute amount.


	-- Substitute power type.
	if powerType and string_find(message, "%p", 1, true) then
		local powerString = _G[powerTokens[powerType] or "UNKNOWN"]
		--if (powerType == powerTypes["ECLIPSE"]) then powerString = amount and (amount > 0 and BALANCE_POSITIVE_ENERGY or BALANCE_NEGATIVE_ENERGY) or UNKNOWN end
		message = string_gsub(message, "%%p", powerString or UNKNOWN)
	end


	-- Substitute names.
	if name and string_find(message, "%n", 1, true) then
		if hideNames then
			message = string_gsub(message, "%s?%-?%s?%%n", "")
			checkParens = true
		else
			-- Strip realm from names.
			if string_find(name, "-", 1, true) then
				name = string_gsub(name, "(.-)%-.*", "%1")
			end

			-- Color the name according to the class if there is one and it's enabled.
			if class and not currentProfile.classColoringDisabled then
				local classSettings = currentProfile[class]
				if classSettings and not classSettings.disabled then
					name = string_format("|cFF%02x%02x%02x%s|r", classSettings.colorR * 255, classSettings.colorG * 255, classSettings.colorB * 255, name)
				end
			end

			-- Substitute all %n event codes with the name.
			message = string_gsub(message, "%%n", name)
		end
	else
		message = string_gsub(message, "%%n", "")
		checkParens = true
	end


	-- Substitute effect names.
	if effectName and string_find(message, "%e", 1, true) then
		message = string_gsub(message, "%%e", effectName)
	end


	-- Substitute skill names.
	if effectName then
		if string_find(message, "%s", 1, true) then
			-- Hide skill names if there is an icon for it and the option is set.
			if (hideSkills) then
				message = string_gsub(message, "%s?%-?%s?%%sl?%s?%-?%s?", "")
				checkParens = true
			else
				-- Use the user defined substitution for the ability if there is one.
				local isChanged
				if (currentProfile.abilitySubstitutions[effectName]) then
					effectName = currentProfile.abilitySubstitutions[effectName]
					isChanged = true
				end

				-- Do long substitutions.
				if string_find(message, "%sl", 1, true) then
					message = string_gsub(message, "%%sl", effectName)
				end

				-- Abbreviate skill for English if it wasn't user substituted and abbreviation is enabled.
				if isEnglish and not isChanged and currentProfile.abbreviateAbilities then
					effectName = AbbreviateSkillName(effectName)
				end

				-- Do remaining substitutions.
				message = string_gsub(message, "%%s", effectName)
			end
		end
	elseif string_find(message, "%s", 1, true) then
		-- No skill known (e.g. Forever's UNIT_COMBAT fallback): drop the
		-- token instead of showing it raw.
		message = string_gsub(message, "%s?%-?%s?%%sl?%s?%-?%s?", "")
		checkParens = true
	end


	-- Remove empty parenthesis left frame ignoring event codes.
	if checkParens then
		message = string_gsub(message, "%(%)", "")
		message = string_gsub(message, "%[%]", "")
		message = string_gsub(message, "%{%}", "")
		message = string_gsub(message, "%<%>", "")
	end


	-- Substitute damage types.
	if damageType and string_find(message, "%t", 1, true) then
		message = string_gsub(message, "%%t", damageTypeMap[damageType] or STRING_SCHOOL_UNKNOWN)
	end


	-- Append partial effects if there are any.
	if partialEffects then
		message = message .. partialEffects
	end


	-- Append the merge trailer if there is one.
	if mergeTrailer then
		message = message .. mergeTrailer
	end

	-- Forever: splice a secret amount last using plain find + concat. This runs
	-- after all other substitutions because a message containing a secret value
	-- can't be used with string.gsub/string_find patterns anymore.
	if pendingSecretAmount then
		local out, rest = "", message
		while true do
			local startPos, endPos = string_find(rest, "%a", 1, true)
			if not startPos then break end
			out = out .. string_sub(rest, 1, startPos - 1) .. pendingSecretAmount
			rest = string_sub(rest, endPos + 1)
		end
		message = out .. rest
	end

	-- Return the formatted message.
	return message
end


-- ****************************************************************************
-- Returns the event type prefix and affected unit name for events that
-- can be incoming or outgoing.
-- ****************************************************************************
local function GetInOutEventData(parserEvent)
	local eventTypeString, affectedUnitName, affectedUnitClass

	-- Get the information for whether the event is incoming or outgoing.
	if parserEvent.recipientUnit == "player" then
		affectedUnitName = parserEvent.sourceName
		eventTypeString = "INCOMING"
		affectedUnitClass = classMap[parserEvent.sourceGUID]
	elseif parserEvent.sourceUnit == "player" then
		affectedUnitName = parserEvent.recipientName
		eventTypeString = "OUTGOING"
		affectedUnitClass = classMap[parserEvent.recipientGUID]
	elseif parserEvent.recipientUnit == "pet" then
		affectedUnitName = parserEvent.sourceName
		eventTypeString = "PET_INCOMING"
		affectedUnitClass = classMap[parserEvent.sourceGUID]
	elseif parserEvent.sourceUnit == "pet" then
		affectedUnitName = parserEvent.recipientName
		eventTypeString = "PET_OUTGOING"
		affectedUnitClass = classMap[parserEvent.recipientGUID]
	end

	return eventTypeString, affectedUnitName, affectedUnitClass
end


-- ****************************************************************************
-- Detect all power gains.
-- ****************************************************************************
local function DetectPowerGain(powerAmount, powerType)
	-- Get the event settings.
	local eventSettings = MSBTProfiles.currentProfile.events.NOTIFICATION_POWER_GAIN

	-- Don't do anything if the event is disabled or the power type is invalid.
	if eventSettings.disabled or not powerType then
		return
	end

	-- Display the power change if it is a gain.
	local lastPowerAmount = lastPowerAmounts[powerType] or 65535
	if powerAmount > lastPowerAmount then
		DisplayEvent(eventSettings, FormatEvent(eventSettings.message, powerAmount - lastPowerAmount, nil, nil, nil, powerType, nil, nil, UNKNOWN))
	end
end

-- UnitPower()/UnitPowerMax() can return secret numbers in combat on the
-- Forever client, which can't be compared; treat those as unknown.
local function UnitPowerMax(unit, powerType)
	local value = _G.UnitPowerMax(unit, powerType)
	if value ~= nil and issecretvalue and issecretvalue(value) then return nil end
	return value
end

-- ****************************************************************************
-- Handle combo point changes.
-- ****************************************************************************
local function HandleComboPoints(amount, powerType)
	-- Get the correct event settings.
	local eventSettings = MSBTProfiles.currentProfile.events.NOTIFICATION_CP_GAIN
	local maxAmount = UnitPowerMax("player", powerType)
	if amount == maxAmount then
		eventSettings = MSBTProfiles.currentProfile.events.NOTIFICATION_CP_FULL
	end
	-- Don't do anything if the event is disabled.
	if eventSettings.disabled then
		return
	end
	-- Don't do anything if 0 CP
	if amount == 0 then
		return
	end
	-- Display the event.
	if amount <= 0 then
		return
	end

	DisplayEvent(eventSettings, FormatEvent(eventSettings.message, amount))
end

-- ****************************************************************************
-- Handle light force changes.
-- ****************************************************************************
local function HandleChi(amount, powerType)
	-- Get the correct event settings.
	local eventSettings = MSBTProfiles.currentProfile.events.NOTIFICATION_CHI_CHANGE
	local maxAmount = UnitPowerMax("player", powerType)
	if amount == maxAmount then
		eventSettings = MSBTProfiles.currentProfile.events.NOTIFICATION_CHI_FULL
	end

	-- Don't do anything if the event is disabled.
	if eventSettings.disabled then
		return
	end

	-- Display the event.
	if amount <= 0 then
		return
	end

	DisplayEvent(eventSettings, FormatEvent(eventSettings.message, amount))
end

-- ****************************************************************************
-- Handle arcane power changes.
-- ****************************************************************************
local function HandleArcanePower(amount, powerType)
	-- Get the correct event settings.
	local eventSettings = MSBTProfiles.currentProfile.events.NOTIFICATION_AC_CHANGE
	local maxAmount = UnitPowerMax("player", powerType)
	if amount == maxAmount then
		eventSettings = MSBTProfiles.currentProfile.events.NOTIFICATION_AC_FULL
	end

	-- Don't do anything if the event is disabled.
	if eventSettings.disabled then
		return
	end

	-- Display the event.
	if amount <= 0 then
		return
	end

	DisplayEvent(eventSettings, FormatEvent(eventSettings.message, amount))
end

-- ****************************************************************************
-- Handle holy power changes.
-- ****************************************************************************
local function HandleHolyPower(amount, powerType)
	-- Get the correct event settings.
	local eventSettings = MSBTProfiles.currentProfile.events.NOTIFICATION_HOLY_POWER_CHANGE
	local maxAmount = UnitPowerMax("player", powerType)
	if amount == maxAmount then
		eventSettings = MSBTProfiles.currentProfile.events.NOTIFICATION_HOLY_POWER_FULL
	end

	-- Don't do anything if the event is disabled.
	if eventSettings.disabled then
		return
	end

	-- Don't do anything if 0 Holy Power
	if amount == 0 then
		return
	end

	-- Display the event.
	if amount <= 0 then
		return
	end

	DisplayEvent(eventSettings, FormatEvent(eventSettings.message, amount))
end

-- ****************************************************************************
-- Handle essence changes.
-- ****************************************************************************
local function HandleEssence(amount, powerType)
	-- Get the correct event settings.
	local eventSettings = MSBTProfiles.currentProfile.events.NOTIFICATION_ESSENCE_CHANGE
	local maxAmount = UnitPowerMax("player", powerType)
	if (amount == maxAmount) then eventSettings = MSBTProfiles.currentProfile.events.NOTIFICATION_ESSENCE_FULL end

	-- Don't do anything if the event is disabled.
	if (eventSettings.disabled) then return end

	-- Don't do anything if 0 Essence
	if (amount == 0) then return end

	-- Display the event.
	if amount <= 0 then
		return
	end

	DisplayEvent(eventSettings, FormatEvent(eventSettings.message, amount))
end

-- ****************************************************************************
-- Handle monster emotes.
-- ****************************************************************************
local function HandleMonsterEmotes(emoteString)
	-- Get the event settings.
	local eventSettings = MSBTProfiles.currentProfile.events.NOTIFICATION_MONSTER_EMOTE

	-- Don't do anything if the event is disabled.
	if eventSettings.disabled then
		return
	end

	-- Loop through all of the recent emotes and remove the old ones.
	local now = GetTime()
	for emote, cleanupTime in pairs(recentEmotes) do
		if now >= cleanupTime then
			recentEmotes[emote] = nil
		end
	end

	-- Don't do anything if the emote has already been shown within the specified time frame.
	if recentEmotes[emoteString] then
		return
	end

	-- Display the event and add it to the recent emotes list.
	DisplayEvent(eventSettings, FormatEvent(eventSettings.message, nil, nil, nil, nil, nil, nil, nil, emoteString))
	recentEmotes[emoteString] = now + EMOTE_HOLD_TIME
end


-- ****************************************************************************
-- Merges like combat events.
-- ****************************************************************************
local function MergeEvents(numEvents, currentProfile)
	-- Holds an unmerged event and whether or not to merge it.
	local unmergedEvent
	local doMerge = false

	-- Don't attempt to merge any more events than were available when the function was called since
	-- more events may get added while the merge is taking place.
	for i = 1, numEvents do
		-- Get the unmerged event.
		unmergedEvent = unmergedEvents[i]

		-- Loop through all of the events in the merged events array.
		for _, mergedEvent in ipairs(mergedEvents) do
			-- Check if the event types match.
			if unmergedEvent.eventType == mergedEvent.eventType then
				-- Check if there is no skill name.
				if not unmergedEvent.effectName then
					-- Set the merge flag if the affected unit name is the same.
					if unmergedEvent.name == mergedEvent.name and unmergedEvent.name then
						doMerge = true
					end

				-- The skill names match.
				elseif unmergedEvent.effectName == mergedEvent.effectName then
					-- Change the name to the multiple targets string if the names don't match.
					if unmergedEvent.name ~= mergedEvent.name then
						mergedEvent.name = L.MSG_MULTIPLE_TARGETS
					end

					-- Clear the class if they don't match.
					if unmergedEvent.class ~= mergedEvent.class then
						mergedEvent.class = nil
					end

					-- Set the merge flag.
					doMerge = true
				end
			end -- Event types match.

			-- Check if the event should be merged.
			if doMerge then
				-- Clear partial effects.
				mergedEvent.partialEffects = nil

				-- Set the event merged flag for the event being merged.
				unmergedEvent.eventMerged = true

				-- Total the amount if there is one.
				if unmergedEvent.amount then
					mergedEvent.amount = (mergedEvent.amount or 0) + unmergedEvent.amount
				end

				-- Total the overheal amount if there is one.
				if unmergedEvent.overhealAmount then
					mergedEvent.overhealAmount = (mergedEvent.overhealAmount or 0) + unmergedEvent.overhealAmount
				end

				-- Increment the number of merged events.
				mergedEvent.numMerged = mergedEvent.numMerged + 1

				-- Increment the number of crits if the event being merged is a crit. Clear the crit flag for the merged event if it isn't.
				if unmergedEvent.isCrit then
					mergedEvent.numCrits = mergedEvent.numCrits + 1 else mergedEvent.isCrit = false
				end

				-- Break out of the merged events loop since the event has been merged.
				break
			end -- Do Merge.
		end -- Loop through merged events.

		-- Add the event to the end of the merged events array if it wasn't merged.
		if not doMerge then
			unmergedEvent.numMerged = 0

			-- Set the number of crits depending on if the event is a crit or not.
			if unmergedEvent.isCrit then
				unmergedEvent.numCrits = 1 else unmergedEvent.numCrits = 0
			end

			-- Add the event to the end of the merged events array.
			mergedEvents[#mergedEvents+1] = unmergedEvent
		end

		-- Reset the event merge flag.
		doMerge = false
	end -- Loop through unmerged events.


	-- Append merge trailer information to the merged events if enabled.
	if not currentProfile.hideMergeTrailer then
		for _, mergedEvent in ipairs(mergedEvents) do
			-- Check if there were any events merged.
			if mergedEvent.numMerged > 0 then
				-- Create the crit trailer text if there were any crits.
				local critTrailer = ""
				if mergedEvent.numCrits > 0 then
					critTrailer = string_format(", %d %s", mergedEvent.numCrits, mergedEvent.numCrits == 1 and L.MSG_CRIT or L.MSG_CRITS)
				end

				-- Set the event's merge trailer field.
				mergedEvent.mergeTrailer = string_format(" [%d %s%s]", mergedEvent.numMerged + 1, L.MSG_HITS, critTrailer)
			end -- Events were merged.
		end -- Loop through merged events.
	end

	-- Remove the processed events from unmerged events queue.
	for i = 1, numEvents do
		-- Recycle the unmerged event if it was merged.
		if unmergedEvents[1].eventMerged then
			EraseTable(unmergedEvents[1])
			combatEventCache[#combatEventCache + 1] = unmergedEvents[1]
		end

		-- Remove the event from the unmerged events array.
		table_remove(unmergedEvents, 1)
	end
end


-------------------------------------------------------------------------------
-- Event handlers.
-------------------------------------------------------------------------------

-- ****************************************************************************
-- Handles damage parser events.
-- ****************************************************************************
local function DamageHandler(parserEvent, currentProfile)
	-- Setup info for whether the event is incoming or outgoing.
	local eventTypeString, affectedUnitName, affectedUnitClass = GetInOutEventData(parserEvent)

	-- Ignore the event if it doesn't pertain to the player or their pet.
	if not eventTypeString then
		return
	end

	-- Ignore the event if the damage amount is under the damage threshold to be shown.
	-- Forever: amounts can be secret values in combat, which can't be compared;
	-- secret amounts are always shown instead of being dropped.
	if parserEvent.amount and not (issecretvalue and issecretvalue(parserEvent.amount)) and parserEvent.amount < currentProfile.damageThreshold then
		return
	end

	-- Recharacterize hunter auto shots to melee damage.
	local skillID = parserEvent.skillID
	if skillID == SPELLID_AUTOSHOT then
		skillID = nil
	end

	-- Append the spell prefix if there is a skill.
	if skillID then
		eventTypeString = eventTypeString .. "_SPELL"
	end

	-- Append correct damage suffix.
	eventTypeString = eventTypeString .. (parserEvent.isDoT and "_DOT" or parserEvent.isDamageShield and "_DAMAGE_SHIELD" or "_DAMAGE")

	return eventTypeString, parserEvent.skillName, affectedUnitName, affectedUnitClass, true
end


-- ****************************************************************************
-- Handles miss parser events.
-- ****************************************************************************
local function MissHandler(parserEvent, currentProfile)
	-- Setup info for whether the event is incoming or outgoing.
	local eventTypeString, affectedUnitName, affectedUnitClass = GetInOutEventData(parserEvent)

	-- Ignore the event if it doesn't pertain to the player or their pet.
	if not eventTypeString then
		return
	end

	-- Recharacterize hunter auto shots to melee damage.
	local skillID = parserEvent.skillID
	if skillID == SPELLID_AUTOSHOT then
		skillID = nil
	end

	-- Append the spell prefix if there is a skill.
	if skillID then
		eventTypeString = eventTypeString .. "_SPELL"
	end

	-- Append the miss type.
	eventTypeString = eventTypeString .. "_" .. parserEvent.missType

	return eventTypeString, parserEvent.skillName, affectedUnitName, affectedUnitClass, true
end


-- ****************************************************************************
-- Handles heal parser events.
-- ****************************************************************************
local function HealHandler(parserEvent, currentProfile)
	-- Setup info for whether the event is incoming or outgoing.
	local eventTypeString, affectedUnitName, affectedUnitClass = GetInOutEventData(parserEvent)

	-- Ignore the event if it doesn't pertain to the player or their pet.
	if not eventTypeString then
		return
	end

	local isHoT = parserEvent.isHoT
	local amount = parserEvent.amount
	if amount and not (issecretvalue and issecretvalue(amount)) then
		-- Ignore the event if the heal amount is under the healing threshold to be shown.
		if amount < currentProfile.healThreshold then
			return
		end

		-- Calculate the effective heal amount.
		local overhealAmount = parserEvent.overhealAmount
		local effectiveHealAmount = overhealAmount and (amount - overhealAmount) or amount

		-- Ignore the event if the effective heal amount is zero and the appropriate
		-- hide full overheals option is set.
		if effectiveHealAmount == 0 then
			if not isHoT and currentProfile.hideFullOverheals then
				return
			end
			if isHoT and currentProfile.hideFullHoTOverheals then
				return
			end
		end
	end

	-- Slicing out self-cast heals into their own thing.
	if parserEvent.sourceName == parserEvent.recipientName then
		eventTypeString = "SELF"
	end

	-- Append hot suffix if it's a hot.
	eventTypeString = eventTypeString .. (isHoT and "_HOT" or "_HEAL")

	return eventTypeString, parserEvent.skillName, affectedUnitName, affectedUnitClass, true
end


-- ****************************************************************************
-- Handles interrupt parser events.
-- ****************************************************************************
local function InterruptHandler(parserEvent, currentProfile)
	-- Setup info for whether the event is incoming or outgoing.
	local eventTypeString, affectedUnitName, affectedUnitClass = GetInOutEventData(parserEvent)

	-- Ignore the event if it doesn't pertain to the player or their pet.
	if not eventTypeString then
		return
	end

	-- Append interrupt suffix.
	eventTypeString = eventTypeString .. "_SPELL_INTERRUPT"

	return eventTypeString, parserEvent.extraSkillName, affectedUnitName, affectedUnitClass
end


-- ****************************************************************************
-- Handles environmental parser events.
-- ****************************************************************************
local function EnvironmentalHandler(parserEvent, currentProfile)
	-- Ignore the event if it isn't the player.
	if parserEvent.recipientUnit ~= "player" then
		return
	end

	return "INCOMING_ENVIRONMENTAL", parserEvent.hazardType
end


-- ****************************************************************************
-- Handles aura parser events.
-- ****************************************************************************
local function AuraHandler(parserEvent, currentProfile)
	local eventTypeString, affectedUnitName, affectedUnitClass
	local effectName = parserEvent.skillName

	-- Aura is pertaining to the player.
	if parserEvent.recipientUnit == "player" then
		-- Ignore auras that don't provide useful information.
		if ignoreAuras[parserEvent.skillName] and parserEvent.sourceUnit == "player" then
			return
		end

		-- Ignore the event if it's suppressed due to a trigger.
		if triggerSuppressions[effectName] then
			return
		end

		-- Set notification buff/debuff.
		eventTypeString = "NOTIFICATION_" .. parserEvent.auraType

		-- Append stack or fade prefix if needed.
		if not parserEvent.isFade then
			if (parserEvent.isDose) then
				eventTypeString = eventTypeString .. "_STACK"
			end
		else
			eventTypeString = eventTypeString .. "_FADE"
		end

	-- Aura is pertaining to another unit.
	else
		-- Ignore the event if it's suppressed due to a trigger.
		if triggerSuppressions[effectName] then
			return
		end

		-- Ignore the event if it isn't for the current target.
		if not TestFlagsAll(parserEvent.recipientFlags, MSBTParser.TARGET_TARGET) then
			return
		end

		-- Ignore the event if it's a friendly unit.
		if not UnitIsEnemy("player", "target") then
			return
		end

		-- Ignore the event if it's not a buff gain.
		if parserEvent.auraType ~= "BUFF" or parserEvent.isFade == true then
			return
		end

		-- Loop through all of the recent enemy buff gains and remove the old ones.
		local now = GetTime()
		for buff, cleanupTime in pairs(recentEnemyBuffs) do
			if (now >= cleanupTime) then
				recentEnemyBuffs[buff] = nil
			end
		end

		-- Ignore the event if it has already been shown within the specified time frame.
		if recentEnemyBuffs[effectName] then
			return
		end

		-- Add the event to the recent enemy buffs list.
		recentEnemyBuffs[effectName] = now + ENEMY_BUFF_HOLD_TIME

		eventTypeString = "NOTIFICATION_ENEMY_BUFF"
		affectedUnitName = parserEvent.recipientName
		affectedUnitClass = classMap[parserEvent.recipientGUID]
	end -- Player or enemy check.

	return eventTypeString, effectName, affectedUnitName, affectedUnitClass
end


-- ****************************************************************************
-- Handles enchant parser events.
-- ****************************************************************************
local function EnchantHandler(parserEvent, currentProfile)
	-- Ignore the event if it isn't the player.
	if parserEvent.recipientUnit ~= "player" then
		return
	end

	-- Set the item buff event type and append fade suffix if the enchant is fading.
	local eventTypeString = "NOTIFICATION_ITEM_BUFF"
	if parserEvent.isFade then
		eventTypeString = eventTypeString .. "_FADE"
	end

	return eventTypeString, parserEvent.skillName
end


-- ****************************************************************************
-- Handles dispel parser events.
-- ****************************************************************************
local function DispelHandler(parserEvent, currentProfile)
	-- Get the correct dispel event.
	local eventTypeString
	if parserEvent.sourceUnit == "player" then
		eventTypeString = "OUTGOING_DISPEL"
	elseif parserEvent.sourceUnit == "pet" then
		eventTypeString = "PET_OUTGOING_DISPEL"
	else
		-- Ignore the event if it isn't from the player or their pet.
		return
	end

	return eventTypeString, parserEvent.extraSkillName, parserEvent.recipientName, classMap[parserEvent.recipientGUID]
end


-- ****************************************************************************
-- Handles power parser events.
-- ****************************************************************************
local function PowerHandler(parserEvent, currentProfile)
	-- Handle certain power types such as holy power, shadow orbs, and chi uniquely.
	if uniquePowerTypes[parserEvent.powerType] ~= nil then
		return
	end

	-- Ignore the event if all power gains are being shown.
	if currentProfile.showAllPowerGains then
		return
	end

	-- Ignore the event it doesn't affect the player and set the correct amount.
	local amount
	if parserEvent.isLeech then
		if parserEvent.sourceUnit ~= "player" then
			return
		end
		amount = parserEvent.extraAmount
	else
		if parserEvent.recipientUnit ~= "player" then
			return
		end
		amount = parserEvent.amount
	end

	if amount == 0 then
		return
	end

	-- Ignore the event if the power change is under the threshold to be shown.
	-- Take the absolute value to ensure negative power amounts such as Lunar Energy are handled correctly.
	if amount and math_abs(amount) < currentProfile.powerThreshold then
		return
	end

	-- Use a different event for alternate power.
	local eventTypePrefix = "NOTIFICATION_POWER_"
	if parserEvent.powerType == powerTypes["ALTERNATE_POWER"] then
		eventTypePrefix = "NOTIFICATION_ALT_POWER_"
	end

	-- Append gain or loss suffix.
	local eventTypeString = eventTypePrefix .. (parserEvent.isDrain and "LOSS" or "GAIN")

	return eventTypeString, parserEvent.skillName, nil, nil, true
end


-- ****************************************************************************
-- Handles kill parser events.
-- ****************************************************************************
local function KillHandler(parserEvent, currentProfile)
	-- Ignore the event if it isn't a kill from the player.
	if parserEvent.sourceUnit ~= "player" then
		return
	end

	-- Ignore the event if it is a player guardian (Hunter snakes, etc).
	if TestFlagsAll(parserEvent.recipientFlags, bit_bor(MSBTParser.UNITTYPE_GUARDIAN, MSBTParser.CONTROL_HUMAN)) then
		return
	end

	-- Ignore the event if it is the player's pet to prevent killing blow events due to sacrifices (Death Knight ghoul, etc).
	if parserEvent.recipientUnit == "pet" then
		return
	end

	-- Figure out the event type depending on whether a player or the server
	-- controlled the unit that was killed.
	local eventTypeString = "NOTIFICATION_"
	eventTypeString = eventTypeString .. (TestFlagsAll(parserEvent.recipientFlags, MSBTParser.CONTROL_SERVER) and "NPC" or "PC")
	eventTypeString = eventTypeString .. "_KILLING_BLOW"

	return eventTypeString, nil, parserEvent.recipientName, classMap[parserEvent.recipientGUID]
end


-- ****************************************************************************
-- Handles honor parser events.
-- ****************************************************************************
local function HonorHandler(parserEvent, currentProfile)
	-- Ignore the event if it isn't for the player.
	if parserEvent.recipientUnit ~= "player" then
		return
	end

	return "NOTIFICATION_HONOR_GAIN"
end


-- ****************************************************************************
-- Handles reputation parser events.
-- ****************************************************************************
local function ReputationHandler(parserEvent, currentProfile)
	-- Ignore the event if it isn't for the player.
	if parserEvent.recipientUnit ~= "player" then
		return
	end

	-- Append loss or gain suffix.
	local eventTypeString = "NOTIFICATION_REP_" .. (parserEvent.isLoss and "LOSS" or "GAIN")
	return eventTypeString, parserEvent.factionName
end


-- ****************************************************************************
-- Handles proficiency parser events.
-- ****************************************************************************
local function ProficiencyHandler(parserEvent, currentProfile)
	-- Ignore the event if it isn't for the player.
	if parserEvent.recipientUnit ~= "player" then
		return
	end

	return "NOTIFICATION_SKILL_GAIN", parserEvent.skillName
end


-- ****************************************************************************
-- Handles experience parser events.
-- ****************************************************************************
local function ExperienceHandler(parserEvent, currentProfile)
	-- Ignore the event if it isn't for the player.
	if parserEvent.recipientUnit ~= "player" then
		return
	end

	return "NOTIFICATION_EXPERIENCE_GAIN"
end


-- ****************************************************************************
-- Handles extra attacks parser events.
-- ****************************************************************************
local function ExtraAttacksHandler(parserEvent, currentProfile)
	-- Ignore the event if it isn't for the player.
	if parserEvent.sourceUnit ~= "player" then
		return
	end

	return "NOTIFICATION_EXTRA_ATTACK", parserEvent.skillName
end


-- ****************************************************************************
-- Parser events handler.
-- ****************************************************************************
local function ParserEventsHandler(parserEvent)
	local seenType = parserEvent.eventType
	if seenType == "damage" or seenType == "heal" then
		if parserEvent.recipientGUID and parserEvent.recipientUnit == "player" then incomingLogSeen = true end
		if parserEvent.sourceGUID and parserEvent.sourceUnit == "player" then outgoingLogSeen = true end
	end

	-- Get a local reference to the current profile.
	local currentProfile = MSBTProfiles.currentProfile

	-- Information regarding how to display the event.
	local eventTypeString, effectName, affectedUnitName, affectedUnitClass, mergeEligible

	-- Local copy for faster access.
	local eventType = parserEvent.eventType

	-- Call the correct handler for the event type if there is one.
	local handler = eventHandlers[eventType]
	if handler then
		eventTypeString, effectName, affectedUnitName, affectedUnitClass, mergeEligible = handler(parserEvent, currentProfile)

	-- Forever: merging totals amounts with arithmetic, which throws on secret
	-- values; force direct display for secret amounts instead of merging them.
	if mergeEligible and parserEvent.amount and (issecretvalue and issecretvalue(parserEvent.amount)) then
		mergeEligible = false
	end
	end

	-- Ignore the event if it is unrecognized.
	if not eventTypeString then
		return
	end

	-- Ignore the event if there is a skill name and it's suppressed.
	if effectName and currentProfile.abilitySuppressions[effectName] then
		return
	end

	-- Ignore the event if there is no profile data for it, it's disabled, or the scroll area it's using is not active.
	local isCrit = parserEvent.isCrit
	local eventSettings = currentProfile.events[isCrit and eventTypeString .. "_CRIT" or eventTypeString]
	if not eventSettings or eventSettings.disabled or not IsScrollAreaActive(eventSettings.scrollArea) then
		return
	end

	-- Local copies for faster access.
	local damageType = parserEvent.damageType
	local skillID = parserEvent.skillID

	-- Recharacterize hunter auto shots to melee damage.
	if skillID == SPELLID_AUTOSHOT then
		skillID = nil
		effectName = nil
	end

	-- Ignore damage coloring on outgoing physical skills so they are easier to tell apart from auto attacks.
	local ignoreDamageColoring
	if eventType == "damage" and parserEvent.sourceUnit == "player" and damageType == DAMAGETYPE_PHYSICAL and skillID then
		ignoreDamageColoring = true
	end

	-- Set the damage type to the school of the fully absorbed skills.
	if eventType == "miss" and parserEvent.missType == "ABSORB" then
		damageType = parserEvent.skillSchool or DAMAGETYPE_PHYSICAL
	end

	-- Get the formatted partial effects if it's a damage or environmental event.
	local partialEffects
	if eventType == "damage" or eventType == "environmental" then
		partialEffects = FormatPartialEffects(parserEvent.absorbAmount, parserEvent.blockAmount, parserEvent.resistAmount, parserEvent.isGlancing, parserEvent.isCrushing)
	end

	-- Attempt to get the texture for the event if icons are not disabled.
	local effectTexture
	if not currentProfile.skillIconsDisabled and IsScrollAreaIconShown(eventSettings.scrollArea) then
		if skillID then
			_, _, effectTexture = GetSpellInfo(skillID)
		end

		-- Override texture for dispels and interrupts.
		if (eventType == "dispel" or eventType == "interrupt" or (eventType == "miss" and parserEvent.missType == "RESIST")) and parserEvent.extraSkillID then
			_, _, effectTexture = GetSpellInfo(parserEvent.extraSkillID)
		end
		if not effectTexture and effectName then
			_, _, effectTexture = GetSpellInfo(effectName)
		end
	end

	-- Event is not eligible to be merged so just display it now without processing the impossible fields.
	if not mergeEligible then
		local outputMessage = FormatEvent(eventSettings.message, parserEvent.amount, damageType, nil, nil, nil, affectedUnitName, affectedUnitClass, effectName)
		DisplayEvent(eventSettings, outputMessage, effectTexture)

	-- Event is eligible for merging, but is excluded so display it now with full processing.
	elseif currentProfile.mergeExclusions[effectName] or (not effectName and currentProfile.mergeSwingsDisabled) then
		-- Hide skill names according to the options if a texture is available.
		local hideSkills = effectTexture and not currentProfile.exclusiveSkillsDisabled or currentProfile.hideSkills
		local outputMessage = FormatEvent(eventSettings.message, parserEvent.amount, damageType, parserEvent.overhealAmount, parserEvent.overkillAmount, parserEvent.powerType, affectedUnitName, affectedUnitClass, effectName, partialEffects, nil, ignoreDamageColoring, hideSkills, currentProfile.hideNames)
		DisplayEvent(eventSettings, outputMessage, effectTexture)

	-- The event is eligible for merging.
	else
		-- Acquire a recycled table from cache or create a new one if there aren't any available in cache.
		local combatEvent = table_remove(combatEventCache) or {}

		-- Strip off-hand trailers so they merge with main hand strikes of the same name.
		-- Use a plain text search since it is faster than doing a full regular expression search.
		if effectName and offHandTrailer and string_find(effectName, offHandTrailer, 1, true) then
			effectName = string_gsub(effectName, offHandPattern, "")
		end


		-- Setup the combat event.
		combatEvent.eventType = eventTypeString
		combatEvent.isCrit = isCrit
		combatEvent.amount = parserEvent.amount
		combatEvent.effectName = effectName
		combatEvent.effectTexture = effectTexture
		combatEvent.name = affectedUnitName
		combatEvent.class = affectedUnitClass
		combatEvent.damageType = damageType
		combatEvent.ignoreDamageColoring = ignoreDamageColoring
		combatEvent.partialEffects = partialEffects
		combatEvent.overhealAmount = parserEvent.overhealAmount
		combatEvent.overkillAmount = parserEvent.overkillAmount
		combatEvent.powerType = parserEvent.powerType

		-- Throttle events according to user settings.
		if effectName then
			-- Get the duration the ability should be throttled for, if any.
			local throttleDuration = currentProfile.throttleList[effectName]

			-- Set throttle duration for power changes or dots/hots if there isn't a specific one set for the ability.
			if not throttleDuration then
				-- Use the dot throttle duration.
				if parserEvent.isDoT and currentProfile.dotThrottleDuration > 0 then
					throttleDuration = currentProfile.dotThrottleDuration

				-- Use the hot throttle duration.
				elseif parserEvent.isHoT and currentProfile.hotThrottleDuration > 0 then
					throttleDuration = currentProfile.hotThrottleDuration

				-- Use the power change throttle duration.
				elseif parserEvent.powerType and currentProfile.powerThrottleDuration > 0 then
					throttleDuration = currentProfile.powerThrottleDuration
				end
			end

			-- Check if there is a throttle duration for the ability.
			if throttleDuration and throttleDuration > 0 then
				-- Get throttle info for the ability. Create it if it hasn't already been.
				local throttledAbility = throttledAbilities[effectName]
				if not throttledAbility then
					throttledAbility = {}
					throttledAbility.throttleWindow = 0
					throttledAbility.lastEventTime = 0
					throttledAbilities[effectName] = throttledAbility
				end

				-- Throttle the event and exit if the throttle window for the ability hasn't elapsed.
				local now = GetTime()
				if throttledAbility.throttleWindow > 0 then
						throttledAbility.lastEventTime = now
						throttledAbility[#throttledAbility + 1] = combatEvent
						return

				-- The throttle window for the ability has elapsed.
				else
					-- Set the throttle window for the ability to its throttle duration.
					throttledAbility.throttleWindow = throttleDuration

					-- Check if the throttle frame is not visible and make it visible so the OnUpdate events start firing.
					-- This is done to keep the number of OnUpdate events down to a minimum for better performance.
					if not throttleFrame:IsVisible() then
						throttleFrame:Show()
					end

					-- Throttle the event and exit if it has been seen within the throttle duration.
					if now - throttledAbility.lastEventTime < throttleDuration then
						throttledAbility.lastEventTime = now
						throttledAbility[#throttledAbility + 1] = combatEvent
						return
					end
				end
			end -- Has throttle duration.
		end -- Has effectName.

		-- Add event to the unmerged events for potential merging.
		unmergedEvents[#unmergedEvents + 1] = combatEvent

		-- Check if the merge event frame is not visible and make it visible so the OnUpdate events start firing.
		-- This is done to keep the number of OnUpdate events down to a minimum for better performance.
		if not eventFrame:IsVisible() then
			eventFrame:Show()
		end
	end -- Merge eligibility.
end


-- ****************************************************************************
-- Called when the event frame is updated.
-- ****************************************************************************
local function OnUpdateEventFrame(this, elapsed)
	-- Increment the amount of time passed since the last update.
	lastMergeUpdate = lastMergeUpdate + elapsed

	-- If it's time for an update.
	if lastMergeUpdate >= MERGE_DELAY_TIME then
		-- Local references for faster access.
		local currentProfile = MSBTProfiles.currentProfile
		local hideNames = currentProfile.hideNames
		local exclusiveSkillsDisabled = currentProfile.exclusiveSkillsDisabled

		-- Merge like events.
		MergeEvents(#unmergedEvents, currentProfile)

		-- Display and recycle the merged events.
		local eventSettings, hideSkills, outputMessage
		for i, combatEvent in ipairs(mergedEvents) do
			eventSettings = currentProfile.events[combatEvent.isCrit and combatEvent.eventType .. "_CRIT" or combatEvent.eventType]
			hideSkills = combatEvent.effectTexture and not exclusiveSkillsDisabled or currentProfile.hideSkills
			outputMessage = FormatEvent(eventSettings.message, combatEvent.amount, combatEvent.damageType, combatEvent.overhealAmount, combatEvent.overkillAmount, combatEvent.powerType, combatEvent.name, combatEvent.class, combatEvent.effectName, combatEvent.partialEffects, combatEvent.mergeTrailer, combatEvent.ignoreDamageColoring, hideSkills, hideNames)
			DisplayEvent(eventSettings, outputMessage, combatEvent.effectTexture)
			mergedEvents[i] = nil
			EraseTable(combatEvent)
			combatEventCache[#combatEventCache + 1] = combatEvent
		end

		-- Hide the frame if there are no remaining unmerged events so the OnUpdate events stop firing.
		-- This is done to keep the number of OnUpdate events down to a minimum for better performance.
		if #unmergedEvents == 0 then
			this:Hide()
		end

		-- Reset the time since last update.
		lastMergeUpdate = 0
	end
end


-- ****************************************************************************
-- Called when the throttle frame is updated.
-- ****************************************************************************
local function OnUpdateThrottleFrame(this, elapsed)
	-- Increment the amount of time passed since the last update.
	lastThrottleUpdate = lastThrottleUpdate + elapsed

	-- If it's time for an update.
	if lastThrottleUpdate >= THROTTLE_UPDATE_TIME then
		-- Flag for whether there are any events currently throttled.
		local eventsThrottled

		-- Loop through all the throttled abilities.
		for _, throttledAbility in pairs(throttledAbilities) do
			-- Check if the ability is currently being throttled.
			if throttledAbility.throttleWindow > 0 then
				-- Decrement the throttle window.
				throttledAbility.throttleWindow = throttledAbility.throttleWindow - lastThrottleUpdate

				-- Check if the throttle window has elapsed.
				if throttledAbility.throttleWindow <= 0 then
					-- Add throttled events to the merging system if there are any.
					if #throttledAbility > 0 then
						for i = 1, #throttledAbility do
							unmergedEvents[#unmergedEvents + 1] = throttledAbility[i]
							throttledAbility[i] = nil
						end

						-- Check if the merge event frame is not visible and make it visible so the OnUpdate events start firing.
						-- This is done to keep the number of OnUpdate events down to a minimum for better performance.
						if not eventFrame:IsVisible() then
							eventFrame:Show()
						end
					end
				-- Ability is still throttled so set the flag.
				else
					eventsThrottled = true
				end
			end -- Ability is within its throttle window.
		end -- Loop through throttled abilities.


		-- Hide the frame if there are no remaining throttled events so the OnUpdate events stop firing.
		-- This is done to keep the number of OnUpdate events down to a minimum for better performance.
		if not eventsThrottled then
			this:Hide()
		end

		-- Reset the time since last update.
		lastThrottleUpdate = 0
	end
end


-- ****************************************************************************
-- Called when a unit's power changes.
-- ****************************************************************************
function eventFrame:UNIT_POWER_UPDATE(unitID, powerToken)
	-- Ignore the event if it isn't for the player.
	if unitID ~= "player" then
		return
	end

	-- Ignore the event if it isn't for a known power type.
	local powerType = powerTypes[powerToken]
	if not powerType then
		return
	end

	-- Get the current power amount for the power type that changed.
	local powerAmount = UnitPower("player", powerType)
	if issecretvalue and issecretvalue(powerAmount) then return end

	local doFullDetect = true
	local lastPowerAmount = lastPowerAmounts[powerType]

	-- Handle chi uniquely.
	if powerToken == "CHI" and playerClass == "MONK" then
		if powerAmount ~= lastPowerAmount then
			HandleChi(powerAmount, powerType)
		end
		doFullDetect = false

	-- Handle Holy Power uniquely.
	elseif powerToken == "HOLY_POWER" and playerClass == "PALADIN" then
		if powerAmount ~= lastPowerAmount then
			HandleHolyPower(powerAmount, powerType)
		end
		doFullDetect = false

	-- Handle Combo Points uniquely.
	elseif powerToken == "COMBO_POINTS" and playerClass == "ROGUE" then
		if powerAmount ~= lastPowerAmount then
			HandleComboPoints(powerAmount, powerType)
		end
		doFullDetect = false

	elseif powerToken == "COMBO_POINTS" and playerClass == "DRUID" then
		if powerAmount ~= lastPowerAmount then
			HandleComboPoints(powerAmount, powerType)
		end
		doFullDetect = false

	-- Handle Arcane Charges uniquely.
	elseif powerToken == "ARCANE_CHARGES" and playerClass == "MAGE" then
		if powerAmount ~= lastPowerAmount then
			HandleArcanePower(powerAmount, powerType)
		end
		doFullDetect = false

	-- Handle Essence uniquely.
	elseif powerToken == "ESSENCE" and playerClass == "EVOKER" then
		if powerAmount ~= lastPowerAmount then
			HandleEssence(powerAmount, powerType)
		end
		doFullDetect = false

	end

	-- Detect power gains if show all power gains is enabled.
	if doFullDetect and MSBTProfiles.currentProfile.showAllPowerGains then
		DetectPowerGain(powerAmount, powerType)
	end
	lastPowerAmounts[powerType] = powerAmount
end


-------------------------------------------------------------------------------
-- SOLO COMBAT FEED (Forever): the player's damage and healing - and nothing
-- but the player's.
-------------------------------------------------------------------------------
-- Every number this pipeline displays comes from a signal that can only
-- describe the player:
--   * UNIT_SPELLCAST_* on "player"        - their own casts;
--   * UNIT_COMBAT on "player"             - damage/misses landing ON the
--                                           player (the recipient is provably
--                                           the player);
--   * UNIT_COMBAT on "target", SOLO only  - outside a group every wound on
--                                           the target is the player's own
--                                           (or their pet's);
--   * C_DamageMeter, GROUP only           - GUID-keyed per-spell totals: the
--                                           ONLY dealt-damage/deal-heal source
--                                           that is provably the player's
--                                           inside a group.
--
-- In a group, UNIT_COMBAT on the target cannot say WHO swung, so it is
-- dropped entirely there: a party member's hit must never surface as the
-- player's. If the meter feed cannot deliver in a group (its per-spell values
-- may be Blizzard secret values mid-combat - see the diagnostics below),
-- dealt damage shows nothing rather than something wrong.
--
-- Both dealt-damage collectors (solo UNIT_COMBAT hits and group meter deltas)
-- feed the SAME classifier and accumulator, so both modes behave alike:
--   * a hit landing right after its cast shows immediately (the direct hit);
--   * hits of one spell keep showing directly while they arrive at melee
--     cadence (multi-hit specials like Stormstrike);
--   * once a spell's hits space out (a DoT's 3s cadence, a slow weapon), the
--     spell switches to sustained mode and groups into "Spell (hits) total",
--     flushed when the spell has been quiet for a few seconds or at combat
--     end;
--   * unattributed hits (weapon swings, procs) render as the classic plain
--     melee numbers, independent of any spell.
-- The look stays 100% MSBT: everything goes through the standard
-- ParserEventsHandler into the profile's regular scroll areas, colors and
-- merge machinery.
--
-- Secret Values: combatSpells entries (spellID, totalAmount) may come back as
-- Blizzard "secret values" while in combat (patch 12.0's Secret Values
-- system) - arithmetic, comparisons or string conversion on them error
-- instead of just returning a wrong result. SafeAddZero below unwraps a value
-- the same way the Midnight fork's NormalizeNumber() does: try "value + 0" in
-- a pcall, and treat it as unusable (skip that entry) if that throws.
-------------------------------------------------------------------------------

local function SafeAddZero(value)
	local ok, result = pcall(function() return value + 0 end)
	if ok and type(result) == "number" then
		return result
	end
	return nil
end

-- Secret strings (e.g. UnitName("target") in combat) can't be compared or
-- merged on, so drop them from synthetic events.
local function NonSecret(value)
	if value ~= nil and issecretvalue and issecretvalue(value) then return nil end
	return value
end

-- Renders any value as printable text without touching secret values
-- (diagnostics only).
local function SafeText(value)
	if value == nil then return "nil" end
	if issecretvalue and issecretvalue(value) then return "<secret>" end
	local ok, text = pcall(tostring, value)
	return ok and text or "<unprintable>"
end

local function damageMeterAvailable()
	return C_DamageMeter and Enum and Enum.DamageMeterType and true or false
end


-------------------------------------------------------------------------------
-- §1 Collectors.
-------------------------------------------------------------------------------

-- CastTracker: the player's own casts. recentCasts keeps the latest cast time
-- per spell (direct-hit detection, in both modes); lastCast is the most
-- recent cast of any spell (the wound-attribution candidate); heal-marked
-- spells are never used to attribute damage, so a DoT tick cannot inherit a
-- heal cast's name; channelled spells always count as sustained damage.
local recentCasts = {}
local lastCast = { spellID = nil, time = 0 }
local playerHealSpellIDs = {}
local channelledSpells = {}

local function TrackPlayerCast(unitID, spellID)
	if unitID ~= "player" then return end
	local ok, id = pcall(function() return spellID + 0 end)
	if not ok or type(id) ~= "number" then return end
	recentCasts[id] = GetTime()
	lastCast.spellID, lastCast.time = id, GetTime()
end

-- The heal/damage from a cast lands with (or before) UNIT_SPELLCAST_SUCCEEDED,
-- so casts are also recorded when they start and are sent.
function eventFrame:UNIT_SPELLCAST_SUCCEEDED(unitID, _, spellID) TrackPlayerCast(unitID, spellID) end
function eventFrame:UNIT_SPELLCAST_START(unitID, _, spellID) TrackPlayerCast(unitID, spellID) end
function eventFrame:UNIT_SPELLCAST_SENT(unitID, _, _, spellID) TrackPlayerCast(unitID, spellID) end
function eventFrame:UNIT_SPELLCAST_CHANNEL_START(unitID, _, spellID)
	if unitID ~= "player" then return end
	local ok, id = pcall(function() return spellID + 0 end)
	if ok and type(id) == "number" then channelledSpells[id] = true end
end
function eventFrame:UNIT_SPELLCAST_CHANNEL_STOP(unitID, _, spellID)
	if unitID ~= "player" then return end
	local ok, id = pcall(function() return spellID + 0 end)
	if ok and type(id) == "number" then channelledSpells[id] = nil end
end

-- HealthLedger: frame-lagged player health observations. When a heal lands,
-- UNIT_HEALTH (which reports the post-heal value) and UNIT_COMBAT's heal
-- event fire in the same frame in unspecified order; the two-slot buffer
-- keeps a pre-heal observation either way, which is what the overheal
-- estimate needs.
local observedHealth, previousHealth = nil, nil

function eventFrame:UNIT_HEALTH(unitTarget)
	if unitTarget ~= "player" then return end
	local ok, hp = pcall(UnitHealth, "player")
	if not ok or type(hp) ~= "number" or (issecretvalue and issecretvalue(hp)) then return end
	previousHealth = observedHealth
	observedHealth = hp
end

-- Estimates how much of a heal landing on the player exceeded their max
-- health at that moment (nil when it can't be estimated). Rendered by
-- FormatEvent's existing overheal trailer - an estimate, since UNIT_COMBAT
-- does not expose the overheal amount.
local function PlayerOverheal(amount)
	if amount == nil or (issecretvalue and issecretvalue(amount)) then return nil end
	local okMax, maxHealth = pcall(UnitHealthMax, "player")
	local before = previousHealth or observedHealth
	if not okMax or type(maxHealth) ~= "number" or before == nil then return nil end
	if issecretvalue and (issecretvalue(maxHealth) or issecretvalue(before)) then return nil end
	local ok, missing = pcall(function() return maxHealth - before end)
	if not ok or type(missing) ~= "number" or missing <= 0 then return nil end
	if amount < missing then missing = amount end
	return missing
end


-------------------------------------------------------------------------------
-- §2 Classifier and §3 accumulator (shared by both modes).
-------------------------------------------------------------------------------

-- Direct-hit discrimination: a hit landing within DIRECT_HIT_WINDOW seconds
-- of the player casting that spell is the spell's direct hit and shows
-- immediately. Further hits of the same spell keep showing directly while
-- they arrive at melee cadence (DIRECT_HIT_SPACING: multi-hit specials such
-- as Stormstrike); once a spell's hits space out beyond that (a DoT's 3s
-- cadence), the spell switches to sustained mode.
local DIRECT_HIT_WINDOW = 1.2
local DIRECT_HIT_SPACING = 1.0
-- A sustained spell flushes "Spell (hits) total" once it has been quiet for
-- SUSTAINED_IDLE_FLUSH seconds or when combat ends. The value must exceed the
-- longest DoT tick interval (3s in Classic) or ticking spells would flush
-- every tick.
local SUSTAINED_IDLE_FLUSH = 3.5
-- A spell switches to sustained (grouped) mode only after this many of its
-- hits arrived spaced beyond DIRECT_HIT_SPACING - evidence of DoT-like
-- behaviour. Until then every attributed hit SHOWS: never withhold a number
-- on a guess.
local SUSTAINED_SPACED_HITS = 2
-- How long a spell's last hit keeps it a candidate for "its next tick" when
-- no cast is in reach (rule 2 below). Must comfortably exceed a DoT tick
-- interval so mid-fight ticks still attribute.
local TICK_TRACKING_WINDOW = 7.0
-- Solo attribution windows. The heal window is short because a heal event
-- always fires right when its cast completes - and a HoT tick arriving later
-- must not mark an unrelated fresh damage cast as a heal.
local WOUND_ATTRIBUTION_WINDOW = 4.0
local HEAL_ATTRIBUTION_WINDOW = 1.0

-- Meter poll cadence, type constants, and the pending-flush age: meter deltas
-- aggregate per spell and flush as one line per second instead of one
-- fragment per 0.5s poll.
local METER_POLL_INTERVAL = 0.5
local METER_PENDING_FLUSH = 1.0
local DM_DAMAGEDONE = (Enum and Enum.DamageMeterType and Enum.DamageMeterType.DamageDone) or 0
local DM_HEALINGDONE = (Enum and Enum.DamageMeterType and Enum.DamageMeterType.HealingDone) or 2

-- Per-spell state: { mode = "direct"|"sustained", lastTime, spacedHits,
-- school, amount, hits, overheal, pendingSince }. Direct mode shows every
-- attributed hit; sustained mode groups them. pendingSince is set only for
-- meter-fed pending amounts (flushed by age); solo sustained groups flush on
-- idle instead.
local hitStates, healStates = {}, {}
local damageMeterLastTotals = {}
local damageMeterLastOverkills = {}
local damageMeterTicker

-- Decision log (diagnostics): records how each wound/heal was attributed and
-- displayed so a test can be verified from the SavedVariables dump. Capped.
local decisionLog = {}
local function LogDecision(text)
	decisionLog[#decisionLog + 1] = string_format("%.1f %s", GetTime() % 10000, text)
	if #decisionLog > 200 then table_remove(decisionLog, 1) end
end

-- Attributes a solo UNIT_COMBAT wound on the target to a spell (or nil for
-- the classic plain melee number). damageType is the wound's school - the
-- school is evidence: a fire wound cannot be a weapon swing. In strict mode
-- (groups) the weaker "old cast" rule is skipped: a hit 2s after a cast may
-- belong to anyone.
--   1. a fresh cast (within DIRECT_HIT_WINDOW): the wound is its direct hit
--      or application tick - always that spell;
--   2. exactly one spell with recent hits whose school matches: the wound is
--      its next tick (multi-spell or school-mismatch falls through, so a
--      weapon swing during a fire DoT is never misattributed);
--   3. an old cast within the window (SOLO only): likely that spell's hit
--      (shown immediately);
--   4. otherwise unattributed: plain melee number (weapon swings, procs).
local function AttributeSoloWound(now, damageType, strict)
	-- 1. Fresh cast.
	if lastCast.spellID and (now - lastCast.time) <= DIRECT_HIT_WINDOW and not playerHealSpellIDs[lastCast.spellID] then
		return lastCast.spellID, lastCast.time
	end
	-- 2. A single spell with recent hits owns its ticks (school-matched).
	local active, activeSchool, ambiguous
	for spellID, state in pairs(hitStates) do
		if (now - state.lastTime) <= TICK_TRACKING_WINDOW then
			if active then ambiguous = true break end
			active, activeSchool = spellID, state.school
		end
	end
	if not ambiguous and active and damageType ~= nil and activeSchool ~= nil and damageType == activeSchool then
		return active, nil
	end
	-- 3. An old cast within the wound window (SOLO only - in a group a hit
	--    arriving 2s after a cast may belong to anyone).
	if not strict and lastCast.spellID and (now - lastCast.time) <= WOUND_ATTRIBUTION_WINDOW
		and not playerHealSpellIDs[lastCast.spellID] then
		return lastCast.spellID, lastCast.time
	end
	-- 4. Unattributed.
	return nil, nil
end

-- ****************************************************************************
-- Flushes one sustained group as a single MSBT event: "<Spell> (<hits>)
-- <total>" (plus the accumulated overheal for heals). Called when the spell
-- has been quiet for SUSTAINED_IDLE_FLUSH seconds, when its meter-pending
-- amount is METER_PENDING_FLUSH seconds old, or at combat end.
-- ****************************************************************************
local function FlushSustained(states, spellID, eventType)
	local state = states[spellID]
	if not state or state.mode ~= "sustained" or (state.amount or 0) <= 0 then
		states[spellID] = nil
		return
	end
	-- NonSecret: a spell name coming back as a secret string must not be
	-- concatenated ("Spell (hits)") or merged mid-combat.
	local spellName = NonSecret(GetSpellInfo(spellID))
	local event = {eventType = eventType, sourceUnit = "player", amount = state.amount,
		skillID = spellID, skillName = spellName and (spellName .. " (" .. state.hits .. ")") or nil}
	if eventType == "heal" then
		event.recipientUnit = "target"
		event.recipientName = NonSecret(UnitName("player"))
		if (state.overheal or 0) > 0 then event.overhealAmount = state.overheal end
	end
	LogDecision("flush " .. SafeText(spellID) .. " " .. eventType .. " hits=" .. SafeText(state.hits) .. " total=" .. SafeText(state.amount))
	ParserEventsHandler(event)
	states[spellID] = nil
end

local function FlushAllSustained()
	for spellID in pairs(hitStates) do FlushSustained(hitStates, spellID, "damage") end
	for spellID in pairs(healStates) do FlushSustained(healStates, spellID, "heal") end
end

-- Emits one of the player's outgoing hits right away. With spellID nil this
-- is the classic plain melee number, independent of any spell.
local function EmitOwnHitNow(spellID, spellName, amount, isCrit, damageType)
	ParserEventsHandler({eventType = "damage", sourceUnit = "player", amount = amount,
		isCrit = isCrit, damageType = damageType, skillID = spellID, skillName = spellName})
end

--*****************************************************************************
-- Feeds one of the player's outgoing hits (a solo UNIT_COMBAT wound or a
-- group meter delta) into the shared classifier. SHOW BY DEFAULT: direct
-- hits, melee-cadence multi-hits and one-off hits all display immediately.
-- Only a spell that demonstrated DoT-like behaviour (SUSTAINED_SPACED_HITS
-- hits spaced beyond the melee cadence) switches to sustained mode, and that
-- affects only its FUTURE hits - the already-shown ones stay on screen.
-- Meter deltas (aggregated totals, no per-hit detail) always buffer per
-- spell and flush once per second (readable, never dropped).
--***************************************************************************
local function FeedOwnHit(spellID, spellName, amount, isCrit, damageType, castTime, isMeterDelta)
	if amount == nil then return end

	-- Weapon swing / unattributed hit: the classic plain melee number.
	if spellID == nil then
		LogDecision("wound nil -> plain show")
		EmitOwnHitNow(nil, nil, amount, isCrit, damageType)
		return
	end

	local now = GetTime()
	local state = hitStates[spellID]
	local secretAmount = issecretvalue and issecretvalue(amount)

	-- A fresh cast is always the spell's direct hit (channelled spells count
	-- as sustained from the start). A recast closes any open sustained group
	-- of the same spell first, so its accumulated total is not lost.
	if castTime and not secretAmount and (now - castTime) <= DIRECT_HIT_WINDOW and not channelledSpells[spellID] then
		if state and state.mode == "sustained" then FlushSustained(hitStates, spellID, "damage") end
		hitStates[spellID] = { mode = "direct", lastTime = now, spacedHits = 0, school = damageType }
		LogDecision("hit " .. SafeText(spellID) .. " -> fresh-cast show")
		EmitOwnHitNow(spellID, spellName, amount, isCrit, damageType)
		return
	end

	-- Meter deltas: aggregate per spell, flush by age (see PollDamageMeter).
	if isMeterDelta then
		if state == nil or state.mode ~= "sustained" then
			state = { mode = "sustained", amount = 0, hits = 0, lastTime = now, pendingSince = now }
			hitStates[spellID] = state
		end
		if state.pendingSince == nil then state.pendingSince = now end
		if secretAmount then
			-- Secret amounts can't be accumulated: show the delta directly.
			state.lastTime = now
			LogDecision("hit " .. SafeText(spellID) .. " -> meter SECRET show")
			EmitOwnHitNow(spellID, spellName, amount, isCrit, damageType)
			return
		end
		state.amount = state.amount + amount
		state.hits = state.hits + 1
		state.lastTime = now
		LogDecision("hit " .. SafeText(spellID) .. " -> meter buffer total=" .. SafeText(state.amount))
		return
	end

	-- Channelled spells always count as sustained damage: their ticks group.
	if channelledSpells[spellID] then
		if state == nil or state.mode ~= "sustained" then
			state = { mode = "sustained", amount = 0, hits = 0, lastTime = now, school = damageType }
			hitStates[spellID] = state
		end
		if secretAmount then
			state.lastTime = now
			LogDecision("hit " .. SafeText(spellID) .. " -> channelled SECRET show")
			EmitOwnHitNow(spellID, spellName, amount, isCrit, damageType)
			return
		end
		state.amount = state.amount + amount
		state.hits = state.hits + 1
		state.lastTime = now
		LogDecision("hit " .. SafeText(spellID) .. " -> channelled buffer total=" .. SafeText(state.amount))
		return
	end

	-- Melee-cadence follow-up of a spell that already shows individually.
	if state and state.mode == "direct" and (now - state.lastTime) <= DIRECT_HIT_SPACING then
		state.lastTime = now
		LogDecision("hit " .. SafeText(spellID) .. " -> cadence show")
		EmitOwnHitNow(spellID, spellName, amount, isCrit, damageType)
		return
	end

	-- First hit of this spell: show it immediately (safety first).
	if state == nil then
		hitStates[spellID] = { mode = "direct", lastTime = now, spacedHits = 0, school = damageType }
		LogDecision("hit " .. SafeText(spellID) .. " -> first show")
		EmitOwnHitNow(spellID, spellName, amount, isCrit, damageType)
		return
	end

	if state.mode == "direct" then
		-- A hit spaced beyond the melee cadence: count it. From the
		-- SUSTAINED_SPACED_HITS-th spaced hit on, the spell groups (DoT-like).
		state.spacedHits = state.spacedHits + 1
		if state.spacedHits < SUSTAINED_SPACED_HITS then
			state.lastTime = now
			LogDecision("hit " .. SafeText(spellID) .. " -> spaced show (" .. SafeText(state.spacedHits) .. ")")
			EmitOwnHitNow(spellID, spellName, amount, isCrit, damageType)
			return
		end
		state.mode = "sustained"
		state.amount, state.hits = 0, 0
		LogDecision("hit " .. SafeText(spellID) .. " -> sustained switch")
	end

	-- Sustained accumulation.
	if secretAmount then
		state.lastTime = now
		LogDecision("hit " .. SafeText(spellID) .. " -> sustained SECRET show")
		EmitOwnHitNow(spellID, spellName, amount, isCrit, damageType)
		return
	end
	state.amount = state.amount + amount
	state.hits = state.hits + 1
	state.lastTime = now
	LogDecision("hit " .. SafeText(spellID) .. " -> sustained buffer total=" .. SafeText(state.amount))
end

--*****************************************************************************
-- Feeds one of the player's outgoing heals (a solo self-heal via UNIT_COMBAT
-- or a group meter delta), with the same show-by-default rules as damage.
-- overhealAmount comes from PlayerOverheal (solo estimate) or the meter's
-- overkillAmount (groups); FormatEvent renders it as the overheal trailer.
--***************************************************************************
local function FeedOwnHeal(spellID, spellName, amount, isCrit, overhealAmount, castTime, isMeterDelta)
	if amount == nil then return end

	local function Emit()
		ParserEventsHandler({eventType = "heal", sourceUnit = "player",
			-- recipientUnit is a non-"player" token so GetInOutEventData
			-- classifies the event as OUTGOING (it checks recipientUnit ==
			-- "player" first); the recipient is the player, so HealHandler's
			-- self-heal check (sourceName == recipientName, both nil here)
			-- also cannot misfire.
			recipientUnit = "target", recipientName = NonSecret(UnitName("player")),
			amount = amount, isCrit = isCrit, skillID = spellID, skillName = spellName,
			overhealAmount = overhealAmount})
	end

	-- Unattributed heal (HoT tick with no cast in reach, potion): show it.
	if spellID == nil then
		LogDecision("heal nil -> plain show")
		Emit()
		return
	end

	local now = GetTime()
	local state = healStates[spellID]
	local secretAmount = issecretvalue and issecretvalue(amount)

	if castTime and not secretAmount and (now - castTime) <= DIRECT_HIT_WINDOW then
		if state and state.mode == "sustained" then FlushSustained(healStates, spellID, "heal") end
		healStates[spellID] = { mode = "direct", lastTime = now, spacedHits = 0 }
		LogDecision("heal " .. SafeText(spellID) .. " -> fresh-cast show")
		Emit()
		return
	end

	if isMeterDelta then
		if state == nil or state.mode ~= "sustained" then
			state = { mode = "sustained", amount = 0, overheal = 0, hits = 0, lastTime = now, pendingSince = now }
			healStates[spellID] = state
		end
		if state.pendingSince == nil then state.pendingSince = now end
		if secretAmount then
			state.lastTime = now
			LogDecision("heal " .. SafeText(spellID) .. " -> meter SECRET show")
			Emit()
			return
		end
		state.amount = state.amount + amount
		if overhealAmount then pcall(function() state.overheal = state.overheal + overhealAmount end) end
		state.hits = state.hits + 1
		state.lastTime = now
		LogDecision("heal " .. SafeText(spellID) .. " -> meter buffer total=" .. SafeText(state.amount))
		return
	end

	if state and state.mode == "direct" and (now - state.lastTime) <= DIRECT_HIT_SPACING then
		state.lastTime = now
		LogDecision("heal " .. SafeText(spellID) .. " -> cadence show")
		Emit()
		return
	end

	if state == nil then
		healStates[spellID] = { mode = "direct", lastTime = now, spacedHits = 0 }
		LogDecision("heal " .. SafeText(spellID) .. " -> first show")
		Emit()
		return
	end

	if state.mode == "direct" then
		state.spacedHits = state.spacedHits + 1
		if state.spacedHits < SUSTAINED_SPACED_HITS then
			state.lastTime = now
			LogDecision("heal " .. SafeText(spellID) .. " -> spaced show (" .. SafeText(state.spacedHits) .. ")")
			Emit()
			return
		end
		state.mode = "sustained"
		state.amount, state.overheal, state.hits = 0, 0, 0
		LogDecision("heal " .. SafeText(spellID) .. " -> sustained switch")
	end

	if secretAmount then
		state.lastTime = now
		LogDecision("heal " .. SafeText(spellID) .. " -> sustained SECRET show")
		Emit()
		return
	end
	state.amount = state.amount + amount
	if overhealAmount then pcall(function() state.overheal = state.overheal + overhealAmount end) end
	state.hits = state.hits + 1
	state.lastTime = now
	LogDecision("heal " .. SafeText(spellID) .. " -> sustained buffer total=" .. SafeText(state.amount))
end

-------------------------------------------------------------------------------
-- §4 Group authority: the C_DamageMeter feed.
-------------------------------------------------------------------------------
-- UNIT_COMBAT on the target cannot attribute hits inside a group, so there
-- the GUID-keyed C_DamageMeter per-spell totals are the ONLY dealt-damage and
-- dealt-healing source. Entries that cannot be unwrapped (secret values) are
-- skipped: in a group this feed shows your damage or nothing, never anyone
-- else's. Solo the meter is not polled at all - UNIT_COMBAT is authoritative
-- and richer there (per-hit detail, crits, damage schools), so nothing can
-- ever display twice.
-- ****************************************************************************

-- Polls one C_DamageMeter type for the player and feeds each spell's
-- newly-registered amount into the shared classifier. The hit-count estimate
-- for grouped spells is one hit per 0.5s poll window in which the spell grew
-- (a window rarely contains two hits of the same spell).
local function PollDamageMeterSource(damageMeterType, isHeal)
	local okGUID, playerGUID = pcall(UnitGUID, "player")
	if not okGUID or not playerGUID then return end

	local okSource, source = pcall(C_DamageMeter.GetCombatSessionSourceFromType, 0, damageMeterType, playerGUID)
	if not okSource or not source then return end

	local okSpells, combatSpells = pcall(function() return source.combatSpells end)
	if not okSpells or type(combatSpells) ~= "table" then return end

	for _, entry in ipairs(combatSpells) do
		local spellID = SafeAddZero(entry.spellID)
		local totalAmount = SafeAddZero(entry.totalAmount)
		if spellID and totalAmount and totalAmount > 0 then
			local key = damageMeterType .. ":" .. spellID
			local previousAmount = damageMeterLastTotals[key] or 0

			-- A drop below the last known total means the session reset
			-- (new pull/segment or meter reset); treat the fresh total as
			-- the delta instead of going negative.
			local delta = totalAmount - previousAmount
			if delta < 0 then delta = totalAmount end
			damageMeterLastTotals[key] = totalAmount

			if delta > 0 then
				local spellName = NonSecret(GetSpellInfo(spellID))
				if isHeal then
					-- The meter's overkillAmount on HealingDone entries is
					-- the overheal; accumulate its delta alongside the amount.
					local overhealDelta
					local overkillAmount = SafeAddZero(entry.overkillAmount)
					if overkillAmount then
						local previousOverkill = damageMeterLastOverkills[key] or 0
						overhealDelta = overkillAmount - previousOverkill
						if overhealDelta < 0 then overhealDelta = overkillAmount end
						damageMeterLastOverkills[key] = overkillAmount
					end
					FeedOwnHeal(spellID, spellName, delta, nil, overhealDelta, recentCasts[spellID], true)
				else
					FeedOwnHit(spellID, spellName, delta, nil, nil, recentCasts[spellID], true)
				end
			end
		end
	end
end

-- ****************************************************************************
-- In-combat meter sampling (diagnostics). The /run DebugMeterInfo() output
-- that was captured earlier was always taken AFTER combat, when Forever
-- relaxes its Secret Values restrictions - so it only ever saw plain numbers
-- and could not tell whether the feed is usable DURING combat, which is the
-- only state that matters for the group display. While in combat, this
-- records every 5 seconds (max 8 samples per fight) whether the GUID source
-- lookup succeeds and whether each spell's spellID/totalAmount can be
-- unwrapped with "value + 0" (the exact gate the meter engine uses). The
-- lines are stored in the saved variable MSBT_DebugDiagnostics (written to
--   WTF\Account\<account>\SavedVariables\MikScrollingBattleText.lua
-- on the next /reload or logout) and are KEPT across fights (capped), so a
-- manual capture after the fight still carries the mid-combat evidence.
-- ****************************************************************************
local combatMeterSampleLines = {}
local combatMeterSampleCount = 0
local meterCombatStartTime = nil
local lastMeterSampleTime = 0

-- Describes one combatSpells entry the way the engine consumes it: does the
-- SafeAddZero gate ("value + 0" in a pcall) succeed, i.e. is the value plain?
local function DescribeMeterEntry(entry)
	local parts = {}
	local okID, unwrappedID = pcall(function() return entry.spellID + 0 end)
	if okID and type(unwrappedID) == "number" then
		parts[#parts + 1] = "id=" .. SafeText(unwrappedID) .. "(plain)"
	else
		parts[#parts + 1] = "id=" .. SafeText(entry.spellID) .. "(SECRET-or-nonnumeric)"
	end
	local okTotal, unwrappedTotal = pcall(function() return entry.totalAmount + 0 end)
	if okTotal and type(unwrappedTotal) == "number" then
		parts[#parts + 1] = "total=" .. SafeText(unwrappedTotal) .. "(plain)"
	else
		parts[#parts + 1] = "total=" .. SafeText(entry.totalAmount) .. "(SECRET-or-nonnumeric)"
	end
	return table.concat(parts, " ")
end

local function SampleMeterCombatState()
	if not C_DamageMeter or not InCombatLockdown() then return end
	local now = GetTime()
	if now - lastMeterSampleTime < 5 then return end
	lastMeterSampleTime = now
	if combatMeterSampleCount >= 8 then return end
	combatMeterSampleCount = combatMeterSampleCount + 1

	local okGUID, playerGUID = pcall(UnitGUID, "player")
	local parts = { "sample#" .. combatMeterSampleCount .. " t=+" .. string_format("%.0f", now - (meterCombatStartTime or now)) .. "s" }
	for _, spec in ipairs({ { "DD", Enum.DamageMeterType.DamageDone }, { "HD", Enum.DamageMeterType.HealingDone } }) do
		local okSource, source = pcall(C_DamageMeter.GetCombatSessionSourceFromType, 0, spec[2], playerGUID)
		if not okSource or not source or type(source.combatSpells) ~= "table" then
			parts[#parts + 1] = spec[1] .. ":lookup-failed"
		else
			parts[#parts + 1] = spec[1] .. ":n=" .. #source.combatSpells
			for i = 1, math.min(2, #source.combatSpells) do
				parts[#parts + 1] = spec[1] .. i .. "{" .. DescribeMeterEntry(source.combatSpells[i]) .. "}"
			end
		end
	end
	combatMeterSampleLines[#combatMeterSampleLines + 1] = table.concat(parts, " ")
	if #combatMeterSampleLines > 100 then table_remove(combatMeterSampleLines, 1) end
	MSBT_DebugDiagnostics = { capturedAt = date("%Y-%m-%d %H:%M:%S"), lines = combatMeterSampleLines }
end

-- ****************************************************************************
-- Runs every METER_POLL_INTERVAL while in combat: polls the meter feed in
-- groups only (solo, UNIT_COMBAT is authoritative and the meter is not
-- touched), flushes sustained groups that have gone quiet, and records the
-- mid-combat diagnostics sample.
-- ****************************************************************************
local function PollDamageMeter()
	if IsInGroup() then
		PollDamageMeterSource(DM_DAMAGEDONE, false)
		PollDamageMeterSource(DM_HEALINGDONE, true)
	end

	-- Flush sustained spells: meter-fed pending amounts flush by age (one
	-- aggregated line per spell per second); solo sustained groups (DoTs)
	-- flush after SUSTAINED_IDLE_FLUSH of quiet.
	local now = GetTime()
	for spellID, state in pairs(hitStates) do
		if state.mode == "sustained" then
			if state.pendingSince ~= nil then
				if (now - state.pendingSince) >= METER_PENDING_FLUSH then
					FlushSustained(hitStates, spellID, "damage")
				end
			elseif (now - state.lastTime) >= SUSTAINED_IDLE_FLUSH then
				FlushSustained(hitStates, spellID, "damage")
			end
		end
	end
	for spellID, state in pairs(healStates) do
		if state.mode == "sustained" then
			if state.pendingSince ~= nil then
				if (now - state.pendingSince) >= METER_PENDING_FLUSH then
					FlushSustained(healStates, spellID, "heal")
				end
			elseif (now - state.lastTime) >= SUSTAINED_IDLE_FLUSH then
				FlushSustained(healStates, spellID, "heal")
			end
		end
	end

	-- Auto-diagnostic: record what the meter returns MID-COMBAT (throttled
	-- inside; see SampleMeterCombatState).
	SampleMeterCombatState()
end

-- ****************************************************************************
-- Diagnostic: /run MikSBT.DebugMeterInfo()
-- Prints what C_DamageMeter currently returns so it can be verified whether
-- the meter feed actually delivers usable (non-secret) data on this client:
-- availability, session sources with the local player flag, and the per-spell
-- entries the GUID-keyed source lookup reports (amounts or <secret> markers).
--
-- The same lines are stored in the saved variable MSBT_DebugDiagnostics,
-- which the client writes to
--   WTF\Account\<account>\SavedVariables\MikScrollingBattleText.lua
-- on the next /reload or logout, so the output can be inspected on disk
-- without copying it out of the in-game chat.
-- ****************************************************************************
local function DebugMeterLine(lines, text)
	lines[#lines + 1] = text
	print(text)
end

-- Stores the diagnostics in the SavedVariables (written to disk on /reload),
-- PREPENDING the automatic in-combat samples so a manual /run capture never
-- wipes the evidence collected mid-fight (that is how the first samples were
-- lost).
local function SaveMeterDiagnostics(lines)
	local merged = {}
	for _, line in ipairs(combatMeterSampleLines) do merged[#merged + 1] = line end
	merged[#merged + 1] = "=== manual /run capture " .. date("%H:%M:%S") .. " ==="
	for _, line in ipairs(lines) do merged[#merged + 1] = line end
	if #decisionLog > 0 then
		merged[#merged + 1] = "=== solo feed decisions (how each wound/heal was attributed and shown) ==="
		for _, line in ipairs(decisionLog) do merged[#merged + 1] = line end
	end
	MSBT_DebugDiagnostics = { capturedAt = date("%Y-%m-%d %H:%M:%S"), lines = merged }
end

function MikSBT.DebugMeterInfo()
	local lines = {}
	if not C_DamageMeter then
		DebugMeterLine(lines, "MSBT meter: C_DamageMeter API not present on this client")
		SaveMeterDiagnostics(lines)
		return
	end

	local okAvailable, isAvailable, failureReason = pcall(C_DamageMeter.IsDamageMeterAvailable)
	DebugMeterLine(lines, "MSBT meter: IsDamageMeterAvailable=" .. SafeText(isAvailable) .. " reason=" .. SafeText(failureReason))
	local okEnabled, enabled = pcall(function() return GetCVarBool("damageMeterEnabled") end)
	DebugMeterLine(lines, "MSBT meter: damageMeterEnabled=" .. (okEnabled and SafeText(enabled) or "unknown"))

	local damageMeterType = (Enum and Enum.DamageMeterType and Enum.DamageMeterType.DamageDone) or 0
	local healingMeterType = (Enum and Enum.DamageMeterType and Enum.DamageMeterType.HealingDone) or 2

	for _, meterType in ipairs({ { damageMeterType, "DamageDone" }, { healingMeterType, "HealingDone" } }) do
		local okSession, session = pcall(C_DamageMeter.GetCombatSessionFromType, 0, meterType[1])
		if not okSession or not session or type(session.combatSources) ~= "table" then
			DebugMeterLine(lines, "MSBT meter [" .. meterType[2] .. "]: no session data (call error=" .. tostring(not okSession) .. ")")
		else
			local localPlayerFound = false
			for _, combatSource in ipairs(session.combatSources) do
				if combatSource.isLocalPlayer then localPlayerFound = true break end
			end
			DebugMeterLine(lines, "MSBT meter [" .. meterType[2] .. "]: sources=" .. #session.combatSources .. " localPlayerInSession=" .. tostring(localPlayerFound))

			local okGUID, playerGUID = pcall(UnitGUID, "player")
			local okSource, source = pcall(C_DamageMeter.GetCombatSessionSourceFromType, 0, meterType[1], playerGUID)
			if not okSource or not source or type(source.combatSpells) ~= "table" then
				DebugMeterLine(lines, "MSBT meter [" .. meterType[2] .. "]: GUID source lookup failed or empty")
			else
				DebugMeterLine(lines, "MSBT meter [" .. meterType[2] .. "]: GUID source spells=" .. #source.combatSpells)
				for i, spell in ipairs(source.combatSpells) do
					if i > 10 then DebugMeterLine(lines, "  ...") break end
					local spellID = SafeAddZero(spell.spellID)
					local spellName
					if spellID then spellName = GetSpellInfo(spellID) end
					DebugMeterLine(lines, "  spellID=" .. SafeText(spellID) .. " name=" .. SafeText(spellName) .. " total=" .. SafeText(SafeAddZero(spell.totalAmount)))
				end
			end
		end
	end

	-- Stored in the SavedVariables so the client writes it to disk on the
	-- next /reload or logout (see the TOC's SavedVariables entry).
	SaveMeterDiagnostics(lines)
	print("MSBT meter: saved to SavedVariables - run /reload to write it to disk")
end

-- ****************************************************************************
-- Starts the combat feed while in combat, if combat log access is blocked or
-- on the Forever client (whose combat log delivers no usable outgoing events
-- at all, gate or no gate).
-- ****************************************************************************
local function StartCombatFeed()
	if not damageMeterAvailable() or not (MikSBT.combatLogBlocked or MikSBT.Client.isForever) or damageMeterTicker then
		return
	end

	-- Recent casts are deliberately NOT cleared: the spell that *starts* a
	-- fight is often cast right before combat begins, and stale entries
	-- cannot fake direct hits beyond DIRECT_HIT_WINDOW. The meter's last
	-- totals are not cleared either (the session-reset delta handling keeps
	-- them correct); only the per-fight hit groups start empty.
	EraseTable(hitStates)
	EraseTable(healStates)

	-- In-combat meter diagnostics: samples accumulate ACROSS fights (capped;
	-- see SampleMeterCombatState) so a /run DebugMeterInfo() after the fight
	-- still carries the mid-combat evidence - only a marker is added per fight.
	combatMeterSampleCount = 0
	lastMeterSampleTime = 0
	meterCombatStartTime = GetTime()
	combatMeterSampleLines[#combatMeterSampleLines + 1] = "--- fight start ---"
	decisionLog[#decisionLog + 1] = "--- fight start ---"
	while #decisionLog > 200 do table_remove(decisionLog, 1) end

	damageMeterTicker = C_Timer.NewTicker(METER_POLL_INTERVAL, PollDamageMeter)
end

-- ****************************************************************************
-- Stops the combat feed when combat ends.
-- ****************************************************************************
local function StopCombatFeed()
	if damageMeterTicker then
		damageMeterTicker:Cancel()
		damageMeterTicker = nil
	end

	-- Show the tail of the fight instead of dropping it because the idle
	-- flush never came.
	FlushAllSustained()
end


-- ****************************************************************************
-- Called when the player leaves combat.
-- ****************************************************************************
function eventFrame:PLAYER_REGEN_ENABLED()
	StopCombatFeed()
end


-- ****************************************************************************
-- Called when the player enters combat.
-- ****************************************************************************
function eventFrame:PLAYER_REGEN_DISABLED()
	-- Get the event settings for entering combat and display it if it isn't disabled.
	local eventSettings = MSBTProfiles.currentProfile.events.NOTIFICATION_COMBAT_ENTER
	if not eventSettings.disabled then
		DisplayEvent(eventSettings, eventSettings.message)
	end

	-- Fresh combat: the solo rules own outgoing damage again; sustained
	-- groups start empty (see StartCombatFeed).
	StartCombatFeed()
end


-- ****************************************************************************
-- Regrouping mid-combat switches the dealt-damage authority (solo
-- UNIT_COMBAT <-> group meter); close the open sustained groups so nothing
-- bleeds across the switch.
-- ****************************************************************************
function eventFrame:GROUP_ROSTER_UPDATE()
	FlushAllSustained()
end


-------------------------------------------------------------------------------
-- §7 COMBAT_TEXT_UPDATE: the game's own floating-combat-text feed.
-------------------------------------------------------------------------------
-- This is the data source of Blizzard's native combat text: events about the
-- unit set with C_CombatText.SetActiveUnit("player"). Per payload type, the
-- heal family carries (sourceName, amount) - the ONLY sanctioned feed that
-- names the caster of a heal - so it is the heal-on-player authority in all
-- modes; the UNIT_COMBAT heal branch stays as a solo fallback with a cross
-- debounce. EXTRA_ATTACKS flags Windfury-style extra swings as the player's
-- own. Values may be Blizzard secret values mid-combat ("SecretReturns",
-- patch 12.0); every event is logged to the decision log so a test dump
-- shows exactly what the game's feed delivered and how secret it was.
-- Payload table (warcraft.wiki.gg): DAMAGE/DAMAGE_CRIT amount; SPELL_DAMAGE
-- amount; HEAL/HEAL_CRIT/PERIODIC_HEAL(_CRIT)(_ABSORB) sourceName + amount;
-- BLOCK/ABSORB damage_taken + blocked/absorbed; MISS/DODGE/PARRY/... nil.
--***************************************************************************

local combatTextHealTypes = {
	HEAL = true, HEAL_CRIT = true, HEAL_ABSORB = true, HEAL_CRIT_ABSORB = true,
	PERIODIC_HEAL = true, PERIODIC_HEAL_CRIT = true, PERIODIC_HEAL_ABSORB = true,
}

local unitCombatHealSeenAt, combatTextHealSeenAt = 0, 0
local extraAttackUntil = 0

local function combatTextAvailable()
	return C_CombatText and C_CombatText.SetActiveUnit and C_CombatText.GetCurrentEventInfo and true or false
end

function eventFrame:COMBAT_TEXT_UPDATE(messageType)
	if not messageType or (issecretvalue and issecretvalue(messageType)) then return end

	if messageType == "EXTRA_ATTACKS" then
		-- The game flags the player's own upcoming extra swings (Windfury
		-- weapon, etc.): wounds on the target within the next moments may be
		-- shown as plain swings even in groups.
		extraAttackUntil = GetTime() + 1.5
		LogDecision("ctu EXTRA_ATTACKS -> own extra swings flagged")
		return
	end
	if not combatTextHealTypes[messageType] then
		-- Incoming damage types etc. are the UNIT_COMBAT player branch's
		-- authority; log the type as feed evidence.
		LogDecision("ctu " .. SafeText(messageType))
		return
	end

	-- Heal family: desc1 = source name, desc2 = amount (desc3 = absorbed
	-- amount on *_ABSORB types). May be secret mid-combat.
	local ok, sourceName, amount, absorbed = pcall(C_CombatText.GetCurrentEventInfo)
	if not ok then
		LogDecision("ctu-heal " .. SafeText(messageType) .. " -> GetCurrentEventInfo FAILED")
		return
	end
	local nameSecret = sourceName ~= nil and issecretvalue ~= nil and issecretvalue(sourceName) or false
	local amountSecret = amount ~= nil and issecretvalue ~= nil and issecretvalue(amount) or false
	combatTextHealSeenAt = GetTime()
	LogDecision("ctu-heal " .. SafeText(messageType) .. " src=" .. SafeText(sourceName)
		.. " srcSecret=" .. tostring(nameSecret) .. " amtSecret=" .. tostring(amountSecret))

	if unitCombatHealSeenAt > 0 and (GetTime() - unitCombatHealSeenAt) < 0.5 then
		LogDecision("ctu-heal -> dropped (UNIT_COMBAT delivered it first)")
		return
	end

	local isHoT = string_find(messageType, "PERIODIC", 1, true) ~= nil
	local isCrit = string_find(messageType, "CRIT", 1, true) ~= nil
	local ownName = NonSecret(UnitName("player"))

	-- The game's own rule: show who healed. A plain source name equal to the
	-- player is the player's own heal.
	if sourceName ~= nil and not nameSecret and ownName ~= nil and sourceName == ownName then
		-- Self-heal: attribute to the cast that just finished (and mark it a
		-- heal so it can never attribute damage later).
		local spellID, castTime
		local now = GetTime()
		if lastCast.spellID and (now - lastCast.time) <= HEAL_ATTRIBUTION_WINDOW then
			spellID, castTime = lastCast.spellID, lastCast.time
			playerHealSpellIDs[spellID] = true
		end
		local spellName = spellID and NonSecret(GetSpellInfo(spellID)) or nil
		LogDecision("ctu-heal -> SELF show spell=" .. SafeText(spellID))
		FeedOwnHeal(spellID, spellName, amount, isCrit, PlayerOverheal(amount), castTime, false)
		return
	end

	-- A heal from somebody else on the player: the user's own healing
	-- received, shown with the healer's name when it is a plain string (that
	-- is exactly what the native combat text shows). A secret source name
	-- cannot be attributed - shown unattributed rather than guessed.
	local event = {eventType = "heal", recipientUnit = "player", recipientName = ownName,
		amount = amount, isCrit = isCrit, isHoT = isHoT}
	if absorbed ~= nil and not (issecretvalue and issecretvalue(absorbed)) then
		event.overhealAmount = absorbed
	end
	if sourceName ~= nil and not nameSecret then event.sourceName = sourceName end
	LogDecision("ctu-heal -> incoming show src=" .. SafeText(sourceName))
	ParserEventsHandler(event)
end


-------------------------------------------------------------------------------
-- §8 UNIT_COMBAT router: the Solo Combat Feed's raw signal source.
-------------------------------------------------------------------------------
-- The combat log delivers nothing usable on Forever, so the player's combat
-- story is routed from UNIT_COMBAT: wounds/misses on the target (SOLO only -
-- inside a group they cannot be attributed and are dropped, because a party
-- member's hit must never surface as the player's; the GUID-keyed meter feed
-- of §4 is the dealt-damage authority there) and wounds/misses/heals on the
-- player (the recipient is provably the player, so those are always the
-- player's own data, in groups too).

-- UNIT_COMBAT actions that map to MSBT miss types. The action doubles as the
-- missType string the MissHandler and the profile events expect.
local missActions = {
MISS = true, DODGE = true, PARRY = true, BLOCK = true,
RESIST = true, ABSORB = true, IMMUNE = true, REFLECT = true,
}

function eventFrame:UNIT_COMBAT(unitTarget, action, flagText, amount, schoolMask)
	if not action or (issecretvalue and issecretvalue(action)) then return end

	local isWound = (action == "WOUND")
	local isMiss = missActions[action]
	local isHeal = (action == "HEAL" or action == "HEAL_CRIT")
	if not isWound and not isMiss and not isHeal then return end

	-- Compound flags (e.g. critical + glancing/block variants) require substring
	-- matching; flagText must be a plain string for pattern work.
	local isCrit = false
	if flagText and not (issecretvalue and issecretvalue(flagText)) then
		isCrit = string_find(flagText, "CRITICAL", 1, true) ~= nil
	end

	-- Plain-number amounts: skip zero-value wounds. Secret amounts flow through
	-- untouched; the display pipeline (FormatEvent, thresholds, merging) is
	-- hardened to handle them safely.
	if isWound and amount ~= nil and not (issecretvalue and issecretvalue(amount)) and amount <= 0 then return end

	-- Outgoing hits (wounds and misses) - SOLO ONLY. Inside a group this
	-- branch drops everything: UNIT_COMBAT on the target cannot say who
	-- swung, and the meter feed (§4) is the dealt-damage authority there.
	-- Solo, UNIT_COMBAT is authoritative and richer (per-hit amounts, crits,
	-- damage schools), so the meter is not even polled (see PollDamageMeter).
	if unitTarget == "target" then
		if outgoingLogSeen or not InCombatLockdown() then return end

		-- schoolMask shares the numeric domain with the old combat log damage
		-- schools, so it can color the amount and acts as evidence in tick
		-- attribution (a fire school wound cannot be a weapon swing), so it is
		-- computed before attribution.
		local damageType = (schoolMask and not (issecretvalue and issecretvalue(schoolMask))) and schoolMask or nil

		local now = GetTime()
		local inGroup = IsInGroup()
		-- In a group, a wound on the target cannot name the attacker. Show
		-- only what can be tied to the player by the game's own signals: a
		-- fresh cast, a cadence follow-up, a school-matched tick of the one
		-- spell with recent hits, or the swings the game itself flagged as
		-- the player's extra attacks. Everything else is dropped - it is
		-- somebody else's hit until proven otherwise.
		local spellID, castTime = AttributeSoloWound(now, damageType, inGroup)
		if inGroup and spellID == nil and now > extraAttackUntil then
			LogDecision("wound amt=" .. SafeText(amount) .. " -> dropped (group, unattributable)")
			return
		end
		if isWound then
			LogDecision("wound amt=" .. SafeText(amount) .. " school=" .. SafeText(damageType)
				.. " grp=" .. tostring(inGroup)
				.. " -> spell=" .. SafeText(spellID)
				.. (castTime and (" castAge=" .. string_format("%.1f", now - castTime)) or ""))
			local spellName = spellID and NonSecret(GetSpellInfo(spellID)) or nil
			FeedOwnHit(spellID, spellName, amount, isCrit, damageType, castTime, false)
		else
			LogDecision("miss " .. SafeText(action) .. " grp=" .. tostring(inGroup) .. " -> spell=" .. SafeText(spellID))
			ParserEventsHandler({eventType = "miss", sourceUnit = "player", missType = action,
				recipientName = NonSecret(UnitName("target")),
				skillID = spellID, skillName = spellID and NonSecret(GetSpellInfo(spellID)) or nil})
		end
		return
	end

	-- Incoming (on the player): the recipient is provably the player, so this
	-- direction is always the player's own data - in groups too.
	if unitTarget ~= "player" or incomingLogSeen then return end
	if isWound then
		ParserEventsHandler({eventType = "damage", recipientUnit = "player", amount = amount, isCrit = isCrit,
			damageType = (schoolMask and not (issecretvalue and issecretvalue(schoolMask))) and schoolMask or nil})
	elseif isMiss then
		ParserEventsHandler({eventType = "miss", recipientUnit = "player", missType = action})
	elseif isHeal then
		-- A heal landing on the player: SOLO it is the player's own heal
		-- (same authority rule as wounds), shown as an outgoing heal with the
		-- live overheal estimate (see PlayerOverheal); the cast it lands
		-- right after is marked as a heal so it can never attribute damage
		-- later. IN A GROUP the caster is unknowable and self-heals would
		-- duplicate the meter's outgoing line, so heals are not shown here -
		-- the meter feed (§4) covers the player's dealt healing.
		if IsInGroup() then return end

		-- The game's combat-text feed is the heal-on-player authority (it
		-- names the healer); this branch is the solo fallback, debounced
		-- against it so a heal is never shown twice.
		local nowDebounce = GetTime()
		if combatTextHealSeenAt > 0 and (nowDebounce - combatTextHealSeenAt) < 0.5 then
			LogDecision("unitcombat-heal -> dropped (game combat-text feed delivered it)")
			return
		end
		unitCombatHealSeenAt = nowDebounce

		local spellID, castTime
		local now = GetTime()
		if lastCast.spellID and (now - lastCast.time) <= HEAL_ATTRIBUTION_WINDOW then
			spellID, castTime = lastCast.spellID, lastCast.time
			playerHealSpellIDs[spellID] = true
		end
		local spellName = spellID and NonSecret(GetSpellInfo(spellID)) or nil
		LogDecision("heal-on-player amt=" .. SafeText(amount) .. " -> spell=" .. SafeText(spellID))
		FeedOwnHeal(spellID, spellName, amount, isCrit or action == "HEAL_CRIT", PlayerOverheal(amount), castTime, false)
	end
end


-- ****************************************************************************
-- Called when a unit's combo points change.
-- ****************************************************************************
function eventFrame:CHAT_MSG_MONSTER_EMOTE(message, sourceName)
	-- Secret strings can't be compared or merged into the message.
	if NonSecret(message) == nil or NonSecret(sourceName) == nil then return end
	local targetName = NonSecret(UnitName("target"))
	if targetName == nil then return end

	-- Ignore the event if it's not the current target.
	if sourceName ~= targetName then
		return
	end
	HandleMonsterEmotes(string_gsub(message, "%%s", sourceName))
end


-- ****************************************************************************
-- Enables the module.
-- ****************************************************************************
local function Enable()
	-- Register events to handle extra notifications.
	eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
	eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
	eventFrame:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")
	if MikSBT.Client.isForever then
		-- Solo Combat Feed (§1/§7/§8): casts, combat routing, group changes,
		-- the health ledger for the live overheal estimate, and the game's
		-- own floating-combat-text feed (heal attribution, extra attacks).
		eventFrame:RegisterEvent("UNIT_COMBAT")
		eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
		eventFrame:RegisterEvent("UNIT_SPELLCAST_SENT")
		eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
		eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
		eventFrame:RegisterEvent("UNIT_HEALTH")
		eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
		if combatTextAvailable() then
			eventFrame:RegisterEvent("COMBAT_TEXT_UPDATE")
			-- The game's own combat text watches the player by default, but
			-- claim it explicitly (same call Blizzard_CombatText makes).
			pcall(C_CombatText.SetActiveUnit, "player")
		end
	end

	-- Register the parser events handler.
	MSBTParser.RegisterHandler(ParserEventsHandler)
end


-- ****************************************************************************
-- Disables the module.
-- ****************************************************************************
local function Disable()
	-- Stop receiving updates.
	eventFrame:Hide()
	eventFrame:UnregisterAllEvents()

	-- Unregister the parser events handler.
	MSBTParser.UnregisterHandler(ParserEventsHandler)
end


-------------------------------------------------------------------------------
-- Initialization.
-------------------------------------------------------------------------------

-- Setup event frame.
eventFrame:Hide()
eventFrame:SetScript("OnEvent", function(self, event, ...)
	if self[event] then
		self[event](self, ...)
	end
end)
eventFrame:SetScript("OnUpdate", OnUpdateEventFrame)

-- Setup throttle frame.
throttleFrame:Hide()
throttleFrame:SetScript("OnUpdate", OnUpdateThrottleFrame)

-- Get the player's class.
_, playerClass = UnitClass("player")

-- Create the map of handlers to call for each event.
eventHandlers["damage"] = DamageHandler
eventHandlers["miss"] = MissHandler
eventHandlers["heal"] = HealHandler
eventHandlers["interrupt"] = InterruptHandler
eventHandlers["environmental"] = EnvironmentalHandler
eventHandlers["aura"] = AuraHandler
eventHandlers["enchant"] = EnchantHandler
eventHandlers["dispel"] = DispelHandler
eventHandlers["power"] = PowerHandler
eventHandlers["kill"] = KillHandler
eventHandlers["honor"] = HonorHandler
eventHandlers["reputation"] = ReputationHandler
eventHandlers["proficiency"] = ProficiencyHandler
eventHandlers["experience"] = ExperienceHandler
eventHandlers["extraattacks"] = ExtraAttacksHandler

-- Create the power tokens lookup map.
for powerToken, powerType in pairs(powerTypes) do
	powerTokens[powerType] = powerToken
end

-- Create map of power types that are handled uniquely.
uniquePowerTypes[Enum.PowerType.HolyPower] = true
uniquePowerTypes[Enum.PowerType.Chi] = true
uniquePowerTypes[Enum.PowerType.ComboPoints] = true
uniquePowerTypes[Enum.PowerType.ArcaneCharges] = true

-- Create damage type and damage color profile maps.
CreateDamageMaps()

-- Set the isEnglish flag correctly.
if string_find(GetLocale(), "en..") then
	isEnglish = true
end

-- Add auras to always ignore.
ignoreAuras[SPELL_BLINK] = true
--ignoreAuras[SPELL_BLIZZARD] = true
--ignoreAuras[SPELL_HELLFIRE] = true
--ignoreAuras[SPELL_HURRICANE] = true
ignoreAuras[SPELL_RAIN_OF_FIRE] = true

-- Get localized off-hand trailer and convert to a lua search pattern.
if type(SPELL_BLOOD_STRIKE) == "string" and SPELL_BLOOD_STRIKE ~= UNKNOWN then
	offHandPattern = string.gsub(SPELL_BLOOD_STRIKE, "([%^%(%)%.%[%]%*%+%-%?])", "%%%1")
end




-------------------------------------------------------------------------------
-- Module interface.
-------------------------------------------------------------------------------

-- Protected Variables.
module.damageTypeMap				= damageTypeMap
module.damageColorProfileEntries	= damageColorProfileEntries

-- Protected Functions.
module.Enable						= Enable
module.Disable						= Disable


------------------------------------------------------------------------------------
-- API.
-------------------------------------------------------------------------------

-- Public Constants.
MikSBT.DISPLAYTYPE_INCOMING			= "Incoming"
MikSBT.DISPLAYTYPE_OUTGOING			= "Outgoing"
MikSBT.DISPLAYTYPE_NOTIFICATION		= "Notification"
MikSBT.DISPLAYTYPE_STATIC			= "Static"

-- Public Functions.
MikSBT.RegisterFont					= MSBTMedia.RegisterFont
MikSBT.RegisterAnimationStyle		= MSBTAnimations.RegisterAnimationStyle
MikSBT.RegisterStickyAnimationStyle	= MSBTAnimations.RegisterStickyAnimationStyle
MikSBT.RegisterSound				= MSBTMedia.RegisterSound
MikSBT.IterateFonts					= MSBTMedia.IterateFonts
MikSBT.IterateScrollAreas			= MSBTAnimations.IterateScrollAreas
MikSBT.IterateSounds				= MSBTMedia.IterateSounds
MikSBT.DisplayMessage				= MSBTAnimations.DisplayMessage
MikSBT.IsModDisabled				= MSBTProfiles.IsModDisabled
