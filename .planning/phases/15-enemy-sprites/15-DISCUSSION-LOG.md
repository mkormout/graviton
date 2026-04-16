# Phase 15: Enemy Sprites - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-17
**Phase:** 15-enemy-sprites
**Areas discussed:** Bullet sprites, Gem glow feel, Culling threshold, Scale approach

---

## Bullet sprites

| Option | Description | Selected |
|--------|-------------|----------|
| Ships only | Replace Polygon2D shapes with ship sprites; bullets stay as-is | |
| Ships + bullets | Use matching bullet sprites from same sheet for all four firing enemy types | ✓ |
| Ships only, note bullets | Replace ship bodies now; note bullets as a follow-up todo | |

**User's choice:** Ships + bullets
**Notes:** All four firing types (Beeliner, Sniper, Flanker, Swarmer) get bullet sprite updates. Suicider has no bullet scene — excluded. Confirmed: update all that fire.

---

## Gem glow feel

| Option | Description | Selected |
|--------|-------------|----------|
| Slow ambient pulse | 2–3s period, energy ~0.3→1.0. Subtle reactor feel. | |
| Fast aggressive pulse | 0.5–1s period, sharp intensity spikes. | |
| You decide | Claude picks values that work for space shooter with 20+ enemies on screen. | |

**User's choice:** Slow ambient pulse (per-enemy personality tuning)

*Follow-up: uniform or per-enemy?*

| Option | Description | Selected |
|--------|-------------|----------|
| Same rate, different colors | All pulse on ~2.5s; color distinguishes enemies | |
| Per-enemy tuning | Each enemy type has a distinct rhythm matching their behavior | ✓ |

*Follow-up: specify values or Claude's call?*

| Option | Description | Selected |
|--------|-------------|----------|
| Claude's call — match personality | Claude assigns pulse period + energy to match each ship's behavior | ✓ |
| I'll specify | User provides exact values for some or all enemies | |

**Notes:** Personality mapping agreed: Suicider=frantic, Sniper=hypnotic slow, Beeliner=steady charging, Flanker=rhythmic, Swarmer=quick flickering.

---

## Culling threshold

| Option | Description | Selected |
|--------|-------------|----------|
| Distance from player | Disable PointLight2D beyond N world units from player | |
| VisibilityNotifier2D | Built-in Godot node; light off when enemy exits camera viewport | ✓ |
| You decide | Claude picks the implementation that performs best | |

*Follow-up: viewport-only or add a hard cap?*

| Option | Description | Selected |
|--------|-------------|----------|
| Viewport only | Off-screen = light off. On-screen enemies all have lights. | ✓ |
| Viewport + max cap | Disable lights beyond N simultaneous active (e.g. cap at 15) | |

**Notes:** VisibilityNotifier2D is the chosen culling mechanism. No simultaneous light cap — viewport-only is sufficient.

---

## Scale approach

| Option | Description | Selected |
|--------|-------------|----------|
| All same size as player | Every enemy scaled to ~688 units — consistent threat size | |
| Role-based sizing | Swarmer/Suicider smaller; Beeliner/Sniper match player; Flanker mid | ✓ |
| Match collision radius | Scale sprite to match collision circle (300px radius) | |

*Follow-up: specify or Claude's call?*

| Option | Description | Selected |
|--------|-------------|----------|
| Claude picks based on role | Sniper+Beeliner ≈ player; Flanker ≈ 75%; Swarmer+Suicider ≈ 50% | ✓ |
| I'll set a range | User specifies min/max unit range | |

**Notes:** Role-based sizing confirmed. Claude decides exact scale values. All scale values will be @export-tunable for post-playtest iteration.

---

## Claude's Discretion

- Exact Rect2 constants for each ship sprite region in the 2110×2048 atlas
- Exact Rect2 constants for each bullet sprite region (bottom half of atlas)
- Sprite rotation offset (−90° expected for +X facing alignment)
- PointLight2D gem position per enemy scene
- Exact pulse period and energy min/max per enemy type
- Final scale values per enemy type (within role-tier ranges)

## Deferred Ideas

None — discussion stayed within phase scope.
