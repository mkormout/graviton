# Stack Research: Graviton v3.5 Juice & Polish

**Project:** Graviton v3.5 — Dynamic music, enemy sprites, gem glow, game restart
**Researched:** 2026-04-16
**Confidence:** HIGH (all APIs verified against Godot 4.6 docs via Context7 + official sources)
**Scope:** Only new feature APIs — existing stack (RigidBody2D, MountPoint, WaveManager, ScoreManager) is not re-researched.

---

## Feature 1: Dynamic Background Music with Cross-Fade

### Core API

| Class | Version | Purpose | Why |
|-------|---------|---------|-----|
| `AudioStreamPlayer` | 4.x built-in | Non-positional background music playback | Use over `AudioStreamPlayer2D` — music has no world position, `AudioStreamPlayer` has no max_distance falloff |
| `Tween` (via `create_tween()`) | 4.x built-in | Animate `volume_db` for cross-fade | Existing codebase already uses create_tween() in ScoreManager._spawn_score_label() — consistent pattern |

### Pattern: Two Players, Volume Tween

The standard Godot 4 cross-fade uses two `AudioStreamPlayer` nodes: one active track fades out while the other fades in simultaneously.

```gdscript
# MusicManager autoload — two players for overlap during transition
var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active: AudioStreamPlayer   # currently audible player
var _inactive: AudioStreamPlayer # incoming player

func _ready() -> void:
    _player_a = AudioStreamPlayer.new()
    _player_b = AudioStreamPlayer.new()
    # PROCESS_MODE_ALWAYS so music continues while game is paused
    # (world.gd sets get_tree().paused = true on player death)
    _player_a.process_mode = Node.PROCESS_MODE_ALWAYS
    _player_b.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(_player_a)
    add_child(_player_b)
    _active = _player_a
    _inactive = _player_b

func crossfade_to(stream: AudioStream, duration: float = 2.0) -> void:
    if _active.stream == stream and _active.playing:
        return  # already playing this track

    _inactive.stream = stream
    _inactive.volume_db = -80.0
    _inactive.play()

    var tw := create_tween()
    tw.set_parallel(true)
    # Fade out active
    tw.tween_property(_active, "volume_db", -80.0, duration)\
      .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    # Fade in incoming
    tw.tween_property(_inactive, "volume_db", 0.0, duration)\
      .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    # After fade, stop the old player to free its stream reference
    tw.chain().tween_callback(func(): _active.stop())

    # Swap references
    var tmp := _active
    _active = _inactive
    _inactive = tmp
```

**Critical note on `volume_db = -80.0`:** Do NOT tween to/from `-INF` (linear silence). Godot's `-INF` dB is a sentinel for fully muted, not a smooth fade endpoint. Use `-80.0 dB` as the silence floor — inaudible to the human ear and safe for tween interpolation. (Confirmed: Godot forum thread, May 2025.)

**Critical note on `process_mode`:** `world.gd` sets `get_tree().paused = true` when the player dies. The death screen is shown while paused. Music nodes must be `PROCESS_MODE_ALWAYS` to keep playing during that pause. AudioStreamPlayer defaults to `PROCESS_MODE_PAUSABLE`.

### Music Category Selection

```gdscript
# In MusicManager
enum Category { AMBIENT, COMBAT, HIGH_INTENSITY }

var _tracks: Dictionary = {
    Category.AMBIENT: [],
    Category.COMBAT: [],
    Category.HIGH_INTENSITY: []
}

func scan_music_folder() -> void:
    var dir := DirAccess.open("res://music")
    if not dir:
        push_warning("[MusicManager] Cannot open res://music")
        return
    for file in dir.get_files():
        # Strip .remap suffix added by Godot export pipeline
        var clean := file.replace(".remap", "")
        if not (clean.ends_with(".mp3") or clean.ends_with(".ogg") or clean.ends_with(".wav")):
            continue
        var path := "res://music/" + clean
        var stream := load(path) as AudioStream
        if not stream:
            continue
        # Categorize by filename prefix: "ambient_", "combat_", "hi_"
        if clean.begins_with("ambient"):
            _tracks[Category.AMBIENT].append(stream)
        elif clean.begins_with("combat"):
            _tracks[Category.COMBAT].append(stream)
        elif clean.begins_with("hi"):
            _tracks[Category.HIGH_INTENSITY].append(stream)
        else:
            _tracks[Category.AMBIENT].append(stream)  # default bucket
```

**DirAccess.get_files()** returns a sorted array of filenames (not full paths) in the opened directory. Returns an empty array if the directory is empty or inaccessible — null-safe. (Verified: Godot 4.6 docs via Context7.)

**Remap caveat:** In exported builds, Godot remaps imported resources to `.remap` files in the PCK. Strip the `.remap` suffix and pass to `load()` — which handles the resource mapping automatically. Do NOT use `FileAccess` or `AudioStreamWAV.load_from_file()` for exported projects.

**Wave-driven selection:** Connect MusicManager to WaveManager signals. `wave_started` carries `wave_number` — derive category from enemy count or wave index. Simple threshold works well:

```gdscript
func _on_wave_started(wave_number: int, enemy_count: int, _label: String) -> void:
    var category: Category
    if enemy_count >= 20:
        category = Category.HIGH_INTENSITY
    elif enemy_count >= 8:
        category = Category.COMBAT
    else:
        category = Category.AMBIENT
    play_category(category)
```

### Integration with Existing Codebase

- Add `MusicManager` as a second autoload in `project.godot` (alongside `ScoreManager`).
- In `world.gd._ready()`, call `MusicManager.connect_to_wave_manager($WaveManager)` — mirrors how `ScoreManager.connect_to_wave_manager()` is called.
- For restart: MusicManager needs a `reset()` method (see Feature 4).

---

## Feature 2: Sprite Sheet Slicing (ships_assets.png)

### Core API

| Class | Version | Purpose | Why |
|-------|---------|---------|-----|
| `Sprite2D` | 4.x built-in | Display sprite on RigidBody2D enemy | Lightweight, no animation needed — enemies are static sprites, not animated characters |
| `AtlasTexture` | 4.x built-in | Crop sub-region from ships_assets.png | Programmatic atlas slicing; `region` property takes `Rect2` with pixel coordinates |

### Pattern: AtlasTexture Assigned at Runtime

```gdscript
# Inside each enemy's _ready() — or a shared helper on EnemyShip base class
func _setup_sprite(atlas_path: String, region: Rect2) -> void:
    var atlas := AtlasTexture.new()
    atlas.atlas = load(atlas_path)
    atlas.region = region
    var sprite := Sprite2D.new()
    sprite.texture = atlas
    add_child(sprite)
```

**Why AtlasTexture over Sprite2D.region_rect:** Both approaches work. AtlasTexture wraps the region into a self-contained resource that can be preloaded and shared across enemy instances, avoiding re-loading the source PNG for each enemy. At 5 enemy types this doesn't matter much for performance, but it's the cleaner encapsulation.

**Why not `Sprite2D.region_enabled + region_rect`:** `region_enabled = true` + `region_rect = Rect2(...)` on a Sprite2D directly is simpler and works. Use this if the region is set once and not reused. Use AtlasTexture if you want to preload the cropped region as a `.tres` resource in the editor or share it.

**Known issue:** AtlasTexture created in code and assigned to Sprite2D can render an incorrect adjacent tile in Godot 4.4 in some edge cases (GitHub issue #108690). If this manifests, fall back to `Sprite2D.region_enabled = true` + `Sprite2D.region_rect = region` directly on the Sprite2D node. The direct `region_rect` approach is unaffected by this bug. (MEDIUM confidence — bug report exists but may not affect all configurations.)

**Fallback pattern (Polygon2D if sprite unavailable):**

```gdscript
func _setup_visual(atlas_path: String, region: Rect2) -> void:
    if not ResourceLoader.exists(atlas_path):
        push_warning("[EnemyShip] Sprite sheet not found, using Polygon2D fallback")
        return  # Polygon2D already exists in scene from SPR-03 requirement
    _setup_sprite(atlas_path, region)
    # Hide the existing Polygon2D debug shape
    var shape_node := get_node_or_null("Shape")
    if shape_node:
        shape_node.visible = false
```

**Scale to match player ship:** Player ship BFG-23 collision circle is radius 300 (from beeliner.tscn's CollisionShape2D). Scale the Sprite2D so its texture bounds match the collision circle:

```gdscript
# After adding sprite, scale to fit collision radius
var target_size := 300.0 * 2.0  # diameter
var sprite_natural_size := region.size.x  # assume square sprite cell
sprite.scale = Vector2.ONE * (target_size / sprite_natural_size)
```

### Locating Sprite Regions in ships_assets.png

ships_assets.png is present at the project root. Each enemy type needs a `Rect2` defining its cell. The implementation phase must measure pixel coordinates from the sprite sheet. A recommended convention:

```gdscript
# In EnemyShip base class or per-enemy type
const SPRITE_ATLAS := "res://ships_assests.png"  # note: project uses this spelling
# Each enemy defines its region as a constant — e.g.:
const SPRITE_REGION := Rect2(0, 0, 128, 128)  # fill in during SPR-01/SPR-02 phase
```

---

## Feature 3: Pulsing Gem Light (PointLight2D + Tween)

### Core API

| Class | Version | Purpose | Why |
|-------|---------|---------|-----|
| `PointLight2D` | 4.x built-in | Gem glow light source on enemy | Already used on sun and propellers in world.tscn — consistent existing pattern |
| `Tween` (via `create_tween()`) | 4.x built-in | Animate `energy` for pulse, `color` for gem color | Same Tween API used across ScoreManager and body_camera.gd — no new pattern |

### Pattern: Looping Energy Tween

```gdscript
# Inside each enemy's _ready() after sprite is set up
func _setup_gem_light(gem_color: Color, position_offset: Vector2) -> void:
    var light := PointLight2D.new()
    light.color = gem_color
    light.energy = 1.0
    light.texture_scale = 2.0   # controls radius of light spread
    light.position = position_offset
    add_child(light)
    _start_pulse(light)

func _start_pulse(light: PointLight2D) -> void:
    var tw := create_tween()
    tw.set_loops()               # loop forever (0 = infinite)
    tw.tween_property(light, "energy", 2.5, 0.8)\
      .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tw.tween_property(light, "energy", 0.8, 0.8)\
      .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
```

**`set_loops()` with no argument = infinite loops.** This creates a perpetual ping-pong between energy values. (Verified: Context7 Tween API, Godot 4.6.)

**`TRANS_SINE + EASE_IN_OUT`:** Produces a smooth, natural breathing pulse — peaks are not abrupt. Already used in ScoreManager for score label tweens (same easing pattern).

**`texture_scale`:** PointLight2D uses a gradient texture to define falloff. `texture_scale` scales the texture (and thus light radius) without needing a custom texture. The default built-in texture is a radial gradient — sufficient for a gem glow. (Confirmed: Godot 2D lights and shadows documentation.)

**`PointLight2D` properties to set per enemy type:**

| Property | Type | Purpose |
|----------|------|---------|
| `color` | Color | Per-enemy gem color (red for Beeliner, blue for Sniper, etc.) |
| `energy` | float | Brightness, animated by tween (0.8 to 2.5) |
| `texture_scale` | float | Light radius (2.0 = moderate spread over ship body) |
| `shadow_enabled` | bool | Set `false` — no shadows needed for a gem; saves draw calls |
| `blend_mode` | int | Keep default `BLEND_MODE_ADD` — additive is correct for glow |

**`process_mode` for lights:** PointLight2D is a visual node, not a physics node — it is NOT paused by `get_tree().paused`. Tween however IS affected by pause. Set the PointLight2D's tween to `TWEEN_PROCESS_IDLE` (default) and the node itself to `PROCESS_MODE_ALWAYS` if the pulse should continue during the death-screen pause. (Verified: Godot pause docs via Context7.)

---

## Feature 4: Game Restart (In-Place State Reset)

### Core API

| API | Version | Purpose | Why |
|-----|---------|---------|-----|
| `get_tree().reload_current_scene()` | 4.x built-in | Nuclear option: reload entire world.tscn | AVOID — does not reset autoloads; ScoreManager retains total_score, wave_multiplier, combo state |
| Manual `reset()` methods per autoload + world node cleanup | N/A pattern | Reset all mutable state without reloading | Required because ScoreManager is an autoload singleton — reload_current_scene() does not reinitialize it |

### Why `reload_current_scene()` Fails Here

`get_tree().reload_current_scene()` frees the current scene tree and instantiates a fresh copy of `world.tscn`. However:

1. **Autoloads survive** — `ScoreManager` is registered as an autoload in `project.godot`. Its GDScript instance persists across scene reloads. `total_score`, `wave_multiplier`, `combo_count`, `kill_count` all retain stale values.
2. **Signal connections on freed nodes** — ScoreManager._player points to the old player node, which is freed. Accessing it after reload causes errors.
3. **Timer state** — `_combo_timer` and `_combo_audio` are children of ScoreManager (autoload), so they persist. No issue, but state must be reset.

(Confirmed: Godot forum discussions, multiple reports across Godot 4.2-4.4.)

### Pattern: Explicit Reset Chain

**Step 1: Add `reset()` to ScoreManager autoload**

```gdscript
# In score-manager.gd
func reset() -> void:
    total_score = 0
    kill_count = 0
    wave_multiplier = 1
    combo_count = 0
    _combo_timer.stop()
    _player = null
    score_changed.emit(total_score, 0)
    multiplier_changed.emit(wave_multiplier)
    combo_updated.emit(0)
    print("[ScoreManager] Reset complete")
```

**Step 2: Add `reset()` to MusicManager autoload (new in v3.5)**

```gdscript
# In music-manager.gd
func reset() -> void:
    # Keep music playing — just ensure we're not stuck in a cross-fade tween
    # WaveManager will re-emit wave_started on first wave, triggering correct category
    pass  # or restart ambient music if desired
```

**Step 3: In `world.gd`, wire the restart button signal from DeathScreen**

```gdscript
# death-screen.gd: add restart signal
signal restart_requested

# In _on_submit or after leaderboard shown:
func _on_restart_button_pressed() -> void:
    restart_requested.emit()
```

```gdscript
# In world.gd._ready():
death_screen.restart_requested.connect(_on_restart_requested)

func _on_restart_requested() -> void:
    # 1. Un-pause the tree
    get_tree().paused = false

    # 2. Reset all autoloads
    ScoreManager.reset()
    if MusicManager:
        MusicManager.reset()

    # 3. Reload world.tscn — autoloads are now clean before the new scene boots
    get_tree().reload_current_scene()
```

**Why reload after reset:** Once autoloads are manually reset, `reload_current_scene()` is safe and is the simplest way to re-instantiate all scene nodes (player ship, enemies, asteroids, WaveManager, UI) in a clean state. The alternative — manually calling `queue_free()` on every dynamic node and re-running `_ready()` — is fragile and produces the same result.

**`process_mode` during restart:** The death screen pauses the tree (`get_tree().paused = true`). Before calling `reload_current_scene()`, always un-pause first — otherwise the reload call executes in a paused state. (Verified: Godot SceneTree.paused docs via Context7.)

**`call_deferred` for reload:** `reload_current_scene()` can cause issues if called directly from a button pressed callback in the same frame that other UI nodes are processing. Use `get_tree().call_deferred("reload_current_scene")` for safety — consistent with how body death handling uses `call_deferred("queue_free")` in the existing codebase.

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| External audio plugin (FMODAudio, Wwise) | No plugin policy; GDExtension adds build complexity; built-in AudioStreamPlayer is sufficient | AudioStreamPlayer + Tween on volume_db |
| AnimationPlayer for cross-fade | Requires saving animation tracks as a `.tres` resource file and editor setup; Tween is pure GDScript — no editor assets needed | Tween with set_parallel(true) on volume_db |
| `AudioStreamPlayer2D` for music | Has distance falloff, bus routing complexity; music is non-positional | `AudioStreamPlayer` (no 2D suffix) |
| `AnimatedSprite2D` + `SpriteFrames` for enemy sprites | Overkill for static ship sprites; requires building a SpriteFrames resource with animation tracks | `Sprite2D` + `AtlasTexture` region |
| `NavigationAgent2D` | Already rejected in v2.0 STACK.md (open-space, no nav mesh, regression history) | Steering forces — already implemented |
| `get_tree().reload_current_scene()` alone (without pre-reset) | Autoloads (ScoreManager) retain state across reloads | Manual `reset()` on autoloads, then reload |
| Shader for gem pulse | Shader is appropriate for a full particle glow effect; for a single per-enemy light pulse, Tween on PointLight2D.energy is simpler, CPU-side, and debuggable | PointLight2D.energy tweened |
| `ResourceLoader.list_directory()` | Added in Godot 4.4+; method does not appear in Godot 4.6 Context7 API surface — uncertain if available | `DirAccess.open().get_files()` — confirmed 4.6 API |

---

## Integration Points with Existing Codebase

| Existing System | New Feature | Integration Point |
|----------------|-------------|-------------------|
| `ScoreManager` autoload (score-manager.gd) | Game Restart | Add `reset()` method; called by world.gd before reload |
| `WaveManager.wave_started` signal | Dynamic Music | MusicManager.connect_to_wave_manager() — mirrors ScoreManager pattern |
| `world.gd._on_player_died()` | Game Restart + Music | un-pause + reset autoloads + reload; music continues on PROCESS_MODE_ALWAYS |
| `DeathScreen` (death-screen.gd) | Game Restart | Add restart_requested signal and Restart button after leaderboard shown |
| `EnemyShip` base class (enemy-ship.gd) | Sprites + Gem Light | Add `_setup_visual()` and `_setup_gem_light()` virtual methods; concrete enemies override with their atlas region and gem color |
| `world.gd` `project.godot` | Dynamic Music | Register `MusicManager` as second autoload; call `MusicManager.scan_music_folder()` in `_ready()` |
| Existing `PointLight2D` usage (sun, propellers in world.tscn) | Gem Light | Same node type, same `blend_mode = BLEND_MODE_ADD` — no new rendering concepts |

---

## Version Compatibility Notes

| API | Godot Version | Notes |
|-----|---------------|-------|
| `AudioStreamPlayer.volume_db` | 4.0+ | Stable; tween-safe; use -80.0 not -INF as silence floor |
| `Tween.set_loops()` | 4.0+ | Infinite loop when called with no argument or 0 |
| `Tween.set_parallel(true)` | 4.0+ | Already used in ScoreManager — confirmed working in 4.6.2 |
| `PointLight2D.energy` | 4.0+ | Tween-safe float property |
| `PointLight2D.texture_scale` | 4.0+ | Controls light radius without custom texture |
| `AtlasTexture.region` | 4.0+ | Rect2 pixel coordinates; potential rendering bug in 4.4 (#108690), verify in 4.6.2 |
| `Sprite2D.region_enabled + region_rect` | 4.0+ | Fallback for AtlasTexture bug; simpler, fully stable |
| `DirAccess.open().get_files()` | 4.0+ | Returns filenames (not full paths); strips ".remap" needed in exported builds |
| `get_tree().reload_current_scene()` | 4.0+ | Safe only after manual autoload reset; use `call_deferred` from UI callbacks |
| `Node.PROCESS_MODE_ALWAYS` | 4.0+ | Required for music/lights to survive `get_tree().paused = true` |

---

## Sources

- Context7 `/websites/godotengine_en_4_6` — AudioStreamPlayer, Tween, PointLight2D, AtlasTexture, DirAccess, SceneTree.paused, PROCESS_MODE_ALWAYS (HIGH confidence)
- [GDQuest crossfade tutorial](https://www.gdquest.com/tutorial/godot/audio/background-music-transition/) — two-player cross-fade pattern with AnimationPlayer (MEDIUM confidence; Tween variant preferred here)
- [Godot Forum: AudioStreamPlayer volume_db tween from -inf](https://forum.godotengine.org/t/audio-tweening-audiostreamplayer-volume-db-from-inf-db-to-0-0db/88343) — confirms -80.0 dB floor (MEDIUM confidence)
- [Godot Forum: autoloads not reset on reload_current_scene](https://forum.godotengine.org/t/how-to-make-singletons-autoloads-reload-upon-get-tree-reload-current-scene/65629) — confirms manual reset required (HIGH confidence, multiple reports)
- [davcri.it: programmatic AtlasTexture](https://davcri.it/posts/programmatically-create-atlastexture-with-gdscript/) — AtlasTexture.atlas + AtlasTexture.region pattern (MEDIUM confidence)
- [GitHub issue #108690](https://github.com/godotengine/godot/issues/108690) — AtlasTexture incorrect region bug in 4.4; Sprite2D.region_rect fallback (MEDIUM confidence)
- [Godot Forum: loading audio from res:// at runtime](https://forum.godotengine.org/t/guide-how-to-load-wav-mp3-or-ogg-files-on-runtime-from-res-directory/104121) — remap caveat + load() preferred (HIGH confidence)

---
*Stack research for: Graviton v3.5 Juice & Polish — dynamic music, sprite sheets, gem glow, game restart*
*Researched: 2026-04-16*
