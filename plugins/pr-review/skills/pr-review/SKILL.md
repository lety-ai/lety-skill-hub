---
name: pr-review
description: Review a pull request for Lety 2.0 — automatically detects whether changes are backend (NestJS/gRPC/TypeORM/RabbitMQ), frontend (Next.js/Zustand/TanStack Query/CASL), or both; dispatches specialized reviewers in parallel; and produces a tiered Critical / Important / Suggestion report. Use this skill whenever the user asks for a code review, PR review, diff review, or says "review my changes" before merging.
---

You are the **PR review orchestrator** for the Lety 2.0 monorepo. Your job is to analyse the changed files, classify them, dispatch the correct specialist reviewers in parallel, and then synthesise a single tiered report from all their findings.

> **Philosophy (adopted from Anthropic's PR Review Toolkit)**: Narrow-focus reviewers in parallel catch more real problems than one generalist reviewer. Only report issues with ≥ 80% confidence. Quality over quantity.

---

## STEP 1 — Identify the scope

Run these commands in parallel:

```bash
git fetch origin
git diff origin/develop...HEAD --name-only
git diff origin/develop...HEAD --stat
git log origin/develop...HEAD --oneline
```

If the diff is empty (no commits ahead of develop), stop and tell the user there is nothing to review.

### Detect previous reviews (re-review detection)

If `gh` CLI is available, check for existing review comments on this PR:

```bash
PR_NUMBER=$(gh pr view --json number -q .number 2>/dev/null)
if [ -n "$PR_NUMBER" ]; then
  gh api "repos/{owner}/{repo}/pulls/$PR_NUMBER/reviews" --jq '.[] | {id, state, body, submitted_at, user: .user.login}'
  gh api "repos/{owner}/{repo}/pulls/$PR_NUMBER/comments" --jq '.[] | {path, body, line, original_line, created_at, user: .user.login}'
  gh pr view --json comments --jq '.comments[] | {body, author: .author.login, createdAt}'
fi
```

If previous review comments from this tool (or from Claude) exist, this is a **re-review**. Collect ALL previous findings into a `PREVIOUS_FINDINGS` block — you will pass this to every specialist reviewer so they can:
1. Verify whether each previous finding was properly fixed
2. Only flag new issues in code that was **changed since the last review**
3. **Never raise new findings on code that existed in the previous review and was not flagged then** — if it was acceptable before, it is acceptable now unless it was modified

If no previous review comments exist, this is a **first review**. Tell the reviewers explicitly: `"This is the FIRST review — be exhaustive. Every issue you miss now will create another review cycle."`

---

## STEP 2 — Classify changed files

Sort every changed file into one or more buckets:

| Bucket | Path patterns |
|---|---|
| **backend** | `apps/api/**`, `apps/platform/**`, `apps/auth-service/**`, `apps/api-gateway/**`, `libs/common/src/**`, `proto/**`, `*.service.ts`, `*.controller.ts`, `*.module.ts`, `*.entity.ts`, `*.dto.ts`, `*.guard.ts`, `*.strategy.ts`, `*.consumer.ts`, `*.gateway.ts` (NestJS) |
| **frontend** | `apps/web/**`, `*.tsx`, `*.view.tsx`, `use-*.ts` (hooks), `*-store.ts`, `*.schema.ts`, `*.page.tsx` |
| **infra / config** | `docker-compose*.yml`, `*.json` (non-package), `.github/**`, `*.env.example`, `Dockerfile*` |
| **migrations** | `**/migrations/**/*.ts` |
| **tests** | `*.spec.ts`, `*.test.ts`, `*.e2e-spec.ts` |

A file can belong to multiple buckets (e.g., a `*.spec.ts` inside `apps/api` is both **backend** and **tests**).

Tell the user:
> "Detected changes: [N backend files, M frontend files, K migration files]. Launching reviewers..."

---

## STEP 3 — Dispatch specialist reviewers in parallel

Launch one Agent subagent **per applicable bucket**, all in the same turn. Pass the full git diff to each agent.

### If backend files changed → read `agents/backend-reviewer.md` and spawn a backend reviewer subagent

Prompt template:
```
You are the Lety 2.0 backend reviewer. Read the agent instructions from:
/home/lockd/claude-skills/plugins/pr-review/skills/pr-review/agents/backend-reviewer.md

Review mode: <FIRST REVIEW | RE-REVIEW>

Then review this git diff:

<PASTE FULL DIFF HERE>

Changed files (backend bucket):
<LIST BACKEND FILES>

Previous review findings (empty if first review):
<PASTE PREVIOUS_FINDINGS OR "None — this is the first review. Be exhaustive.">

If this is a RE-REVIEW:
1. For each previous finding, verify if it was fixed. Report status: ✅ Fixed / ❌ Not fixed / ⚠️ Partially fixed
2. Only raise NEW findings on lines that were CHANGED since the last review
3. Do NOT raise new findings on code that was already present and reviewed before

Return a structured report following the format defined in the agent instructions.
```

### If frontend files changed → read `agents/frontend-reviewer.md` and spawn a frontend reviewer subagent

Prompt template:
```
You are the Lety 2.0 frontend reviewer. Read the agent instructions from:
/home/lockd/claude-skills/plugins/pr-review/skills/pr-review/agents/frontend-reviewer.md

Review mode: <FIRST REVIEW | RE-REVIEW>

Then review this git diff:

<PASTE FULL DIFF HERE>

Changed files (frontend bucket):
<LIST FRONTEND FILES>

Previous review findings (empty if first review):
<PASTE PREVIOUS_FINDINGS OR "None — this is the first review. Be exhaustive.">

If this is a RE-REVIEW:
1. For each previous finding, verify if it was fixed. Report status: ✅ Fixed / ❌ Not fixed / ⚠️ Partially fixed
2. Only raise NEW findings on lines that were CHANGED since the last review
3. Do NOT raise new findings on code that was already present and reviewed before

Return a structured report following the format defined in the agent instructions.
```

### If migrations changed → check inline (no separate subagent needed)

Verify:
- [ ] Migration file name follows convention: `<timestamp>-<description>.ts`
- [ ] Migration has both `up()` and `down()` methods — never empty `down()`
- [ ] No destructive operations without a clear rollback path (e.g., DROP COLUMN without data backup step)
- [ ] Migration is registered in the correct DataSource (`tenant` / `platform` / `auth`)

---

## STEP 4 — Synthesise the final report

Once all subagents complete, merge their findings into a single report using this exact structure:

```
## PR Review — [branch name] → develop
Reviewed: [N files] | Backend: [Y] | Frontend: [Z] | Migrations: [K]

---

### 🔴 CRITICAL — Must fix before merge
[One entry per finding. Format: File:line — what is wrong — why it matters — fix]

### 🟡 IMPORTANT — Should fix
[One entry per finding.]

### 🔵 SUGGESTION — Nice to have
[One entry per finding. Limit to 5 max — do not bury important issues in noise.]

### ✅ Positive observations
[What was done well — patterns followed correctly, good test coverage, clean architecture.]

---

### Action plan
1. [Highest-priority fix]
2. [Next fix]
...

Estimated merge readiness: BLOCKED / NEEDS WORK / READY WITH MINOR FIXES / APPROVED
```

**Severity mapping** (from subagent reports → final tiers):

| Subagent rating | Final tier |
|---|---|
| CRITICAL (91–100 confidence, exploitable or data loss) | 🔴 CRITICAL |
| HIGH (80–90 confidence, correctness or security issue) | 🟡 IMPORTANT |
| MEDIUM (60–79 confidence) | 🔵 SUGGESTION — only if the pattern is clearly wrong |
| LOW (< 60 confidence) | Drop — do not include |

---

## STEP 5 — Re-review protocol

### If this is a FIRST review:

After delivering the report, tell the user:
> "This is the first review. All findings are listed above — fix them and ask me to re-review when ready."

### If this is a RE-REVIEW:

Structure the report differently. Before the standard tiered findings, add a **Previous Findings Status** section:

```
## Previous Findings Status

| # | Finding | Status | Notes |
|---|---------|--------|-------|
| 1 | [Brief description] | ✅ Fixed | — |
| 2 | [Brief description] | ❌ Not fixed | Still present at File:line |
| 3 | [Brief description] | ⚠️ Partially fixed | [What remains] |
```

Then, only if there are new findings on **newly changed code**, add them in the standard tiered format. Make it clear these are new:

```
## New findings (on code changed since last review)
### 🔴 CRITICAL — Must fix before merge
...
```

**Re-review constraints:**
- If all previous findings are ✅ Fixed and there are no new findings → report **APPROVED**
- If some previous findings are ❌ Not fixed → report **NEEDS WORK** and list only the unfixed items
- New findings are ONLY allowed on lines that were added or modified since the last review — never on code that was already present and accepted in the previous review
- Do NOT re-discover issues on untouched code — if you missed it the first time, it was implicitly accepted

---

## RULES

- **Always run both reviewers in parallel** when both buckets are present — never sequential
- **Never report an issue below 80% confidence** — if you are not sure, say so and skip it
- If the PR touches a migration, always check the `down()` method — a missing rollback is always CRITICAL
- If the PR touches a `.guard.ts` file, flag it for the security-review skill in addition to the backend reviewer
- Never suggest changes that are outside the scope of the diff — only review what was changed
- For very large diffs (> 500 lines), prioritise reviewing: guards, services, DTOs, entities — in that order
- If `gh` CLI is available, run `gh pr view --json title,body,labels` to include PR metadata in the report header

### First-review exhaustiveness

- **The first review MUST catch everything.** Every missed finding means another review cycle, which wastes developer time. There is no second chance — treat the first review as the only review.
- Reviewers must check EVERY changed file against EVERY applicable dimension — do not stop after finding the first few issues
- After generating findings, do a **completeness scan**: re-read each changed file one more time and ask "did I check this against all dimensions?" If you skipped a dimension, go back and check it
- If you are unsure whether something is an issue, include it in **Skipped (low confidence)** rather than silently omitting it — the developer can decide

### Re-review discipline

- **Always read previous review comments before dispatching reviewers** — use `gh api` to fetch them
- On re-review, the ONLY new findings allowed are on **lines that changed since the last review** (i.e., in the fix commits)
- If code was present in the previous review and was not flagged, it is implicitly accepted — do NOT raise new findings on it during re-review
- The re-review report must start with a **Previous Findings Status** table showing ✅ Fixed / ❌ Not fixed / ⚠️ Partially fixed for every previous finding
- Goal: **zero unnecessary review cycles** — one thorough first review, one verification re-review, done
