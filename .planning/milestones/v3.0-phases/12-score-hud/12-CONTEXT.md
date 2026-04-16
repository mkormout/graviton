# Phase 12: Score HUD - Context

**Gathered:** 2026-04-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Wire a new `score-hud.tscn` to ScoreManager signals, displaying score, kill count, wave multiplier, and combo in a top-right HUD panel. The ScoreManager backend (signals, autoload) is already complete from Phase 11 — this phase is purely the frontend display layer.

</domain>

<decisions>
## Implementation Decisions

### Scene structure
- **D-01:** Create a **new `score-hud.tscn`** in `prefabs/ui/` — do NOT extend `wave-hud.tscn`. WaveHud owns wave state (count, countdown, announcement); ScoreHud owns scoring state. Matches the existing one-job-per-scene pattern.
- **D-02:** Extend `CanvasLayer` (matching `wave-hud.gd` and `status-bar.gd`), with a companion `score-hud.gd` script.

### Screen position
- **D-03:** Anchor the score block to the **top-right corner**. Classic arcade layout — wave info top-left, score info top-right, two distinct non-competing zones.

### Label layout
- **D-04:** Four rows, bare labels (no panel background), matching `wave-hud.tscn` visual style:
  ```
  SCORE  12,450
  KILLS  8
  MULT   ×4
  COMBO  --
  ```
- **D-05:** Prefix label + value format (e.g., `SCORE  12,450`, not icons or value-only).
- **D-06:** White text with outline for contrast against dark space background (same approach as wave-hud Labels).

### Combo display
- **D-07:** Combo row is **always visible** — shows `--` when no combo is active, updates to `x{N}` when active.
- **D-08:** Connect to `ScoreManager.combo_updated(combo_count)` and `ScoreManager.combo_expired()`. On `combo_updated`: show `x{N}` in normal color. On `combo_expired` (or `combo_count == 0`): revert to `--` in greyed-out color.

### Animations
- **D-09:** Multiplier label: **scale pulse + gold flash** on `multiplier_changed`. Scale 1.0 → 1.4 → 1.0 and color white → gold (#FFD700) → white, over ~0.4s using a tween. Matches existing tween pattern from `wave-hud.gd`.
- **D-10:** Score label: **small color flash** (brief bright-white or light-yellow → normal) on each `score_changed` signal. Subtle, not as dramatic as multiplier.
- **D-11:** Kill count and combo row: no animation — text update only.

### Signal connections
- **D-12:** Connect in `score-hud.gd` via a `connect_to_score_manager()` method, mirroring the `connect_to_wave_manager()` pattern in `wave-hud.gd`. Called from `world.gd` at scene startup.
- **D-13:** Signals to connect: `ScoreManager.score_changed` → update score + flash, `ScoreManager.multiplier_changed` → update multiplier + pulse, `ScoreManager.combo_updated` → update combo row, `ScoreManager.combo_expired` → reset combo to `--`.
- **D-14:** Kill count: connect to `ScoreManager.score_changed` is insufficient — kills need a dedicated signal OR poll `ScoreManager.kill_count` on `score_changed`. Check if `ScoreManager` exposes a `kill_count_changed` signal; if not, read `ScoreManager.kill_count` inside the `score_changed` handler (kill always accompanies a score update).

### Claude's Discretion
- Exact font sizes (match wave-hud sizing as baseline)
- Whether score uses comma formatting (`12,450`) or plain integer (`12450`) — comma preferred if GDScript supports it easily, otherwise plain
- Exact tween easing curve for the scale pulse
- Whether the `COMBO --` grey is achieved via `modulate` or `add_theme_color_override`

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

No external ADRs. Decisions are above; key files to read:

### Existing HUD patterns to follow
- `prefabs/ui/wave-hud.gd` — Signal-connection pattern, tween usage, CanvasLayer extension
- `prefabs/ui/wave-hud.tscn` — Scene structure to mirror for score-hud.tscn
- `prefabs/ui/status-bar.gd` — Secondary CanvasLayer reference

### Backend to wire to
- `components/score-manager.gd` — Signals: `score_changed(new_score, delta)`, `multiplier_changed(new_multiplier)`, `combo_updated(combo_count)`, `combo_expired()`. Also exposes: `total_score`, `kill_count`, `wave_multiplier`, `combo_count` as vars.

### World wiring
- `world.gd` — Add `score_hud.connect_to_score_manager(ScoreManager)` alongside existing `wave_hud.connect_to_wave_manager(wave_manager)` call.

### Phase success criteria
- Kill count increments on each kill (visible immediately in top-right HUD)
- Score updates in real time with small flash
- Multiplier label pulses gold on wave clear and resets on damage
- Combo shows `--` at rest, `x3` etc. during active chain

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Patterns
- `WaveHud.connect_to_wave_manager(wm: WaveManager)` — exact pattern to follow for `connect_to_score_manager()`
- `wave-hud.gd` tween for announcement fade: `var tween := label.create_tween(); tween.tween_property(...)` — reuse for scale pulse and color flash
- `ScoreManager._combo_color(combo)` — existing bronze→silver→gold gradient; may be useful for combo row coloring but not required here (combo row shows count, not color gradient)

### Integration Points
- `world.gd` — Find where `wave_hud.connect_to_wave_manager(wave_manager)` is called; add score-hud wiring directly after it
- `ScoreManager` is autoload — accessible as `ScoreManager` globally; no `@export` needed on ScoreHud

### Note on kill_count signal
- `ScoreManager` does NOT have a `kill_count_changed` signal (only `score_changed`, `multiplier_changed`, `combo_updated`, `combo_expired`)
- Read `ScoreManager.kill_count` inside the `_on_score_changed()` handler — every kill triggers `score_changed`, so kill_count is always fresh at that point

</code_context>

<specifics>
## Specific Ideas

- Score label format: `SCORE  12,450` (comma-formatted if easy; `%d` is fine if not)
- Combo inactive: `COMBO  --` with a dimmed color (e.g., `Color(0.5, 0.5, 0.5)`)
- Combo active: `COMBO  x3` in white (or bronze/silver/gold from ScoreManager._combo_color if user wants visual feedback — Claude's discretion)
- Multiplier pulse: gold = `Color(1.0, 0.843, 0.0)` — same gold used in `ScoreManager._combo_color()`

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 12-score-hud*
*Context gathered: 2026-04-15*
