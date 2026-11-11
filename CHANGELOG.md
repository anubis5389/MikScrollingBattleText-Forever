# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.2.2] - 2026-11-11

### Fixed
- **No outgoing damage displayed at all (regression in 1.2.0).** The new
  safety checks added in 1.2.0 silently blocked the entire meter feed on some
  setups: the `damageMeterEnabled`/`IsDamageMeterAvailable()` gate and the
  `isLocalPlayer` session guard both failed closed. They are now warnings
  only (fail-open) - the feed is always attempted, and attribution is instead
  cross-checked by comparing the GUID-keyed source total against the
  session's local-player total; only a provable mismatch (both values plain
  and comparable) skips the data, with a one-time chat warning.

### Changed
- `MikSBT.DebugMeterInfo()` now also prints the feed state (ticker running,
  seconds since the last meter activity, pending events, tracked totals) to
  distinguish a dead feed from a blocked one.

## [1.2.1] - 2026-11-11

### Changed
- **Instant, single-hit spells now display immediately when cast.** A meter
  delta arriving within 1s of the player casting that spell is recognized as
  its direct hit and shown right away (`Spell amount`), instead of waiting for
  the grouping window. Only sustained damage keeps grouping into
  `Spell (hits) total`: DoT/HoT ticks (deltas arriving long after the cast),
  channelled spells (marked as sustained for their whole duration via
  `UNIT_SPELLCAST_CHANNEL_START/STOP`), and weapon hits (no cast at all).
- The cast that starts a fight is not forgotten: recent casts survive the
  combat-start reset (stale entries can't cause false direct-hits since they
  only match within the 1s window).

## [1.2.0] - 2026-11-11

### Changed
- **Outgoing combat text engine rewritten around strict per-spell attribution.**
  The `C_DamageMeter` feed (keyed to the player's own GUID) is now the *sole*
  source for outgoing damage and healing, both solo and in groups. The
  `UNIT_COMBAT` outgoing path was removed entirely: it cannot tell *who* dealt
  a hit, so it misattributed party members' damage (any class, same spells or
  weapon hits) as the player's own, and its cast-correlation heuristic lumped
  melee swings and DoT ticks together under whichever spell was cast last.

### Fixed
- **Each spell's damage is now independent.** Meter deltas key strictly by
  `spellID`; weapon hits (which the meter reports under their own ID) render
  as the classic plain melee number instead of being folded into the last cast
  spell.
- **Only the player's own damage/healing is shown.** The feed is filtered by
  the player's GUID and additionally requires the local player to be present
  in the meter session (`isLocalPlayer`) before anything is displayed.
- **Spells are grouped with a hit estimate.** Each spell accumulates while it
  keeps producing damage and is displayed as one line when it goes quiet
  (3.5s) or when combat ends: `<Spell> (<hits>) <total>` - e.g. a DoT that
  deals 30 damage over 10 seconds shows as one line with its hit count
  (estimated as one hit per 0.5s poll window in which the total grew).
- **Combat-start garbage number fixed.** The meter totals baseline is no
  longer cleared when combat starts; previously that could re-emit the whole
  accumulated session total as one giant number.

### Added
- `MikSBT.DebugMeterInfo()` - run `/run MikSBT.DebugMeterInfo()` in game to
  print live diagnostics of what the meter API returns (availability, session
  sources, per-spell totals) to diagnose attribution issues.
- A one-time chat hint if Blizzard's Damage Meter tracking is disabled
  (`damageMeterEnabled`), since the outgoing text feed requires it.

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
