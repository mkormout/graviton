# Phase 15: Enemy Sprites - Context

**Gathered:** 2026-04-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Visual upgrade: all five enemy types (Beeliner, Sniper, Flanker, Swarmer, Suicider) replace their Polygon2D debug shapes with sprites from `ships_assests.png`. Each enemy gains a pulsing PointLight2D gem glow tuned to their personality. Enemy bullet scenes for the four firing types also receive sprite updates from the same atlas. Suicider has no bullet scene to update.

No new enemy types, no gameplay or AI changes, no collision changes. This phase ends when all five ships look distinct and polished, and gem lights pulse at wave 20 without FPS regression.

</domain>

<decisions>
## Implementation Decisions

### Scope — ships and bullets
- **D-01:** Phase 15 includes BOTH ship sprite replacement AND enemy bullet sprite updates in one pass.
- **D-02:** The four firing enemy types (Beeliner, Sniper, Flanker, Swarmer) each have an existing bullet scene that gets a matching sprite from the atlas bottom half. Suicider has no bullet scene — no update needed.

### Sprite mapping (locked by requirements)
- **D-03:** ENM-07 → Beeliner, ENM-08 → Sniper, ENM-09 → Flanker, ENM-10 → Swarmer, ENM-11 → Suicider. The atlas labels match the requirements specification exactly.

### Gem glow — per-enemy personality-tuned pulse
- **D-04:** Each enemy gets a `PointLight2D` placed at its gem position with a color matching the visible gem:
  - Beeliner: green
  - Sniper: purple
  - Flanker: orange
  - Swarmer: yellow/amber
  - Suicider: red
- **D-05:** Pulse is per-enemy, tuned to match behavioral personality. Claude picks exact period and energy range:
  - Beeliner: steady rhythmic pulse — matches its charging, predictable aggression
  - Sniper: slow hypnotic pulse — long period, wide energy swing, deliberate feel
  - Flanker: rhythmic mid-tempo — steady orbit energy
  - Swarmer: quick flickering — short period, active, slightly erratic
  - Suicider: frantic fast pulse — high urgency, escalating feel

### Gem light culling
- **D-06:** A `VisibilityNotifier2D` node on each enemy controls gem light on/off. When the enemy exits the camera viewport, `PointLight2D.enabled` is set to false; when it enters, set to true.
- **D-07:** No hard cap on simultaneous active lights. Viewport-only culling is sufficient — off-screen enemies never have active lights.

### Scale — role-based sizing
- **D-08:** Enemies are NOT all scaled to the same size. Role determines visual size:
  - Sniper, Beeliner: approximately player ship size (~688 world units wide)
  - Flanker: approximately 75% of player ship size
  - Swarmer, Suicider: approximately 50% of player ship size
- **D-09:** Claude picks exact scale values per enemy type. All values are `@export`-tunable for post-playtest adjustment.

### Claude's Discretion
- Exact `Rect2` constants for each ship sprite region in the 2110×2048 atlas
- Exact `Rect2` constants for each bullet sprite region in the atlas bottom half
- Sprite rotation offset (sprites point "up" in the atlas; need −90° offset to align with Godot's +X facing direction used by `look_at()`)
- `PointLight2D` position within each enemy scene based on visible gem location in the sprite
- Exact pulse period and energy min/max per enemy type
- Final sprite scale values per enemy (within the role-tier ranges in D-08)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Sprite atlas
- `ships_assests.png` — 2110×2048 RGBA PNG. Top half: 5 ship sprites (ENM-07 through ENM-11, left to right). Bottom half: 5 matching bullet sprite sets. No import file exists yet — Godot will auto-import on first use.

### Enemy scenes (ship bodies)
- `prefabs/enemies/base-enemy-ship.tscn` — base scene; already has an empty `Sprite2D` child node to populate
- `prefabs/enemies/beeliner/beeliner.tscn` — has `Polygon2D` named "Shape" (to hide), and collision radius 300
- `prefabs/enemies/sniper/sniper.tscn` — same pattern
- `prefabs/enemies/flanker/flanker.tscn` — same pattern
- `prefabs/enemies/swarmer/swarmer.tscn` — same pattern
- `prefabs/enemies/suicider/suicider.tscn` — same pattern; no bullet scene

### Enemy bullet scenes (to update with sprites)
- `prefabs/enemies/beeliner/beeliner-bullet.tscn`
- `prefabs/enemies/sniper/sniper-bullet.tscn`
- `prefabs/enemies/flanker/flanker-bullet.tscn`
- `prefabs/enemies/swarmer/swarmer-bullet.tscn`

### Player ship scale reference
- `prefabs/ship-bfg-23/ship-bfg-23.tscn` — polygon spans ~688 units; use as the "full size" baseline for enemy scale calculations

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sprite2D` node in `base-enemy-ship.tscn` — already present but empty; each enemy scene can configure its `texture` and `region_rect` directly rather than adding a new node
- `Polygon2D` "Shape" node in each enemy scene — keep in scene for fallback (SPR-03); hide via `visible = false` when sprite loads successfully
- Existing `_ready()` pattern in enemy scripts — good place to attempt sprite load and fall back to Polygon2D if atlas is missing

### Established Patterns
- `@export` for tunable values — all scale, pulse period, and energy values should be exports so they survive the post-playtest iteration cycle
- Flat scene structure — sprites are configured per-enemy scene, not in the base scene, consistent with established inheritance-avoidance decision
- `look_at()` sets `global_rotation` to face +X — sprites pointing "up" in atlas need a −90° `rotation_offset` in `Sprite2D` (or Polygon2D child rotation equivalent)
- `CanvasLayer` process_mode pattern for HUD — not directly relevant here, but PointLight2D must have `process_mode` set correctly so it still culls when the game is paused on the death screen

### Integration Points
- Each enemy `_ready()` — load atlas texture, configure `Sprite2D.texture` + `region_rect`, hide Polygon2D on success, leave Polygon2D visible on failure (SPR-03)
- `VisibilityNotifier2D` signals: `screen_entered` → `PointLight2D.enabled = true`; `screen_exited` → `PointLight2D.enabled = false`
- Pulse animation: a `Tween` created in `_ready()` with `set_loops(0)` is the lightest approach; no AnimationPlayer node needed

</code_context>

<specifics>
## Specific Ideas

- Atlas labels are embedded in the image itself (ENM-07 through ENM-11 text visible on sprites). The mapping is reliable — no ambiguity in which ship goes where.
- Suicider (ENM-11) is a disc/sphere shape with a huge red gem — the gem IS most of the ship. The PointLight2D energy range should be dramatic to match the visual.
- Bullet sprites in the bottom half: each enemy type has a small group of projectile shapes (2–3 variants visible per type). Use the primary/largest bullet shape from each group for the bullet scene texture.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 15-enemy-sprites*
*Context gathered: 2026-04-17*
