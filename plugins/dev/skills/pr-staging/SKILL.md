---
name: pr-staging
description: Cut a release branch from `develop`, bump the version to RC, and create a PR to `staging` following GitFlow and semver conventions.
---

Cut a release branch from `develop`, bump the version, and create a PR from `release/vX.X.X` to `staging` following GitFlow and semver conventions. Follow these steps exactly:

## Step 1 — Protected branch guard

Run `git branch --show-current`. If the current branch is NOT `develop`, stop and tell the user:

> "This skill must be run from `develop`. You are currently on `<branch>`. Please switch to `develop` and try again."

Do **not** continue with any further steps.

## Step 2 — Sync and validate develop

Run `git status`. If there are uncommitted changes, stop and tell the user:

> "There are uncommitted changes on `develop`. Please commit or stash them before cutting a release branch."

Do **not** continue with any further steps if there are uncommitted changes.

Sync with the remote to ensure the comparison is accurate:
```bash
git fetch origin
git pull origin develop
```

If `git pull` results in a merge conflict, stop and tell the user to resolve conflicts before proceeding.

## Step 3 — Analyze commits since last version

Run in parallel:
- `git log origin/staging..HEAD --oneline 2>/dev/null || git log $(git describe --tags --abbrev=0 2>/dev/null || git rev-list --max-parents=0 HEAD)..HEAD --oneline` — commits not yet in staging (uses remote ref, falls back to last tag)
- `git diff origin/staging...HEAD --stat 2>/dev/null || git diff HEAD~5...HEAD --stat` — summary of changed files

If the commit list is empty (no commits ahead of staging), stop and tell the user:
> "There are no new commits on `develop` that aren't already in `staging`. Nothing to release."

Determine the version bump type from Conventional Commit messages (ignore `chore(release):` bump commits themselves):
- Any `BREAKING CHANGE` footer or `!` after type → **major**
- Any `feat:` → **minor**
- Any `fix:` or anything else → **patch**

Detect the project's version file by checking in this order:
1. `package.json` (Node.js) — read `"version"` field
2. `pyproject.toml` (Python) — read `version` under `[project]` or `[tool.poetry]`
3. `Cargo.toml` (Rust) — read `version` under `[package]`
4. `pom.xml` (Java/Maven) — read `<version>` under `<project>`
5. `build.gradle` / `build.gradle.kts` (Kotlin/Gradle) — read `version = "..."`
6. `VERSION` or `version.txt` — read the file contents directly

Use the first file found. If none are found, ask the user where the version is tracked.

Calculate the next version:
- Strip any existing pre-release suffix from the current version to get the base
- Apply the bump to the base version
- Append `-rc.1`
- Example: `1.0.0` + fix → `1.0.1-rc.1`, `1.0.0` + feat → `1.1.0-rc.1`

Check if a release branch for this version already exists:
```bash
git branch --list "release/v<base-version>"
git branch -r --list "origin/release/v<base-version>"
```

If a release branch already exists, increment the RC counter (e.g., `1.0.1-rc.2`).

Show the user the proposed bump:
> "Proposed version bump: `<current>` → `<next>` (based on <bump-type> change). Release branch: `release/v<base-version>`. Confirm?"

Only continue after explicit user approval.

## Step 4 — Create release branch from develop

```bash
git checkout -b release/v<base-version>
```

Where `<base-version>` is the version WITHOUT the `-rc.N` suffix (e.g., `release/v1.0.2`).

## Step 5 — Bump version in the version file

Update the version to the new RC value (e.g., `1.0.2-rc.1`) in the version file detected in Step 3 (`package.json`, `pyproject.toml`, `Cargo.toml`, etc.).

Show the commit message to the user and ask for approval before committing:

```bash
git add <version-file>
git commit -m "chore(release): bump version to <version>"
```

## Step 6 — Push release branch to origin

Show the user:
> "Ready to push `release/v<base-version>` to origin. Confirm?"

Only run after explicit user approval:
```bash
git push -u origin release/v<base-version>
```

If push fails due to diverged remote, explain and ask whether to rebase. **Never force-push without explicit approval.**

## Step 7 — Check for existing PR and create

Check if a PR already exists:
```bash
gh pr list --head "release/v<base-version>" --base staging --json number,url,title
```

If a PR already exists, show its URL and ask the user whether to skip creation.

Otherwise, show the full PR draft and ask:
> "Ready to create PR `release/v<base-version>` → `staging` with title `release: v<next-version>`. Confirm?"

Only run `gh pr create` after explicit user approval:

```bash
gh pr create --base staging --head "release/v<base-version>" --title "release: v<next-version>" --body "..."
```

PR body structure:

```markdown
## Release v<next-version>

<!-- one-line description of what this release contains -->

## Changes

<!-- List of all commits since last version, grouped by type -->
### Features
- <feat commits>

### Bug Fixes
- <fix commits>

### Maintenance
- <chore/refactor/docs commits>

## Type of change

- [ ] New feature
- [ ] Bug fix
- [ ] Hotfix
- [ ] Refactor
- [x] Release / staging promotion

## Database migrations

<!-- YES/NO. If yes, list the migration files -->

## Breaking changes

<!-- YES/NO. If yes, describe impact and migration path -->

## Testing

<!-- What to validate in staging -->

## Post-merge checklist

- [ ] Merge `release/v<base-version>` back into `develop` after staging approval
- [ ] Delete the release branch after all merges are complete

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

Fill every section based on the commit analysis. Do **not** leave placeholder text.

## Step 8 — Report result

Output:
- The PR URL
- The version promoted (`<previous>` → `<next>`)
- A one-line summary of what ships in this RC
- Reminder:
  > **After this PR is merged to staging:** run `/pr-production` from the `staging` branch to promote to `master`. Then back-merge `release/v<base-version>` into `develop` and delete the release branch.

---

## Rules & guardrails

- **Always ask for explicit user approval** before: creating release branch, version bump commit, push, and PR creation
- **Never** run this skill from a branch other than `develop`
- **Never** bump version directly on `develop` — version bumps belong on the release branch
- **Never** force-push without explicit user approval
- The RC counter (`-rc.N`) resets to 1 for each new base version; increment it if a release branch for the same base version already exists
- **Always use `gh` CLI** for all GitHub operations
- If `gh` CLI is not authenticated, tell the user to run `! gh auth login`
