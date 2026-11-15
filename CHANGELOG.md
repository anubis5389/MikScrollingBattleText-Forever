# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.6.0] - 2026-11-15

### Added
- **The game's own floating-combat-text feed (`COMBAT_TEXT_UPDATE` +
  `C_CombatText.SetActiveUnit("player")`)**, the data source of Blizzard's
  native combat text, now feeds MSBT:
  - **Heals on the player with the healer's name** - the only sanctioned feed
    that names the caster of a heal. Incoming heals from other players display
    as `+X [Healer]` (in groups and solo); self-heals attribute to the cast
    that just finished and mark it as a heal cast (it can never attribute
    damage later).
  - **`EXTRA_ATTACKS`** (Windfury-style extra swings) flags the player's own
    upcoming extra swings, so they show as plain melee numbers even in groups.
  - Returns may be Blizzard secret values mid-combat ("SecretReturns",
    patch 12.0); every event is logged to the decision log, so a test dump
    shows exactly what the feed delivered and how secret it was.
- **Group mode: strict correlation instead of total discard.** In a group, a
  wound on the target only shows when it can be tied to the player by the
  game's own signals: a fresh cast, a melee-cadence follow-up, a
  school-matched tick of the one spell with recent hits, or game-flagged extra
  attack swings. Everything else is dropped (group, unattributable) - it is
  somebody else's hit until proven otherwise. The weaker "old cast" rule is
  solo-only. Solo behaviour is unchanged (everything is yours there).
- **Cross-debounce** between the game's combat-text feed and `UNIT_COMBAT`
  heals: a heal is never shown twice; `UNIT_COMBAT` remains the authority for
  incoming damage and the solo heal fallback.

### Fixed
- Group-mode testing was a dead end in v1.5.1: the test dump proved the meter
  (`C_DamageMeter`) returns secret values for every entry mid-combat, and the
  group gate discarded all target wounds before the classifier ever saw them
  (empty decision log). Group play now runs on the strict-correlation path
  above instead of depending on a feed that is sealed mid-combat.

## [1.5.1] - 2026-11-15

### Fixed
- **No outgoing damage displayed during combat (v1.5.0)**: the classifier
  buffered into a sustained group every hit whose cast was 1.2-4s old, and
  every following hit refreshed that group - which never went idle for
  SUSTAINED_IDLE_FLUSH during an ongoing fight, so nothing showed until
  combat end. The classifier is now **show-by-default**: direct hits,
  melee-cadence multi-hits and one-off hits all display immediately. Only a
  spell that demonstrated DoT-like behaviour (2+ hits spaced beyond the melee
  cadence) groups its FUTURE hits; already-shown hits stay on screen.
- **Meter deltas (group mode) could also sit buffered until combat end**:
  meter-fed pending amounts now flush by age - one aggregated line per spell
  per second - instead of relying on the idle window.
- **Tick attribution now uses the damage school as evidence**: a wound is
  attributed to a single spell with recent hits only when the school matches
  (a fire wound cannot be a weapon swing); school mismatches and ambiguous
  candidates fall through to the (immediate) old-cast rule or to plain melee
  numbers - visible over perfectly attributed.

### Added
- **Solo feed decision log**: every wound/heal's attribution decision and
  display choice (fresh-cast show, cadence show, first show, spaced show,
  sustained switch, buffer, flush) is recorded (capped, per-fight markers)
  into `MSBT_DebugDiagnostics`, merged by `DebugMeterInfo()` - a test can now
  be verified from the SavedVariables dump without guessing.

## [1.5.0] - 2026-11-15

Complete redesign of the damage/healing pipeline ("Solo Combat Feed") after
the v1.3-v1.4 meter-based engines failed to display damage on the Forever
client. Same MSBT look, new data path.

### Added
- **Solo Combat Feed engine**: every number displayed comes from a signal that
  can only describe the player - `UNIT_SPELLCAST_*` on the player (casts),
  `UNIT_COMBAT` on the player (incoming damage, misses, self-heals) and
  `UNIT_COMBAT` on the target **solo only**. In groups the GUID-keyed
  `C_DamageMeter` per-spell totals are the ONLY dealt-damage/healing source;
  entries that cannot be unwrapped (Secret Values mid-combat) are skipped, so
  the feed shows your damage or nothing - never anyone else's.
- **Per-spell classifier with sustained grouping**: a hit landing within 1.2s
  of its cast shows immediately (direct hit); hits of the same spell arriving
  at melee cadence (multi-hit specials) keep showing directly; hits that
  space out (DoT ticks, slow weapon procs) switch to sustained mode and
  render as one grouped line `Spell (hits) total`, flushed after 3.5s of
  quiet or at combat end. A recast closes the open group first so no total is
  lost.
- **Independent weapon hits**: unattributed wounds (weapon swings, procs)
  render as classic plain melee numbers, independent of any spell.
- **Live overheal estimate**: a double-buffered `UNIT_HEALTH` ledger estimates
  how much of each self-heal exceeded max health, rendered through
  FormatEvent's existing overheal trailer. In groups the meter's
  `overkillAmount` delta is used instead.
- **Self-heals solo**: a heal landing on the player is shown as the player's
  own outgoing heal (attributed to the cast just finished); the cast is marked
  as a heal so it can never attribute damage later. In groups heals are not
  shown from UNIT_COMBAT (caster unknowable) - the meter covers dealt healing.
- **Channelled spells** always count as sustained damage (their ticks group
  instead of popping per tick).
- **Regrouping mid-combat** closes open sustained groups before switching the
  dealt-damage authority (solo `UNIT_COMBAT` <-> group meter).

### Changed
- The damage meter is no longer polled solo (UNIT_COMBAT is authoritative and
  richer there), eliminating every double-display scenario.
- Diagnostics: mid-combat meter sampling now accumulates across fights with
  fight-start markers; `DebugMeterInfo()` merges (never overwrites) samples.

### Removed
- The v1.4 stand-down flags (`unitCombatOutgoingSeen`/`unitCombatHealSeen`)
  and the meter's aggregated pending-event buffer - replaced by the shared
  classifier/accumulator.

## [1.4.2] - 2026-11-11

### Fixed
- **Outgoing heals never displayed (v1.1.2 engine)**: heals landing on the
  player were deliberately excluded from `UNIT_COMBAT` and left to the
  `C_DamageMeter` healing-done feed - which does not deliver mid-combat.
  Solo, a `UNIT_COMBAT` heal on the player is now delivered as the player's
  own outgoing heal (same authority rule as wounds), attributed to the cast
  that just finished; in groups the meter stays the healing source (a heal
  from another player cannot be attributed). The meter feed stands down once
  `UNIT_COMBAT` has delivered heals, so nothing shows twice.
- **DoT ticks inherited the name of a heal cast within the attribution
  window** (e.g. a Flame Shock tick labeled as Healing Wave): spells observed
  to produce a heal on the player are now marked as heals and excluded from
  the damage attribution.

### Changed
- `DebugMeterInfo()` now PREPENDS the automatic in-combat samples instead of
  overwriting them - running the manual capture after a fight no longer wipes
  the mid-combat evidence (that is how the first samples were lost). Samples
  also accumulate across fights (capped at 100 lines) with a fight-start
  marker each.

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
