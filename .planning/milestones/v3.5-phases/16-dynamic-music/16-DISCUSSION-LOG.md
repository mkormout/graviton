# Phase 16: Dynamic Music - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-17
**Phase:** 16-dynamic-music
**Areas discussed:** Wave thresholds, Cross-fade timing, Track catalog design, Category change trigger

---

## Wave Thresholds

| Option | Description | Selected |
|--------|-------------|----------|
| Waves 1–5 Ambient, 6–10 Combat, 11+ High-Intensity | Balanced thirds across a ~15-wave run | ✓ |
| Waves 1–3 Ambient, 4–7 Combat, 8+ High-Intensity | Earlier escalation, suits short arcade session | |
| Custom thresholds | User-specified wave numbers | |

**User's choice:** Waves 1–5 Ambient, 6–10 Combat, 11+ High-Intensity  
**Notes:** Recommended option selected; gives the player time in each mood before escalation.

---

## Cross-Fade Timing

| Option | Description | Selected |
|--------|-------------|----------|
| 2 seconds | Standard game music practice — intentional but not laggy | ✓ |
| 1 second | Snappy, arcade-feel | |
| 3 seconds | Cinematic, gradual | |

**User's choice:** 2 seconds  
**Notes:** Recommended option selected.

---

## Track Catalog Design

### Multiple tracks per category

| Option | Description | Selected |
|--------|-------------|----------|
| Shuffle (no repeat) | Random pick, never replay last track | ✓ |
| Random pick | Pure random, can repeat | |
| Sequential loop | Deterministic catalog order | |

**User's choice:** Shuffle (no repeat)

### Empty category fallback

| Option | Description | Selected |
|--------|-------------|----------|
| Fall back to any available track | Music always plays, never silent | ✓ |
| Stay on current track | Keep playing whatever is active | |
| Silence | Stop music for that category | |

**User's choice:** Fall back to any available track

---

## Category Change Trigger

| Option | Description | Selected |
|--------|-------------|----------|
| On wave_started | Music correct as enemies arrive — dramatic moment | ✓ |
| On wave_completed | Music shifts as breather after clearing | |
| Both (shift on started, soften on completed) | More complex dual-mode | |

**User's choice:** On wave_started  
**Notes:** Recommended option selected.

---

## Claude's Discretion

- Initial volume levels for the two AudioStreamPlayers
- Cross-fade interruption handling (new category change while fade is in progress)
- Exact preload catalog entries (placeholder: all three categories use Gravimetric Dawn.mp3)
- Whether MusicManager emits a signal on category change

## Deferred Ideas

None.
