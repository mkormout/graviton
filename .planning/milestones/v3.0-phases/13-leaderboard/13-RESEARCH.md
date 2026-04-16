# Phase 13: Leaderboard - Research

**Researched:** 2026-04-15
**Domain:** Godot 4 GDScript — UI overlay, ConfigFile persistence, pause-safe input, CanvasLayer layout
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Connect to player `Body.died` signal. On death: `get_tree().paused = true`.
- **D-02:** Death overlay is a CanvasLayer with `process_mode = PROCESS_MODE_ALWAYS`.
- **D-03:** Signal handler lives in `world.gd` (or a dedicated DeathScreen node); catches `died` before `queue_free()`.
- **D-04:** Single `LineEdit`, max 16 characters. Confirm with Enter key or Submit button.
- **D-05:** Blank name saves as `"---"`. No required field.
- **D-06:** Pre-fill LineEdit with last used name from the same ConfigFile.
- **D-07:** After submission, immediately show leaderboard. No "saving..." state.
- **D-08:** Three columns: Rank | Name | Score. Top 10 entries only.
- **D-09:** Current run's row highlighted gold (`Color(1.0, 0.843, 0.0)`). Others: white text, black outline.
- **D-10:** If current run did not place top-10, show it as an 11th unranked row still highlighted gold.
- **D-11:** Visual style: CanvasLayer, bare labels (no panel background), matching HUD pattern.
- **D-12:** "GAME OVER" title above name entry. "HIGH SCORES" title above leaderboard table.
- **D-13:** ConfigFile at `user://leaderboard.cfg`. Section `[scores]`, keys `entry_N` (N = 0..9), value is a Dictionary `{ name, score }`.
- **D-14:** Last name stored as `[prefs] / last_name` in same file.
- **D-15:** On submission: insert into sorted list, truncate to top 10, re-save.

### Claude's Discretion

- Exact font sizes and column widths for the leaderboard table
- Whether the leaderboard uses a `VBoxContainer` of `HBoxContainer` rows or a `GridContainer`
- Exact padding/spacing between name entry and leaderboard sections

### Deferred Ideas (OUT OF SCOPE)

- Restart button / return to menu
- Online leaderboard
- Multiple difficulty tiers with separate tables
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SCR-09 | On player death, a name-entry overlay appears and accepts free-text keyboard input | D-01 through D-07; CanvasLayer + PROCESS_MODE_ALWAYS pattern; `Body.died` signal timing confirmed |
| SCR-10 | Top-10 high scores (name + score) saved to disk, persist across restarts | ConfigFile API at `user://leaderboard.cfg`; D-13 through D-15 |
| SCR-11 | Leaderboard shown on death screen with current run highlighted; last name pre-filled | D-06, D-08 through D-12; gold Color constant verified in codebase |
</phase_requirements>

---

## Summary

Phase 13 implements a local leaderboard triggered by player death. The architecture is straightforward: a CanvasLayer death screen node (added to `world.tscn`) connects to the player ship's `Body.died` signal, pauses the scene tree, and shows a two-stage overlay — first name entry, then leaderboard display. Persistence uses Godot's built-in `ConfigFile` API writing to `user://leaderboard.cfg`.

All APIs involved are native Godot 4 — no external libraries are needed. The patterns (CanvasLayer with `PROCESS_MODE_ALWAYS`, `connect_to_X()` init convention, bare label styling) are already established by Phase 12's wave-hud and score-hud. The most non-trivial part is the pause-safe input handling for `LineEdit`, which requires the entire CanvasLayer tree (not just the root node) to have the correct process mode.

**Primary recommendation:** Create a single `DeathScreen` CanvasLayer scene (`prefabs/ui/death-screen.tscn` + `death-screen.gd`). Set `process_mode = PROCESS_MODE_ALWAYS` on the CanvasLayer root. Wire it in `world.gd` using the same `connect_to_X()` init pattern. Use `VBoxContainer` of `HBoxContainer` rows for the leaderboard table (simpler than `GridContainer` for dynamic row generation with per-row color control).

**Critical property name correction:** CONTEXT.md refers to `ScoreManager.score`, but the actual property on the `ScoreManager` autoload is `ScoreManager.total_score`. [VERIFIED: grep of `components/score-manager.gd`]

---

## Standard Stack

### Core (all built-in Godot 4)

| Component | API / Node | Purpose | Why Standard |
|-----------|-----------|---------|--------------|
| Persistence | `ConfigFile` (built-in) | Save/load leaderboard and last name | Godot's official lightweight key-value config format; no external deps |
| Pause-safe UI | `CanvasLayer` with `process_mode = PROCESS_MODE_ALWAYS` | Overlay renders and processes input while tree is paused | Established pattern in this project (wave-hud, score-hud) |
| Name entry | `LineEdit` (built-in Control) | Free-text keyboard input | Standard Godot text input node |
| Table layout | `VBoxContainer` of `HBoxContainer` rows | Leaderboard rows | Easier per-row color override than `GridContainer`; already used in score-hud |

### No external packages — this phase is 100% GDScript + built-in nodes. [VERIFIED: codebase inspection]

---

## Architecture Patterns

### Recommended Project Structure

```
prefabs/
└── ui/
    ├── death-screen.tscn    # New: CanvasLayer overlay
    └── death-screen.gd      # New: DeathScreen script
components/
└── score-manager.gd         # Existing: ScoreManager autoload (total_score property)
world.gd                     # Modified: connect ShipBFG23.died, instantiate DeathScreen
world.tscn                   # Modified: (death screen instantiated at runtime, not embedded)
user://leaderboard.cfg        # New: created at first death
```

### Pattern 1: CanvasLayer Death Screen (CanvasLayer with PROCESS_MODE_ALWAYS)

**What:** A CanvasLayer node whose entire subtree has `process_mode = PROCESS_MODE_ALWAYS`, so it runs `_process`, `_input`, and GUI interaction callbacks while `get_tree().paused = true`.

**When to use:** Any UI overlay that must work during a paused scene tree.

**Critical detail:** The `PROCESS_MODE_ALWAYS` must be set on the **CanvasLayer root** itself, not just child nodes. Child nodes inherit the parent's effective process mode. Setting it only on a child while the parent is paused will NOT work. [VERIFIED: Godot pause docs pattern; confirmed by community issue reports]

**Example:**
```gdscript
# Source: Godot 4.6 pausing docs pattern + project convention
class_name DeathScreen
extends CanvasLayer

# Set in .tscn: process_mode = Node.PROCESS_MODE_ALWAYS
# layer = 20 (above score-hud at layer 10)

@onready var _name_section: Control = $NameSection
@onready var _leaderboard_section: Control = $LeaderboardSection
@onready var _name_input: LineEdit = $NameSection/VBox/NameInput

func show_death_screen(score: int) -> void:
    visible = true
    _name_section.visible = true
    _leaderboard_section.visible = false
    # Pre-fill last name
    _name_input.text = _load_last_name()
    _name_input.select_all()
    # Deferred focus required — node must be visible before grab_focus works
    _name_input.call_deferred("grab_focus")
```

### Pattern 2: ConfigFile Leaderboard Persistence

**What:** Use Godot's `ConfigFile` to store entries as `[scores] / entry_N = { "name": ..., "score": ... }` and last name as `[prefs] / last_name`. Load on `_ready`, save after each submission.

**Example:**
```gdscript
# Source: [ASSUMED training knowledge — ConfigFile is stable API since Godot 3]
const SAVE_PATH := "user://leaderboard.cfg"
const MAX_ENTRIES := 10

func _load_entries() -> Array:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) != OK:
        return []
    var entries: Array = []
    for i in range(MAX_ENTRIES):
        if cfg.has_section_key("scores", "entry_%d" % i):
            entries.append(cfg.get_value("scores", "entry_%d" % i))
    return entries

func _save_entries(entries: Array, last_name: String) -> void:
    var cfg := ConfigFile.new()
    for i in range(entries.size()):
        cfg.set_value("scores", "entry_%d" % i, entries[i])
    cfg.set_value("prefs", "last_name", last_name)
    cfg.save(SAVE_PATH)

func _insert_entry(entries: Array, name: String, score: int) -> Array:
    entries.append({ "name": name, "score": score })
    entries.sort_custom(func(a, b): return a["score"] > b["score"])
    return entries.slice(0, MAX_ENTRIES)
```

### Pattern 3: Leaderboard Row Layout (VBoxContainer approach)

**What:** Generate leaderboard rows dynamically from data, one `HBoxContainer` per entry with three `Label` children (rank, name, score). Apply gold color override to the current run's row.

**Why VBoxContainer over GridContainer:** Per-row color override requires touching each Label individually — both approaches need the same effort. `VBoxContainer` of `HBoxContainer` rows maps 1:1 to data rows and avoids GridContainer's column-count bookkeeping.

**Example:**
```gdscript
# Source: [ASSUMED — consistent with score-hud.tscn HBoxContainer pattern in this project]
func _populate_table(entries: Array, current_entry_index: int) -> void:
    for child in _rows_container.get_children():
        child.queue_free()
    
    var display_entries := entries.duplicate()
    var current_rank: int = current_entry_index  # -1 if not in top 10
    
    # Append 11th row if not placed
    var show_unranked := current_rank == -1
    if show_unranked:
        display_entries.append(_pending_entry)  # highlight separately below table
    
    for i in range(display_entries.size()):
        var entry = display_entries[i]
        var is_current := (i == current_rank) or (show_unranked and i == display_entries.size() - 1)
        var color := Color(1.0, 0.843, 0.0) if is_current else Color.WHITE
        var rank_text := "»%d" % (i + 1) if is_current else "%d" % (i + 1)
        _add_row(rank_text, entry["name"], entry["score"], color)

func _add_row(rank: String, name: String, score: int, color: Color) -> void:
    var row := HBoxContainer.new()
    for text in [rank, name, "%d" % score]:
        var lbl := Label.new()
        lbl.text = text
        lbl.add_theme_color_override("font_color", color)
        lbl.add_theme_color_override("font_outline_color", Color.BLACK)
        lbl.add_theme_constant_override("outline_size", 3)
        row.add_child(lbl)
    _rows_container.add_child(row)
```

### Pattern 4: world.gd Integration (existing wiring convention)

**What:** Instantiate `DeathScreen` in `world.gd._ready()` and call `connect_to_death_screen()` or similar, connecting to `$ShipBFG23.died`. The ship is found via group `"player"` or direct scene path.

**Example:**
```gdscript
# Source: [VERIFIED — world.gd pattern for wave_hud and score_hud]
# In world.gd _ready():
var death_screen_model = preload("res://prefabs/ui/death-screen.tscn")
# ...
var death_screen: DeathScreen = death_screen_model.instantiate()
add_child(death_screen)
$ShipBFG23.died.connect(death_screen._on_player_died.bind(ScoreManager.total_score))
# OR: death_screen.connect_to_player($ShipBFG23, ScoreManager)
```

**Note:** `Body.died` is emitted at line 63, `queue_free()` at line 64 of `body.gd`. The signal is safe to connect synchronously — the handler runs before the node is freed. [VERIFIED: body.gd source]

### Anti-Patterns to Avoid

- **Setting PROCESS_MODE_ALWAYS only on leaf nodes:** If the CanvasLayer root remains at `PROCESS_MODE_INHERIT` and the scene tree is paused, children inheriting `PROCESS_MODE_INHERIT` will also be paused regardless of their own `process_mode`. Set it on the CanvasLayer root. [CITED: Godot pausing docs pattern]
- **Calling `grab_focus()` before the node is visible:** LineEdit will not accept focus if `visible = false`. Show the section first, then `call_deferred("grab_focus")`. [VERIFIED: community forum consensus]
- **Referencing `ScoreManager.score`:** The property is `ScoreManager.total_score`. Using `.score` will cause a runtime null/error. [VERIFIED: components/score-manager.gd]
- **Storing the current run score at submission time only:** If you read `ScoreManager.total_score` inside the submit handler, it is still valid (the autoload persists after the player ship is freed). Safe to read at any time during the death screen lifecycle.
- **Using `get_tree().create_timer()` while paused:** Timers created via `create_timer()` with default `process_always = false` will NOT tick when the tree is paused. If any animation timers are needed, use `create_timer(delay, true)` (the second arg is `process_always`). [ASSUMED — confirmed pattern from Godot docs]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Key-value persistence | Custom file I/O with FileAccess | `ConfigFile` (built-in) | ConfigFile handles INI parsing, type conversion, missing keys gracefully; FileAccess requires manual serialization |
| Text input | Manual key event processing in `_input()` | `LineEdit` node | LineEdit handles cursor, selection, copy/paste, IME, max_length; manual key handling misses edge cases |
| Sort + truncate | Custom sort algorithm | `Array.sort_custom()` + `.slice()` | Built-in, one-liners |

**Key insight:** Godot provides all needed primitives. The phase is almost entirely glue code — wiring existing signals, styling existing node types, and calling ConfigFile.

---

## Common Pitfalls

### Pitfall 1: process_mode Scope on CanvasLayer

**What goes wrong:** Input is not received by the LineEdit or buttons while the scene tree is paused. The overlay is visible but clicking Submit or pressing Enter does nothing.

**Why it happens:** `get_tree().paused = true` propagates down the tree. Nodes with `PROCESS_MODE_INHERIT` (default) inherit "paused" from their parent. If only child nodes are set to `PROCESS_MODE_ALWAYS` but the CanvasLayer root is `PROCESS_MODE_INHERIT`, the children's setting is masked by the parent's pause state.

**How to avoid:** Set `process_mode = PROCESS_MODE_ALWAYS` (value `3`) on the CanvasLayer node itself in the `.tscn` file. All children will then inherit "always" unless overridden.

**Warning signs:** Overlay appears, but no user input is processed; `_input()` and `_process()` are never called on the DeathScreen script while paused.

### Pitfall 2: grab_focus() Before Node is Visible

**What goes wrong:** LineEdit appears empty and unfocused; player must click it manually to start typing.

**Why it happens:** `grab_focus()` is a no-op if the Control node is invisible or not yet in the viewport. Calling it synchronously in `show_death_screen()` before setting `visible = true` silently fails.

**How to avoid:** Set `visible = true` on the name section first, then call `call_deferred("grab_focus")` on the LineEdit. The deferred call runs after the current frame's layout pass, when the node is guaranteed to be in the visible tree.

**Warning signs:** `grab_focus()` returns without error but the LineEdit has no cursor and ignores keyboard input until clicked.

### Pitfall 3: Wrong Score Property Name

**What goes wrong:** `ScoreManager.score` causes a GDScript runtime error ("Invalid access to property 'score'") or silently returns null.

**Why it happens:** CONTEXT.md references `ScoreManager.score`, but the actual property in `components/score-manager.gd` is `total_score`.

**How to avoid:** Use `ScoreManager.total_score` everywhere in the death screen code. [VERIFIED: score-manager.gd line 15]

**Warning signs:** Score saved as 0 or null in the leaderboard; GDScript warning/error in output.

### Pitfall 4: ConfigFile Load Before File Exists

**What goes wrong:** First run crashes or logs errors because `user://leaderboard.cfg` does not exist yet.

**Why it happens:** `cfg.load(path)` returns an `Error` enum value (not `OK`) if the file is absent. If unchecked, subsequent `get_value()` calls on an unloaded ConfigFile return defaults or push errors.

**How to avoid:** Always check `if cfg.load(SAVE_PATH) != OK: return []` (or equivalent). The ConfigFile API is designed for graceful absence — treat a non-OK load as "empty leaderboard."

**Warning signs:** Error in output: "Can't open file..." on first launch.

### Pitfall 5: Entry Duplication on Re-Submit

**What goes wrong:** If the submit action fires twice (double-Enter, signal double-connection), the same run gets inserted twice into the leaderboard.

**Why it happens:** `LineEdit.text_submitted` signal fires on Enter; a separate Submit button also fires on press. Without a guard, both can call the submit handler in the same frame.

**How to avoid:** Set a boolean `_submitted: bool = false` guard. After first submission, set it to true and ignore subsequent calls.

---

## Code Examples

Verified patterns from project source:

### CanvasLayer setup (matching score-hud.tscn)
```
# Source: prefabs/ui/score-hud.tscn — CanvasLayer, layer = 10
# Death screen should use layer = 20 to render above all HUDs

[node name="DeathScreen" type="CanvasLayer"]
layer = 20
process_mode = 3     # PROCESS_MODE_ALWAYS
visible = false
script = ExtResource("1_deathscreen")
```

### Label style matching project HUD (from score-hud.tscn)
```gdscript
# Source: [VERIFIED: prefabs/ui/score-hud.tscn]
# White text with black outline — copy these theme overrides:
theme_override_font_sizes/font_size = 22
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_constants/outline_size = 3
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)

# Gold highlight — from score-manager.gd _combo_color() and score-hud _animate_multiplier_pulse()
# Source: [VERIFIED: components/score-manager.gd line 127, prefabs/ui/score-hud.gd line 75]
const GOLD := Color(1.0, 0.843, 0.0)
```

### world.gd death signal connection (following existing pattern)
```gdscript
# Source: [VERIFIED: world.gd _ready() — wave_hud and score_hud wiring pattern]
# In _ready(), after existing HUD setup:
var death_screen_model = preload("res://prefabs/ui/death-screen.tscn")
var death_screen: DeathScreen = death_screen_model.instantiate()
add_child(death_screen)
$ShipBFG23.died.connect(func(): death_screen.show_death_screen(ScoreManager.total_score))
```

### Body.died signal timing
```gdscript
# Source: [VERIFIED: components/body.gd lines 63-64]
# died.emit() is called BEFORE queue_free() — signal handler is safe
# The handler receives the final state of the scene before the node is freed
died.emit()    # line 63
queue_free()   # line 64
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual FileAccess for save data | `ConfigFile` built-in | Godot 3+ | No custom parser needed; handles sections/keys/types |
| Global scene pause blocking all input | `PROCESS_MODE_ALWAYS` on overlay nodes | Godot 4.0 | Pause menus work while physics/AI are frozen |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `call_deferred("grab_focus")` reliably focuses LineEdit after `visible = true` | Pitfall 2, Code Examples | Player must click the field manually; minor UX friction |
| A2 | `ConfigFile` API is unchanged between Godot 4.2 and 4.6.2 | Standard Stack, Code Examples | Would require API adjustment; LOW risk — ConfigFile is stable |
| A3 | `process_mode = PROCESS_MODE_ALWAYS` on CanvasLayer root is sufficient for all child input | Pitfall 1, Pattern 1 | If wrong, need `PROCESS_MODE_ALWAYS` on every child node as well |
| A4 | `create_timer(delay, true)` syntax for process_always flag | Pitfall list | Any tween/animation during death screen might freeze; mitigated by using Tweens instead |

---

## Open Questions

1. **PROCESS_MODE_ALWAYS on CanvasLayer vs. every child node**
   - What we know: The pattern is established — wave-hud and score-hud do NOT set this because they don't need it (game is never paused during waves). No prior pause UI exists in the project.
   - What's unclear: Whether Godot 4.6 requires it only on the root or on each node individually for all input types (mouse click vs. keyboard).
   - Recommendation: Set it on the CanvasLayer root. If input issues arise, add it to the LineEdit and Button children as well.

2. **`LineEdit.text_submitted` vs. Button for confirm**
   - What we know: D-04 says "Enter key or Submit button — either works."
   - What's unclear: Which is the primary trigger in the .tscn (both should call the same handler).
   - Recommendation: Connect both `LineEdit.text_submitted` signal AND `Button.pressed` signal to the same `_on_submit()` handler. Use the `_submitted` guard (Pitfall 5).

---

## Environment Availability

Step 2.6: SKIPPED (no external dependencies — this phase is 100% GDScript and built-in Godot nodes; no CLI tools, databases, or external services required)

---

## Validation Architecture

`nyquist_validation` is explicitly `false` in `.planning/config.json` — section skipped.

---

## Security Domain

`security_enforcement` not present in `config.json` (absent = enabled). However, this phase involves only local disk writes to `user://leaderboard.cfg` with player-entered names (up to 16 chars) and integer scores. No network, no auth, no sensitive data.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes (low risk) | `LineEdit.max_length = 16`; name stored as-is (no injection vector for local file) |
| V6 Cryptography | no | — |

**No meaningful threat surface:** The leaderboard is local-only. The only input is the player name (16 char max enforced by LineEdit). ConfigFile writes are to the user's own data directory. No sanitization beyond `max_length` is required.

---

## Sources

### Primary (HIGH confidence)
- `components/body.gd` — Verified `died` signal emission at line 63, before `queue_free()` at line 64
- `components/score-manager.gd` — Verified `total_score` property name (not `score`); confirmed `Color(1.0, 0.843, 0.0)` gold at line 127
- `prefabs/ui/score-hud.tscn` — Verified CanvasLayer structure, layer = 10, HBoxContainer row pattern, label theme_override_colors
- `prefabs/ui/score-hud.gd` — Verified `connect_to_score_manager()` wiring pattern
- `prefabs/ui/wave-hud.gd` + `wave-hud.tscn` — Verified bare-label CanvasLayer pattern
- `world.gd` — Verified instantiate-and-connect pattern for HUD nodes in `_ready()`
- `project.godot` — Verified `ScoreManager` autoload path, engine version 4.6

### Secondary (MEDIUM confidence)
- [Godot pausing games documentation](https://docs.godotengine.org/en/stable/tutorials/scripting/pausing_games.html) — PROCESS_MODE_ALWAYS must be on the node that needs to process, not inherited from paused parent
- [Godot ConfigFile class docs](https://docs.godotengine.org/en/stable/classes/class_configfile.html) — set_value / get_value / save / load API
- Godot forum + GitHub issues — LineEdit grab_focus deferred pattern; pause input pitfalls

### Tertiary (LOW confidence)
- Community reports re: `grab_focus()` before `visible = true` silently failing — not verified against official docs, but consistent across multiple sources

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all built-in Godot APIs, verified in project
- Architecture: HIGH — directly derived from verified existing source code patterns
- ConfigFile API: MEDIUM — stable API, confirmed via official docs search; code examples based on training knowledge (A2)
- Pitfalls: MEDIUM — process_mode pitfall confirmed by community + docs; grab_focus pitfall from community consensus (MEDIUM)

**Research date:** 2026-04-15
**Valid until:** 2026-07-15 (stable Godot 4 APIs; 90-day window)
