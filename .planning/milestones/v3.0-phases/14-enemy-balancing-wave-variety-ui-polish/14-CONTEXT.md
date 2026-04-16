# Phase 14: Enemy Balancing + Wave Variety + UI Polish - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Game-feel polish pass: enemies are harder and more distinct (doubled HP, doubled fire range, per-type behavioral tweaks, vertex orientation), waves have manual pacing (player controls when next wave starts), and HUD is clearer (larger wave announcement with enemy-type subtitle, cheat sheet hidden by default with Tab + edge-arrow toggle).

No new enemy types, no new weapons, no menu or game loop — this phase ends when all five enemies feel balanced, waves feel paced, and the UI is polished.

</domain>

<decisions>
## Implementation Decisions

### Wave-clear flow
- **D-01:** When the last enemy dies, show a persistent centered label: `"WAVE X CLEARED\nPress Enter or F to continue"`. The label stays visible until the player presses Enter or F. The auto-countdown timer (`countdown_seconds` in WaveManager) is removed entirely — no automatic wave start.
- **D-02:** KEY_ENTER is reassigned from "spawn asteroids" to "advance wave" (when a wave-cleared prompt is showing). KEY_F remains the secondary trigger. Asteroid spawning via ENTER is removed from the cheat sheet; it can move to a different key (e.g., N) or be dropped as a dev-only shortcut.
- **D-03:** The "WAVE X CLEARED" label is a new UI element — either a new Label node in WaveHud or a dedicated CanvasLayer child in world.tscn. It must be visible above all other HUD layers (no CanvasLayer z-ordering issues).

### Cheat sheet toggle
- **D-04:** Default state is **hidden** — the controls hint is not visible when the game starts.
- **D-05:** TAB key toggles the controls hint on/off.
- **D-06:** A small static ► arrow button is fixed to the right edge of the screen. It persists even when the cheat sheet is hidden, giving a permanent visible affordance. Clicking it also toggles the panel. The arrow is part of the controls-hint CanvasLayer.
- **D-07:** The controls-hint is updated to list all v3.0 shortcuts, including:
  - `Tab` — toggle cheat sheet
  - `F` — next wave (replacing the old "trigger wave" behavior)
  - Score HUD, wave HUD entries for context
  - H and J debug shortcuts stay on the list (keep them as-is)
  - ENTER row updated: remove "asteroid spawn", replace with "next wave" note

### Enemy score values
- **D-08:** Per-type score values (update `score_value` export in each enemy script):
  - Swarmer: 50
  - Suicider: 75
  - Beeliner: 100 (baseline, unchanged)
  - Flanker: 150
  - Sniper: 200

### Enemy stat buffs (all types)
- **D-09:** HP x2 — update `max_health` export on each enemy scene/script.
- **D-10:** Fire range x2 — update `fight_range` (and equivalent: `comfort_range`, `flee_range`, `safe_range` for Sniper) exports on each enemy script.
- **D-11:** Projectile speed increase — update `bullet_speed` exports on all enemy scripts. Planner picks exact multiplier (roughly 1.3–1.5x feels right given doubled range).

### Enemy orientation
- **D-12:** Each enemy's Polygon2D visual should have a corner or vertex pointing in the enemy's facing direction. Implement by rotating the Polygon2D child node so a vertex aligns with the +X axis (which `look_at()` sets as the facing direction). This is a per-scene offset in the Polygon2D `rotation` property — no code change needed if the polygon is already rotationally symmetrical and has a vertex on +X.

### Per-type behavioral tweaks
- **D-13 (Beeliner):** Add subtle perpendicular jitter — small steering force applied every 1–2s at a random perpendicular angle. Formation looks natural, attack lines mostly predictable. Easy to dodge with skill.
- **D-14 (Sniper):** Add slow left-right oscillation (sinusoidal perpendicular force) while in FIGHTING state. Amplitude ~200–300px. Sniper drifts side-to-side while aiming, making it harder to hit.
- **D-15 (Flanker):** Fix the patrol resumption bug — when distance > `max_follow_distance`, transition to PATROLLING (or SEEKING if PATROLLING is not wired) instead of going IDLING. The Flanker must not get stuck far from the player.
- **D-16 (Swarmer):** Implement per-wave-group speed tier. Swarmers spawned in the same wave group share a speed multiplier (e.g., 0.6x for "slow swarm", 1.5x for "fast swarm"). Individual per-instance variance (±20%) still applies on top. World.gd wave configs can then define distinct slow/fast swarmer groups.
- **D-17 (Suicider):** Increase max movement speed and buff explosion radius/damage. Claude picks exact values; start with +30% speed, +50% explosion radius.

### Wave announcement UI
- **D-18:** The wave announcement label (`_announcement_label`) should be significantly larger — increase font size to 72px or larger. It already shows `"Wave N\nEnemy Types"` — no content change needed, just font/size polish.
- **D-19:** The announcement should fade in quickly (0.3s) and remain visible for 2s before fading out (1s fade). This replaces the current 3s linear fade. The label is already centered and above other HUD elements.

### Claude's Discretion
- Exact Polygon2D rotation offset per enemy type (visual tweaking per shape)
- Exact bullet_speed multiplier for each enemy type
- Suicider explosion radius exact value
- Beeliner jitter timer interval and force magnitude
- Sniper strafe oscillation period and exact force
- Font size for the wave-cleared label and exact positioning
- Whether the ► arrow uses a Button node or a stylized Label with mouse_entered/gui_input

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

No external specs or ADRs exist for this phase. Requirements are fully captured in the decisions above and the files below.

### Enemy scripts to modify
- `components/beeliner.gd` — `fight_range`, `bullet_speed`, `score_value`; add jitter logic
- `components/sniper.gd` — `fight_range`, `comfort_range`, `flee_range`, `safe_range`, `bullet_speed`, `score_value`; add strafe force in `_tick_state` FIGHTING branch
- `components/flanker.gd` — `fight_range`, `bullet_speed`, `score_value`; fix PATROLLING resumption in `_tick_state`
- `components/swarmer.gd` — `fight_range`, `bullet_speed`, `score_value`; add speed tier export
- `components/suicider.gd` — `max_speed`, `score_value`; explosion radius lives in `explosion.gd` or the suicider prefab scene
- `components/enemy-ship.gd` — base `score_value = 100`; `max_speed`, `detection_radius`; HP via Body base class

### HUD and UI
- `prefabs/ui/wave-hud.gd` — add wave-clear label and `connect_to_wave_manager` wiring; listen for new `wave_completed` signal to show/hide prompt
- `prefabs/ui/wave-hud.tscn` — add Label node for "WAVE X CLEARED / Press Enter or F"
- `prefabs/ui/controls-hint.tscn` — RichTextLabel text to update; add ► arrow Button node; add toggle logic
- `components/wave-manager.gd` — remove `_countdown_timer` auto-advance; add `wave_cleared_waiting` signal; `trigger_wave()` only called by explicit input, not timer

### World wiring
- `world.gd` — KEY_ENTER: remove asteroid spawn, add wave-advance call; KEY_TAB: add controls-hint toggle; wave array: add fast/slow swarmer group variants; connect WaveManager `wave_cleared_waiting` signal to UI

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `WaveManager.wave_completed` signal — already emitted when last enemy dies; WaveHud can listen to this to show the wave-clear label
- `_announcement_label` in WaveHud — already a centered CanvasLayer label with tween support; reuse for larger font-size announcement
- `randf_range(0.8, 1.2)` per-instance jitter pattern — already used in all enemies' `_ready()`; Beeliner jitter and Swarmer speed tier follow the same pattern
- `CanvasLayer` process_mode pattern — established in Phase 12/13; any new overlay nodes must follow this

### Established Patterns
- Enemy stat tuning via `@export` — all enemies expose `fight_range`, `bullet_speed`, `max_speed` as exports; stat changes are export-value-only (no logic changes needed for pure buffs)
- `look_at()` sets `global_rotation` to face the target — vertex orientation means the Polygon2D child needs its `rotation` offset so a vertex aligns with +X
- Bare-label HUD style (no Panel background) — established in wave-hud and score-hud; wave-clear label should follow this pattern
- `connect_to_X(manager)` init method — wave-hud already uses this; any new wave-clear widget follows the same pattern

### Integration Points
- `world.gd` `_input()` — add KEY_TAB → controls-hint.toggle(); KEY_ENTER → wave-advance (only when wave-cleared prompt visible)
- `WaveManager._on_wave_complete()` — currently starts countdown; replace with: emit `wave_cleared_waiting`, wait for explicit `trigger_wave()` call
- `prefabs/ui/controls-hint.tscn` — add a `toggle()` method to the CanvasLayer script; add ► Button node as sibling to the MarginContainer

</code_context>

<specifics>
## Specific Ideas

- Wave-clear label mockup confirmed:
  ```
               WAVE 3 CLEARED
          Press Enter or F to continue
  ```
  Centered, persistent, no fade until player presses Enter or F.

- Enemy score tier confirmed:
  ```
  Swarmer  :  50 pts
  Suicider :  75 pts
  Beeliner : 100 pts
  Flanker  : 150 pts
  Sniper   : 200 pts
  ```

- Cheat sheet is hidden by default. TAB key and a ► arrow on the right screen edge both toggle it.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 14-enemy-balancing-wave-variety-ui-polish*
*Context gathered: 2026-04-16*
