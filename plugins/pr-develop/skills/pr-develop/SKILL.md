---
name: pr-develop
description: Analyze the current branch and create a PR to `develop` following GitFlow conventions and Conventional Commits standard.
---

Analyze the current branch and create a PR to `develop` following GitFlow conventions and Conventional Commits standard. Follow these steps exactly:

> **Version policy**: PRs to `develop` never touch `package.json` version. Version bumps happen only on `release/*` branches, cut via the `/pr-staging` skill.

> **GitFlow reminder**: The release flow is `develop` → `release/vX.X.X` → `staging` → `master`. Never bump version directly on `develop` or `staging`.

## Step 1 — Validate branch name (GitFlow)

Run `git branch --show-current` to get the current branch.

### 1a — Protected branch guard

If the current branch is any of: `develop`, `staging`, `master`, `main` — **stop immediately** and tell the user:

> "You are currently on `<branch>`, which is a protected branch. PRs must be created from a working branch (feature/*, fix/*, chore/*, etc.), never directly from `<branch>`. Please switch to your working branch and try again."

Do **not** continue with any further steps.

### 1b — Release branch intercept

If the current branch matches `release/*`, **stop immediately** and tell the user:

> "You are on a `release/*` branch. This branch is managed by `/pr-staging` (release → staging) and `/pr-production` (staging → master). Run `/pr-staging` instead."

Do **not** continue with any further steps.

### 1c — GitFlow naming check

Verify the branch follows GitFlow naming:
- `feature/<ticket-or-description>` → new feature
- `fix/<ticket-or-description>` or `bugfix/<ticket-or-description>` → bug fix
- `hotfix/<ticket-or-description>` → urgent production fix
- `chore/<ticket-or-description>` → maintenance, deps, config
- `refactor/<ticket-or-description>` → code refactor without behavior change
- `docs/<ticket-or-description>` → documentation only
- `test/<ticket-or-description>` → tests only

If the branch name does NOT match any of these patterns, warn the user and ask for confirmation before continuing.

The base branch for the PR is always **`develop`**, **except** for `hotfix/*` branches — see Step 6.

## Step 2 — Analyze changes

First, sync with the remote to ensure comparisons are accurate:
```bash
git fetch origin
```

Then run in parallel:
- `git log origin/develop..HEAD --oneline` — list commits not yet in develop (uses remote, not stale local)
- `git diff origin/develop...HEAD --stat` — summary of changed files
- `git diff origin/develop...HEAD` — full diff (to understand what changed and why)

Carefully read all diffs and commit messages to understand:
- What was built, fixed, or changed
- Which modules, packages, or services were touched
- Any migration, config, or breaking change

## Step 3 — Stage and commit uncommitted changes (if any)

Run `git status`. If there are uncommitted changes:
1. Show the user what will be staged
2. Run `git add -p` is NOT available in non-interactive mode — instead, stage all tracked changes with `git add -u` and new relevant files explicitly (avoid `.env`, secrets, binaries)
3. Generate a **Conventional Commit** message following the format:

```
<type>(<scope>): <short imperative summary, max 72 chars>

<body — what was done and why, wrapped at 72 chars>

<footer — breaking changes, issue refs if available>
```

**Types**: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `perf`, `ci`, `build`
**Scope**: the module, package, or domain affected (e.g., the directory name, feature area, or service that changed)

Rules:
- Subject line: imperative mood, lowercase after type, no period at end
- Body: explain *what* and *why*, not *how*
- If there are multiple logical changes, list them in the body with `-` bullets
- BREAKING CHANGE footer only if the change breaks a public API or contract

**Before committing**: show the proposed commit message to the user and ask for explicit approval. Only run `git commit` after the user confirms.

Commit using a HEREDOC to avoid escaping issues.

## Step 4 — Push branch to origin

**Before pushing**: show the user the branch name and target remote, then ask:
> "Ready to push `<branch>` to origin. Confirm?"

Only run `git push -u origin HEAD` after the user explicitly approves.

If the push fails because the remote branch has diverged (non-fast-forward), explain the situation to the user and ask whether to rebase or force-push. **Never force-push without explicit user approval.**

## Step 5 — Create PR to `develop` using `gh` CLI

First check if a PR already exists for this branch:
```bash
gh pr list --head "$(git branch --show-current)" --base develop --json number,url,title
```

If a PR already exists, show the URL and skip creation.

Otherwise, draft the full PR (title + body) and **show it to the user for approval before creating it**. Ask:
> "Ready to create this PR to `develop`. Confirm?"

Only run `gh pr create` after the user explicitly approves.

The PR title must follow Conventional Commits format (same as the commit subject if there's only one commit, otherwise a summary of all commits).

PR body structure:

```markdown
## Summary

<!-- 2-4 bullet points describing what this PR does -->

## Changes

<!-- Grouped by service/module. For each group: -->
### <Service or Module Name>
- <change 1>
- <change 2>

## Type of change

<!-- Check the box that matches the branch prefix: feature/* → New feature, fix/bugfix/* → Bug fix, hotfix/* → Hotfix, refactor/* → Refactor, chore/* → Chore, docs/* → Documentation, test/* → Tests -->
- [ ] New feature
- [ ] Bug fix
- [ ] Hotfix
- [ ] Refactor
- [ ] Chore / maintenance
- [ ] Documentation
- [ ] Tests

## Database migrations

<!-- YES/NO. If yes, list the migration files -->

## Breaking changes

<!-- YES/NO. If yes, describe impact and migration path -->

## Testing

<!-- Briefly describe how changes were tested or how to test manually -->

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

Fill every section based on your analysis of the diff. Do **not** leave placeholder text — write real content.

For "Type of change", mark the correct checkbox with `[x]` based on the branch prefix (e.g., `feature/*` → New feature, `fix/*` or `bugfix/*` → Bug fix, `hotfix/*` → Hotfix, `refactor/*` → Refactor, `chore/*` → Chore, `docs/*` → Documentation, `test/*` → Tests).

Run:
```bash
gh pr create --base develop --title "<title>" --body "$(cat <<'EOF'
<body>
EOF
)"
```

After creation, run `gh pr view --json url,title,number` to get the PR details.

## Step 6 — Hotfix: create PRs to `master` AND `develop`

If the current branch is `hotfix/*`, GitFlow requires merging to **both `master` and `develop`** — and `master` comes first because the goal is to fix production urgently. Hotfixes **bypass** `staging` entirely to avoid deploying unvalidated features.

After the PR to `develop` is created (Step 5), also create a PR to `master`:

> "This is a hotfix. In GitFlow, hotfixes must be merged to `master` first (to fix production immediately) and then back-merged to `develop`. Do you want me to create the PR to `master` now?"

If the user confirms, run:
```bash
gh pr create --base master --title "<same-title>" --body "$(cat <<'EOF'
<same-body>
EOF
)"
```

After both PRs are created, remind the user:
> ⚠️ Merge the `master` PR first to fix production. Then merge the `develop` PR to back-merge the fix. Once merged to `master`, tag the hotfix release:
> ```bash
> git tag -a v<hotfix-version> -m "Hotfix v<hotfix-version>"
> git push origin v<hotfix-version>
> ```

## Step 7 — Report result

After the PR is created (or already existed), output:
- The PR URL (from `gh pr view`)
- The PR title
- A one-line summary of what was shipped

---

## Rules & guardrails

- **Always ask for explicit user approval** before: committing, pushing, and creating the PR — these are the three gates that require confirmation
- **Never** commit `.env` files, secrets, credentials, or binary blobs
- **Never** force-push without explicit user approval
- **Never** target a branch other than `develop` unless the branch is `hotfix/*` (which also targets `master` — see Step 6)
- **Always use `gh` CLI** for all GitHub operations (PR creation, listing, viewing). Never construct GitHub URLs manually.
- If `gh` CLI is not authenticated, tell the user to run `! gh auth login` in the prompt
- If there is nothing to commit and the branch is already up-to-date with origin, skip Steps 3–4 and go straight to PR creation (or inform the user a PR may already exist)
