---
phase: quick-260419-jxl
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - .github/workflows/gitlab-ci.yml
autonomous: true
requirements:
  - QUICK-CI-01
  - QUICK-CI-02

must_haves:
  truths:
    - "All four export jobs (windows, linux, web, mac) check out the repo using actions/checkout@v4"
    - "No job in the workflow still references the deprecated actions/checkout@v2"
    - "The release job has permissions: contents: write so softprops/action-gh-release@v1 can create releases"
    - "YAML remains syntactically valid (loadable by GitHub Actions / any YAML parser)"
  artifacts:
    - path: ".github/workflows/gitlab-ci.yml"
      provides: "Updated CI workflow with checkout@v4 everywhere and release write permissions"
      contains: "actions/checkout@v4"
  key_links:
    - from: ".github/workflows/gitlab-ci.yml (release job)"
      to: "softprops/action-gh-release@v1"
      via: "permissions.contents: write"
      pattern: "permissions:\\s*\\n\\s*contents:\\s*write"
    - from: "export-windows / export-linux / export-web / export-mac jobs"
      to: "repository source code"
      via: "actions/checkout@v4 with lfs: true"
      pattern: "actions/checkout@v4"
---

<objective>
Fix the CI/CD pipeline deployment failure in `.github/workflows/gitlab-ci.yml` by:
1. Upgrading the four export jobs from the deprecated `actions/checkout@v2` to `actions/checkout@v4`
2. Granting the `release` job `contents: write` permission so `softprops/action-gh-release@v1` can create GitHub Releases.

Purpose: GitHub deprecated Node.js 16 (used by `checkout@v2`) in May 2024 — the export jobs currently fail at the checkout step. Additionally, the default `GITHUB_TOKEN` no longer includes write scopes by default, so the release step silently fails without explicit permissions.

Output: A single updated workflow file that passes on the next push.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.github/workflows/gitlab-ci.yml

<interfaces>
<!-- Current state of the workflow (relevant excerpts) — no codebase exploration needed. -->

Jobs using the deprecated action (MUST be updated to @v4):
- `export-windows` (line ~17):   `uses: actions/checkout@v2` with `lfs: true`
- `export-linux`   (line ~42):   `uses: actions/checkout@v2` with `lfs: true`
- `export-web`     (line ~67):   `uses: actions/checkout@v2` with `lfs: true`
- `export-mac`     (line ~114):  `uses: actions/checkout@v2` with `lfs: true`

Jobs already on `@v4` (do NOT touch their checkout step):
- `deploy-web`  (line ~91)
- `release`     (line ~137)

Release job (line ~131) — needs a `permissions:` block added under the job:
```yaml
release:
  name: Create GitHub Release
  runs-on: ubuntu-22.04
  needs: [export-windows, export-linux, export-mac]
  permissions:
    contents: write            # <-- ADD THIS BLOCK
  steps:
    - name: Checkout
      uses: actions/checkout@v4
    ...
    - name: Create GitHub Release and Upload Binaries
      uses: softprops/action-gh-release@v1
      ...
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Upgrade checkout action and grant release write permissions</name>
  <files>.github/workflows/gitlab-ci.yml</files>
  <action>
Make TWO edits to `.github/workflows/gitlab-ci.yml`:

**Edit A — Upgrade checkout action in all four export jobs.**
Replace every occurrence of `uses: actions/checkout@v2` with `uses: actions/checkout@v4`. There are exactly 4 occurrences (export-windows, export-linux, export-web, export-mac). Do NOT change the `with: lfs: true` arguments — just the version tag on the `uses:` line. Leave the existing `@v4` usages in `deploy-web` and `release` untouched.

**Edit B — Add `permissions: contents: write` to the `release` job.**
Locate the `release:` job (around line 131). Immediately after the `needs: [export-windows, export-linux, export-mac]` line and before the `steps:` line, insert:

```yaml
    permissions:
      contents: write
```

Match the existing indentation of job-level keys like `name:`, `runs-on:`, `needs:` (4 spaces from column 0, since the job key `release:` is at 2 spaces). Do NOT modify any other job. Do NOT add a top-level (workflow-level) `permissions:` block — it must be job-scoped so the export jobs retain their default minimal scopes.

After editing, verify no stray `@v2` references remain and the YAML parses cleanly (see verify below).
  </action>
  <verify>
    <automated>grep -c 'actions/checkout@v2' .github/workflows/gitlab-ci.yml | grep -q '^0$' && grep -c 'actions/checkout@v4' .github/workflows/gitlab-ci.yml | awk '$1 >= 6 {exit 0} {exit 1}' && grep -A1 '^  release:' .github/workflows/gitlab-ci.yml | head -20 | grep -q 'contents: write' || (awk '/^  release:/,/^  [a-z]/' .github/workflows/gitlab-ci.yml | grep -q 'contents: write') && python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/gitlab-ci.yml'))" && echo OK</automated>
  </verify>
  <done>
- `grep 'actions/checkout@v2' .github/workflows/gitlab-ci.yml` returns zero matches
- `grep -c 'actions/checkout@v4' .github/workflows/gitlab-ci.yml` returns 6 (4 export jobs + deploy-web + release)
- The `release` job has a `permissions:` block with `contents: write`
- `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/gitlab-ci.yml'))"` succeeds (file is valid YAML)
- No other jobs or lines in the workflow have been modified
  </done>
</task>

</tasks>

<verification>
Full-file sanity pass after the edit:

1. **No deprecated action remains:**
   `grep 'actions/checkout@v2' .github/workflows/gitlab-ci.yml` — must be empty.

2. **All six checkout usages are on @v4:**
   `grep -c 'actions/checkout@v4' .github/workflows/gitlab-ci.yml` — must return `6`.

3. **Release job has write permission:**
   Inspect lines ~131–140 and confirm:
   ```yaml
   release:
     name: Create GitHub Release
     runs-on: ubuntu-22.04
     needs: [export-windows, export-linux, export-mac]
     permissions:
       contents: write
     steps:
   ```

4. **Workflow still parses:**
   `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/gitlab-ci.yml'))"` exits 0.

5. **No unintended diff:**
   `git diff .github/workflows/gitlab-ci.yml` should show only:
   - 4 lines changed (`@v2` → `@v4`)
   - 2 lines added (`permissions:` + `contents: write`)
   Total: 4 modifications + 2 insertions, nothing else.
</verification>

<success_criteria>
- `.github/workflows/gitlab-ci.yml` no longer contains `actions/checkout@v2`
- The `release` job explicitly grants `contents: write` via a job-scoped `permissions` block
- YAML is syntactically valid
- On the next `push`, the four export jobs complete the Checkout step without the Node.js 16 deprecation failure, and the `release` job can create/update the `latest` GitHub Release
- No other jobs, steps, or env vars were modified
</success_criteria>

<output>
After completion, create `.planning/quick/260419-jxl-fix-ci-cd-pipeline-deployment-failure/260419-jxl-SUMMARY.md` using the standard summary template, covering:
- Which jobs were upgraded to `checkout@v4`
- That `permissions: contents: write` was added to the `release` job only (job-scoped, not workflow-scoped)
- Confirmation that YAML still parses and git diff is minimal
</output>
