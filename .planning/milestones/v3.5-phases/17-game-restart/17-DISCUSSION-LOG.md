# Phase 17: Game Restart - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-18
**Phase:** 17-game-restart
**Areas discussed:** Play Again placement, World cleanup scope, Player ship position

---

## Play Again Placement

| Option | Description | Selected |
|--------|-------------|----------|
| After leaderboard only | Button appears after submit → leaderboard flow | ✓ |
| Always visible | Present from death screen open, before score submission | |
| Both: immediate + after submit | Skip link on name entry + full button after leaderboard | |

**User's choice:** After leaderboard only
**Notes:** Standard flow — submit name, see leaderboard, then Play Again.

---

## World Cleanup Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Enemies only | Clear enemies; leave floating items and asteroids | |
| Enemies + item drops | Clear enemies and floating items | |
| Everything + fresh asteroids | Full reset: enemies, items, asteroids cleared; new asteroids spawned | ✓ |

**User's choice:** Full reset — everything cleared, fresh asteroids spawned
**Notes:** "The game should start similarly to how the application starts." User wants restart to feel indistinguishable from a fresh app launch.

---

## Player Ship Position

| Option | Description | Selected |
|--------|-------------|----------|
| Reset to origin | Teleport to Vector2.ZERO, zero velocity | ✓ |
| Leave wherever it died | Keep death position, just restore health | |

**User's choice:** Reset to origin
**Notes:** Consistent with "start like fresh app launch" philosophy.

---

## Claude's Discretion

- Exact signal name on DeathScreen for Play Again
- Whether to use `call_deferred` during unpause sequence
- How to identify asteroids and item nodes for cleanup
- Whether item drops need a group tag or class-based identification

## Deferred Ideas

- Difficulty settings phase — "Start New Game" dialog with difficulty selection; Play Again button can evolve into this. User mentioned wanting this as a separate phase after v3.5.
