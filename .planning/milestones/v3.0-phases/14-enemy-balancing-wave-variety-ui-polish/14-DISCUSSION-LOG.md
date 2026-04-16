# Phase 14: Enemy Balancing + Wave Variety + UI Polish - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-16
**Phase:** 14-enemy-balancing-wave-variety-ui-polish
**Areas discussed:** Wave-clear flow, Cheat sheet toggle, Enemy behavior feel, Enemy score values

---

## Wave-clear flow

| Option | Description | Selected |
|--------|-------------|----------|
| Persistent center label | Permanent centered label "WAVE CLEARED / Press Enter or F to continue". Stays until player presses Enter/F. Replaces countdown. | ✓ |
| Panel in wave HUD | Info appears in top-left wave panel, less interruptive. | |
| Fade-in then persist | Fades in like current wave announcement but stays visible. | |

**User's choice:** Persistent center label

---

| Option | Description | Selected |
|--------|-------------|----------|
| Reassign ENTER to wave-only | ENTER advances wave. Asteroid spawn moves to different key or removed. | ✓ |
| Context-sensitive ENTER | ENTER does wave-advance when prompt visible, asteroids otherwise. | |
| Keep both, conflict fine | ENTER does both behaviors simultaneously. | |

**User's choice:** Reassign ENTER to wave-only

---

## Cheat sheet toggle

| Option | Description | Selected |
|--------|-------------|----------|
| Tab | Tab is free, semantically fits "toggle UI", easy to reach. | ✓ |
| H key | Reassign H from unlimited ammo to cheat sheet toggle. | |
| Backtick/tilde (~) | Classic dev console toggle, not currently used. | |

**User's choice:** Tab

---

| Option | Description | Selected |
|--------|-------------|----------|
| Keep H/J, add new shortcuts | Add F (next wave), Tab (toggle cheat sheet). Existing debug shortcuts stay. | ✓ |
| Remove H/J from cheat sheet | Remove from visible list but keep behavior. | |
| Remove H/J entirely | Delete behavior from world.gd too. | |

**User's choice:** Keep them, add new shortcuts

---

**User's notes (freeform):** Default cheat sheet state should be hidden. If hidden, can be toggled by TAB or by small arrow on the edge of the screen.

| Option | Description | Selected |
|--------|-------------|----------|
| Static arrow button | ► arrow fixed to right edge, always visible. Click to toggle. | ✓ |
| Arrow only, no Tab | Mouse-only toggle via arrow button. | |
| You decide arrow style | Tab is primary, Claude decides edge indicator style. | |

**User's choice:** Static arrow button (► persists on screen edge, clicking also toggles)

---

## Enemy behavior feel

| Option | Description | Selected |
|--------|-------------|----------|
| Subtle drift | Small perpendicular jitter every 1-2s. Formation natural, attack lines predictable. | ✓ |
| Noticeable chaos | Bigger random direction changes every 0.5-1s. Harder to dodge. | |
| You decide | Claude picks jitter magnitude. | |

**User's choice (Beeliner pathing):** Subtle drift

---

| Option | Description | Selected |
|--------|-------------|----------|
| Slow left-right oscillation | Sinusoidal perpendicular force, ~200-300px amplitude, while FIGHTING. | ✓ |
| Tight short bursts | Quick perpendicular jerks, low amplitude (~100px), high frequency. | |
| You decide | Claude picks amplitude and frequency. | |

**User's choice (Sniper strafe):** Slow left-right oscillation

---

| Option | Description | Selected |
|--------|-------------|----------|
| Per-wave-group speed tier | Swarmers in same group share a speed tier; wave config defines slow/fast groups. | ✓ |
| Fully random per instance | Each Swarmer rolls wide speed range independently (0.5x–2.0x). | |
| You decide | Claude implements best contrast approach. | |

**User's choice (Swarmer variance):** Per-wave-group speed tier

---

## Enemy score values

| Option | Description | Selected |
|--------|-------------|----------|
| Difficulty-based tiering | Swarmer=50, Suicider=75, Beeliner=100, Flanker=150, Sniper=200 | ✓ |
| Flat + combo incentive | All stay at 100, differentiation via combos/multipliers only. | |
| Player reviews baseline | Start with difficulty tier as baseline, user wants to review. | |

**User's choice:** Difficulty-based tiering (Swarmer=50, Suicider=75, Beeliner=100, Flanker=150, Sniper=200)

---

## Claude's Discretion

- Polygon2D rotation offsets per enemy type (visual vertex alignment)
- Exact bullet_speed multiplier per enemy
- Suicider explosion radius exact value
- Beeliner jitter timer interval and force magnitude
- Sniper strafe oscillation period and force
- Font size for wave-cleared label and positioning
- Arrow button node type (Button vs styled Label)

## Deferred Ideas

None — discussion stayed within phase scope.
