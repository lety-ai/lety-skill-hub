# pr-staging

Cut a release branch from `develop`, bump the version to RC, and create a PR to `staging` following GitFlow and semver conventions.

**Version:** 1.0.0 | **Author:** @lety-ai | **Category:** dev

## When to use

Run this from `develop` when you're ready to promote the next batch of features to staging for QA validation.

## Usage

```
/pr-staging
```

Must be run from the `develop` branch with no uncommitted changes.

## What it does

1. Validates you're on `develop` with no uncommitted changes
2. Analyzes commits since last staging/tag to determine version bump (major/minor/patch)
3. Calculates next RC version (e.g., `1.0.0` → `1.1.0-rc.1`)
4. Creates `release/vX.X.X` branch (with your approval)
5. Bumps version in `package.json` / `pyproject.toml` / `Cargo.toml` / etc. (with your approval)
6. Pushes release branch (with your approval)
7. Creates PR `release/vX.X.X` → `staging` (with your approval)

## Requirements

- `gh` CLI installed and authenticated
- Must be run from `develop`
- No uncommitted changes on `develop`

## Installation

```bash
cp skill.md ~/.claude/skills/pr-staging.md
```

## Related skills

- `/pr-develop` — create PR from working branch to develop
- `/pr-production` — finalize RC and PR to master
