---
name: linear-report
description: Generate a weekly activity report from Linear for a specific project, showing completed and in-progress issues grouped by milestone/cycle, with labels and contributors. Triggered when the user asks for a Linear report, weekly summary, or sprint recap.
---

You are generating a **weekly Linear activity report** for a specified project. Follow every step in order.

---

## STEP 1 — Identify report parameters

Determine the following from the user's request:

**Required:**
- **Project**: The Linear project to report on (name or ID)
  - If not specified, list available projects and ask the user to choose

**Optional (ask only if not provided):**
- **Week**: Which week? Default = current week (Monday–Sunday containing today's date)
  - Accept natural language: "last week", "this week", "week of March 3"
  - Convert to concrete date range: `YYYY-MM-DD → YYYY-MM-DD`
- **Milestone**: Specific milestone to focus on, or "all" (default: all)
- **Granularity**: Summary (default) | Detailed
  - Summary = counts + highlights
  - Detailed = full issue list with descriptions

Compute the week boundaries:
- Week starts on **Monday**
- If "this week" → Monday of current week through today
- If "last week" → the full Monday–Sunday of the previous week

---

## STEP 2 — Fetch project and team metadata

Run these lookups in parallel:

1. `mcp__linear-server__list_projects` → find the target project, get `id`, `name`, `teamId`
2. `mcp__linear-server__list_milestones` (with `projectId`) → get all milestones/targets
3. `mcp__linear-server__list_cycles` (with `teamId`) → identify which cycle overlaps the report week
4. `mcp__linear-server__list_issue_statuses` (with `teamId`) → get status names and categories
5. `mcp__linear-server__list_issue_labels` (with `teamId`) → get label names for display

If the project is not found, tell the user and list available projects.

---

## STEP 3 — Fetch issues for the report period

Fetch issues from Linear for the target project. Use `mcp__linear-server__list_issues` with filters:

- `projectId`: the resolved project ID
- Focus on issues that were **updated or completed within the report week**:
  - Status category = "completed" AND `completedAt` within the week range
  - Status category = "started" (in progress) — include all currently active ones
  - Status category = "cancelled" AND `cancelledAt` within the week range

Run multiple fetches in parallel if needed (e.g., one per status category).

For each issue, collect:
- `id`, `identifier` (e.g. ENG-42), `title`
- `state` (status name and category)
- `priority`
- `labels` (names)
- `assignee` (display name)
- `milestone` (name, if set)
- `cycle` (name, if set)
- `estimate`
- `completedAt`, `updatedAt`, `createdAt`
- `url`

---

## STEP 4 — Organize and analyze

Group issues into these buckets:

1. **Completed this week** — `completedAt` within report range
2. **In Progress** — currently active (started/in review/in QA)
3. **Cancelled this week** — cancelled within report range
4. **Carried over** — were in progress last week, still in progress (started before week start, still open)

Within each bucket, sub-group by **Milestone** (then by **Label** if no milestone).

Compute summary stats:
- Total issues completed
- Total story points completed (if estimates exist)
- Issues in progress
- Issues carried over
- Contributors (unique assignees of completed issues)
- Most active label/area

---

## STEP 5 — Render the report

Output the report in this exact format:

---

```
# Weekly Linear Report
**Project:** [Project Name]
**Week:** [Monday date] – [Sunday/today date]  ([Cycle name if applicable])
**Generated:** [today's date]

---

## Summary

| Metric | Count |
|--------|-------|
| ✅ Completed | [N] issues ([X pts] if estimates available) |
| 🔄 In Progress | [N] issues |
| ⏩ Carried Over | [N] issues |
| ❌ Cancelled | [N] issues |
| 👥 Contributors | [name1, name2, ...] |

---

## Completed This Week

### [Milestone Name] *(or "No Milestone" if unassigned)*

| ID | Title | Labels | Assignee | Points |
|----|-------|--------|----------|--------|
| [ENG-42]([url]) | [title] | [label1, label2] | [name] | [pts or —] |
| ... | | | | |

*(repeat for each milestone)*

---

## In Progress

### [Milestone Name]

| ID | Title | Status | Labels | Assignee | Points |
|----|-------|--------|--------|----------|--------|
| [ENG-55]([url]) | [title] | [In Review] | [label] | [name] | [pts or —] |
| ... | | | | |

---

## Carried Over from Previous Week

| ID | Title | Status | Labels | Assignee | Age (days) |
|----|-------|--------|--------|----------|-----------|
| [ENG-33]([url]) | [title] | [In Progress] | [label] | [name] | [N] |
| ... | | | | |

---

## Cancelled This Week

| ID | Title | Labels | Assignee |
|----|-------|--------|----------|
| [ENG-22]([url]) | [title] | [label] | [name] |

*(omit this section if empty)*

---

## Highlights & Notes

- [Largest completed item or epic progress note]
- [Any blocked items or risks if visible from data]
- [Milestone progress: X of Y issues done]

---
*Report generated by linear-report skill*
```

---

Rules for the report:
- Issue IDs must be clickable links to the Linear URL
- If estimates are not used in the project, omit the Points column
- Omit empty sections entirely (e.g., no Cancelled section if none)
- If a milestone filter was specified, only show issues in that milestone
- For Detailed granularity, add a description row under each issue title
- Age in "Carried Over" = days since issue was moved to In Progress

---

## STEP 6 — Offer follow-up actions

After the report, offer:

> **Follow-up options:**
> - `/linear-task` — Create a new task for any gaps spotted
> - Ask me to filter by a specific milestone or label
> - Ask me to compare with the previous week
> - Ask me to export this report as markdown

---

## RULES

- Always convert relative date references ("last week") to absolute dates before fetching
- Never hallucinate issue data — only report what Linear returns
- If the project has no activity in the period, state that clearly rather than generating empty tables
- Prioritize completed issues in the report — that is the primary signal of team progress
- If milestone data is unavailable, group by label instead
- Do not include issues from other projects even if they share a team
