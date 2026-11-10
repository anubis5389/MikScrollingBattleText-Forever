# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.1.0] - 2026-11-10

First release of the dedicated WoW: Forever fork (based on NeeRgY/MSBT v1.0.6,
Forever code tree, with Midnight-fork hardening patterns).

### Added
- Base `MikScrollingBattleText.toc` alongside `_Mainline.toc`, both at
  `## Interface: 16001`, so the addon loads on the Forever client regardless of
  which TOC flavor the loader picks.
- Miss event support on the Forever `UNIT_COMBAT` fallback: incoming misses on
  the player and outgoing misses on the target (`MISS`, `DODGE`, `PARRY`,
  `BLOCK`, `RESIST`, `ABSORB`, `IMMUNE`, `REFLECT`). Previously misses were
  never shown on Forever.
- Damage school coloring on Forever: `schoolMask` from `UNIT_COMBAT` is
  propagated as `damageType` to the display pipeline.
- Secret-value passthrough: amounts that arrive as Blizzard Secret Values are
  now displayed instead of being silently dropped. `FormatEvent`, the
  damage/heal thresholds and the AoE merge path are hardened to never perform
  arithmetic, comparisons, `tonumber`, or pattern operations on secret values;
  the `%a` template token is spliced last via plain `string.find` +
  concatenation.

### Changed
- Crit detection in the `UNIT_COMBAT` fallback now matches compound flags by
  substring (`string_find(flagText, "CRITICAL", 1, true)`) instead of exact
  equality.
- Trigger conditions `buffActive` / `buffInactive` use
  `C_UnitAuras.GetAuraDataByIndex` instead of the removed `UnitBuff` global.
- Version metadata bumped to 1.1.0 in both TOC files.

### Notes
- Outgoing heals on other units remain a synthetic approximation via the
  `C_DamageMeter` fallback (per-spell session totals polled every 0.5s), as
  Forever exposes no per-hit outgoing heal feed to addons.

## [1.0.6] (upstream) - 2026-10-06

Baseline: NeeRgY/MSBT v1.0.6 package — multi-client TOCs, `Forever/` code tree
with `_Mainline.toc` at interface 16001, `UNIT_COMBAT` + cast-correlation
fallback, `C_DamageMeter` synthetic outgoing feed, minimap button, redesigned
options UI, and Base64 profile export (`MSBT1:` strings).
