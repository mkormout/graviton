# Phase 11: ScoreManager - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-14
**Phase:** 11-scoremanager
**Areas discussed:** ScoreManager placement, Kill detection hook, Enemy point values, Combo audio

---

## ScoreManager placement

| Option | Description | Selected |
|--------|-------------|----------|
| Autoload singleton | Globally accessible, no scene coupling. Phase 12 HUD and Phase 13 Leaderboard reference directly | ✓ |
| World child Node | Like WaveManager — consistent architecture but requires explicit reference passing | |
| Attached to WaveManager | Conflates responsibilities; complicates Phase 13 | |

**User's choice:** Autoload singleton
**Notes:** Clean global state pattern; no prior autoloads exist so this will be the first.

---

## Kill detection hook

| Option | Description | Selected |
|--------|-------------|----------|
| Signal on Body.die() | Add `died` signal to Body.gd; ScoreManager connects per enemy at spawn | ✓ |
| Via WaveManager signal | Extend enemy_count_changed with type info; couples scoring to wave logic | |
| tree_exiting in WaveManager | Requires WaveManager to know about ScoreManager | |

**User's choice:** Signal on Body.die()
**Notes:** Also decided to add `health_changed` signal to Body.damage() for multiplier reset detection. Both signals added in a single pass to Body.gd.

| Option (damage detection) | Description | Selected |
|---------------------------|-------------|----------|
| Signal on Body.damage() | health_changed signal fired on any health decrease | ✓ |
| Poll in ScoreManager._process | Wasteful, brittle | |
| PlayerShip emits own signal | Separate pattern, inconsistent | |

**User's choice:** Signal on Body.damage()

---

## Enemy point values

| Option | Description | Selected |
|--------|-------------|----------|
| @export on EnemyShip | score_value set per scene in Inspector; consistent with existing @exports | ✓ |
| Dictionary in ScoreManager | All values in one place; requires two-file edits to add new enemy types | |
| Resource per enemy type | Overkill for a single value | |

**User's choice:** @export on EnemyShip

| Option (initial values) | Description | Selected |
|-------------------------|-------------|----------|
| Difficulty-based tiers | Beeliner=100, Swarmer=50, Flanker=150, Sniper=200, Suicider=75 | ✓ |
| Equal/arbitrary values | Placeholder only | |
| Claude decides | | |

**User's choice:** Difficulty-based tiers (Beeliner=100, Swarmer=50, Flanker=150, Sniper=200, Suicider=75)

---

## Combo audio

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse existing + pitch_scale | coin-pick.wav at varied pitch; no new asset | |
| New dedicated combo sound | Import/create dedicated chime asset | ✓ |
| AudioStreamGenerator (synthesized) | Code-driven tone generation; complex | |

**User's choice:** New dedicated combo sound
**Notes:** But since sourcing a real asset takes time, decided to use coin-pick.wav as placeholder now and swap in Phase 14 polish.

| Option (sound type) | Description | Selected |
|---------------------|-------------|----------|
| Coin-pick style (metallic click) | Familiar, fits palette | |
| Higher-pitched chime / ding | Clean ascending tone, distinct from coins | ✓ |
| Claude decides | | |

**User's choice:** Higher-pitched chime / ding (to be sourced for Phase 14; coin-pick.wav placeholder in Phase 11)

| Option (pitch progression) | Description | Selected |
|---------------------------|-------------|----------|
| Linear steps (×0.15 per kill) | Simple, predictable | |
| Semitone steps (×1.0595) | Musical, one semitone per combo kill | ✓ |
| Claude decides | | |

**User's choice:** Semitone steps — `pitch_scale = pow(1.0595, combo_count - 1)`

---
