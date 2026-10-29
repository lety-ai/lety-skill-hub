---
name: pr-production
description: Finalize the RC version on `staging` and create a PR from `staging` to `master` for production release following GitFlow conventions.
---

Finalize the version on `staging`, then create a PR from `staging` to `master` following GitFlow and semver conventions. Follow these steps exactly:

## Step 1 — Protected branch guard

Run `git branch --show-current`. If the current branch is NOT `staging`, stop and tell the user:

> "This skill must be run from `staging`. You are currently on `<branch>`. Please switch to `staging` and try again."

Do **not** continue with any further steps.

## Step 2 — Validate RC version and analyze commits

First, sync with the remote:
```bash
git fetch origin
```

Then run in parallel:
- Detect and read the current version from the project's version file (`package.json`, `pyproject.toml`, `Cargo.toml`, `pom.xml`, `VERSION`, etc. — use the first one found)
- `git log origin/master..HEAD --oneline` — commits not yet in master (uses remote ref, not stale local)
- `git diff origin/master...HEAD --stat` — summary of changed files

If the commit list is empty (nothing ahead of master), stop and tell the user:
> "There are no new commits on `staging` that aren't already in `master`. Nothing to release to production."

If the version does NOT contain `-rc`, stop and tell the user:

> "The current version `<version>` is not a release candidate. Run `/pr-staging` from `develop` first to cut a release branch and promote it to staging with an RC version."

If it does contain `-rc`, show the user:
> "Current RC version: `<version>`. This will be released as `<stable-version>` (e.g., `1.0.2-rc.1` → `1.0.2`). Confirm?"

Only continue after explicit user approval.

## Step 3 — Finalize version in the version file

Strip the `-rc.N` suffix from the version in the version file detected in Step 2.
Example: `1.0.2-rc.1` → `1.0.2`

Show the commit message to the user and ask for approval before committing:

```bash
git add <version-file>
git commit -m "chore(release): release v<version>"
```

## Step 4 — Push staging to origin

Show the user:
> "Ready to push `staging` to origin with the release version. Confirm?"

Only run `git push origin staging` after explicit user approval.

If push fails due to diverged remote, explain and ask whether to rebase. **Never force-push without explicit approval.**

## Step 5 — Check for existing PR and create

Check if a PR already exists:
```bash
gh pr list --head staging --base master --json number,url,title
```

If a PR already exists, show its URL and ask whether to update the title or skip.

Otherwise, show the full PR draft and ask:
> "Ready to create PR `staging` → `master` with title `release: v<version>`. Confirm?"

Only run `gh pr create` after explicit user approval:

```bash
gh pr create --base master --head staging --title "release: v<version>" --body "..."
```

PR body structure:

```markdown
## Release v<version>

<!-- one-line description of what this release contains -->

## Changes

<!-- All commits since the previous production release, grouped by type -->
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
- [x] Production release

## Database migrations

<!-- YES/NO. If yes, list the migration files and confirm they have been tested in staging -->

## Breaking changes

<!-- YES/NO. If yes, describe impact and rollback plan -->

## Pre-release checklist

- [ ] All changes validated in staging
- [ ] No pending migrations unrun in production
- [ ] Rollback plan defined if migrations are included
- [ ] Team notified of release

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

Fill every section based on the commit analysis. Do **not** leave placeholder text.

## Step 6 — Post-merge reminders

Check whether the release branch exists (local or remote):
```bash
git branch --list "release/v<version>"
git branch -r --list "origin/release/v<version>"
```

After the PR is created, remind the user:

> **After merging to `master`:**
> 1. Tag the release with an **annotated tag** (required by GitFlow — includes author, date, and message, and works correctly with `git describe`):
>    ```bash
>    git tag -a v<version> -m "Release v<version>"
>    git push origin v<version>
>    ```

If the release branch exists, also include:
> 2. Back-merge `release/v<version>` into `develop`:
>    ```bash
>    git checkout develop
>    git merge --no-ff release/v<version>
>    git push origin develop
>    ```
> 3. Delete the release branch:
>    ```bash
>    git branch -d release/v<version>
>    git push origin --delete release/v<version>
>    ```

If no release branch exists (e.g., merged directly from `develop` → `staging`), skip steps 2–3 and only remind about tagging.

## Step 7 — User-facing release notes (every release)

Besides the technical PR body, every production release gets a **user-facing changelog** that the product owner can publish as-is. Write it in **Spanish** and upload it as a Linear document to the project **RELEASE WHITE LABEL NOTES CHANGE LOGS** (`P-LET-23`, https://linear.app/lety/project/release-white-label-notes-change-logs-8c48cde529fa), titled `Release v<version> — Notas para usuarios`.

Build it from the commits analyzed in Step 2, but verify every claim against the code being released (`origin/release/v<version>` or `staging`): menu labels come from the Spanish locale (`es.json`: `nav.*`, `agentConfig.tabs.*`, …) and availability comes from feature-flag gates (`useFeatureFlag`, `featureFlag:` in the sidebar). Never guess a menu path.

**Three groups:**
- **Novedades** — something new the user can use.
- **Mejoras** — something that already existed and now works better.
- **Arreglos** — something that failed and no longer does.

**Writing rules:**
- Write every point from the user's side: what they can do now and where they find it. Never how it was built.
- No technical language: no flag names, iframe, endpoint, HTTP status codes, Embedded Signup, internal provider names (Featurebase, OpenRouter, Composio, Stripe Connect, …) or ticket numbers.
- Leave out what the user doesn't see: flag changes, syncs of hotfixes already published to production, dependency/framework upgrades, security patches, and internal refactors or repairs.
- If something is not available to everyone, say so: `Disponible para: agencias con X activado / plan Y`.

**Template for each Novedad or Mejora** (each one carries a screenshot):

```markdown
### <beneficio en pocas palabras>

**Qué es:** <1 o 2 frases: qué puede hacer ahora el usuario>

**Dónde está:** <ruta en el menú, ej. Agentes › Brief>

**Disponible para:** <todos / solo con X activado>

[Captura: <pantalla › parte a recortar>]
```

**Arreglos** go in a simple bullet list, with no screenshots.

**Screenshots:** one per point, of the real screen and cropped to the new part only, never the full page. Use sample data, never real customer data. Do not start dev servers or headless browsers to take them. Leave the placeholder `[Captura: Agentes › Brief, copiloto abierto]` and the product owner takes it.

End the document with an internal section, `## Lo que quité y por qué (interno, no publicar)`, that lists each change left out and the reason.

Show the user the draft and ask for approval before uploading it to Linear. Then share the document URL.

After uploading, post a **project update** on the same Linear project (health `onTrack`) with the version, the release date and a link to the document:

```markdown
**Release v<version>** · <día> de <mes> de <año>

Notas para usuarios: [Release v<version> — Notas para usuarios](<document URL>)
```

## Step 8 — Report result

Output:
- The PR URL
- The Linear URL of the user-facing release notes and of the project update
- The version released (`<rc-version>` → `<stable-version>`)
- A one-line summary of what ships to production

---

## Rules & guardrails

- **Always ask for explicit user approval** before: version finalization commit, push, and PR creation
- **Never** run this skill from a branch other than `staging`
- **Never** force-push without explicit user approval
- **Never** create a production PR if the version is not an RC (no `-rc` suffix)
- **Always use `gh` CLI** for all GitHub operations
- If `gh` CLI is not authenticated, tell the user to run `! gh auth login`
- After merge to `master`, always remind the user to tag the release and back-merge the release branch into `develop`
- **Always** produce the user-facing release notes (Step 7) and upload them to the Linear project `P-LET-23`. Never skip this step, even for small releases
