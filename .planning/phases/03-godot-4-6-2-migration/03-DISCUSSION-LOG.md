# Phase 3: Godot 4.6.2 Migration - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-10
**Phase:** 03-godot-4-6-2-migration
**Areas discussed:** API scan strategy, Export target scope, CI pipeline update, Validation method

---

## API Scan Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Run in 4.6.2, chase errors | Open project in 4.6.2 editor, let Godot's built-in conversion assistant flag issues, fix as they surface | ✓ |
| Pre-scan .gd files manually | Read each .gd file and cross-reference Godot 4.2→4.6 changelogs before touching the editor | |
| Headless lint first | Run `godot --headless --check-only` on 4.6.2 to get a machine-readable error list | |

**User's choice:** Run in 4.6.2, chase errors
**Notes:** Godot's built-in converter is the fastest and most accurate path — it knows what changed between versions.

---

## Export Target Scope

| Option | Description | Selected |
|--------|-------------|----------|
| All 4 (Windows/Linux/Mac/Web) | CI already builds all 4 — verify all of them keep CI green | ✓ |
| Web only | Web is the only publicly deployed target (GitHub Pages) | |
| One platform minimum | Match the literal MIG-03 requirement | |

**User's choice:** All 4 platforms (Windows/Linux/Mac/Web)
**Notes:** Web deploys to GitHub Pages via CI — verifying all 4 keeps consistency with existing CI setup.

---

## CI Pipeline Update

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — in scope | Update gitlab-ci.yml from barichello/godot-ci:4.2.1 to 4.6.2 as part of this phase | |
| No — out of scope | CI update is a separate concern; verify exports locally for MIG-03 | ✓ |

**User's choice:** Out of scope
**Notes:** Deferred to a follow-up. Local export verification satisfies MIG-03.

---

## Validation Method

| Option | Description | Selected |
|--------|-------------|----------|
| Editor run + manual smoke test | Open in 4.6.2, run game, check Output panel, move ship, fire weapons, swap items | ✓ |
| Headless export compile only | Run `godot --headless --export-release` — if it compiles clean, MIG-02 passes | |
| Both — compile + manual play | Headless export + manual playtesting | |

**User's choice:** Editor run + manual smoke test
**Notes:** Smoke test covers the real gameplay paths: ship movement, all weapon types, inventory drag-drop.

---

## Claude's Discretion

- Order in which API errors are fixed (address them as Godot surfaces them)
- Exact features string value in `project.godot` after migration (use whatever Godot 4.6.2 sets automatically)

## Deferred Ideas

- CI pipeline update (`.github/workflows/gitlab-ci.yml`) — explicitly deferred, noted as a quick follow-up after migration is verified
