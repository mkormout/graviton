---
phase: 16-dynamic-music
reviewed: 2026-04-17T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - components/music-manager.gd
  - project.godot
  - world.gd
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 16: Code Review Report

**Reviewed:** 2026-04-17
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Phase 16 adds a `MusicManager` autoload with dual-`AudioStreamPlayer` cross-fade, a preloaded track catalog, and wave-driven category selection. The implementation is structurally sound and the signal wiring in `world.gd` follows the established `ScoreManager` pattern correctly. No critical issues were found. Three warnings cover logic correctness and one edge-case crash risk; three info items cover dead asset reference, duplicate catalog data, and debug prints.

## Warnings

### WR-01: `_finish_swap` called on interrupted tween leaves `_player_b` in undefined volume state

**File:** `components/music-manager.gd:97-99`

When a new cross-fade request arrives while one is already running, the code kills the active tween and immediately calls `_finish_swap()`. At that moment the tween has been killed mid-animation, so `_player_a.volume_db` and `_player_b.volume_db` are whatever intermediate values they happened to reach. `_finish_swap()` only stops `_player_a` and swaps references — it does not reset volumes. After the swap, the new `_player_b` (the old `_player_a`) will start the next cross-fade from a random mid-value rather than from `-80.0`, producing an audible pop or incorrect fade.

**Fix:** Reset volumes explicitly before starting the new fade:

```gdscript
func _crossfade_to(stream: AudioStream) -> void:
    if _active_tween and _active_tween.is_running():
        _active_tween.kill()
        _finish_swap()
    # Ensure clean start state regardless of where the tween was killed
    _player_a.volume_db = music_volume_db
    _player_b.volume_db = -80.0

    _player_b.stream = stream
    _player_b.volume_db = -80.0
    _player_b.play()
    # ... rest unchanged
```

---

### WR-02: `reset()` does not guard against null players if called before `_ready()`

**File:** `components/music-manager.gd:121-135`

`reset()` calls `_player_a.stop()` and `_player_b.stop()` directly. `_player_a` and `_player_b` are initialised in `_ready()`. As an autoload, `_ready()` runs at scene startup, but `reset()` is described as a "Phase 17 game restart" entry point. If `reset()` is ever invoked before `_ready()` has completed (e.g. in a test or an edge case during scene reload) this will crash with a null-object call.

**Fix:** Add null guards:

```gdscript
func reset() -> void:
    if not _player_a or not _player_b:
        return
    # ... existing body
```

---

### WR-03: Category transitions only on category change, not on track completion — track can loop forever mid-session

**File:** `components/music-manager.gd:60-67`

`_on_wave_started` only triggers a cross-fade when the category changes. If the player stays within the same category across many waves, the same track plays indefinitely because there is no `finished` signal handler on `_player_a` to advance to the next track in the pool. This is a gameplay quality issue that may read as a bug when the same 2-minute loop repeats for 10+ minutes.

**Fix:** Connect `_player_a`'s `finished` signal in `_ready()` to a handler that picks and plays the next track in the current category:

```gdscript
func _ready() -> void:
    # ... existing player setup ...
    _player_a.finished.connect(_on_track_finished)

func _on_track_finished() -> void:
    var track := _pick_track(_current_category)
    if track:
        _player_a.stream = track
        _player_a.play()
```

Note: after a cross-fade swap `_player_a` is actually the old `_player_b`, so the signal would need to be re-connected on swap or connected to both players. An alternative is to check in `_process` or use a single dedicated handler that fires on either player finishing.

---

## Info

### IN-01: `"Graviton Lullaby.mp3"` exists on disk but is not referenced in `_catalog`

**File:** `components/music-manager.gd:11-24`

The music directory contains `Graviton Lullaby.mp3` (confirmed by file listing) but it is not included in any catalog category. This may be intentional (reserved for a future phase), but if it was meant to be in `"ambient"` it is silently excluded.

**Fix:** Either add it to the `"ambient"` pool or add a comment confirming it is reserved:

```gdscript
# "Graviton Lullaby.mp3" — reserved for Phase 17 credits / game-over screen
```

---

### IN-02: `"combat"` and `"high_intensity"` catalog entries contain identical tracks

**File:** `components/music-manager.gd:17-24`

Both `"combat"` and `"high_intensity"` contain exactly the same two tracks (`Static Lullaby.mp3`, `Gravimetric Dawn.mp3`). The category threshold (`high_intensity_wave: 11`) will never produce a distinct listening experience from wave 11 onward. This is likely a placeholder pending final track assignment, but worth flagging so it is not overlooked.

**Fix:** Assign distinct tracks to `"high_intensity"` when available, or collapse the two categories into one until they diverge.

---

### IN-03: `print()` statements left in production path

**File:** `components/music-manager.gd:51, 57, 67, 135`

Four `print()` calls remain in normal execution paths (startup, every wave-start, every reset). Per project conventions, debug prints are typically commented out rather than removed. These will emit noise to the Godot output on every wave transition for the life of the game.

**Fix:** Comment them out following the project convention of leaving them as lightweight debug markers:

```gdscript
#print("[MusicManager] Started playback: ambient")
```

---

_Reviewed: 2026-04-17_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
