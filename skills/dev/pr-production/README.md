# pr-production

Finalize the RC version on `staging` and create a PR from `staging` to `master` for production release following GitFlow conventions.

**Version:** 1.0.0 | **Author:** @lety-ai | **Category:** dev

## When to use

Run this from `staging` after QA has validated the release candidate and it's ready to ship to production.

## Usage

```
/pr-production
```

Must be run from the `staging` branch. The version must contain `-rc`.

## What it does

1. Validates you're on `staging` with an RC version
2. Analyzes all commits ahead of `master`
3. Strips the `-rc.N` suffix from the version (e.g., `1.1.0-rc.1` → `1.1.0`) (with your approval)
4. Pushes the finalized version to staging (with your approval)
5. Creates PR `staging` → `master` with full release notes (with your approval)
6. Reminds you to tag the release and back-merge into `develop` after merge

## Requirements

- `gh` CLI installed and authenticated
- Must be run from `staging`
- Current version must contain `-rc` suffix

## Installation

```bash
cp skill.md ~/.claude/skills/pr-production.md
```

## Related skills

- `/pr-develop` — create PR from working branch to develop
- `/pr-staging` — cut release branch and PR to staging
