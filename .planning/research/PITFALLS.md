# Pitfalls Research: v3.5 Juice & Polish (Graviton)

**Domain:** Adding dynamic music, enemy sprites, and game restart to an existing single-scene Godot 4.6.2 space shooter with autoload singletons
**Researched:** 2026-04-16
**Confidence:** HIGH (autoload restart pitfalls verified against Godot official docs and confirmed engine behavior; music pitfalls verified against official AudioStreamInteractive docs and known bug trackers; sprite pitfalls verified against AtlasTexture issue trackers and codebase inspection)

---

## Critical Pitfalls

---

### Pitfall C-1: ScoreManager Autoload State Not Reset on Restart

**What goes wrong:**
When the player restarts from the death screen, `ScoreManager` is an autoload singleton — it persists across any scene reload. `total_score`, `kill_count`, `wave_multiplier`, `combo_count`, and the `_player` reference all retain their values from the previous run. The new game starts with the old score already populated and the wave multiplier at whatever it was when the player died.

**Why it happens:**
Godot autoloads are instantiated once at engine startup and live at the root of the scene tree above `current_scene`. `get_tree().reload_current_scene()` (or `change_scene_to_file`) frees and recreates the scene nodes, but never touches autoloads. `_ready()` on `ScoreManager` does not run again — only its initial run at game launch. The `_find_player()` deferred call also does not re-execute, so `_player` still holds a reference to the now-freed previous `PlayerShip` node.

**How to avoid:**
Add an explicit `reset()` method to `ScoreManager` and call it from the restart entry point before the scene is reloaded:

```gdscript
# score-manager.gd
func reset() -> void:
    total_score = 0
    kill_count = 0
    wave_multiplier = 1
    combo_count = 0
    _player = null
    _combo_timer.stop()
    # Re-connect to new player after scene reloads
    call_deferred("_find_player")
    score_changed.emit(total_score, 0)
    multiplier_changed.emit(wave_multiplier)
    combo_updated.emit(0)
```

Call this from `DeathScreen` before triggering the reload:

```gdscript
func _on_restart_pressed() -> void:
    ScoreManager.reset()
    get_tree().paused = false          # MUST unpause before reload (see C-2)
    get_tree().reload_current_scene()
```

**Warning signs:**
- Second run starts with non-zero score
- Wave multiplier HUD shows x2 or higher on wave 1
- Score popups show incorrect combo multipliers immediately after spawn

**Phase to address:** Game Restart phase (UI-05)

---

### Pitfall C-2: Scene Tree Stays Paused After Restart

**What goes wrong:**
`_on_player_died()` in `world.gd` calls `get_tree().paused = true` before showing the death screen. If restart is triggered without first setting `get_tree().paused = false`, `reload_current_scene()` is called on a paused tree. In Godot 4, the paused state persists across scene reloads — the new scene loads but all nodes with default `process_mode = INHERIT` are immediately paused. The game appears to start (scene loads, background visible) but nothing moves or responds to input.

**Why it happens:**
This is documented Godot behavior. `reload_current_scene()` replaces the scene node but does not reset `SceneTree.paused`. The only unpause is an explicit `get_tree().paused = false`. `CanvasLayer` nodes (`DeathScreen`, `ScoreHud`, `WaveHud`) use `process_mode = ALWAYS` by convention, which is why the death screen is visible and interactive even while paused — but new scene nodes default to `INHERIT`, which means paused.

**How to avoid:**
Always unpause before reloading:

```gdscript
get_tree().paused = false
get_tree().call_deferred("reload_current_scene")  # deferred avoids mid-frame teardown errors
```

The `call_deferred` wrapping is also important: calling `reload_current_scene()` directly while processing an `InputEvent` that originated in a node that is about to be freed can produce "attempt to call function on a freed instance" errors in the output.

**Warning signs:**
- New game loads (stars visible, ship visible) but ship does not respond to input
- `_process` and `_physics_process` callbacks never fire
- No errors in the output — the game silently does nothing

**Phase to address:** Game Restart phase (UI-05)

---

### Pitfall C-3: WaveManager Internal State Not Reset After Scene Reload

**What goes wrong:**
`WaveManager` is a scene node (not an autoload), so `reload_current_scene()` recreates it from the `.tscn` file. Its `_current_wave_index`, `_enemies_alive`, and `_wave_total` are reset correctly on reload. However, `world.gd` assigns the `waves` array at runtime in `_ready()`, not through `@export` serialized into the `.tscn`. If any restart path skips `world._ready()` re-running fully (e.g., partial scene reload, manual node recreation, or calling `restart()` in-place without reloading), `WaveManager` will have an empty `waves` array and `trigger_wave()` will push_warning and do nothing.

**Why it happens:**
The 20-wave configuration lives entirely in `world.gd._ready()`. If `world.gd` re-runs, it gets re-assigned. If it does not re-run (e.g., only part of the scene is rebuilt), `WaveManager.waves` stays empty. This is a hidden coupling between `world.gd._ready()` and `WaveManager`.

**How to avoid:**
Use `reload_current_scene()` for restart, not partial node recreation. The full reload guarantees `world.gd._ready()` re-runs and re-assigns all 20 waves. Avoid any "soft restart" approach that only resets individual nodes rather than reloading the scene.

Additionally, add a guard to `WaveManager.trigger_wave()` (already present) and validate in `world.gd._ready()` that waves were assigned:

```gdscript
assert($WaveManager.waves.size() == 20, "WaveManager: expected 20 waves, got %d" % $WaveManager.waves.size())
```

**Warning signs:**
- Wave 1 does not start; no enemies spawn
- `[WaveManager] No waves configured` appears in output
- `_wave_clear_pending` is set but Enter does nothing

**Phase to address:** Game Restart phase (UI-05)

---

### Pitfall C-4: Audio Files Not Found at Runtime in Exported Build (DirAccess + PCK)

**What goes wrong:**
The music system is designed to scan `res://music/` at runtime with `DirAccess` to auto-discover all tracks. In the Godot editor this works. In an exported `.pck`-based build, `DirAccess.get_files_at("res://music/")` returns only `.import` files (e.g., `Gravimetric Dawn.mp3.import`) instead of the actual audio files. The scanner finds zero loadable tracks, and the game runs silently.

**Why it happens:**
Godot's export pipeline converts audio files to an internal format and packs the result. The original `.mp3` or `.ogg` files are not included in the exported `.pck` unless explicitly added to the export filter. `DirAccess` listing returns `.import` manifest files instead. This is a long-standing documented Godot behavior (issue #25672, confirmed in 4.x).

**How to avoid:**
Two safe approaches:

1. **Preload-based catalog** (recommended for this project): Maintain a `const` array of preloaded tracks in the music manager script. Auto-scan only in the editor; in exports, use the static list. This is zero-risk and matches the existing codebase pattern (all scenes are preloaded in `world.gd`).

2. **`.remap` workaround**: When scanning, filter for files ending in `.remap`, strip the suffix, and call `ResourceLoader.load()` on the base path. This works at runtime in exports. Requires Godot 4.2+.

Do not use `ResourceLoader.load("res://music/trackname.mp3")` with hardcoded names — the `.import` redirects work via the resource remapper only when Godot knows the path ahead of time (i.e., the path was known at import time).

**Warning signs:**
- Music plays in editor, silent in exported build
- `DirAccess.get_files_at()` returns zero items or only `.import` entries
- No error messages (silent failure)

**Phase to address:** Dynamic Music phase (MUS-02)

---

### Pitfall C-5: AtlasTexture Region Off-By-One Causes Wrong Sprite on Enemy

**What goes wrong:**
When slicing `ships_assests.png` with `AtlasTexture` programmatically, the `region` Rect2 is calculated from assumed grid dimensions. If the sprite sheet has any padding, irregular spacing, or the grid math is one pixel off, the wrong ship sprite is displayed — often a neighbor sprite is partially visible at the edge.

**Why it happens:**
`AtlasTexture.region = Rect2(x, y, width, height)` is pixel-exact. There is a documented Godot 4 bug (issue #108690) where `AtlasTexture` created in code renders an incorrect region — specifically one column over — when assigned to a `Sprite2D.texture`. The bug was reported in Godot 4.x and may or may not be fixed in 4.6.2. Even without the bug, sprite sheet layouts often include 1–2 pixel gutters between sprites that break naive `col * width` arithmetic.

**How to avoid:**
- Inspect `ships_assests.png` pixel dimensions before writing any slicing code. Measure the actual grid cell size, not assumed size.
- Define region constants explicitly per enemy type rather than computing from a grid index, until the sprite sheet layout is confirmed:

```gdscript
const BEELINER_REGION := Rect2(0, 0, 64, 64)
const SNIPER_REGION   := Rect2(64, 0, 64, 64)
# etc.
```

- Test all 5 enemy sprites in the editor before writing the fallback path.
- If the off-by-one Godot bug is present in 4.6.2, the workaround is to add 1 pixel margin to the `x` coordinate of the Rect2.

**Warning signs:**
- Enemy shows a sliver of the wrong sprite on one side
- All enemies show the same sprite
- Sprite is blank or transparent

**Phase to address:** Enemy Sprites phase (SPR-02)

---

## Moderate Pitfalls

---

### Pitfall M-1: `_player` Reference in ScoreManager Points to Freed Node After Restart

**What goes wrong:**
`ScoreManager._find_player()` is called with `call_deferred` in `_ready()`, which runs only once at engine start. After a restart via `reload_current_scene()`, the scene's `PlayerShip` node is freed and a new one is created, but `ScoreManager._player` still holds the old (freed) reference. The health signal connection is to a freed node. If `ScoreManager` tries to read `_player.health` or check `is_instance_valid(_player)` fails silently without the explicit check.

**Why it happens:**
`_ready()` on an autoload does not re-run on scene reload. The deferred `_find_player()` was designed for initial load only.

**How to avoid:**
The `reset()` method (from C-1) must set `_player = null` and re-call `_find_player()` deferred. The `_find_player()` implementation already uses `get_tree().get_first_node_in_group("player")`, which is safe and will find the new `PlayerShip` after the new scene has loaded. The key is that `_find_player()` is called *after* the new scene is fully in the tree — hence `call_deferred` is correct.

Also guard all `_player` accesses with `is_instance_valid(_player)`:

```gdscript
func _on_player_health_changed(old_health: int, new_health: int) -> void:
    if not is_instance_valid(_player):
        return
    # ... rest of handler
```

**Warning signs:**
- "Attempt to call function on a freed instance" in output on second run
- Wave multiplier not resetting on damage in second run

**Phase to address:** Game Restart phase (UI-05)

---

### Pitfall M-2: Cross-Fade Leaves Previous Track Audible (Tween Not Stopped)

**What goes wrong:**
A cross-fade implementation using two `AudioStreamPlayer` nodes and a `Tween` fades track A out while fading track B in. If a new transition is triggered before the current tween completes (e.g., wave 2 starts while the ambient→combat fade is midway), the previous tween continues running and fights the new tween. This produces a three-way volume battle: old track still fading out, new target track fading in from the first fade, second target track starting a new fade — result is volume spiking and multiple tracks audible simultaneously.

**Why it happens:**
`create_tween()` creates a new tween every call. Without killing the previous one, old tweens keep running. GDScript `Tween` objects are not automatically stopped when their target node changes volume via a different tween.

**How to avoid:**
Keep a reference to the active tween and kill it before starting a new one:

```gdscript
var _fade_tween: Tween = null

func _crossfade_to(new_stream: AudioStream) -> void:
    if _fade_tween and _fade_tween.is_running():
        _fade_tween.kill()
    _fade_tween = create_tween()
    _fade_tween.set_parallel(true)
    _fade_tween.tween_property(_player_a, "volume_db", -40.0, FADE_DURATION)
    _fade_tween.tween_property(_player_b, "volume_db", 0.0, FADE_DURATION)
```

**Warning signs:**
- Multiple music tracks audible simultaneously
- Volume spikes during rapid wave transitions
- Music cuts out abruptly mid-fade

**Phase to address:** Dynamic Music phase (MUS-05)

---

### Pitfall M-3: AudioStreamInteractive Beat-Based Fade Incompatible With WAV Files

**What goes wrong:**
`AudioStreamInteractive` (the built-in Godot 4.3+ adaptive music container) expresses cross-fade duration in musical beats, not seconds. WAV files do not carry BPM metadata. Assigning a WAV-based track to an `AudioStreamInteractive` clip results in the cross-fade length being undefined or zero, causing an audible pop on transition instead of a smooth fade.

**Why it happens:**
`AudioStreamInteractive` cross-fade config requires BPM to convert beats to seconds. Only OGG Vorbis and MP3 imports can carry BPM in Godot 4. WAV imports cannot. The project already has one MP3 (`Gravimetric Dawn.mp3`) — if additional tracks are added as WAV, this breaks.

**How to avoid:**
Use only MP3 or OGG Vorbis for music tracks (not WAV). WAV is appropriate for short sound effects (combo.wav) but not looping music. If `AudioStreamInteractive` is used, set BPM on all tracks at import time. Alternatively, skip `AudioStreamInteractive` entirely and implement cross-fading manually with two `AudioStreamPlayer` nodes and a tween (simpler, more controllable, not beat-locked).

**Warning signs:**
- Audible click or pop on music transition
- Transition happens instantly with no fade despite fade settings

**Phase to address:** Dynamic Music phase (MUS-05)

---

### Pitfall M-4: Polygon2D `_draw()` Override in `EnemyShip` Must Be Disabled When Sprites Are Active

**What goes wrong:**
`enemy-ship.gd` has a `_draw()` override that draws red arcs, a yellow arrow, and large cyan/white debug labels. This runs every frame for every enemy. When Polygon2D shapes are replaced by sprites, `_draw()` continues rendering the debug overlay on top of the sprite. The enemy displays both the new sprite AND the old debug arc/arrow/labels simultaneously.

**Why it happens:**
`_draw()` is a virtual method inherited by all concrete enemy types through the `EnemyShip` base class. Adding a `Sprite2D` child node does not automatically disable `_draw()`.

**How to avoid:**
Add a flag to `EnemyShip` that disables the debug draw when a sprite is present:

```gdscript
var _use_sprite: bool = false

func _draw() -> void:
    if _use_sprite:
        return
    # ... existing debug draw code
```

Set `_use_sprite = true` in any concrete enemy's `_ready()` if the sprite was successfully loaded. This also enables the fallback (SPR-03): if the sprite is unavailable, `_use_sprite` stays false and debug draw shows normally.

**Warning signs:**
- Debug arcs and labels visible on top of sprite graphics
- `queue_redraw()` called from `_physics_process` causes constant redraws even with sprites active (wasted GPU time)

**Phase to address:** Enemy Sprites phase (SPR-01, SPR-03)

---

### Pitfall M-5: PointLight2D Per-Enemy Gem Glow Drops FPS at High Wave Counts

**What goes wrong:**
Wave 20 spawns 54 enemies simultaneously. Adding one `PointLight2D` per enemy means up to 54 dynamic 2D lights active at once. The project uses `gl_compatibility` renderer (mobile fallback). `PointLight2D` has documented severe performance problems in `gl_compatibility`, with even a single `PointLight2D` reducing FPS from 60 to 42 on mobile targets (issue #81152). Even on desktop with `gl_compatibility`, 54 simultaneous 2D lights will cause measurable FPS drop.

**Why it happens:**
Each `PointLight2D` requires a separate rendering pass in `gl_compatibility`. 54 lights = 54 extra passes per frame. The existing propeller `PointLight2D` on the player ship is one light; multiplying by 54 enemies is a qualitatively different load.

**How to avoid:**
- Set a hard cap on visible gem lights: only activate `PointLight2D` for enemies within a distance threshold from the player camera (e.g., within 3000 units). Disable it with `visible = false` for out-of-range enemies.
- Use `CanvasModulate` tinting or `Sprite2D.modulate` color pulsing as a visual-only alternative to `PointLight2D` — no rendering overhead.
- If `PointLight2D` is kept, reduce `shadow_enabled = false` and reduce `texture_scale` to minimum viable.
- Profile before committing to per-enemy lights in late waves.

**Warning signs:**
- FPS drops from ~100 to below 30 when many enemies are on screen
- Frame time spikes correlate with enemy count, not bullet count

**Phase to address:** Enemy Sprites phase (SPR-04)

---

### Pitfall M-6: Sprite Scale Calculated Against Wrong Reference Dimensions

**What goes wrong:**
`SPR-05` requires enemy sprites to scale to match the player ship size. If the scale calculation uses the ship's scene root `global_scale` or a hardcoded pixel size without accounting for the physics body's actual collision radius, sprites look wrong — either too large (overlapping other enemies during swarms) or too small (invisible at game zoom level).

**Why it happens:**
The player ship's visual size and its physics collision shape are not the same dimension. `ships_assests.png` sprite cells may be a different pixel size than the `Polygon2D` shapes (which were tuned for hitbox feel, not visual size). Blindly scaling sprite pixels to match polygon vertices produces incorrect results.

**How to avoid:**
Use the `HitBox/HitBoxShape` radius (currently drawn in green in debug) as the canonical size reference, not the visual polygon bounds. Scale the sprite so its meaningful visual boundary aligns with the hitbox radius. A comment in the code should document the reference measurement:

```gdscript
# Player hitbox radius = 30px (HitBoxShape CircleShape2D)
# Sprite cell = 64x64px
# scale = (30.0 * 2) / 64.0 = ~0.94
```

**Warning signs:**
- Enemies visually larger or smaller than expected relative to the player
- Sprites clip through asteroids visually (mismatch between visual and physics boundary)

**Phase to address:** Enemy Sprites phase (SPR-05)

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcode music track list instead of scanning | Zero DirAccess/PCK risk | Must update code when adding tracks | Acceptable for v3.5; document the list location clearly |
| In-place state reset (manually zero all vars) instead of reload_current_scene | Faster restart, no flicker | Each new state variable must be manually added to reset; easy to miss | Never — full reload is safer and simpler |
| Single AudioStreamPlayer with stream reassignment instead of dual-player crossfade | Fewer nodes | No cross-fade; track cuts abruptly | Only acceptable if cross-fade (MUS-05) is explicitly out of scope |
| Disable `_draw()` entirely in EnemyShip when sprites land | Simple | Loses fallback debug visualization | Never — use the `_use_sprite` flag pattern instead |
| One PointLight2D per enemy, always on | Simple implementation | FPS cliff at wave 20 | Never without distance culling in place first |

---

## Integration Gotchas

Common mistakes when connecting these features to the existing single-scene architecture.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| ScoreManager reset on restart | Call `reset()` after `reload_current_scene()` fires | Call `reset()` BEFORE reload, then `call_deferred("reload_current_scene")` — after reload, `_ready()` does not re-run so late resets are lost |
| WaveManager signal reconnect | Assume `world.gd._ready()` reconnects ScoreManager signals automatically | It does — but only if full reload is used. Partial restart paths break the reconnect chain |
| MusicManager as autoload | Autoload persists across restart, music continues from wrong position | Implement `MusicManager.reset()` alongside `ScoreManager.reset()` to restart tracks from the beginning |
| DeathScreen visibility on restart | `DeathScreen.visible = false` before reload to prevent flash of leaderboard | Set `visible = false` before `get_tree().paused = false` to avoid one-frame flash |
| Sprite fallback and `_draw()` | Test sprite path with both missing and present asset | Delete sprite asset temporarily to verify fallback activates — do not trust code path untested |
| `_combo_timer` in ScoreManager after restart | Timer is a child node, not recreated on reload, so it retains any pending timeout | ScoreManager.reset() must call `_combo_timer.stop()` before resetting `combo_count` |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| PointLight2D per enemy in gl_compatibility | FPS drops proportionally to enemy count, especially waves 15–20 | Distance culling; or use modulate pulsing instead | Above ~10 simultaneous 2D dynamic lights |
| `queue_redraw()` called every `_physics_process` in EnemyShip | Constant GPU redraws for every enemy every physics tick | Suppress `queue_redraw()` when `_use_sprite = true` | Scales with enemy count; worse in late waves |
| Two AudioStreamPlayers both playing with high-quality MP3 | Mild: two decode threads active during cross-fade | Use OGG Vorbis for loop-friendly music (better looping support, smaller memory footprint) | Not a real cliff — manageable |
| DirAccess scanning in `_ready()` blocking main thread | Brief hitch when world loads | Pre-catalog tracks; only scan in editor debug builds | Even with 1–2 tracks, async is safer |

---

## "Looks Done But Isn't" Checklist

- [ ] **Game Restart:** `get_tree().paused` is explicitly set to `false` before `reload_current_scene()` — verify by pausing the game and restarting; if nodes don't move, this was missed
- [ ] **Game Restart:** ScoreManager `total_score`, `kill_count`, `wave_multiplier`, `combo_count` are all zero on the second run's first kill — check the score HUD
- [ ] **Game Restart:** `_combo_timer` is not running at the start of run 2 — add a temporary `print(ScoreManager._combo_timer.is_stopped())` to verify
- [ ] **Dynamic Music:** Music plays in an exported build, not just in the editor — export to a local folder and verify audio is audible
- [ ] **Dynamic Music:** Cross-fade does not leave both tracks audible at full volume after rapid wave transitions — trigger wave 1 then immediately trigger wave 2 manually
- [ ] **Enemy Sprites:** All 5 enemy types show the correct distinct sprite — visually verify Beeliner, Sniper, Flanker, Swarmer, Suicider each show a different ship
- [ ] **Enemy Sprites:** Fallback activates correctly — rename `ships_assests.png` temporarily and confirm Polygon2D debug shapes reappear instead of a crash
- [ ] **Enemy Sprites:** Debug `_draw()` overlay (red arcs, yellow arrow) is NOT visible when sprites are active — check in-game with camera zoomed in
- [ ] **Gem glow:** FPS remains above 60 during wave 16 (12 Swarmers + 6 Suiciders + 4 Snipers = 22 enemies simultaneously) — profile with Godot's built-in FPS counter

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Autoload state leaks into run 2 | LOW | Add `reset()` to ScoreManager; ensure it's called in restart handler |
| Scene tree stays paused after restart | LOW | Insert `get_tree().paused = false` before reload call; one-line fix |
| Music silent in export | MEDIUM | Switch from DirAccess scan to preload-based catalog; test in exported build |
| Wrong sprite shown due to AtlasTexture off-by-one | LOW | Hardcode per-enemy region Rect2 constants measured from the actual image |
| FPS cliff from PointLight2D on all enemies | MEDIUM | Implement distance culling; or replace with modulate pulsing (no lights) |
| `_draw()` debug overlay on top of sprites | LOW | Add `_use_sprite` flag to EnemyShip._draw(); set it in sprite-equipped enemies |

---

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| C-1: ScoreManager state not reset | Game Restart (UI-05) | Score is 0 on run 2 kill 1; wave multiplier is x1 |
| C-2: Scene tree stays paused | Game Restart (UI-05) | Ship responds to input immediately after restart |
| C-3: WaveManager waves array empty | Game Restart (UI-05) | Wave 1 spawns enemies within 2 seconds of restart |
| C-4: Audio not found in export | Dynamic Music (MUS-02) | Test in exported build before marking complete |
| C-5: AtlasTexture region wrong | Enemy Sprites (SPR-02) | All 5 distinct sprites visible in-game, no wrong-ship display |
| M-1: ScoreManager._player freed ref | Game Restart (UI-05) | No freed-instance errors in output on run 2 |
| M-2: Cross-fade tween fight | Dynamic Music (MUS-05) | Rapid wave changes produce single clean transition |
| M-3: WAV incompatible with beat-based fades | Dynamic Music (MUS-03, MUS-05) | Music files are MP3 or OGG only |
| M-4: Debug `_draw()` visible over sprites | Enemy Sprites (SPR-01) | No red arcs or debug labels when sprites active |
| M-5: PointLight2D FPS cliff | Enemy Sprites (SPR-04) | FPS above 60 during wave 16 |
| M-6: Wrong sprite scale | Enemy Sprites (SPR-05) | Enemy visual size roughly matches player ship on screen |

---

## Sources

- Godot 4 official — Singletons (Autoload): https://docs.godotengine.org/en/4.6/tutorials/scripting/singletons_autoload.html
- Godot forum — Autoloads not reloading on reload_current_scene: https://forum.godotengine.org/t/how-to-make-singletons-autoloads-reload-upon-get-tree-reload-current-scene/65629
- Godot issue #13087 — Paused state persists across scene reset: https://github.com/godotengine/godot/issues/13087
- Godot issue #25672 — DirAccess returns only .import files in exported projects: https://github.com/godotengine/godot/issues/25672
- Godot issue #108690 — AtlasTexture renders incorrect region when created in code: https://github.com/godotengine/godot/issues/108690
- Godot issue #81152 — Single PointLight2D causes extreme lag on Android (gl_compatibility): https://github.com/godotengine/godot/issues/81152
- Godot issue #94538 — AudioStreamInteractive pop and mistiming in seamless transitions: https://github.com/godotengine/godot/issues/94538
- Godot forum — Loading WAV/MP3/OGG at runtime from res:// directory: https://forum.godotengine.org/t/guide-how-to-load-wav-mp3-or-ogg-files-on-runtime-from-res-directory/104121
- Godot docs — AudioStreamInteractive: https://docs.godotengine.org/en/stable/classes/class_audiostreaminteractive.html
- Godot issue #57268 — Reloading a scene won't reset exported custom resource properties: https://github.com/godotengine/godot/issues/57268
- Codebase inspection: `components/score-manager.gd`, `components/wave-manager.gd`, `components/enemy-ship.gd`, `prefabs/ui/death-screen.gd`, `world.gd`, `project.godot`

---
*Pitfalls research for: Graviton v3.5 — dynamic music, enemy sprites, game restart*
*Researched: 2026-04-16*
