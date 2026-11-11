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
-- the Forever-only UNIT_COMBAT incoming fallback stands down.
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
-- Damage meter fallback for blocked combat log access.
-------------------------------------------------------------------------------
-- MikSBT.combatLogBlocked (see MikSBT.lua) can end up permanently true for a
-- whole session - Retail's taint rules refuse to register
-- COMBAT_LOG_EVENT_UNFILTERED at all once execution is tainted, and that can
-- come from another addon loaded earlier at login, not just from MSBT's own
-- code. Without combat log access there is no outgoing damage/heal text at
-- all. C_DamageMeter (patch 12.0+) is Blizzard's own sanctioned replacement
-- data source, but it only exposes the player's own combat *totals* (no
-- per-hit detail, no incoming damage), so this polls it periodically and
-- turns the deltas into synthetic outgoing damage/heal events through the
-- normal ParserEventsHandler pipeline above - an approximation, not a full
-- replacement. Ported from the "Midnight" MSBT fork's
-- Components/DamageMeterSource.lua, which polls the same API the same way.
--
-- combatSpells entries (spellID, totalAmount) come back as Blizzard "secret
-- values" while in combat (patch 12.0's Secret Values system) - arithmetic,
-- comparisons or string conversion on them error instead of just returning
-- a wrong result. SafeAddZero below unwraps a value the same way the
-- Midnight fork's NormalizeNumber() does: try "value + 0" in a pcall, and
-- treat it as unusable (skip that entry) if that throws.
-------------------------------------------------------------------------------

local function SafeAddZero(value)
	local ok, result = pcall(function() return value + 0 end)
	if ok and type(result) == "number" then
		return result
	end
	return nil
end

-- Availability is now existence-only: the CVar/IsDamageMeterAvailable checks
-- turned out to silently block the whole outgoing feed on some setups (no
-- damage displayed at all). They run as one-time warnings instead - the feed
-- is attempted regardless, and the session cross-check below guards
-- attribution.
local function damageMeterAvailable()
	return C_DamageMeter and true or false
end

-- Renders any value as printable text without touching secret values.
local function SafeText(value)
	if value == nil then return "nil" end
	if issecretvalue and issecretvalue(value) then return "<secret>" end
	local ok, text = pcall(tostring, value)
	return ok and text or "<unprintable>"
end

local damageMeterLastTotals = {}
local damageMeterTicker
local meterWarnedThisSession = false
local meterMismatchWarned = false
-- GetTime() of the last poll that saw a growing spell total; the diagnostics
-- (/run MikSBT.DebugMeterInfo()) use it to tell a dead feed from a blocked one.
local meterLastActivity = nil

local function WarnMeterStateOnce()
	if meterWarnedThisSession then return end
	meterWarnedThisSession = true

	-- Note: the damageMeterEnabled CVar is deliberately NOT warned about -
	-- in-game diagnostics on Forever confirmed the feed delivers usable data
	-- even with the toggle off. Only a hard API unavailability is reported.

	local okAvailable, isAvailable, failureReason = pcall(C_DamageMeter.IsDamageMeterAvailable)
	if okAvailable and isAvailable == false then
		print("|cffff7d0aMSBT:|r Damage Meter API reports unavailable (reason: " .. SafeText(failureReason) .. ") - attempting to read the feed anyway")
	end
end

-- Numeric meter type values (in-game-verified constants for the Midnight
-- engine; Enum.DamageMeterType is used only when present, as a sanity check).
local DM_DAMAGEDONE = (Enum and Enum.DamageMeterType and Enum.DamageMeterType.DamageDone) or 0
local DM_HEALINGDONE = (Enum and Enum.DamageMeterType and Enum.DamageMeterType.HealingDone) or 2

-- Meter deltas are accumulated PER SPELL ID (never merged across different
-- spells) and flushed after the spell goes quiet for METER_IDLE_FLUSH_TIME
-- seconds (or when combat ends). A ticking DoT never goes quiet, so its whole
-- duration ends up as one line: "<Spell> (<hits>) <total>". The hit count is
-- an estimate: one hit per 0.5s poll window in which the spell's total grew
-- (a window rarely contains two hits of the same spell). The value must stay
-- above the longest DoT tick interval (3s in Classic) or ticking spells would
-- flush every tick.
local METER_IDLE_FLUSH_TIME = 3.5
local pendingMeterEvents = {}

-- Direct-hit discrimination: when a meter delta for a spell arrives within
-- DIRECT_HIT_WINDOW seconds of the player casting that spell, it is the
-- spell's direct hit and is displayed immediately instead of being grouped.
-- Deltas that arrive later are DoT/HoT ticks and keep accumulating; weapon
-- hits (no cast at all) also keep accumulating. Channels are always treated
-- as sustained damage (see UNIT_SPELLCAST_CHANNEL_START below).
local DIRECT_HIT_WINDOW = 1.0
local recentPlayerCasts = {}
local channelledSpells = {}

-- Resolves a spellID to its name, preferring the modern C_Spell API. A nil
-- result means the meter entry has no spell name (weapon/melee hits), which
-- MSBT then renders as the classic plain melee number.
local function ResolveMeterSpellName(spellID)
	local okModern, name = pcall(C_Spell.GetSpellName, spellID)
	if okModern and type(name) == "string" and name ~= "" then return name end
	local okLegacy, legacyName = pcall(GetSpellInfo, spellID)
	if okLegacy and type(legacyName) == "string" and legacyName ~= "" then return legacyName end
	return nil
end

-- ****************************************************************************
-- Polls one C_DamageMeter type (damage or healing) for the player and
-- accumulates any newly-registered amount per spell into pendingMeterEvents
-- (see FlushPendingMeterEvent for when those are displayed).
-- ****************************************************************************
local function PollDamageMeterSource(damageMeterType, eventType)
	local okGUID, playerGUID = pcall(UnitGUID, "player")
	if not okGUID or not playerGUID then return end

	-- Attribution cross-check: read the session's local player total (isLocalPlayer
	-- is NeverSecret) and compare it against the GUID-keyed source's total when
	-- both can be unwrapped. Only a PROVABLE mismatch (both values plain and the
	-- comparison succeeding) blocks this poll - a missing session, a secret value,
	-- or an error all fail open, because silently blocking would leave the addon
	-- showing nothing (that regression shipped in 1.2.0 and had to be reverted).
	local sessionLocalTotal
	local okSession, session = pcall(C_DamageMeter.GetCombatSessionFromType, 0, damageMeterType)
	if okSession and session and session.combatSources then
		for _, combatSource in ipairs(session.combatSources) do
			if combatSource.isLocalPlayer then
				sessionLocalTotal = SafeAddZero(combatSource.totalAmount)
				break
			end
		end
	end

	local okSource, source = pcall(C_DamageMeter.GetCombatSessionSourceFromType, 0, damageMeterType, playerGUID)
	if not okSource or not source then return end

	local sourceTotal = SafeAddZero(source.totalAmount)
	if sourceTotal ~= nil and sessionLocalTotal ~= nil then
		local okCompare, isEqual = pcall(function() return sourceTotal == sessionLocalTotal end)
		if okCompare and isEqual == false then
			if not meterMismatchWarned then
				meterMismatchWarned = true
				print("|cffff7d0aMSBT:|r damage meter source lookup does not match the session's local player - data skipped for safety (run /run MikSBT.DebugMeterInfo())")
			end
			return
		end
	end

	local okSpells, combatSpells = pcall(function() return source.combatSpells end)
	if not okSpells or type(combatSpells) ~= "table" then return end

	for _, entry in ipairs(combatSpells) do
		local spellID = SafeAddZero(entry.spellID)
		local totalAmount = SafeAddZero(entry.totalAmount)
		if spellID and totalAmount and totalAmount > 0 then
			-- Key strictly by spellID: each spell (and weapon hits, which the
			-- meter reports under their own ID) accumulates independently.
			local key = eventType .. ":" .. spellID
			local previousAmount = damageMeterLastTotals[key] or 0

			-- A drop below the last known total means the session reset
			-- (new pull/segment or meter reset); treat the fresh total as
			-- the delta instead of going negative.
			local delta = totalAmount - previousAmount
			if delta < 0 then delta = totalAmount end
			damageMeterLastTotals[key] = totalAmount

			if delta > 0 then
				local now = GetTime()
				meterLastActivity = now
				local pending = pendingMeterEvents[key]

				-- A delta arriving right after the player cast this spell is
				-- its direct hit: show it immediately (single-hit instant
				-- spells must not wait for the grouping window). Ticks (no
				-- recent cast), channels, and already-accumulating spells are
				-- sustained damage and keep being grouped; weapon hits (no
				-- cast) also group.
				local isDirectHit = pending == nil
					and not channelledSpells[spellID]
					and recentPlayerCasts[spellID]
					and (now - recentPlayerCasts[spellID]) <= DIRECT_HIT_WINDOW

				if isDirectHit then
					local spellName = ResolveMeterSpellName(spellID)
					local parserEvent = { eventType = eventType, sourceUnit = "player", amount = delta }
					if spellName then
						parserEvent.skillID = spellID
						parserEvent.skillName = spellName
					end
					ParserEventsHandler(parserEvent)
				else
					if not pending then
						pending = { eventType = eventType, spellID = spellID, amount = 0, hitWindows = 0 }
						pendingMeterEvents[key] = pending
					end
					pending.amount = pending.amount + delta
					pending.hitWindows = pending.hitWindows + 1
					pending.lastIncrease = now
				end
			end
		end
	end
end

-- ****************************************************************************
-- Displays one accumulated spell's total: "<Spell> (<hits>) <amount>", or the
-- plain amount for weapon hits (no resolvable spell name). Called either when
-- the spell has been quiet for METER_IDLE_FLUSH_TIME seconds or at combat end.
-- ****************************************************************************
local function FlushPendingMeterEvent(key)
	local pending = pendingMeterEvents[key]
	if not pending then return end
	pendingMeterEvents[key] = nil

	if pending.amount <= 0 then return end

	local spellName = ResolveMeterSpellName(pending.spellID)
	local parserEvent = { eventType = pending.eventType, sourceUnit = "player", amount = pending.amount }
	if spellName then
		parserEvent.skillID = pending.spellID
		parserEvent.skillName = spellName .. " (" .. pending.hitWindows .. ")"
	end
	ParserEventsHandler(parserEvent)
end

-- ****************************************************************************
-- Polls both damage and healing done by the player, then flushes every spell
-- that has been quiet for METER_IDLE_FLUSH_TIME seconds.
-- ****************************************************************************
local function PollDamageMeter()
	-- The availability/CVar checks are warnings only (see WarnMeterStateOnce):
	-- polling unconditionally avoids silently dead feeds when a check can't be
	-- confirmed on this client.
	PollDamageMeterSource(DM_DAMAGEDONE, "damage")
	PollDamageMeterSource(DM_HEALINGDONE, "heal")

	local now = GetTime()
	for key, pending in pairs(pendingMeterEvents) do
		if now - pending.lastIncrease >= METER_IDLE_FLUSH_TIME then
			FlushPendingMeterEvent(key)
		end
	end
end

-- ****************************************************************************
-- Diagnostic: /run MikSBT.DebugMeterInfo()
-- Prints what C_DamageMeter currently returns so attribution problems can be
-- diagnosed live: whether the meter is tracking, whether the local player is
-- present in the session, and which spells the GUID-keyed source lookup
-- reports (with amounts or <secret> markers). Also prints the feed state
-- (ticker, last activity, pending events).
--
-- The same lines are stored in the saved variable MSBT_DebugDiagnostics,
-- which the client writes to
--   WTF\Account\<account>\SavedVariables\MikScrollingBattleText.lua
-- on the next /reload or logout, so the output can be inspected on disk
-- without copying it out of the in-game chat.
-- ****************************************************************************
function MikSBT.DebugMeterInfo()
	local lines = {}
	local function DebugLine(text)
		lines[#lines + 1] = text
		print(text)
	end

	if not C_DamageMeter then
		DebugLine("MSBT meter: C_DamageMeter API not present on this client")
		MSBT_DebugDiagnostics = { capturedAt = date("%Y-%m-%d %H:%M:%S"), lines = lines }
		return
	end

	DebugLine("MSBT meter: tickerRunning=" .. tostring(damageMeterTicker ~= nil) ..
		" lastActivity=" .. (meterLastActivity and string_format("%.1fs ago", GetTime() - meterLastActivity) or "never") ..
		" pendingEvents=" .. tostring((function() local n = 0 for _ in pairs(pendingMeterEvents) do n = n + 1 end return n end)()) ..
		" trackedTotals=" .. tostring((function() local n = 0 for _ in pairs(damageMeterLastTotals) do n = n + 1 end return n end)()))

	local okAvailable, isAvailable, failureReason = pcall(C_DamageMeter.IsDamageMeterAvailable)
	DebugLine("MSBT meter: IsDamageMeterAvailable=" .. SafeText(isAvailable) .. " reason=" .. SafeText(failureReason))
	local okEnabled, enabled = pcall(function() return GetCVarBool("damageMeterEnabled") end)
	DebugLine("MSBT meter: damageMeterEnabled=" .. (okEnabled and SafeText(enabled) or "unknown"))

	for _, meterType in ipairs({ { DM_DAMAGEDONE, "DamageDone" }, { DM_HEALINGDONE, "HealingDone" } }) do
		local okSession, session = pcall(C_DamageMeter.GetCombatSessionFromType, 0, meterType[1])
		if not okSession or not session or type(session.combatSources) ~= "table" then
			DebugLine("MSBT meter [" .. meterType[2] .. "]: no session data")
		else
			local localPlayerFound = false
			for _, combatSource in ipairs(session.combatSources) do
				if combatSource.isLocalPlayer then localPlayerFound = true break end
			end
			DebugLine("MSBT meter [" .. meterType[2] .. "]: sources=" .. #session.combatSources .. " localPlayerInSession=" .. tostring(localPlayerFound))

			local okGUID, playerGUID = pcall(UnitGUID, "player")
			local okSource, source = pcall(C_DamageMeter.GetCombatSessionSourceFromType, 0, meterType[1], playerGUID)
			if not okSource or not source or type(source.combatSpells) ~= "table" then
				DebugLine("MSBT meter [" .. meterType[2] .. "]: GUID source lookup failed or empty")
			else
				DebugLine("MSBT meter [" .. meterType[2] .. "]: GUID source spells=" .. #source.combatSpells)
				for i, spell in ipairs(source.combatSpells) do
					if i > 10 then DebugLine("  ...") break end
					local spellID = SafeAddZero(spell.spellID)
					local name = spellID and ResolveMeterSpellName(spellID) or nil
					DebugLine("  spellID=" .. SafeText(spellID) .. " name=" .. SafeText(name) .. " total=" .. SafeText(SafeAddZero(spell.totalAmount)))
				end
			end
		end
	end

	-- Stored in the SavedVariables so the client writes it to disk on the
	-- next /reload or logout (see the TOC's SavedVariables entry).
	MSBT_DebugDiagnostics = { capturedAt = date("%Y-%m-%d %H:%M:%S"), lines = lines }
end

-- ****************************************************************************
-- Starts polling while in combat, if combat log access is blocked or on the
-- Forever client (whose combat log delivers no usable outgoing events at
-- all, gate or no gate). Stands down once PollDamageMeter sees a real one.
-- ****************************************************************************
local function StartDamageMeterFallback()
	if not damageMeterAvailable() or not (MikSBT.combatLogBlocked or MikSBT.Client.isForever) or damageMeterTicker then
		return
	end

	WarnMeterStateOnce()

	-- damageMeterLastTotals is deliberately NOT cleared here: the meter
	-- session totals persist across pulls (or reset to 0), and in both cases
	-- the "delta < 0" handling in PollDamageMeterSource keeps deltas correct.
	-- Clearing them here would re-emit the whole accumulated total as one
	-- giant number at the start of every fight.
	--
	-- recentPlayerCasts is NOT cleared either: the spell that *starts* a fight
	-- is often cast right before combat begins, and stale entries can't cause
	-- false direct-hits (they only match within DIRECT_HIT_WINDOW seconds).
	EraseTable(pendingMeterEvents)
	EraseTable(channelledSpells)
	damageMeterTicker = C_Timer.NewTicker(0.5, PollDamageMeter)
end

-- ****************************************************************************
-- Stops polling when combat ends.
-- ****************************************************************************
local function StopDamageMeterFallback()
	if damageMeterTicker then
		damageMeterTicker:Cancel()
		damageMeterTicker = nil
	end

	-- Show any accumulated damage/healing from the tail of the fight instead
	-- of dropping it because the idle flush never came.
	for key in pairs(pendingMeterEvents) do
		FlushPendingMeterEvent(key)
	end
end


-- ****************************************************************************
-- Called when the player leaves combat.
-- ****************************************************************************
function eventFrame:PLAYER_REGEN_ENABLED()
	-- Get the event settings for leaving combat and display it if it isn't disabled.
	local eventSettings = MSBTProfiles.currentProfile.events.NOTIFICATION_COMBAT_LEAVE
	if not eventSettings.disabled then
		DisplayEvent(eventSettings, eventSettings.message)
	end

	StopDamageMeterFallback()
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

	StartDamageMeterFallback()
end


-- ****************************************************************************
-- Forever fallback: the combat log delivers nothing usable there, so the
-- C_DamageMeter feed is the SOLE source for outgoing damage and healing (it
-- is keyed to the player's own GUID, so it can never show anyone else's
-- damage, and it reports each spell - including weapon hits - under its own
-- spellID). UNIT_COMBAT only contributes incoming damage/misses on the player
-- and, solo only, outgoing misses on the target. The incoming direction stands
-- down once a real combat log event for the player has been parsed (see
-- incomingLogSeen), so nothing is ever shown twice.
-- ****************************************************************************
-- Secret strings (e.g. UnitName("target") in combat) can't be compared or
-- merged on, so drop them from the synthetic events below.
local function NonSecret(value)
	if value ~= nil and issecretvalue and issecretvalue(value) then return nil end
	return value
end

-- UNIT_COMBAT actions that map to MSBT miss types. The action doubles as the
-- missType string the MissHandler and the profile events expect.
local missActions = {
MISS = true, DODGE = true, PARRY = true, BLOCK = true,
RESIST = true, ABSORB = true, IMMUNE = true, REFLECT = true,
}

-- Records the player's own casts so the meter feed can tell a spell's direct
-- hit (delta right after the cast) from its periodic ticks (see
-- DIRECT_HIT_WINDOW). Channelled spells are flagged as sustained damage for
-- their whole duration.
function eventFrame:UNIT_SPELLCAST_SUCCEEDED(unitID, _, spellID)
	if unitID ~= "player" then return end
	local ok, id = pcall(function() return spellID + 0 end)
	if ok and type(id) == "number" then recentPlayerCasts[id] = GetTime() end
end

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

function eventFrame:UNIT_COMBAT(unitTarget, action, flagText, amount, schoolMask)
	if not action or (issecretvalue and issecretvalue(action)) then return end

	local isWound = (action == "WOUND")
	local isMiss = missActions[action]
	if not isWound and not isMiss then return end

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

	-- Outgoing misses (solo only). UNIT_COMBAT on the target cannot say WHO
	-- missed, so in a group a party member's miss would show as the player's
	-- own - they are dropped there. Outgoing damage/healing never comes from
	-- UNIT_COMBAT at all (it is unattributable and would mix spells with
	-- weapon hits); the player-only C_DamageMeter feed is the sole authority
	-- for that (see PollDamageMeter).
	if unitTarget == "target" then
		if outgoingLogSeen or IsInGroup() or not InCombatLockdown() then return end
		if not isMiss then return end
		ParserEventsHandler({eventType = "miss", sourceUnit = "player", missType = action,
			recipientName = NonSecret(UnitName("target"))})
		return
	end

	if unitTarget ~= "player" or incomingLogSeen then return end
	if isWound then
		ParserEventsHandler({eventType = "damage", recipientUnit = "player", amount = amount, isCrit = isCrit,
			damageType = (schoolMask and not (issecretvalue and issecretvalue(schoolMask))) and schoolMask or nil})
	elseif isMiss then
		ParserEventsHandler({eventType = "miss", recipientUnit = "player", missType = action})
	end
	-- Note: heals on the player are intentionally NOT delivered here.
	-- UNIT_COMBAT can't say who cast the heal, so a heal from another player
	-- would be misattributed as the player's own, and self-heals would show up
	-- twice (here and in the C_DamageMeter healing-done feed, which is the sole
	-- outgoing-heal source on Forever - see PollDamageMeter).
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
		eventFrame:RegisterEvent("UNIT_COMBAT")
		eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
		eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
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
