# Phase 16: Dynamic Music - Context

**Gathered:** 2026-04-17
**Status:** Ready for planning

<domain>
## Phase Boundary

MusicManager autoload plays background music that automatically shifts between three intensity categories (Ambient, Combat, High-Intensity) as the wave number increases. Transitions are smooth cross-fades. Tracks are loaded via a preload catalog (no DirAccess — export-safe). Phase ends when music plays from game start, shifts category on each wave, and cross-fades cleanly.

No new gameplay, no UI changes, no enemy or score changes.

</domain>

<decisions>
## Implementation Decisions

### Wave Category Thresholds
- **D-01:** Waves 1–5 → Ambient; Waves 6–10 → Combat; Waves 11+ → High-Intensity.
- **D-02:** Category check fires on `wave_started(wave_number)` — music is already correct as enemies arrive, matching the dramatic moment of each wave announcement.

### Cross-Fade
- **D-03:** Cross-fade duration is **2 seconds** — long enough to feel intentional and musical, short enough to not feel laggy.
- **D-04:** Mechanism: dual `AudioStreamPlayer` nodes + `Tween` (per MUS-05, already locked by requirements). Outgoing track fades out while incoming track fades in simultaneously.

### Track Catalog Design
- **D-05:** When a category has multiple tracks, use **shuffle (no-repeat)** — pick randomly, never replay the track that just played. Avoids back-to-back repeats without being deterministic.
- **D-06:** When a category has **no tracks assigned**, fall back to any available track from another category. Music never goes silent due to a missing category.
- **D-07:** Catalog is a preload dictionary (no DirAccess). Structure: `{ "ambient": [preload(...)], "combat": [...], "high_intensity": [...] }`. Each array can be empty or have multiple entries.

### Autoload Structure
- **D-08:** MusicManager follows the ScoreManager autoload pattern: `extends Node`, registered in `project.godot [autoload]`, no scene file needed.
- **D-09:** MusicManager must expose a `reset()` method that restores Ambient category and restarts playback from Wave 1 state — required by Phase 17 (game restart). Claude picks the exact reset implementation.

### Claude's Discretion
- Initial volume levels for the two AudioStreamPlayers
- How to handle the edge case where a category change fires while a cross-fade is already in progress (interrupt or queue)
- Exact preload catalog GDScript syntax (preload() calls for all four track files)
- Whether to emit a signal from MusicManager when category changes (useful for Phase 17 debugging but not required)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing autoload pattern
- `components/score-manager.gd` — Reference implementation for a GDScript autoload: `extends Node`, signal declarations, `_ready()` pattern with deferred lookups, `call_deferred` for wiring to other autoloads/scene nodes.

### Wave signal source
- `components/wave-manager.gd` — Emits `wave_started(wave_number: int, enemy_count: int, label_text: String)` and `wave_completed(wave_number: int)`. MusicManager connects to `wave_started`.

### World wiring reference
- `world.gd` — Shows how `ScoreManager.connect_to_wave_manager(wm)` is called after the scene is ready. MusicManager will need the same wiring pattern.

### Music assets

Preload catalog assignments (hardcoded — no DirAccess):

| Category | Tracks |
|----------|--------|
| Ambient | `music/Gravity-Drum Choir.mp3`, `music/Sulfur Orbit.mp3`, `music/Graviton Lullaby.mp3` |
| Combat | `music/Static Lullaby.mp3`, `music/Gravimetric Dawn.mp3` |
| High-Intensity | `music/Static Lullaby.mp3`, `music/Gravimetric Dawn.mp3` |

Note: Combat and High-Intensity share the same two tracks. The category shift still triggers a cross-fade, and the shuffle/no-repeat logic applies within each category's pool independently.

### Project autoload registration
- `project.godot` `[autoload]` section — Add `MusicManager="*res://components/music-manager.gd"` following the ScoreManager pattern.

### Requirements
- No external spec — requirements fully captured in MUS-01 through MUS-05 in `.planning/REQUIREMENTS.md` and decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ScoreManager` autoload (`components/score-manager.gd`) — Exact pattern to clone: `extends Node`, registered in project.godot, uses `call_deferred` for safe scene-node lookups from autoload context.
- `RandomAudioPlayer` (`components/random-audio-player.gd`) — Shows `AudioStreamPlayer2D` creation in `_ready()`. MusicManager uses non-positional `AudioStreamPlayer` (no 2D positioning needed for background music).

### Established Patterns
- `@export` for tunable values — Cross-fade duration and wave thresholds should be `@export` vars so they can be tweaked in the editor without code changes.
- `call_deferred` for autoload-to-scene wiring — Autoloads run before the scene tree; connect to WaveManager via `call_deferred("_connect_wave_manager")` in `_ready()`.
- `Tween` for animation — Used for gem-light pulse in Phase 15. Same pattern applies here for cross-fade volume interpolation.

### Integration Points
- `world.gd` — Must call `MusicManager.connect_to_wave_manager(wave_manager_node)` after scene is ready (mirrors `ScoreManager.connect_to_wave_manager` pattern).
- `project.godot [autoload]` — Add one line to register MusicManager.
- Phase 17 `restart()` — Will call `MusicManager.reset()` as part of the reset sequence.

</code_context>

<specifics>
## Specific Ideas

- All four tracks are now assigned across categories — no empty-category fallback will be triggered in the current state.
- The two `AudioStreamPlayer` nodes (A and B, ping-pong) can be created dynamically in `_ready()` rather than requiring a scene file — consistent with ScoreManager's approach of building its own children.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 16-dynamic-music*
*Context gathered: 2026-04-17*
