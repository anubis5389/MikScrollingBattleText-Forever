# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.4.1] - 2026-11-11

### Reverted
- **Outgoing damage went dark again in v1.3.0/v1.4.0 - the meter-only engine
  is not viable DURING combat on Forever.** The diagnosis: the earlier
  `/run MikSBT.DebugMeterInfo()` captures were always taken *after* combat,
  when the client relaxes its Secret Values restrictions, so the meter feed
  looked fully usable - but mid-combat the spellID/totalAmount values cannot
  be unwrapped, and the engine silently produces nothing. The working engine
  (v1.1.2: solo UNIT_COMBAT on the target for outgoing damage/misses,
  C_DamageMeter as backup) is restored exactly, as of the v1.2.4 state
  (commit 4fa2bb3). The v1.4.0 heal/overheal work is undone with it and will
  be re-built on top of the working engine.

### Added
- **In-combat meter sampling (auto-diagnostics)**: while in combat, every 5s
  (max 8 per fight) the addon records whether the `C_DamageMeter` GUID source
  lookup succeeds and whether each spell's `spellID`/`totalAmount` can be
  unwrapped with `value + 0` (the exact gate the meter engine uses). Stored
  in the `MSBT_DebugDiagnostics` saved variable (readable from disk after
  /reload), reset per fight. This will settle with hard evidence what the
  meter delivers mid-combat before any further engine work.

## [1.2.3] - 2026-11-11

### Changed
- **REVERTED the entire 1.2.x outgoing engine** (per-spell meter-only
  attribution, instant direct-hit display, safety guards). Outgoing damage
  displayed nothing since 1.2.0; behavior is back to the 1.1.2 engine
  (`UNIT_COMBAT` cast-correlation + `C_DamageMeter` feed), which displayed
  damage. The known 1.1.x issues return with it: party members' damage on the
  same target can show as yours, and sustained damage may appear fragmented.

### Kept
- `MikSBT.DebugMeterInfo()` (`/run MikSBT.DebugMeterInfo()`) - prints whether
  the meter API is available, whether the session tracks the local player,
  and whether per-spell totals come back as usable numbers or `<secret>`
  values. This determines whether a meter-only engine can work on Forever at
  all, and was kept from the 1.2.x line for that purpose.

## [1.1.2] - 2026-11-10

### Fixed
- **Outgoing damage no longer appears fragmented into many small pieces.**
  The `C_DamageMeter` feed emitted a separate display event per spell on every
  0.5s poll, and MSBT's AoE merge window (`MERGE_DELAY_TIME = 0.3s`) could
  never coalesce events arriving 0.5s apart - continuous damage (DoTs,
  multi-hits, channels) read as the damage being split into pieces. Meter
  deltas are now accumulated per spell name (also coalescing the per-rank
  entries Classic can produce for the same spell) and flushed as a single
  event per spell every 1.0s, all in one frame so MSBT's merge pipeline can
  coalesce further.
- The tail of a fight is no longer dropped: pending aggregated deltas are
  flushed when combat ends.

## [1.1.1] - 2026-11-10

### Fixed
- **Damage from other players no longer shows as yours in groups.** On Forever,
  `UNIT_COMBAT` on the target can't tell *who* dealt the hit, so party members
  attacking the same target (any class, including the same class as the player)
  were displayed as the player's own outgoing damage. The player-only
  `C_DamageMeter` feed is now the sole authority for outgoing damage while in a
  group; the `UNIT_COMBAT` target path stands down entirely (wounds and misses).
  In solo play `UNIT_COMBAT` remains authoritative (per-hit detail, crits,
  schools).
- **Duplicate outgoing damage eliminated.** Previously the `C_DamageMeter`
  fallback and the `UNIT_COMBAT` target path could both deliver the same hit
  (meter delta + individual wound). A strict authority split (group = meter,
  solo = `UNIT_COMBAT`, flagged via `unitCombatOutgoingSeen` with resets on
  combat start and `GROUP_ROSTER_UPDATE`) guarantees exactly one source per hit.
- **Self-heal duplication removed.** Heals were shown twice: once from
  `UNIT_COMBAT` on the player (misattributed as a self-heal via cast
  correlation) and once from the `C_DamageMeter` healing-done feed.
  Outgoing healing now comes exclusively from the meter; `UNIT_COMBAT` no
  longer emits heal events (it can't attribute a heal to a caster, so heals
  from other players on the player were also being misattributed as self-heals).

### Changed
- Removed the meter/`UNIT_COMBAT` overlap heuristics
  (`meterDeliveredThisCombat`, `lastMeterDeltaTime` window) in favor of the
  strict authority split.

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
