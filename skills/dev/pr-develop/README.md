# pr-develop

Create a PR from a feature/fix/chore branch to `develop` following GitFlow conventions and Conventional Commits standard.

**Version:** 1.0.0 | **Author:** @lety-ai | **Category:** dev

## When to use

Run this from any working branch (`feature/*`, `fix/*`, `chore/*`, `refactor/*`, etc.) when you're ready to open a PR to `develop`.

Also handles `hotfix/*` branches, which create PRs to both `develop` and `master`.

## Usage

```
/pr-develop
```

No arguments needed. The skill analyzes the current branch automatically.

## What it does

1. Validates branch name follows GitFlow conventions
2. Analyzes all changes (diff + commits) since `develop`
3. Stages and commits any uncommitted changes (with your approval)
4. Pushes the branch to origin (with your approval)
5. Creates a PR to `develop` with a structured body (with your approval)
6. For `hotfix/*`: also creates a PR to `master`

## Requirements

- `gh` CLI installed and authenticated (`gh auth login`)
- GitFlow branch naming: `feature/*`, `fix/*`, `bugfix/*`, `hotfix/*`, `chore/*`, `refactor/*`, `docs/*`, `test/*`

## Installation

```bash
cp skill.md ~/.claude/skills/pr-develop.md
```

## Related skills

- `/pr-staging` — cut release branch and PR to staging
- `/pr-production` — finalize RC and PR to master
