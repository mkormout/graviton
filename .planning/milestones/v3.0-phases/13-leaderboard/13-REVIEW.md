---
phase: 13-leaderboard
reviewed: 2026-04-15T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - prefabs/ui/death-screen.gd
  - prefabs/ui/death-screen.tscn
  - world.gd
findings:
  critical: 0
  warning: 4
  info: 3
  total: 7
status: issues_found
---

# Phase 13: Code Review Report

**Reviewed:** 2026-04-15
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Reviewed the leaderboard death-screen implementation (`prefabs/ui/death-screen.gd`, `prefabs/ui/death-screen.tscn`) and the world wiring (`world.gd`). The feature is functionally sound: save/load via `ConfigFile`, `MAX_ENTRIES` trimming, gold highlight for the current run, and unranked 11th-row fallback all work correctly.

Four warnings were found, none of which will crash the game but each represents a real logic or correctness risk. The most notable is a silent tie-breaking ambiguity that can highlight the wrong row when duplicate name+score entries exist in the leaderboard. Three info items flag minor code quality concerns.

---

## Warnings

### WR-01: `_on_submit` tie-breaking finds wrong row when duplicate name+score exists

**File:** `prefabs/ui/death-screen.gd:56-59`

**Issue:** The current-run detection searches for the first entry whose `name` and `score` both equal the just-submitted values. If a previous run had the same name and identical score, `_current_entry_index` will point to that older entry (which sorted earlier or at the same rank) rather than the freshly inserted one. The gold highlight will therefore mark the wrong row, or mark an old entry instead of the new one.

```gdscript
# Problem: first-match scan doesn't distinguish current run from prior identical entries
for i in range(entries.size()):
    if entries[i]["name"] == player_name and entries[i]["score"] == _current_score:
        _current_entry_index = i
        break
```

**Fix:** Insert the entry with a unique sentinel field so the scan is unambiguous, then strip it before saving:

```gdscript
func _on_submit(_text: String = "") -> void:
    # ...
    var new_entry := { "name": player_name, "score": _current_score, "_current": true }
    entries.append(new_entry)
    entries.sort_custom(func(a, b): return a["score"] > b["score"])
    entries = entries.slice(0, MAX_ENTRIES)

    _current_entry_index = -1
    for i in range(entries.size()):
        if entries[i].get("_current", false):
            _current_entry_index = i
            break

    # Strip sentinel before saving
    var save_entries := entries.map(func(e):
        var copy := e.duplicate()
        copy.erase("_current")
        return copy
    )
    _save_entries(save_entries, player_name)
    # ...
    _populate_table(entries)  # pass entries that still carry _current flag
```

---

### WR-02: Tree is paused when `death_screen.show_death_screen()` is called — `call_deferred("grab_focus")` may not fire

**File:** `world.gd:373` / `prefabs/ui/death-screen.gd:38`

**Issue:** `_on_player_died` calls `get_tree().paused = true` before calling `death_screen.show_death_screen(...)`. The `DeathScreen` node has `process_mode = 3` (Always) in the scene, so the node itself continues to process. However `call_deferred` posts a callback to the idle queue. With the tree paused, deferred calls on nodes that are *not* in Always mode may not execute in the same frame. While `DeathScreen` is in Always mode, the specific node `_name_input` is a child `LineEdit` whose `process_mode` is inherited (default = Inherit). If any ancestor between `DeathScreen` and `_name_input` has a non-Always process mode, `grab_focus` will silently do nothing.

**Fix:** Confirm that the `CanvasLayer` itself and all of its UI children inherit Always mode, or explicitly set `process_mode = Node.PROCESS_MODE_ALWAYS` on the `NameSection` and `VBox` nodes in the scene. Alternatively, replace `call_deferred` with a check that focus is grabbed after the frame boundary:

```gdscript
# In death-screen.gd show_death_screen():
_name_input.grab_focus.call_deferred()
# AND ensure NameSection / VBox nodes have process_mode = PROCESS_MODE_ALWAYS in .tscn
```

---

### WR-03: `_save_entries` overwrites the file unconditionally — previous entries are lost if `_load_entries` returned a truncated list

**File:** `prefabs/ui/death-screen.gd:89-94`

**Issue:** `_save_entries` creates a fresh `ConfigFile` every time. If in a future code path `_load_entries` is modified to return fewer than `MAX_ENTRIES` entries (e.g. for testing or error recovery), `_save_entries` will discard any entries beyond those that were loaded, silently shrinking the leaderboard. This is a latent data-loss risk that becomes active if the load/save pair is ever called in a context other than `_on_submit`.

Currently the risk is low because `_on_submit` always loads the full set before saving, but the function offers no protection against accidental misuse.

**Fix:** Document the invariant explicitly, or make `_save_entries` defensive:

```gdscript
# Add a guard comment or assertion:
func _save_entries(entries: Array, last_name: String) -> void:
    assert(entries.size() <= MAX_ENTRIES, "_save_entries received more entries than MAX_ENTRIES")
    var cfg := ConfigFile.new()
    for i in range(entries.size()):
        cfg.set_value("scores", "entry_%d" % i, entries[i])
    cfg.set_value("prefs", "last_name", last_name)
    var err := cfg.save(SAVE_PATH)
    if err != OK:
        push_error("[DeathScreen] Failed to save leaderboard: %d" % err)
```

---

### WR-04: `_save_entries` return value from `cfg.save()` is not checked

**File:** `prefabs/ui/death-screen.gd:94`

**Issue:** `cfg.save(SAVE_PATH)` returns an `Error` code. If the file system is read-only or the path is unavailable (common on some export targets), the save silently fails. The player sees the leaderboard displayed as if it was saved, but the next run starts with an empty leaderboard. This is particularly surprising on web or sandboxed mobile exports.

**Fix:** Check the return value and emit a warning:

```gdscript
var err := cfg.save(SAVE_PATH)
if err != OK:
    push_error("[DeathScreen] Failed to save leaderboard to %s (error %d)" % [SAVE_PATH, err])
```

---

## Info

### IN-01: `spawn_asteroids` uses float multiplication for loop ranges — silent truncation

**File:** `world.gd:329-336`

**Issue:** `range(count * 0.5)`, `range(count * 0.4)`, and `range(count * 0.1)` multiply an `int` by a `float`, producing a `float` passed to `range()`. GDScript silently truncates, but `count * 0.1` for `count = 10` yields `1.0` which rounds correctly; for `count = 3` it yields `0.3` which truncates to 0 — so no large asteroids spawn. The math works for powers-of-ten counts but is fragile.

**Fix:** Use integer arithmetic explicitly:

```gdscript
func spawn_asteroids(count: int):
    for _x in range(count / 2):
        add_asteroid(asteroids_small_model.pick_random())
    for _x in range(count * 2 / 5):
        add_asteroid(asteroids_medium_model.pick_random())
    for _x in range(count / 10):
        add_asteroid(asteroids_large_model.pick_random())
```

---

### IN-02: Unused loop variable `x` should be prefixed with `_`

**File:** `world.gd:329-336`

**Issue:** Loop variables `x` in `spawn_asteroids` are never used inside the loop body. Per project conventions, unused variables should be prefixed with `_`.

**Fix:**

```gdscript
for _x in range(count / 2):
```

---

### IN-03: `_on_submit` uses `_name_input.text.strip_edges()` redundantly in `_populate_table`

**File:** `prefabs/ui/death-screen.gd:120-122`

**Issue:** `_populate_table` re-reads `_name_input.text.strip_edges()` to reconstruct `name_text` for the unranked 11th row (lines 120-122), duplicating the same normalization logic already applied in `_on_submit` (line 48) and stored in `player_name`. The reconstructed value should be identical but it is not reusing the already-computed `player_name` variable, making the logic harder to trace and subtly inconsistent if `_name_input.text` were modified between the two calls.

**Fix:** Pass `player_name` to `_populate_table`, or store the normalized name in a class-level field alongside `_current_score`:

```gdscript
var _current_name: String = ""

# In _on_submit:
_current_name = player_name

# In _populate_table, replace lines 120-122:
_add_row("\u00BB\u2013", _current_name, str(_current_score), GOLD)
```

---

_Reviewed: 2026-04-15_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
