---
phase: 17-game-restart
plan: "01"
subsystem: game-restart
tags: [wave-manager, score-manager, reset, game-state]
dependency_graph:
  requires: []
  provides: [WaveManager.reset(), ScoreManager.reset()]
  affects: [world.gd _restart_game()]
tech_stack:
  added: []
  patterns: [autoload-reset-pattern]
key_files:
  created: []
  modified:
    - components/wave-manager.gd
    - components/score-manager.gd
decisions:
  - "reset() does not call trigger_wave(); world.gd is responsible for triggering Wave 1 after reset (D-09)"
  - "_combo_timer.stop() called first in ScoreManager.reset() to prevent spurious _on_combo_expired() callback (D-10, Threat T-17-02)"
  - "wave_multiplier resets to 1 (not 0) — 1 is the no-modifier baseline"
metrics:
  duration: "~5 minutes"
  completed: "2026-04-18T16:21:17Z"
  tasks_completed: 2
  tasks_total: 2
---

# Phase 17 Plan 01: WaveManager and ScoreManager Reset Methods Summary

WaveManager.reset() and ScoreManager.reset() added — zeroing all tracking state and emitting HUD flush signals so world.gd can call them during the Play Again restart sequence.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add reset() to WaveManager | f4a5a28 | components/wave-manager.gd |
| 2 | Add reset() to ScoreManager | 2829a2e | components/score-manager.gd |

## What Was Built

### WaveManager.reset() (components/wave-manager.gd, line 135)
Zeros the three wave tracking variables (`_current_wave_index`, `_enemies_alive`, `_wave_total`) so the next `trigger_wave()` call starts from Wave 1. Does not call `trigger_wave()` — world.gd calls it manually after reset, matching the app launch pattern.

### ScoreManager.reset() (components/score-manager.gd, line 182)
Stops `_combo_timer` first (prevents spurious `_on_combo_expired()` callback with stale values after reset), then zeros `total_score`, `kill_count`, `combo_count`, and resets `wave_multiplier` to 1. Emits all three HUD signals (`score_changed`, `multiplier_changed`, `combo_updated`) so ScoreHUD flushes stale display values immediately.

## Deviations from Plan

None — plan executed exactly as written.

## Threat Model Coverage

| Threat ID | Mitigation | Status |
|-----------|------------|--------|
| T-17-02 | _combo_timer.stop() called first in reset() | Implemented |

## Self-Check: PASSED

- FOUND: components/wave-manager.gd
- FOUND: components/score-manager.gd
- FOUND: commit f4a5a28 (WaveManager.reset())
- FOUND: commit 2829a2e (ScoreManager.reset())
