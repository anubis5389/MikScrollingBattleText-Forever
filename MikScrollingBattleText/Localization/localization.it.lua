-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text Italian Localization
-- Author: Mikord
-- Italian Translation by: Kelhar@Runetotem-EU
-------------------------------------------------------------------------------

-- Local reference for faster access.
local L = MikSBT.translations

-------------------------------------------------------------------------------
-- Italian localization
-------------------------------------------------------------------------------

-- Font selection stays tied to GetLocale() only, never the override - a
-- client only has glyph data for its own locale (see localization.lua).
if (GetLocale() == "itIT") then

------------------------------
-- Fonts
------------------------------

L.FONT_FILES = {
	["MSBT Adventure"]		= "Interface\\Addons\\MikScrollingBattleText\\Fonts\\adventure.ttf",
	["MSBT Bazooka"]		= "Interface\\Addons\\MikScrollingBattleText\\Fonts\\bazooka.ttf",
	["MSBT Cooline"]		= "Interface\\Addons\\MikScrollingBattleText\\Fonts\\cooline.ttf",
	["MSBT Diogenes"]		= "Interface\\Addons\\MikScrollingBattleText\\Fonts\\diogenes.ttf",
	["MSBT Ginko"]			= "Interface\\Addons\\MikScrollingBattleText\\Fonts\\ginko.ttf",
	["MSBT Heroic"]			= "Interface\\Addons\\MikScrollingBattleText\\Fonts\\heroic.ttf",
	["MSBT Porky"]			= "Interface\\Addons\\MikScrollingBattleText\\Fonts\\porky.ttf",
	["MSBT Talisman"]		= "Interface\\Addons\\MikScrollingBattleText\\Fonts\\talisman.ttf",
	["MSBT Transformers"]	= "Interface\\Addons\\MikScrollingBattleText\\Fonts\\transformers.ttf",
	["MSBT Yellowjacket"]	= "Interface\\Addons\\MikScrollingBattleText\\Fonts\\yellowjacket.ttf",
}

L.DEFAULT_FONT_NAME = "MSBT Porky"

end

-- Registered in MikSBT.localePacksCore for re-application once the
-- language override is readable (see MSBTProfiles.lua's ADDON_LOADED
-- handler).
local function Apply()

------------------------------
-- Commands
------------------------------

L.COMMAND_RESET		= "reset"
L.COMMAND_DISABLE	= "disabilita"
L.COMMAND_ENABLE	= "abilita"
L.COMMAND_SHOWVER	= "versione"
L.COMMAND_HELP		= "aiuto"

L.COMMAND_USAGE = {
	"Usage: " .. MikSBT.COMMAND .. " <command> [params]",
	" Commands:",
	"  " .. L.COMMAND_RESET .. " - REimposta il profilo corrente alle impostazioni di base.",
	"  " .. L.COMMAND_DISABLE .. " - Disabilita l'addon.",
	"  " .. L.COMMAND_ENABLE .. " - Abilita l'addon.",
	"  " .. L.COMMAND_SHOWVER .. " - Mostra la versione corrente.",
	"  " .. L.COMMAND_HELP .. " - Mostra come usare i comandi.",
}


------------------------------
-- Output messages
------------------------------

L.MSG_DISABLE				= "Addon Disabilitato."
L.MSG_ENABLE				= "Addon Abilitato."
L.MSG_PROFILE_RESET			= "Profilo Reimpostato"
L.MSG_HITS					= "Colpi"
L.MSG_CRIT					= "Critico"
L.MSG_CRITS					= "Critici"
L.MSG_MULTIPLE_TARGETS		= "Multipli"
L.MSG_READY_NOW				= "Pronto Ora"


------------------------------
-- Scroll area names
------------------------------

L.MSG_INCOMING			= "In Arrivo"
L.MSG_OUTGOING			= "In Uscita"
L.MSG_NOTIFICATION		= "Notifiche"
L.MSG_STATIC			= "Statico"


----------------------------------------
-- Master profile event output messages
----------------------------------------

L.MSG_COMBAT					= "Combattimento"
L.MSG_DISPEL					= "Dissipare"
--L.MSG_CHI_FULL					= "Full Chi"
L.MSG_CP						= "PC"
L.MSG_CP_FULL					= "FINISCILO"
L.MSG_HOLY_POWER_FULL			= "Potere Benedetto Pieno"
--L.MSG_SHADOW_ORBS_FULL			= "Full Shadow Orbs"
L.MSG_KILLING_BLOW				= "Colpo Mortale"
L.MSG_TRIGGER_LOW_HEALTH		= "Vita Bassa"
L.MSG_TRIGGER_LOW_MANA			= "Mana Basso"
L.MSG_TRIGGER_LOW_PET_HEALTH	= "Vita Famiglio Bassa"

end

MikSBT.localePacksCore = MikSBT.localePacksCore or {}
MikSBT.localePacksCore["itIT"] = Apply
if (GetLocale() == "itIT") then Apply() end
