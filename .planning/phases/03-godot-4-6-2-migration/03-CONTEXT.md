# Phase 3: Godot 4.6.2 Migration - Context

**Gathered:** 2026-04-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Upgrade the Godot engine from 4.2.1 to 4.6.2 so the project opens, runs, and exports correctly — no deprecated API warnings or runtime errors. This phase does NOT include new gameplay features, CI pipeline updates, or code refactoring beyond what the migration strictly requires.

</domain>

<decisions>
## Implementation Decisions

### API Discovery (MIG-02)
- **D-01:** Open the project in the Godot 4.6.2 editor and let Godot's built-in conversion assistant flag deprecated/removed APIs. Fix errors as they surface — no pre-scan required.
- **D-02:** The project currently declares `config/features=PackedStringArray("4.2", "GL Compatibility")` in `project.godot` — this must be updated to reflect 4.6.2 after migration.

### Export Verification (MIG-03)
- **D-03:** All 4 CI export targets must produce working executables post-migration: Windows Desktop, Linux/X11, Mac OSX, Web (HTML5).
- **D-04:** Export verification is done **locally** (not via CI). The CI workflow (`barichello/godot-ci:4.2.1`) is intentionally NOT updated in this phase — that is deferred.

### Validation (MIG-01 + MIG-02)
- **D-05:** Validation method: open project in Godot 4.6.2 editor, run the game, and do a manual smoke test — move the ship, fire weapons, swap inventory items. Check the Output panel for any errors or deprecation warnings.
- **D-06:** The project is considered migration-complete when: (a) the editor opens with no import errors, (b) the smoke test produces no Output panel errors, and (c) a local export of all 4 platforms completes without errors.

### Claude's Discretion
- Exact order of fixing API errors — address them in the order Godot surfaces them unless a logical dependency requires a different order.
- Whether `project.godot` features string becomes `"4.6"` or `"4.6.2"` — use whatever Godot 4.6.2 sets automatically on conversion.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — MIG-01, MIG-02, MIG-03 acceptance criteria

### Configuration Files
- `project.godot` — Current engine config (`config/features=PackedStringArray("4.2", "GL Compatibility")`); this file will be modified by Godot on migration
- `export_presets.cfg` — Export configurations for Windows Desktop, Linux/X11, Mac OSX, HTML5 (Web)

### CI (reference only — not in scope for this phase)
- `.github/workflows/gitlab-ci.yml` — Currently hardcodes `GODOT_VERSION: 4.2.1` and `barichello/godot-ci:4.2.1`; NOT updated in this phase

### Source Files to Watch for API Changes
- `components/` (all .gd files) — Primary location for GDScript that may use deprecated 4.2 APIs
- `prefabs/` (all .gd files) — Secondary location; weapon and item scripts
- `world.gd` — Main scene script; uses physics, input, and node APIs directly

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phases 1 and 2 already cleaned up the codebase: `@export` spawn_parent pattern, CONNECT_ONE_SHOT, typed Action enum, cached mount lookups — fewer fragile patterns means fewer migration surprises.

### Established Patterns
- All game logic is in GDScript — no C# or plugins, so migration scope is contained to `.gd` files and `project.godot`.
- `export_presets.cfg` has 4 working presets from 4.2.1 — the presets themselves may need template path updates after migration.

### Integration Points
- `project.godot` is the primary migration artifact — Godot 4.6.2 will update it on first open.
- `export_presets.cfg` may need export template version paths updated to match 4.6.2 templates.
- All `.gd` files in `components/` and `prefabs/` are candidates for API deprecation fixes.

</code_context>

<specifics>
## Specific Ideas

- When Godot 4.6.2 opens the project, accept the built-in migration assistant prompt — it handles the most mechanical API renames automatically.
- The smoke test path: spawn asteroids → move ship → fire each weapon type (minigun, laser, gausscannon, RPG, gravitygun) → open inventory and drag-drop a weapon → confirm no Output panel errors.

</specifics>

<deferred>
## Deferred Ideas

- **CI pipeline update** — Updating `.github/workflows/gitlab-ci.yml` from `barichello/godot-ci:4.2.1` to `4.6.2` is explicitly deferred. Worth doing as a quick follow-up after migration is verified.

</deferred>

---

*Phase: 03-godot-4-6-2-migration*
*Context gathered: 2026-04-10*
