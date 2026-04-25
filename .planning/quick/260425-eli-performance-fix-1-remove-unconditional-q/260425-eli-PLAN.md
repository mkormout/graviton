---
phase: 260425-eli
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - components/enemy-ship.gd
autonomous: true
requirements:
  - PERF-FIX-1
must_haves:
  truths:
    - "EnemyShip._physics_process no longer calls queue_redraw() unconditionally every physics tick"
    - "Debug overlay still updates on toggle (set_debug_visible) and state changes (_change_state)"
    - "components/enemy-ship.gd parses successfully in Godot 4.2.1 (no syntax errors)"
  artifacts:
    - path: "components/enemy-ship.gd"
      provides: "EnemyShip class with queue_redraw() removed from _physics_process"
      contains: "func _physics_process(delta: float):"
  key_links:
    - from: "EnemyShip._physics_process"
      to: "queue_redraw"
      via: "REMOVED — must NOT contain queue_redraw() inside _physics_process body"
      pattern: "absence verified by grep"
    - from: "EnemyShip.set_debug_visible"
      to: "queue_redraw"
      via: "preserved at line ~56 — toggling debug overlay still works"
      pattern: "queue_redraw\\(\\)"
    - from: "EnemyShip._change_state"
      to: "queue_redraw"
      via: "preserved at line ~107 — state changes still trigger redraw"
      pattern: "queue_redraw\\(\\)"
---

<objective>
Remove the unconditional `queue_redraw()` call from `EnemyShip._physics_process` (components/enemy-ship.gd:82).

Purpose: Performance fix #1 of 5 from debug session `wave-performance-slowdown`. With 250 enemies in wave 2, this single line triggers ~15,000 CanvasItem dirty-marks per second (250 enemies × 60 physics ticks), even though `_draw()` early-exits when atlas sprites are active. The debug overlay is already covered by transition-time redraws in `set_debug_visible()` (line 56) and `_change_state()` (line 107), so this call is redundant.

Output: `components/enemy-ship.gd` with line 82 deleted; the function body of `_physics_process` becomes `super(delta)` followed by the `dying` check and `_tick_state(delta)`.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md
@components/enemy-ship.gd
@.planning/debug/wave-performance-slowdown.md

<interfaces>
<!-- Current shape of EnemyShip._physics_process (lines 80-85): -->
```gdscript
func _physics_process(delta: float) -> void:
    super(delta)
    queue_redraw()      # <-- DELETE THIS LINE
    if dying:
        return
    _tick_state(delta)
```

<!-- Target shape after fix: -->
```gdscript
func _physics_process(delta: float) -> void:
    super(delta)
    if dying:
        return
    _tick_state(delta)
```

<!-- These two queue_redraw() calls MUST remain untouched: -->
<!-- Line ~56 inside set_debug_visible() — covers SHIFT+D toggle -->
<!-- Line ~107 inside _change_state() — covers state transitions (state label in _draw) -->
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Delete unconditional queue_redraw() from EnemyShip._physics_process</name>
  <files>components/enemy-ship.gd</files>
  <action>
    In components/enemy-ship.gd, delete line 82 (`	queue_redraw()`) — the standalone `queue_redraw()` call inside `func _physics_process(delta: float) -> void`.

    Use the Edit tool with this exact replacement:
    - old: "func _physics_process(delta: float) -> void:\n\tsuper(delta)\n\tqueue_redraw()\n\tif dying:\n\t\treturn\n\t_tick_state(delta)"
    - new: "func _physics_process(delta: float) -> void:\n\tsuper(delta)\n\tif dying:\n\t\treturn\n\t_tick_state(delta)"

    Do NOT touch the other two `queue_redraw()` calls in this file:
    - Line 56 inside `set_debug_visible()` — required for SHIFT+D toggle to refresh the overlay
    - Line 107 inside `_change_state()` — required so the STATE label in `_draw()` reflects new state on transition

    Rationale (per debug session wave-performance-slowdown): `_draw()` early-exits at lines 116-118 when `$Shape.visible == false` (atlas sprite active), so 99% of these queue_redraw() calls dirty-mark the CanvasItem and traverse render tree only to render nothing. With 250 enemies × 60 ticks/sec = ~15,000 wasted dirty-marks/second. Transition-time redraws (debug toggle, state change) provide complete coverage of when the overlay actually needs to redraw.
  </action>
  <verify>
    <automated>cd /Users/milan.kormout/Projects/personal/graviton &amp;&amp; awk '/^func _physics_process/,/^func [^_]/' components/enemy-ship.gd | grep -c queue_redraw | grep -q '^0$' &amp;&amp; grep -c queue_redraw components/enemy-ship.gd | grep -q '^2$' &amp;&amp; echo OK</automated>
  </verify>
  <done>
    1. `queue_redraw()` no longer appears anywhere in the body of `_physics_process` in components/enemy-ship.gd
    2. `queue_redraw()` is still present exactly twice in the file: once in `set_debug_visible()` and once in `_change_state()`
    3. The function `_physics_process` body is exactly: `super(delta)` → `if dying: return` → `_tick_state(delta)` (3 statements)
    4. File still parses as valid GDScript (no syntax errors introduced — tabs preserved, no stray indentation)
  </done>
</task>

</tasks>

<verification>
After the edit, verify with two greps:

```bash
# Should print exactly 2 (set_debug_visible + _change_state)
grep -c 'queue_redraw' components/enemy-ship.gd

# Should print 0 — no queue_redraw inside the _physics_process function block
awk '/^func _physics_process/,/^func [^_]/' components/enemy-ship.gd | grep -c queue_redraw
```

Visual smoke check (post-merge, user-driven — no headless game runner exists in this project):
1. Open project in Godot 4.2.1 editor — should load without parser errors
2. Run the game, spawn enemies, press SHIFT+D — debug overlays should still toggle correctly
3. Observe an enemy transitioning IDLING → SEEKING (player approaches) — STATE label in debug overlay should still update on the transition
</verification>

<success_criteria>
- [ ] components/enemy-ship.gd line 82 (`queue_redraw()` inside `_physics_process`) is deleted
- [ ] Total `queue_redraw()` count in the file drops from 3 to 2
- [ ] The two surviving calls are inside `set_debug_visible()` and `_change_state()`
- [ ] No other lines modified
- [ ] File still uses tab indentation (Godot GDScript convention) — no stray spaces introduced
</success_criteria>

<output>
After completion, create `.planning/quick/260425-eli-performance-fix-1-remove-unconditional-q/260425-eli-SUMMARY.md` summarizing:
- The line removed and its location
- Confirmation that the two preserved `queue_redraw()` calls remain
- Note that perf impact verification is post-merge user testing (no headless runner)
</output>
