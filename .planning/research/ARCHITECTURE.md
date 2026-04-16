# Architecture Research

**Domain:** Godot 4.6.2 single-scene 2D space shooter — v3.5 feature integration
**Researched:** 2026-04-16
**Confidence:** HIGH — all conclusions drawn from direct inspection of production source files

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Autoload Singletons                          │
│  ┌─────────────────────┐    ┌───────────────────────────────────┐   │
│  │    ScoreManager      │    │         MusicManager (NEW)         │   │
│  │  (score-manager.gd)  │    │       (music-manager.gd)           │   │
│  └──────────┬──────────┘    └────────────────┬──────────────────┘   │
└─────────────┼───────────────────────────────┼─────────────────────┘
              │ signals                        │ controls playback
┌─────────────▼───────────────────────────────▼─────────────────────┐
│                          world.tscn (Node2D)                        │
│                                                                      │
│  ┌────────────┐  ┌──────────────┐  ┌──────────┐  ┌─────────────┐  │
│  │ ShipBFG23  │  │  WaveManager │  │ Camera2D │  │ ShipCamera  │  │
│  │(PlayerShip)│  │ (wave-mgr.gd)│  │(static)  │  │(BodyCamera) │  │
│  └────────────┘  └──────┬───────┘  └──────────┘  └─────────────┘  │
│                          │ spawns                                    │
│                   ┌──────▼──────────────────────┐                  │
│                   │   Enemy Instances at runtime  │                  │
│                   │  Beeliner / Sniper / Flanker  │                  │
│                   │  Swarmer / Suicider           │                  │
│                   └─────────────────────────────┘                  │
│                                                                      │
│  CanvasLayer overlays (added dynamically in _ready):                 │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│  │ WaveHud  │ │ScoreHud  │ │EnemyRadar│ │DeathScr. │ │CtrlsHint │ │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Status for v3.5 |
|-----------|----------------|-----------------|
| `world.gd` | Scene orchestration, input handling, wave config, spawn_parent propagation | MODIFIED — restart logic, music wiring |
| `ScoreManager` (autoload) | Kill scoring, combo chain, wave multiplier, leaderboard bridge | MODIFIED — reset() method |
| `MusicManager` (autoload, NEW) | Track loading, category routing, cross-fade, wave-driven intensity | NEW |
| `WaveManager` | Wave sequencing, enemy spawning, wave_completed / wave_cleared_waiting signals | MODIFIED — reset() method |
| `EnemyShip` (base class) | State machine, _draw(), physics loop | MODIFIED — sprite/light toggle helper |
| `[Type].tscn` (5 scenes) | Per-enemy visual + script composition | MODIFIED — add Sprite2D + GemLight |
| `DeathScreen` | Score submission, leaderboard display | MODIFIED — add restart signal and button |

## Recommended Project Structure Changes

```
graviton/
├── components/
│   ├── music-manager.gd        # NEW — autoload singleton
│   ├── enemy-ship.gd           # MODIFIED — _apply_sprite() helper, _get_sprite_region()
│   ├── score-manager.gd        # MODIFIED — reset() method
│   ├── wave-manager.gd         # MODIFIED — reset() method
│   └── ... (no other changes)
├── prefabs/
│   └── enemies/
│       ├── beeliner/
│       │   └── beeliner.tscn   # MODIFIED — add Sprite2D + GemLight (PointLight2D) nodes
│       ├── sniper/
│       │   └── sniper.tscn     # MODIFIED
│       ├── flanker/
│       │   └── flanker.tscn    # MODIFIED
│       ├── swarmer/
│       │   └── swarmer.tscn    # MODIFIED
│       └── suicider/
│           └── suicider.tscn   # MODIFIED
│   └── ui/
│       └── death-screen.gd     # MODIFIED — restart_requested signal + "Play Again" button
├── music/
│   ├── Gravimetric Dawn.mp3    # EXISTS — will be categorized as Ambient or Combat
│   └── [additional tracks]/   # Player-provided; MusicManager auto-scans at startup
├── ships_assests.png           # EXISTS — sprite source for all 5 enemy types
└── project.godot               # MODIFIED — register MusicManager under [autoload]
```

### Structure Rationale

- **music-manager.gd in components/**: Consistent with score-manager.gd placement — all autoloads live in components/.
- **Enemy scene modifications only**: No new enemy scenes are needed; Sprite2D and PointLight2D are added as child nodes to existing .tscn files in the editor.
- **ships_assests.png stays at project root**: Atlas stays where it already exists; no import configuration changes beyond region rect setup at runtime.

## Architectural Patterns

### Pattern 1: MusicManager as Autoload Singleton

**What:** MusicManager is registered as an autoload in project.godot (like ScoreManager). It owns two `AudioStreamPlayer` nodes internally — one for the currently playing track, one for the incoming track — and cross-fades between them using a `Tween`. It exposes a `set_intensity(level: MusicIntensity)` method that world.gd wires to WaveManager signals.

**When to use (autoload, not a world.tscn node):**
1. Music must survive game restart without restarting the app. An autoload persists across scene reloads; a world node gets destroyed.
2. Any node in the game can call `MusicManager.set_intensity()` without signal plumbing.
3. Consistent with the established ScoreManager pattern already in the project.

**Trade-offs:** Autoload state persists if you ever add scene transitions. For this single-scene game that is only a benefit.

**Signal wiring (in world.gd _ready):**
```gdscript
# world.gd _ready():
$WaveManager.wave_started.connect(MusicManager._on_wave_started)
$WaveManager.all_waves_complete.connect(MusicManager._on_all_waves_complete)
```

**Category mapping driven by wave index:**
```gdscript
enum MusicIntensity { AMBIENT, COMBAT, HIGH_INTENSITY }

func _on_wave_started(wave_number: int, _enemy_count: int, _label: String) -> void:
    if wave_number <= 3:
        set_intensity(MusicIntensity.AMBIENT)
    elif wave_number <= 12:
        set_intensity(MusicIntensity.COMBAT)
    else:
        set_intensity(MusicIntensity.HIGH_INTENSITY)
```

**Auto-scan pattern:**
```gdscript
func _scan_music_folder() -> void:
    var dir := DirAccess.open("res://music")
    if not dir:
        return
    dir.list_dir_begin()
    var file := dir.get_next()
    while file != "":
        if file.ends_with(".mp3") or file.ends_with(".ogg"):
            var stream := load("res://music/" + file) as AudioStream
            # Categorize by filename prefix: "ambient_", "combat_", "hi_"
            # Uncategorized tracks default to COMBAT
            _register_track(stream, file)
        file = dir.get_next()
```

**Cross-fade mechanics:** Two `AudioStreamPlayer` children (player_a, player_b). On track switch, tween player_a volume from 0dB to -80dB over 2 seconds while tween player_b from -80dB to 0dB. Swap references after fade. This pattern requires no external audio middleware.

### Pattern 2: Sprite Sheet Slicing via AtlasTexture in _ready()

**What:** Each enemy's `Sprite2D` node is configured at runtime (not in the editor) by a shared helper in `enemy-ship.gd` that creates an `AtlasTexture` pointing at `ships_assests.png` with the correct `region` Rect2 for that enemy type. The `Polygon2D` node is hidden (not removed) when sprite loads, so the fallback path is a one-line re-show.

**Visual mapping confirmed from ships_assests.png:**
```
ENM-07 (Beeliner)  — leftmost fighter, green gem
ENM-08 (Sniper)    — stealth cruiser, purple gem
ENM-09 (Flanker)   — industrial transport, orange gem
ENM-10 (Swarmer)   — scout craft, yellow/cream gem
ENM-11 (Suicider)  — defense node, red sphere
```

Region rects must be measured from the PNG in the editor. The sprite sheet has label text ("ENM-07" etc.) printed over the ships — crop regions must exclude that text band at the bottom of each sprite.

**Fallback behavior:**
```gdscript
# In enemy-ship.gd:
func _apply_sprite(sprite: Sprite2D, polygon: Polygon2D) -> void:
    var region := _get_sprite_region()   # returns Rect2 or Rect2() for "no sprite"
    if region == Rect2():
        polygon.visible = true
        sprite.visible = false
        return
    var atlas := AtlasTexture.new()
    atlas.atlas = preload("res://ships_assests.png")
    atlas.region = region
    sprite.texture = atlas
    sprite.visible = true
    polygon.visible = false

# Override in each concrete type, or use a dictionary keyed by class name:
func _get_sprite_region() -> Rect2:
    return Rect2()   # base returns empty = fallback; concrete types return real rects
```

**Trade-offs:** Region rects require manual measurement from the PNG and iterative adjustment. This is a one-time cost. The alternative of slicing the sheet into 5 separate PNGs is more files to maintain with no runtime benefit.

### Pattern 3: Gem Glow via PointLight2D Child Node

**What:** Each enemy `.tscn` gets a `PointLight2D` child named `GemLight`. Its `color` is set to the gem's color per type. A looping pulse tween runs in `_ready()` that oscillates `energy` between 0.5 and 1.5 on a 1.5-second cycle.

**Key concern:** `PointLight2D` only illuminates nodes that have a normal map and are on the same CanvasLayer. For enemy ship sprites (Sprite2D with no normal map) the light will produce a simple additive glow overlay — this is acceptable as a "gem pulse" effect. Confirm `blend_mode` is set to `Mix` to prevent the black background from being overlit.

**Placement:** `GemLight` must be positioned at the gem's local offset within the sprite (varies per enemy type). This offset is set in the scene file after sprite region rects are confirmed.

**The Sprite2D must be visible before GemLight is enabled** — this is why sprite application (Pattern 2) runs in `EnemyShip._ready()` before the light tween starts.

```gdscript
# In enemy-ship.gd _ready(), after _apply_sprite():
var gem_light: PointLight2D = get_node_or_null("GemLight")
if gem_light:
    gem_light.color = _get_gem_color()   # per-type constant
    var tween := create_tween().set_loops()
    tween.tween_property(gem_light, "energy", 1.5, 0.75)
    tween.tween_property(gem_light, "energy", 0.5, 0.75)
```

### Pattern 4: Game Restart Without App Reload

**What:** The death screen emits a `restart_requested` signal. `world.gd` receives it and calls `restart_game()` — an imperative reset function that clears mutable state without `get_tree().reload_current_scene()`.

**Why not reload_current_scene:** That call destroys and recreates all autoloads' child nodes (Timer, AudioStreamPlayer). ScoreManager and MusicManager would lose state and connected signals. Manual reset is the correct approach for a single-scene game with stateful autoloads.

**Reset checklist — what must be reset and how:**

| Owner | What to Reset | Mechanism |
|-------|--------------|-----------|
| `world.gd` | `_wave_clear_pending` flag | Set to `false` |
| `world.gd` | Player ship | `queue_free()` old instance, re-instantiate from `ship_model`, re-run `setup_spawn_parent`, re-mount weapons, reconnect `died` signal |
| `world.gd` | All enemy nodes | `get_tree().get_nodes_in_group("enemy")` → `queue_free()` each |
| `WaveManager` | `_current_wave_index`, `_enemies_alive`, `_wave_total` | Add public `reset()` method |
| `ScoreManager` | `total_score`, `kill_count`, `wave_multiplier`, `combo_count` | Add public `reset()` method |
| `ScoreManager` | `_player` reference | Call `_find_player()` deferred after ship re-added |
| `MusicManager` | Music intensity | Call `set_intensity(MusicIntensity.AMBIENT)` |
| `DeathScreen` | Hide self | `visible = false` at start of `restart_game()` |
| Physics | Pause state | `get_tree().paused = false` must be first action |

**Ordering matters:**
```gdscript
func restart_game() -> void:
    get_tree().paused = false              # 1. Unpause (required before queue_free works)
    death_screen.visible = false           # 2. Hide overlay
    _clear_world()                         # 3. queue_free enemies + bullets
    $WaveManager.reset()                   # 4. Reset wave state
    ScoreManager.reset()                   # 5. Reset score state
    MusicManager.set_intensity(            # 6. Reset music
        MusicManager.MusicIntensity.AMBIENT)
    _respawn_player()                      # 7. Re-add ship + weapons
    # 8. WaveManager._find_player() runs deferred (already in _ready pattern)
    # 9. ScoreManager._find_player() runs deferred (already in _ready pattern)
    spawn_asteroids(10)                    # 10. Optional: refresh asteroid field
```

**Death screen modification:** Add a "Play Again" `Button` to the `LeaderboardSection` layout (visible after score submission). Emit `restart_requested` from `death-screen.gd`. Connect in `world.gd _ready()` alongside the existing `$ShipBFG23.died` connection.

## Data Flow

### Music Intensity Transitions

```
WaveManager.wave_started(wave_number, enemy_count, label)
    ↓ (connected in world.gd _ready)
MusicManager._on_wave_started(wave_number)
    ↓
MusicManager.set_intensity(AMBIENT | COMBAT | HIGH_INTENSITY)
    ↓
_select_random_track_from_category()
    ↓
_cross_fade(new_track)
    ↓ (Tween, 2 seconds)
player_a.volume_db tweens to -80   (current track fades out)
player_b.volume_db tweens to 0     (new track fades in)
swap player_a / player_b references
```

### Enemy Sprite Application

```
enemy.tscn instantiated (Beeliner / Sniper / Flanker / Swarmer / Suicider)
    ↓
ConcreteType._ready() calls super() → EnemyShip._ready()
    ↓
_apply_sprite($Sprite2D, $Shape)
    ↓ success path (region != Rect2())
AtlasTexture.region set
Sprite2D.visible = true
Polygon2D.visible = false
_start_gem_pulse($GemLight)
    ↓ fallback path (region == Rect2())
Polygon2D.visible = true (default, no change)
Sprite2D.visible = false
```

### Restart Data Flow

```
Player ship dies → Body.die() → died.emit()
    ↓
world.gd._on_player_died()
    get_tree().paused = true
    death_screen.show_death_screen(ScoreManager.total_score)

[Player submits name, views leaderboard, clicks "Play Again"]

DeathScreen.restart_requested.emit()
    ↓
world.gd.restart_game()
    ↓
[Full reset sequence per Pattern 4 checklist]
    ↓
Game resumes at Wave 1, score 0, Ambient music
```

### Wave-to-Music Intensity Mapping

```
Wave 1–3  (Suiciders, Beelines, Flankers)    → AMBIENT
Wave 4–12 (Mixed combat escalation)          → COMBAT
Wave 13+  (Full assaults, final wave)        → HIGH_INTENSITY
all_waves_complete signal                    → AMBIENT (victory)
player died (via world.gd._on_player_died)   → MusicManager.stop() or AMBIENT fade
```

## Integration Points

### New vs. Modified Components

| Component | Status | Touch Points |
|-----------|--------|--------------|
| `components/music-manager.gd` | NEW | Registered in project.godot; connected to WaveManager in world.gd |
| `project.godot` | MODIFIED | Add `MusicManager="*res://components/music-manager.gd"` to [autoload] section |
| `world.gd` | MODIFIED | Connect MusicManager to WaveManager signals; add `restart_game()`; connect `death_screen.restart_requested` |
| `components/score-manager.gd` | MODIFIED | Add public `reset()` method; clear all state vars |
| `components/wave-manager.gd` | MODIFIED | Add public `reset()` method; reset `_current_wave_index`, `_enemies_alive`, `_wave_total` |
| `components/enemy-ship.gd` | MODIFIED | Add `_apply_sprite()` helper and `_get_sprite_region()` / `_get_gem_color()` virtual methods |
| `prefabs/enemies/beeliner/beeliner.tscn` | MODIFIED | Add Sprite2D node + GemLight (PointLight2D) as children |
| `prefabs/enemies/sniper/sniper.tscn` | MODIFIED | Add Sprite2D node + GemLight (PointLight2D) as children |
| `prefabs/enemies/flanker/flanker.tscn` | MODIFIED | Add Sprite2D node + GemLight (PointLight2D) as children |
| `prefabs/enemies/swarmer/swarmer.tscn` | MODIFIED | Add Sprite2D node + GemLight (PointLight2D) as children |
| `prefabs/enemies/suicider/suicider.tscn` | MODIFIED | Add Sprite2D node + GemLight (PointLight2D) as children |
| `prefabs/ui/death-screen.gd` | MODIFIED | Add `restart_requested` signal; add "Play Again" Button to leaderboard section |

### Node References in world.gd After Restart

After `restart_game()`, these member vars and node paths need handling:

| Reference | How to Handle |
|-----------|--------------|
| `death_screen` | Keep same instance — just hide it, no re-instantiation needed |
| `_wave_hud` | Keep same instance — already connected to WaveManager signals which persist |
| `_controls_hint` | Keep same instance — stateless, no action needed |
| `$ShipBFG23` (node path) | Re-instantiate: queue_free old node, add new from ship_model, run setup_spawn_parent, mount weapons, reconnect died signal |
| `$WaveManager` | Keep node — call `reset()`, player lookup re-runs via deferred `_find_player()` |
| `ScoreManager._player` | Re-runs `_find_player()` deferred after new ship added to tree |

### Signal Wiring Summary

```gdscript
# In world.gd _ready() — additions for v3.5:
$WaveManager.wave_started.connect(MusicManager._on_wave_started)           # NEW
$WaveManager.all_waves_complete.connect(MusicManager._on_all_waves_complete)  # NEW
death_screen.restart_requested.connect(restart_game)                        # NEW

# In music-manager.gd _ready():
# No external connections — world.gd pushes intensity via set_intensity()
# Internal: two AudioStreamPlayer children, Tween for cross-fade
```

## Recommended Build Order for Phases

Based on feature dependencies, the correct build order is:

**Phase 1: Enemy Sprites (SPR-01 to SPR-05)**

Build this first because:
- No dependencies on other new v3.5 features.
- Establishes which child nodes exist in enemy .tscn files (Sprite2D, GemLight).
- SPR-04 (gem glow) depends on SPR-01 (sprite visible) — both are in this phase.
- Region rect measurement is a one-time manual step; get it done early so it doesn't block other work.
- Fallback path (SPR-03) must be verified before any further work on enemy scenes.

**Phase 2: Music System (MUS-01 to MUS-05)**

Build second because:
- Independent of sprite work — no shared nodes.
- Requires WaveManager signals (already exist and are stable).
- Requires a new autoload registration (project.godot change).
- Cross-fade complexity justifies its own focused phase.
- MusicManager.reset() must exist before the restart phase can call it.

**Phase 3: Game Restart (UI-05)**

Build last because:
- Requires ScoreManager.reset() — must be written in Phase 2 prep or Phase 3.
- Requires WaveManager.reset() — same.
- Requires MusicManager.set_intensity() to exist (Phase 2).
- DeathScreen needs a new button/signal that should be tested against the complete feature set.
- All other v3.5 features must be working so restart is validated against the full game state.

## Anti-Patterns

### Anti-Pattern 1: Placing MusicManager as a Node in world.tscn

**What people do:** Add an AudioStreamPlayer or music controller node directly to the world scene.

**Why it's wrong:** When `restart_game()` clears the world or if scene reloading is ever added, any scene-owned music node loses state or gets queue_freed. The autoload pattern is already established by ScoreManager.

**Do this instead:** Register `music-manager.gd` as an autoload in project.godot. It owns its AudioStreamPlayer children directly, persists for the entire app lifetime, and can be called from anywhere.

### Anti-Pattern 2: Removing Polygon2D Nodes from Enemy Scenes

**What people do:** Delete the Polygon2D node when adding Sprite2D, assuming it "won't be needed."

**Why it's wrong:** SPR-03 explicitly requires fallback to Polygon2D when the sprite is unavailable. The `_draw()` method in `enemy-ship.gd` also draws debug arcs, state labels, and direction arrows — these are separate from the Polygon2D shape node and remain active in both sprite and fallback paths.

**Do this instead:** Keep the Polygon2D. Control visibility: `polygon.visible = false` when sprite loads successfully, `polygon.visible = true` in the fallback path.

### Anti-Pattern 3: Using reload_current_scene() for Restart

**What people do:** Call `get_tree().reload_current_scene()` as the restart mechanism because it is simple.

**Why it's wrong:** Autoloads (ScoreManager, MusicManager) will have their child Timers and AudioStreamPlayers recreated by their own `_ready()`, but signals connected to world.gd nodes become dangling. The ScoreManager `_player` reference will be stale. Cross-fade Tweens in MusicManager will be orphaned.

**Do this instead:** Implement `restart_game()` in world.gd as an imperative reset per the Pattern 4 checklist. Explicit resets are debuggable; reload is opaque.

### Anti-Pattern 4: Storing AtlasTexture Region Rects in .tscn Files

**What people do:** Pre-configure AtlasTexture on each Sprite2D node in the Godot editor and save it into the .tscn file.

**Why it's wrong:** The region rects in ships_assests.png need iterative tuning during development (label text overlaps ship art). Storing them in 5 separate .tscn files means 5 files to update per adjustment.

**Do this instead:** Hardcode region rects as constants in enemy-ship.gd and apply at runtime in `_apply_sprite()`. One file to update when regions need adjustment.

### Anti-Pattern 5: Forgetting to Unpause Before queue_free in Restart

**What people do:** Call `queue_free()` on enemies while `get_tree().paused = true`, then unpause after.

**Why it's wrong:** In Godot 4, paused nodes with `PROCESS_MODE_PAUSABLE` (the default) do not process deferred calls. `queue_free()` is deferred. Enemies will not actually be freed until after unpause, causing a frame flash of dead enemies in the revived world.

**Do this instead:** `get_tree().paused = false` is the very first line of `restart_game()`, before any queue_free calls.

## Sources

- Direct inspection of `world.gd` (397 lines, Godot 4.6.2)
- Direct inspection of `components/score-manager.gd`
- Direct inspection of `components/wave-manager.gd`
- Direct inspection of `components/enemy-ship.gd`
- Direct inspection of `components/beeliner.gd`, `components/sniper.gd`
- Direct inspection of `prefabs/enemies/beeliner/beeliner.tscn`
- Direct inspection of `prefabs/enemies/sniper/sniper.tscn` (partial)
- Direct inspection of `prefabs/ui/death-screen.gd`
- Direct inspection of `project.godot` — confirmed autoload section structure
- Direct inspection of `ships_assests.png` — confirmed 5 sprite positions and gem colors
- `.planning/PROJECT.md` — active requirements UI-05, MUS-01 to MUS-05, SPR-01 to SPR-05

---
*Architecture research for: Graviton v3.5 — MusicManager, enemy sprites, game restart integration*
*Researched: 2026-04-16*
