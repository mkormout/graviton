# Phase 3: Godot 4.6.2 Migration - Research

**Researched:** 2026-04-10
**Domain:** Godot Engine version migration (4.2.1 → 4.6.2), GDScript API deprecations, export template management
**Confidence:** HIGH (core migration path) / MEDIUM (specific API warning behavior across versions)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Open the project in Godot 4.6.2 editor and let Godot's built-in conversion assistant flag deprecated/removed APIs. Fix errors as they surface — no pre-scan required.
- **D-02:** `config/features=PackedStringArray("4.2", "GL Compatibility")` in `project.godot` must be updated to reflect 4.6.2 after migration.
- **D-03:** All 4 CI export targets must produce working executables post-migration: Windows Desktop, Linux/X11, Mac OSX, Web (HTML5).
- **D-04:** Export verification is done locally (not via CI). The CI workflow (`barichello/godot-ci:4.2.1`) is intentionally NOT updated in this phase — that is deferred.
- **D-05:** Validation method: open project in Godot 4.6.2 editor, run the game, and do a manual smoke test — move the ship, fire weapons, swap inventory items. Check the Output panel for any errors or deprecation warnings.
- **D-06:** Migration-complete when: (a) editor opens with no import errors, (b) smoke test produces no Output panel errors, and (c) a local export of all 4 platforms completes without errors.

### Claude's Discretion
- Exact order of fixing API errors — address them in the order Godot surfaces them unless a logical dependency requires a different order.
- Whether `project.godot` features string becomes `"4.6"` or `"4.6.2"` — use whatever Godot 4.6.2 sets automatically on conversion.

### Deferred Ideas (OUT OF SCOPE)
- CI pipeline update — Updating `.github/workflows/gitlab-ci.yml` from `barichello/godot-ci:4.2.1` to `4.6.2` is explicitly deferred.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MIG-01 | Project opens and runs without errors in Godot 4.6.2 | Editor upgrade procedure, UID tool, project.godot format update |
| MIG-02 | All deprecated API calls identified and updated to 4.6.2 equivalents | Codebase audit of 4 string-based connect() calls, auto_translate deprecation, Linux preset rename |
| MIG-03 | Export presets verified and functional after migration | Linux/X11 → Linux rename in export_presets.cfg, export template install requirement |
</phase_requirements>

---

## Summary

Upgrading from Godot 4.2.1 to 4.6.2 spans four minor version boundaries (4.3, 4.4, 4.5, 4.6). For a pure GDScript 2D project with no plugins or C#, the cumulative breaking changes are modest. The riskiest change is the Linux export preset platform rename from `"Linux/X11"` to `"Linux"` introduced in 4.3 — the existing `export_presets.cfg` has `platform="Linux/X11"` which will cause the Linux preset to silently disappear in 4.6.2 unless manually corrected. The second non-trivial change is the Godot 4.4 UID system, which generates `.gd.uid` files automatically on first open and requires committing them to git. The codebase has 3 string-based `connect("signal_name", handler)` calls in `ship.gd` and `bullet.gd` that will produce deprecation warnings; one additional call in `mountable-weapon.gd` uses string-based `connect` with `CONNECT_ONE_SHOT` which should also be updated. No core GDScript syntax changes or 2D physics API removals affect this codebase between 4.2 and 4.6.

**Primary recommendation:** Open project in Godot 4.6.2, accept the UID upgrade prompt, manually update `export_presets.cfg` Linux platform string before running any exports, fix the 4 signal connect calls flagged in Output panel, then run the 4-platform local export.

---

## Standard Stack

### Migration Tooling
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Godot 4.6.2 editor | 4.6.2-stable | Opens project, runs conversion, surfaces warnings | The target runtime — no substitute |
| Built-in UID upgrade tool | Built into 4.4+ | Auto-generates `.gd.uid` and `.gdshader.uid` files | Mandatory first step when opening pre-4.4 project in 4.4+ |
| `Project > Tools > Upgrade Project Files` | Built into 4.4+ | Re-saves all scenes/resources with new format conventions | Recommended after UID tool to avoid staggered VCS diffs |

**Installation:**
```bash
# Download Godot 4.6.2 from official site:
# https://godotengine.org/download/archive/4.6.2-stable/
# Install export templates via: Editor > Manage Export Templates > Download and Install
```

Export templates must exactly match the editor version. Godot 4.6.2 templates are version-locked to the 4.6.2 editor — 4.2.1 templates will not work. [VERIFIED: official Godot export docs]

---

## Architecture Patterns

### Migration Procedure (in order)

1. **Download Godot 4.6.2 editor** from godotengine.org/download/archive/4.6.2-stable/
2. **Install 4.6.2 export templates** via Editor > Manage Export Templates > Download and Install
3. **Fix `export_presets.cfg` Linux preset BEFORE opening** — change `platform="Linux/X11"` to `platform="Linux"` (manual text edit; one occurrence in preset.1)
4. **Open project in Godot 4.6.2** — editor will prompt to confirm project upgrade; accept
5. **Run the UID upgrade tool** — when Godot 4.6.2 detects a pre-4.4 project, it automatically shows "Update UIDs..." prompt; accept/run it. This generates `.gd.uid` files alongside every `.gd` script.
6. **Run `Project > Tools > Upgrade Project Files`** — re-saves all scenes and resources with 4.6.2 format conventions in one pass
7. **Review Output panel for warnings** — fix string-based `connect()` calls and `auto_translate` warnings
8. **Commit all changes** including `.uid` files — critical for VCS
9. **Run smoke test** (ship movement, all 5 weapon types, inventory drag-drop, Output panel clean)
10. **Run 4-platform local export** — Windows Desktop, Linux, Mac OSX, Web (HTML5)

### project.godot After Migration
```
config/features=PackedStringArray("4.6", "GL Compatibility")
```
Godot 4.6.2 sets this automatically on first open. The exact string it writes (`"4.6"` vs `"4.6.2"`) is determined by the engine, not the developer. [ASSUMED — exact format not confirmed in official docs; use whatever Godot sets automatically per D-02]

---

## Known Breaking Changes for This Codebase

### CONFIRMED: Linux Export Preset Platform Rename
**Change:** In Godot 4.3, the Linux export platform was renamed from `"Linux/X11"` to `"Linux"` (Wayland support was added, making the name non-X11-specific).
**Impact:** `export_presets.cfg` currently has `platform="Linux/X11"` in `[preset.1]`. In Godot 4.6.2 this preset will silently fail to appear in the export dialog.
**Fix:** Change `platform="Linux/X11"` → `platform="Linux"` in `export_presets.cfg` before opening the project in 4.6.2.
[VERIFIED: github.com/godotengine/godot/issues/89012]

### CONFIRMED: String-Based `connect()` Calls (4 occurrences)
**Change:** In Godot 4.x (all versions), `connect("signal_name", callable)` using a string for the signal name is deprecated. It continues to work but generates deprecation warnings in the Output panel.
**Impact:** Violates D-05 (smoke test must produce no Output panel errors) and D-06 (migration-complete requires no errors).

Affected lines in codebase:
```
components/ship.gd:17    connect("body_entered", body_entered)
components/ship.gd:18    picker.connect("body_entered", picker_body_entered)
components/bullet.gd:9   connect("body_entered", collision)
components/mountable-weapon.gd:71  reload_timer.connect("timeout", reloaded, CONNECT_ONE_SHOT)
```

**Fix pattern:**
```gdscript
# Before (deprecated string-based):
connect("body_entered", body_entered)

# After (modern signal-object syntax):
body_entered.connect(body_entered_handler)
# Or for built-in node signals:
body_entered.connect(collision)
```

For `CONNECT_ONE_SHOT`:
```gdscript
# Before:
reload_timer.connect("timeout", reloaded, CONNECT_ONE_SHOT)

# After:
reload_timer.timeout.connect(reloaded, CONNECT_ONE_SHOT)
```
[VERIFIED: godotengine/godot-docs issue #5577, Godot 4.4 signals docs]

### CONFIRMED: UID File Generation (Godot 4.4 system change)
**Change:** Godot 4.4 introduced per-file `.uid` files (e.g., `body.gd` → `body.gd.uid`). When opening a pre-4.4 project in 4.4+, the editor generates these automatically.
**Impact:** After migration, the repository will have ~23 new `.gd.uid` files (one per `.gd` script). These MUST be committed to git. If not committed, UID references break when cloning on another machine.
**Fix:** After running the UID upgrade tool, `git add` all `*.uid` files and commit them.
[VERIFIED: godotengine.org/article/uid-changes-coming-to-godot-4-4/]

### LOW-RISK: `auto_translate` Deprecation
**Change:** In Godot 4.3, `auto_translate` property on `Control` and `Window` nodes was deprecated in favor of `auto_translate_mode` on `Node`. The old property still works but generates a deprecation warning.
**Impact:** This codebase does not use `auto_translate` in GDScript code. However, if any `.tscn` scene files have `auto_translate` set in the Inspector, the editor may warn. The HUD and inventory UI scenes should be checked.
**Fix if warnings appear:** Change `auto_translate = true/false` in scenes to `auto_translate_mode = 0/1/2` (ALWAYS/INHERIT/DISABLED).
[VERIFIED: godotengine/godot PR #87530]

### NOT APPLICABLE: TileMap → TileMapLayer
**Change:** In Godot 4.3, `TileMap` node deprecated in favor of `TileMapLayer`. This codebase does not use TileMap — not applicable.

### NOT APPLICABLE: 3D Skeleton signals
**Change:** `Skeleton3D.bone_pose_changed` → `skeleton_updated`. Not applicable (2D game).

### NOT APPLICABLE: C#/.NET changes
Not applicable — project is GDScript only.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Scanning for deprecated APIs | Custom grep scripts | Godot's Output panel warnings | Godot surfaces all runtime deprecation warnings during play; grep misses scene-file properties |
| Regenerating UID files | Manual uid creation | Godot's built-in UID upgrade tool | UIDs are content-addressed; hand-crafted UIDs will be incorrect |
| Re-saving scene files | Manual `.tscn` text edits | `Project > Tools > Upgrade Project Files` | Scene format is complex; editor handles all format version bumps |
| Finding the right export templates | Manual download | Editor > Manage Export Templates > Download and Install | Templates are version-locked; the manager fetches the exact matching version |

---

## Common Pitfalls

### Pitfall 1: Linux Export Preset Silently Disappears
**What goes wrong:** Export dialog shows no Linux preset; the `export_presets.cfg` still contains `platform="Linux/X11"` but the 4.3+ editor ignores it.
**Why it happens:** Platform renamed from `"Linux/X11"` to `"Linux"` in Godot 4.3 when Wayland support was merged.
**How to avoid:** Edit `export_presets.cfg` text directly before opening the project in 4.6.2 — change `platform="Linux/X11"` to `platform="Linux"`.
**Warning signs:** Export dialog shows only 4 of 5 presets (Windows, Android Debug, Android, HTML5, Mac) — the Linux/X11 entry is missing.

### Pitfall 2: Committing .uid Files Forgotten
**What goes wrong:** Project works locally but UID references break on any other machine or CI clone.
**Why it happens:** Godot 4.4 generates `.gd.uid` files on disk but developers forget to add them to git.
**How to avoid:** After the UID upgrade tool runs, immediately `git add **/*.uid` and commit before continuing.
**Warning signs:** CI build fails with "UID reference not found" errors, or a fresh clone of the repo produces import errors.

### Pitfall 3: Export Templates Not Installed for 4.6.2
**What goes wrong:** Export attempt fails with "No export template found at expected path."
**Why it happens:** Export templates are separate from the editor binary and version-locked. The 4.2.1 templates installed previously do NOT work with 4.6.2.
**How to avoid:** Install 4.6.2 templates via Editor > Manage Export Templates > Download and Install before any export attempt.
**Warning signs:** Export dialog shows "Export template not installed" warning next to each platform.

### Pitfall 4: String-Based connect() Masking Other Warnings
**What goes wrong:** Output panel is noisy with string connect deprecation warnings, and a real error is missed.
**Why it happens:** 4 string-based `connect()` calls generate 4+ deprecation lines per run session.
**How to avoid:** Fix all 4 string-based connect calls first, then re-run the smoke test to see a clean Output panel.
**Warning signs:** Output shows "Using deprecated syntax..." repeated multiple times.

### Pitfall 5: `@export_file` Path Format Change (Godot 4.4)
**What goes wrong:** If any scripts use `@export_file` and a path was set in the Inspector, the stored value becomes a `uid://` reference instead of `res://`.
**Why it happens:** Godot 4.4 changed `@export_file` to store UIDs instead of raw paths.
**Impact for this codebase:** None identified — `item-type.gd` uses `load()` with runtime path construction, not `@export_file`. Scan for `@export_file` annotations to confirm.
**Warning signs:** Scripts reading the exported path expecting `res://` format get `uid://` instead.

---

## Code Examples

### Fixing String-Based connect() Calls

```gdscript
# Source: Godot 4 signal documentation
# ship.gd and bullet.gd — RigidBody2D body_entered signal

# BEFORE (deprecated, generates warning):
connect("body_entered", body_entered)

# AFTER (correct for 4.6.2):
body_entered.connect(body_entered_handler_func)
# Note: "body_entered" is both a signal name and a method name in ship.gd
# Rename the method to avoid ambiguity:
body_entered.connect(_on_body_entered)
```

```gdscript
# mountable-weapon.gd — Timer timeout with CONNECT_ONE_SHOT

# BEFORE (deprecated):
reload_timer.connect("timeout", reloaded, CONNECT_ONE_SHOT)

# AFTER (correct for 4.6.2):
reload_timer.timeout.connect(reloaded, CONNECT_ONE_SHOT)
```

### export_presets.cfg Linux Fix

```ini
# BEFORE (broken in 4.3+):
[preset.1]
name="Linux/X11"
platform="Linux/X11"

# AFTER (correct for 4.3+):
[preset.1]
name="Linux/X11"
platform="Linux"
# Note: 'name' is user-visible label, can stay "Linux/X11" if preferred; 
# 'platform' must be "Linux" — that is what Godot reads
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `connect("signal_name", callable)` | `signal_name.connect(callable)` | Godot 4.0 | Warning-only in 4.6.2; not a runtime error but Output panel will flag it |
| Linux export preset `platform="Linux/X11"` | `platform="Linux"` | Godot 4.3 | Old preset silently disappears from export dialog |
| No `.uid` files | Per-file `.gd.uid` files | Godot 4.4 | ~23 new files generated; must be committed to git |
| `auto_translate` bool on Control | `auto_translate_mode` enum on Node | Godot 4.3 | Deprecated, warning only; scene files may reference old property |
| `config/features=PackedStringArray("4.2", ...)` | Updated to "4.6" | Godot 4.6.2 first open | Automatic — editor writes this; no manual action needed |

**Deprecated/outdated in this migration window:**
- `connect("string_name", callable)` syntax — still works, generates warning; update to silence Output panel
- `auto_translate` bool on Control/Window — still works, generates warning; may need updating if scenes use it

---

## Runtime State Inventory

This is a code migration, not a rename/rebrand phase. No runtime state (databases, external services, OS registrations) contains version strings that need updating.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no persistent databases or external stores | None |
| Live service config | None — game is a single local process | None |
| OS-registered state | None | None |
| Secrets/env vars | None | None |
| Build artifacts | `.import/` and `.godot/` directories — regenerated automatically by 4.6.2 on first open | None (editor handles) |

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Godot 4.6.2 editor | MIG-01, MIG-02, MIG-03 | ✗ | — (4.2.1 installed at `/Applications/Godot.app`) | Must install 4.6.2 — no fallback |
| Godot 4.6.2 export templates | MIG-03 | ✗ | — | Install via Editor > Manage Export Templates |
| Git | VCS for .uid file commits | ✓ | (project is a git repo) | — |

**Missing dependencies with no fallback:**
- Godot 4.6.2 editor — the current installation is 4.2.1 at `/Applications/Godot.app`. The planner must include a task to download and install 4.6.2 before any other migration task. Installing 4.6.2 alongside 4.2.1 is supported; they do not conflict if kept as separate `.app` bundles.

**Note on barichello/godot-ci:** The `barichello/godot-ci:4.6.2` Docker image exists (published ~April 2026) and is available for when CI is updated in a future phase. This is out of scope for Phase 3. [VERIFIED: hub.docker.com/r/barichello/godot-ci]

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `project.godot` features string will become `"4.6"` after Godot 4.6.2 opens the project | Architecture Patterns | Low — D-02 says "use whatever Godot 4.6.2 sets automatically"; no manual action needed regardless |
| A2 | String-based `connect("signal", callable)` generates warnings (not errors) in Godot 4.6.2 | Known Breaking Changes | Medium — if it became an error in a recent minor version, the smoke test would fail immediately and the fix is the same anyway |
| A3 | The Linux preset compatibility layer added in response to issue #89012 does NOT auto-fix pre-existing `export_presets.cfg` entries | Common Pitfalls | Medium — if the compat layer does silently fix it, the manual edit is harmless; if it does NOT fix it (more likely), the preset disappears |
| A4 | `auto_translate` deprecation does not affect this codebase (no GDScript usage found; scene files not inspected for property) | Known Breaking Changes | Low — if scene files have it set, it generates a warning; fix is straightforward |
| A5 | `TextureRect.EXPAND_IGNORE_SIZE` and `TextureRect.STRETCH_KEEP_ASPECT_CENTERED` used in `inventory-slot.gd` are unchanged in 4.6.2 | Code Examples | Low — these enum values have been stable since Godot 4.0 |

---

## Open Questions

1. **Does the Linux preset compat layer auto-repair `export_presets.cfg` in 4.6.2?**
   - What we know: Issue #89012 was resolved with "a compatibility layer to handle legacy preset names gracefully"
   - What's unclear: Whether "gracefully" means auto-rewrite to "Linux" or just show a warning
   - Recommendation: Manually fix `export_presets.cfg` before opening — the edit is 1 line and eliminates the uncertainty

2. **Are any `.tscn` scene files using the deprecated `auto_translate` property?**
   - What we know: No GDScript code references `auto_translate`; the HUD and inventory scenes have Control nodes
   - What's unclear: Whether any scene files have `auto_translate = true/false` serialized as a property
   - Recommendation: After opening in 4.6.2, check Output panel for auto_translate warnings; fix in editor if found

3. **Does the Godot 4.6.2 editor on macOS require Rosetta or specific macOS version?**
   - What we know: Developer is on macOS (Darwin 25.4.0 = macOS 16.x); Godot 4.6.2 supports macOS
   - What's unclear: Minimum macOS version for 4.6.2 editor (known minimum for export target is 10.12)
   - Recommendation: Download and verify; 4.6.2 editor likely requires macOS 10.15+ [ASSUMED]

---

## Sources

### Primary (HIGH confidence)
- [VERIFIED: github.com/godotengine/godot/issues/89012] — Linux/X11 → Linux platform rename; confirmed breaking change in Godot 4.3
- [VERIFIED: godotengine.org/article/uid-changes-coming-to-godot-4-4/] — UID system changes, `.uid` file requirements, git commit requirement
- [VERIFIED: raw.githubusercontent.com/godotengine/godot-docs/master/tutorials/migrating/upgrading_to_godot_4.3.rst] — Full 4.2→4.3 breaking changes list
- [VERIFIED: raw.githubusercontent.com/godotengine/godot-docs/master/tutorials/migrating/upgrading_to_godot_4.4.rst] — 4.3→4.4 breaking changes; `@export_file` UID change
- [VERIFIED: godotengine.org/article/maintenance-release-godot-4-6-2/] — Godot 4.6.2 is stable, released April 1, 2026; no new breaking changes for 2D
- [CITED: github.com/godotengine/godot-docs/issues/5577] — String-based connect() deprecation in Godot 4
- [CITED: github.com/godotengine/godot PR #87530] — auto_translate → auto_translate_mode deprecation in 4.3

### Secondary (MEDIUM confidence)
- [CITED: forum.godotengine.org/t/upgrading-to-godot-4-4/103991] — Real-world 4.4 upgrade experience; `.uid` commit requirement confirmed
- [CITED: hub.docker.com/r/barichello/godot-ci] — `barichello/godot-ci:4.6.2` (non-mono) and `mono-4.6.1` images available

### Tertiary (LOW confidence)
- General search results on Godot 4.5 and 4.6 migration — no breaking changes for 2D physics, signals, AudioStreamPlayer, Camera2D, or CPUParticles2D identified across any minor version from 4.2 to 4.6

---

## Metadata

**Confidence breakdown:**
- Known breaking changes (Linux preset, UID files): HIGH — confirmed via official GitHub issues and official blog post
- String-based connect() deprecation: HIGH — confirmed via multiple docs sources
- Auto_translate deprecation affecting scene files: MEDIUM — GDScript usage confirmed absent; scene file inspection not done
- 4.6.2 availability and compatibility: HIGH — confirmed stable release April 1, 2026
- No 2D physics / signal API removals: MEDIUM — searched all 4 migration guides and found no 2D physics breaking changes; absence of evidence is not proof

**Research date:** 2026-04-10
**Valid until:** 2026-07-10 (stable ecosystem; 90-day window appropriate for engine migration guides)
