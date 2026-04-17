# Phase 16: Dynamic Music - Research

**Researched:** 2026-04-17
**Domain:** Godot 4 audio system — AudioStreamPlayer, Tween, autoload pattern
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Wave thresholds: Waves 1–5 → Ambient; Waves 6–10 → Combat; Waves 11+ → High-Intensity.
- **D-02:** Category check fires on `wave_started(wave_number)` signal from WaveManager.
- **D-03:** Cross-fade duration is 2 seconds.
- **D-04:** Mechanism: dual `AudioStreamPlayer` nodes + `Tween`. Outgoing fades out while incoming fades in simultaneously.
- **D-05:** Shuffle (no-repeat) within a category pool. Never replay the track that just played.
- **D-06:** If a category has no tracks, fall back to any available track from another category. Music never silences.
- **D-07:** Catalog is a preload dictionary. Structure: `{ "ambient": [preload(...)], "combat": [...], "high_intensity": [...] }`.
- **D-08:** MusicManager follows ScoreManager autoload pattern: `extends Node`, registered in `project.godot [autoload]`, no scene file.
- **D-09:** MusicManager must expose a `reset()` method that restores Ambient category and restarts playback from Wave 1 state.

### Claude's Discretion

- Initial volume levels for the two AudioStreamPlayers.
- How to handle the edge case where a category change fires while a cross-fade is already in progress (interrupt or queue).
- Exact preload catalog GDScript syntax (preload() calls for all four track files).
- Whether to emit a signal from MusicManager when category changes.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MUS-01 | Background music begins playing automatically when the game starts | `_ready()` starts playback on player_a immediately after catalog is built |
| MUS-02 | MusicManager loads tracks via preload catalog (export-safe; no DirAccess scan) | Hardcoded `preload()` calls in a Dictionary — fully export-safe |
| MUS-03 | Tracks are categorized as Ambient, Combat, or High-Intensity | `_catalog` Dictionary with three keys; category selection by wave number |
| MUS-04 | Active music category updates based on current wave number | `_on_wave_started()` compares wave_number against threshold constants |
| MUS-05 | Music transitions between categories with a cross-fade (dual AudioStreamPlayer + Tween) | `create_tween()` with `set_parallel(true)` tweens volume_db on both players simultaneously |
</phase_requirements>

---

## Summary

Phase 16 builds a single GDScript autoload (`MusicManager`) that manages two `AudioStreamPlayer` nodes in a ping-pong pattern. One player fades out while the other fades in whenever the active music category changes. No external libraries are involved — everything is Godot 4 built-in.

The architecture is simple: the ScoreManager autoload in `components/score-manager.gd` is the exact blueprint. MusicManager copies its structure: `extends Node`, adds child nodes in `_ready()`, wires to WaveManager via the same `call_deferred` + `connect_to_wave_manager(wm)` pattern already present in `world.gd`.

The single most important non-obvious fact: **three of the four MP3 files are newly added (April 17 2026) and do NOT yet have `.import` files**. Godot's `preload()` will silently fail at runtime (stream will be null) if the editor has not imported the files. Wave 0 of the plan must ensure all four files are opened in the Godot editor and imported before any GDScript references them.

**Primary recommendation:** Clone ScoreManager's autoload skeleton exactly — child creation in `_ready()`, `call_deferred` for wiring, `connect_to_wave_manager` entry point in world.gd. Then add the cross-fade logic on top.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Music playback | Autoload (MusicManager) | — | Autoload survives scene restart; world nodes do not |
| Cross-fade volume animation | Autoload (MusicManager, Tween) | — | Tween is owned by the node that creates it; MusicManager owns both players |
| Wave threshold detection | Autoload (MusicManager) | — | MusicManager subscribes to WaveManager.wave_started signal |
| WaveManager signal source | World scene (WaveManager node) | — | WaveManager is a scene node; MusicManager connects via world.gd wiring call |
| Autoload registration | project.godot [autoload] | — | Single line addition matching ScoreManager pattern |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Godot `AudioStreamPlayer` | 4.6 (project) | Non-positional music playback | Built-in; no positional attenuation needed for background music |
| Godot `Tween` (via `create_tween()`) | 4.6 | Volume interpolation for cross-fade | Built-in; proven in Phase 15 gem glow; no extra dependency |
| GDScript autoload | 4.6 | Singleton node that persists across scene lifecycle | Exact pattern of ScoreManager already in project |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Godot `AudioStreamMP3` | 4.6 | Stream type imported from .mp3 files | Automatically used when file is imported; set `loop=true` in import |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `AudioStreamPlayer` (non-positional) | `AudioStreamPlayer2D` | 2D player requires world position; background music has no position — non-positional is correct |
| `create_tween()` | Manual `_process` interpolation | Tween is built-in, fire-and-forget, cleaner; `_process` polling adds per-frame overhead and is harder to interrupt |

**Installation:** No installation — Godot built-ins only.

---

## Architecture Patterns

### System Architecture Diagram

```
wave_started signal (WaveManager)
        |
        v
MusicManager._on_wave_started(wave_number)
        |
        v
  _get_category(wave_number)
  [1-5 → ambient | 6-10 → combat | 11+ → high_intensity]
        |
   same category?
      /     \
    yes      no
     |        |
  (no-op)  _crossfade(new_category)
              |
    _pick_track(new_category)  [shuffle no-repeat]
              |
        create_tween()
         set_parallel(true)
        /              \
 tween player_a        tween player_b
 volume_db → -80        volume_db → 0
 (outgoing fade out)    (incoming fade in)
              |
       swap A/B roles after fade
```

### Recommended Project Structure

```
components/
└── music-manager.gd     # New autoload — extends Node
music/
├── Gravity-Drum Choir.mp3          # Ambient — needs import
├── Sulfur Orbit.mp3                 # Ambient — needs import
├── Static Lullaby.mp3              # Combat + High-Intensity — needs import
├── Gravimetric Dawn.mp3            # Combat + High-Intensity — imported
└── Gravimetric Dawn.mp3.import     # Existing import file
project.godot                        # Add MusicManager to [autoload]
world.gd                             # Add MusicManager.connect_to_wave_manager($WaveManager)
```

### Pattern 1: Autoload Structure (Clone of ScoreManager)

**What:** `extends Node` with child nodes created in `_ready()`, deferred wiring via `call_deferred`.
**When to use:** Any singleton that must persist across scene lifetime and wire to scene nodes.

```gdscript
# Source: components/score-manager.gd (verified in codebase)
extends Node

var _player_a: AudioStreamPlayer = null
var _player_b: AudioStreamPlayer = null

func _ready() -> void:
    _player_a = AudioStreamPlayer.new()
    _player_a.volume_db = 0.0
    add_child(_player_a)

    _player_b = AudioStreamPlayer.new()
    _player_b.volume_db = -80.0
    add_child(_player_b)

    call_deferred("_start_playback")
```

### Pattern 2: Cross-Fade via Tween

**What:** `create_tween()` with `set_parallel(true)` fades two players simultaneously.
**When to use:** Whenever a smooth volume transition between two audio sources is needed.

```gdscript
# Source: Godot 4.6 docs — tween_property, set_parallel [CITED: docs.godotengine.org/en/4.6]
func _crossfade(incoming_stream: AudioStream) -> void:
    if _active_tween:
        _active_tween.kill()   # interrupt any in-progress fade

    _player_b.stream = incoming_stream
    _player_b.volume_db = -80.0
    _player_b.play()

    _active_tween = create_tween()
    _active_tween.set_parallel(true)
    _active_tween.tween_property(_player_a, "volume_db", -80.0, CROSSFADE_DURATION)
    _active_tween.tween_property(_player_b, "volume_db", 0.0, CROSSFADE_DURATION)
    _active_tween.chain().tween_callback(_swap_players)


func _swap_players() -> void:
    _player_a.stop()
    var tmp := _player_a
    _player_a = _player_b
    _player_b = tmp
```

### Pattern 3: Shuffle No-Repeat Track Selection

**What:** Pick randomly from a pool, excluding the last-played track to prevent back-to-back repeats.
**When to use:** Any audio system with per-category pools.

```gdscript
# Source: project pattern [ASSUMED] — standard shuffle-exclusion idiom
var _last_track: AudioStream = null

func _pick_track(category: String) -> AudioStream:
    var pool: Array = _catalog.get(category, [])
    if pool.is_empty():
        pool = _get_fallback_pool()   # D-06: never go silent
    if pool.is_empty():
        return null

    var candidates := pool.filter(func(t): return t != _last_track)
    if candidates.is_empty():
        candidates = pool   # only 1 track in pool — allow repeat
    var chosen: AudioStream = candidates.pick_random()
    _last_track = chosen
    return chosen
```

### Pattern 4: Preload Catalog (Export-Safe)

**What:** Hardcoded `preload()` calls in a Dictionary — zero DirAccess dependency.
**When to use:** Any audio or resource catalog that must survive export (MUS-02).

```gdscript
# Source: D-07 decision; preload() confirmed export-safe [CITED: Godot docs]
const _CATALOG: Dictionary = {
    "ambient": [
        preload("res://music/Gravity-Drum Choir.mp3"),
        preload("res://music/Sulfur Orbit.mp3"),
    ],
    "combat": [
        preload("res://music/Static Lullaby.mp3"),
        preload("res://music/Gravimetric Dawn.mp3"),
    ],
    "high_intensity": [
        preload("res://music/Static Lullaby.mp3"),
        preload("res://music/Gravimetric Dawn.mp3"),
    ],
}
```

**Critical:** `preload()` at script scope means Godot resolves these paths at load time. If any file is not yet imported by the editor, the engine will print a load error and the stream will be null. See Pitfall 1.

### Pattern 5: World.gd Wiring (Mirrors ScoreManager)

**What:** After scene is ready, `world.gd._ready()` calls `MusicManager.connect_to_wave_manager($WaveManager)`.
**When to use:** Every autoload that needs a signal from a scene node.

```gdscript
# Source: world.gd line 67 (verified in codebase) — ScoreManager pattern
if MusicManager:
    MusicManager.connect_to_wave_manager($WaveManager)
```

### Anti-Patterns to Avoid

- **DirAccess scan in `_ready()`:** Finds files in editor but returns empty array in exported builds. Requirements explicitly forbid this (MUS-02, REQUIREMENTS.md).
- **Single `AudioStreamPlayer` with stop/play:** Creates an audible silence gap between tracks instead of a cross-fade.
- **Inline Tween without storing reference:** If you do not store the Tween in a variable, you cannot call `.kill()` on it when a second category change arrives mid-fade. Causes volume corruption.
- **`AudioStreamPlayer2D` for background music:** Positional attenuation applies — the music volume would change as the player ship moves. Use non-positional `AudioStreamPlayer`.
- **`loop=false` on import:** MP3 tracks will stop playing mid-wave. Set `loop=true` in the .import file (or via editor Import tab) for all four tracks.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Property animation over time | Manual `_process` lerp | `create_tween().tween_property()` | Tween is fire-and-forget, interruptible via `.kill()`, handles delta internally |
| Non-positional audio playback | Custom audio node | `AudioStreamPlayer` (built-in) | Built-in handles bus routing, volume_db, play/stop, stream assignment |
| Shuffle-no-repeat | Complex shuffled array | `Array.filter() + pick_random()` | Two lines; GDScript Array methods handle this cleanly |

**Key insight:** The cross-fade pattern (two players + Tween) is Godot's documented standard for music transitions. Building anything custom (manual timers, `_process` polling) adds complexity with no benefit.

---

## Common Pitfalls

### Pitfall 1: Unimported MP3 Files Cause Silent Null Streams

**What goes wrong:** `preload("res://music/Gravity-Drum Choir.mp3")` returns null at runtime if the Godot editor has not yet generated the `.import` file for that asset. Only `Gravimetric Dawn.mp3` has an existing `.import` file as of 2026-04-17. The other three files (`Gravity-Drum Choir.mp3`, `Static Lullaby.mp3`, `Sulfur Orbit.mp3`) were added the same day and have no `.import` files yet.

**Why it happens:** Godot's resource system requires every asset to be processed by the editor before it can be loaded. Without an `.import` file, `preload()` errors silently in release builds.

**How to avoid:** Before writing any GDScript that references the three new files, open the Godot editor and let the import scan complete (or manually open each file in the FileSystem panel). Verify all four `.import` files exist in `music/` before committing.

**Warning signs:** `preload()` error in the Godot output: `"ERROR: Can't preload resource at path: res://music/..."`. Music plays null → `AudioStreamPlayer.play()` on a null stream is a no-op with a console error.

### Pitfall 2: loop=false Stops Music Mid-Wave

**What goes wrong:** The existing `Gravimetric Dawn.mp3.import` has `loop=false`. If all four tracks use this default, each track plays once and stops. The game will be silent after the first track ends.

**Why it happens:** Godot MP3 import defaults to `loop=false`. The `AudioStreamPlayer.finished` signal fires and no automatic restart occurs.

**How to avoid:** Set `loop=true` in each track's import settings via the editor Import tab (or by editing the `.import` file directly, setting `loop=true`). Do this for all four tracks in Wave 0.

**Warning signs:** Music stops after 3–7 minutes of play depending on track length.

### Pitfall 3: In-Progress Tween Not Killed on Rapid Category Change

**What goes wrong:** If `wave_started` fires while a cross-fade is still running (e.g., wave 5→6 triggers Combat, then wave 6 completes immediately and triggers another fade), the second `create_tween()` runs in parallel with the first. Both tweens modify `volume_db` simultaneously — one tries to fade in player_b while another tries to fade out the same node. The result is volume corruption: a player ends at neither 0 nor -80 dB.

**Why it happens:** `create_tween()` creates a new independent Tween. Old Tweens are not automatically stopped.

**How to avoid:** Store the active Tween in `_active_tween`. At the start of every `_crossfade()` call: `if _active_tween and _active_tween.is_running(): _active_tween.kill()`. Then `_swap_players()` must be called manually if killing mid-fade (to ensure roles are consistent).

**Warning signs:** Volume levels drift over multiple rapid category changes; players end up at intermediate dB values.

### Pitfall 4: Autoload Runs Before Scene Nodes Are Ready

**What goes wrong:** If `_ready()` in MusicManager tries to access `$WaveManager` or any world scene node directly, it will fail — autoloads initialize before the main scene tree is populated.

**Why it happens:** Godot initializes autoloads before running `_ready()` on any scene node.

**How to avoid:** Follow the ScoreManager pattern exactly: `call_deferred("_start_playback")` in `_ready()`. Wire to WaveManager only through `connect_to_wave_manager(wm)` called from `world.gd._ready()`.

**Warning signs:** `get_tree().get_first_node_in_group(...)` returns null at startup; node path references throw errors.

### Pitfall 5: `const` Dictionary Cannot Use `preload()` (Godot 4 Limitation)

**What goes wrong:** Declaring `const _CATALOG: Dictionary = { "ambient": [preload(...)] }` may not work in GDScript 4 because `preload()` is not a compile-time constant in all Godot versions.

**Why it happens:** `const` in GDScript requires expressions that are fully resolvable at compile time. `preload()` is a keyword that runs during resource loading, which is not strictly compile-time.

**How to avoid:** Use `var _catalog: Dictionary` instead of `const`. Assign it in `_ready()` or at class scope initialization. [ASSUMED — should be verified by attempting compilation. `preload()` at class scope variable initialization generally works in Godot 4 but behavior at `const` scope varies.]

**Warning signs:** GDScript parse error: "Identifier not found" or "Expected constant expression".

---

## Code Examples

Verified patterns from official and codebase sources:

### AudioStreamPlayer Volume Cross-Fade

```gdscript
# Source: Godot 4.6 Tween docs [CITED: docs.godotengine.org/en/4.6/classes/class_propertytweener.html]
var _active_tween: Tween = null

func _crossfade_to(stream: AudioStream) -> void:
    if _active_tween and _active_tween.is_running():
        _active_tween.kill()
        _finish_swap()  # ensure roles are clean before new fade

    _player_b.stream = stream
    _player_b.volume_db = -80.0
    _player_b.play()

    _active_tween = create_tween()
    _active_tween.set_parallel(true)
    _active_tween.tween_property(_player_a, "volume_db", -80.0, CROSSFADE_DURATION)
    _active_tween.tween_property(_player_b, "volume_db", 0.0, CROSSFADE_DURATION)
    _active_tween.chain().tween_callback(_finish_swap)


func _finish_swap() -> void:
    _player_a.stop()
    var tmp := _player_a
    _player_a = _player_b
    _player_b = tmp
    _active_tween = null
```

### Category Resolution from Wave Number

```gdscript
# Source: D-01 decision (CONTEXT.md) — implementation sketch
const COMBAT_WAVE: int = 6
const HIGH_INTENSITY_WAVE: int = 11

func _get_category(wave_number: int) -> String:
    if wave_number >= HIGH_INTENSITY_WAVE:
        return "high_intensity"
    elif wave_number >= COMBAT_WAVE:
        return "combat"
    return "ambient"
```

### Track Selection with No-Repeat Shuffle

```gdscript
# Source: Project pattern — GDScript Array.filter() + pick_random() [VERIFIED: codebase uses pick_random() in random-audio-player.gd]
var _last_track: AudioStream = null

func _pick_track(category: String) -> AudioStream:
    var pool: Array = _catalog.get(category, [])
    if pool.is_empty():
        for key in _catalog:
            if not _catalog[key].is_empty():
                pool = _catalog[key]
                break
    if pool.is_empty():
        return null
    var candidates: Array = pool.filter(func(t): return t != _last_track)
    if candidates.is_empty():
        candidates = pool
    var chosen: AudioStream = candidates.pick_random()
    _last_track = chosen
    return chosen
```

### reset() for Phase 17

```gdscript
# Source: D-09 decision (CONTEXT.md)
func reset() -> void:
    if _active_tween and _active_tween.is_running():
        _active_tween.kill()
        _active_tween = null
    _current_category = "ambient"
    _last_track = null
    _player_a.stop()
    _player_b.stop()
    _player_b.volume_db = -80.0
    _player_a.volume_db = 0.0
    var track := _pick_track("ambient")
    if track:
        _player_a.stream = track
        _player_a.play()
```

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Godot editor (local) | MP3 import processing | Must be confirmed | 4.6 (project.godot) | None — must open editor to generate .import files |
| `music/Gravity-Drum Choir.mp3` | Ambient catalog | Present (no .import) | — | Import required before use |
| `music/Sulfur Orbit.mp3` | Ambient catalog | Present (no .import) | — | Import required before use |
| `music/Static Lullaby.mp3` | Combat + High-Intensity | Present (no .import) | — | Import required before use |
| `music/Gravimetric Dawn.mp3` | Combat + High-Intensity | Present (.import exists) | — | Ready |

**Missing dependencies with no fallback:**
- Three MP3 files (`Gravity-Drum Choir.mp3`, `Sulfur Orbit.mp3`, `Static Lullaby.mp3`) need Godot editor import before `preload()` can reference them. Wave 0 of the plan must include: "Open Godot editor; let FileSystem scan complete; verify all 4 `.import` files exist in `music/`."

**Missing dependencies with fallback:**
- None beyond the above.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual `_process` lerp for volume fade | `create_tween().tween_property()` | Godot 4.0 | Fire-and-forget; no per-frame lerp code |
| `AnimationPlayer` for audio fade | `Tween` API | Godot 4.0 | No scene file needed; works in pure-script autoload |
| DirAccess scan for catalog | Hardcoded `preload()` catalog | Export requirement | Export-safe; compile-time path validation |

**Deprecated/outdated:**
- Godot 3 `$Tween.interpolate_property()`: replaced by `create_tween().tween_property()` in Godot 4. The old API does not exist in 4.x.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `var _catalog: Dictionary` with `preload()` at class scope initialization will work in Godot 4.6 (the `const` form may not) | Common Pitfalls (Pitfall 5), Code Examples | Low risk — `var` initialization with `preload()` is universally supported; `const` form is the uncertain path |
| A2 | `_active_tween.is_running()` is a valid method on Godot 4 Tween | Code Examples | Medium risk — if method name differs, use `_active_tween != null` as fallback guard |

**If this table is empty:** Not applicable — two assumed claims are logged above.

---

## Open Questions

1. **`const` vs `var` for preload catalog**
   - What we know: `var` with `preload()` at class scope works universally. `const` with `preload()` may or may not be supported as a compile-time constant.
   - What's unclear: Whether Godot 4.6 specifically allows `const Dictionary` with `preload()` values.
   - Recommendation: Use `var` to be safe. Cost is negligible.

2. **loop=false on three unimported tracks**
   - What we know: `Gravimetric Dawn.mp3.import` has `loop=false`. The three new tracks have no .import file.
   - What's unclear: What default loop setting will Godot apply when it auto-generates import files for the three new tracks.
   - Recommendation: Explicitly set `loop=true` in the editor Import tab for all four tracks as part of Wave 0. Do not rely on defaults.

---

## Sources

### Primary (HIGH confidence)
- `/websites/godotengine_en_4_6` (Context7) — AudioStreamPlayer, Tween, tween_property API
- `components/score-manager.gd` (codebase, verified) — autoload pattern, `call_deferred`, child node creation
- `components/wave-manager.gd` (codebase, verified) — `wave_started(wave_number)` signal signature
- `world.gd` (codebase, verified) — `connect_to_wave_manager` wiring pattern, `$WaveManager` node path
- `project.godot` (codebase, verified) — `[autoload]` section syntax, existing ScoreManager registration
- `music/Gravimetric Dawn.mp3.import` (codebase, verified) — import format, `loop=false` default

### Secondary (MEDIUM confidence)
- `components/random-audio-player.gd` (codebase, verified) — `AudioStreamPlayer2D` creation pattern; confirmed non-2D variant is correct choice for background music

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all built-ins confirmed in Godot 4.6 docs and project codebase
- Architecture: HIGH — ScoreManager is the exact template; all integration points verified in world.gd
- Pitfalls: HIGH (Pitfalls 1–4 verified from codebase inspection); MEDIUM (Pitfall 5 — const/preload behavior is [ASSUMED])

**Research date:** 2026-04-17
**Valid until:** 2026-07-17 (Godot 4 stable API; unlikely to change)
