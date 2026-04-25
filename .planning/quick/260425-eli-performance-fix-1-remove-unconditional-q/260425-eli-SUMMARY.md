---
quick_id: 260425-eli
slug: performance-fix-1-remove-unconditional-q
date: 2026-04-25
status: complete
commit: 4005bb4
description: |
  Performance fix #1 of 5 from debug session wave-performance-slowdown:
  Remove unconditional queue_redraw() call from EnemyShip._physics_process.
---

# Quick Task 260425-eli — Summary

## What was done

Deleted line 82 of `components/enemy-ship.gd` — the unconditional
`queue_redraw()` call inside `_physics_process`. With 250 enemies at
60 physics ticks/sec, this single line caused ~15,000 wasted CanvasItem
dirty-marks per second.

## Why it's safe

Two surviving `queue_redraw()` calls cover the legitimate cases:

| Line | Function | Purpose |
|------|----------|---------|
| 56 | `set_debug_visible(show_debug)` | SHIFT+D toggle re-renders debug overlay |
| 106 | `_change_state(new_state)` | State transitions update STATE label in `_draw()` |

Since the debug overlay only changes on toggle and on state transition,
both events already trigger a redraw. The per-frame call was redundant.

## Files changed

- `components/enemy-ship.gd` — 1 line deleted

## Verification

```
$ grep -n "queue_redraw" components/enemy-ship.gd
56:    queue_redraw()
106:   queue_redraw()
```

Zero `queue_redraw` calls inside `_physics_process`. Two surviving calls,
both in the correct event handlers.

## Commit

- `4005bb4` — `perf(260425-eli): remove unconditional queue_redraw() from EnemyShip._physics_process`

## Source

Diagnosed in debug session `wave-performance-slowdown` — Root Cause Report,
priority #2 (now applied as fix #1 of 5).
