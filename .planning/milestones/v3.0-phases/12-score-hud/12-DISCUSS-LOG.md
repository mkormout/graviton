# Phase 12: Score HUD - Discussion Log

**Session:** 2026-04-15
**Status:** Complete

---

## Area 1: New scene vs extend wave-hud

**Q:** Should score/kills/multiplier live in a new score-hud.tscn or be added to the existing wave-hud.tscn?
**Options:** New score-hud.tscn / Extend wave-hud.tscn
**Selected:** New score-hud.tscn
**Notes:** Separate file keeps WaveHud about waves and ScoreHud about scoring; consistent with how wave-hud.tscn was split from hud.tscn.

---

## Area 2: Screen position

**Q:** Where on screen should the score block be anchored?
**Options:** Top-right corner / Top-left below wave-hud / Top-center
**Selected:** Top-right corner
**Notes:** Classic arcade layout — wave info top-left, score info top-right, two non-competing zones.

---

## Area 3: Multiplier animation

**Q:** When the wave multiplier changes, should the label animate?
**Options:** Brief color flash / Scale pulse + color / No animation (defer to Phase 14)
**Selected:** Scale pulse + color
**Notes:** Scale 1.0→1.4→1.0 + gold flash on multiplier_changed signal.

**Q:** Should the score label also animate when it updates?
**Options:** Multiplier only / Score too — small flash
**Selected:** Score too — small flash
**Notes:** Subtle flash on score_changed; more dramatic pulse only on multiplier.

---

## Area 4: Visual style

**Q:** Should the score block have a background panel, or just bare labels?
**Options:** Bare labels (match wave-hud) / Semi-transparent panel
**Selected:** Bare labels — match wave-hud

**Q:** Label format — how should each line read?
**Options:** Prefix label + value / Inline with icon chars / Value only — large
**Selected:** Prefix label + value
**Format:** `SCORE  12,450 / KILLS  8 / MULT  ×4 / COMBO  --`

**User note (freeform):** Add combo to the panel below multiplier, always visible greyed out with `--` when inactive.

**Q:** How should the combo display behave when there's no active combo?
**Options:** Hidden when combo = 0 / Always visible greyed out
**Selected:** Always visible, greyed out — shows `--` at rest, `x{N}` when active.
