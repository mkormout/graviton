---
phase: quick-260419-jxl
plan: "01"
subsystem: ci-cd
tags: [ci, github-actions, checkout, permissions, release]
dependency_graph:
  requires: []
  provides: [working-ci-export-jobs, github-release-creation]
  affects: [.github/workflows/gitlab-ci.yml]
tech_stack:
  added: []
  patterns: [job-scoped-permissions]
key_files:
  modified:
    - .github/workflows/gitlab-ci.yml
decisions:
  - "Used job-scoped permissions on release job only — not a top-level workflow permission — to keep export jobs at minimal default scopes"
metrics:
  duration: "3 minutes"
  completed: "2026-04-19"
  tasks_completed: 1
  files_modified: 1
---

# Quick Task 260419-jxl: Fix CI/CD Pipeline Deployment Failure — Summary

**One-liner:** Upgraded 4 export jobs from deprecated `actions/checkout@v2` to `@v4` and added job-scoped `permissions: contents: write` to the `release` job so `softprops/action-gh-release@v1` can create GitHub Releases.

## What Was Done

### Edit A — Upgrade checkout action in all four export jobs

Replaced every occurrence of `uses: actions/checkout@v2` with `uses: actions/checkout@v4` in:
- `export-windows`
- `export-linux`
- `export-web`
- `export-mac`

The `with: lfs: true` arguments were left untouched. The two jobs already on `@v4` (`deploy-web`, `release`) were not modified.

**Reason:** GitHub deprecated Node.js 16 (used by `checkout@v2`) in May 2024. These four export jobs were failing at the Checkout step with a Node.js 16 deprecation error.

### Edit B — Add `permissions: contents: write` to the `release` job

Inserted a job-scoped `permissions:` block immediately after `needs: [export-windows, export-linux, export-mac]` and before `steps:` in the `release` job:

```yaml
    permissions:
      contents: write
```

**Reason:** GitHub's default `GITHUB_TOKEN` no longer includes write scopes by default. Without this, `softprops/action-gh-release@v1` silently fails to create or update the `latest` GitHub Release.

**Scope:** Job-scoped only — the export jobs retain their minimal default scopes, which is the correct security posture.

## Verification Results

| Check | Result |
|-------|--------|
| `grep -c 'actions/checkout@v2'` | 0 (none remain) |
| `grep -c 'actions/checkout@v4'` | 6 (4 export + deploy-web + release) |
| `release` job has `permissions: contents: write` | Confirmed |
| YAML structure valid (Python structure checks) | Passed |
| Git diff — lines changed | 4 modifications + 2 insertions, nothing else |
| Unexpected file deletions | None |

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- Commit `5995e7a` exists: confirmed
- `.github/workflows/gitlab-ci.yml` modified: confirmed
- 0 occurrences of `@v2`, 6 occurrences of `@v4`: confirmed
- `permissions: contents: write` present in `release` job: confirmed
