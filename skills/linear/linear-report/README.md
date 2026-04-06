# linear-report

Generate a weekly activity report from Linear for any project — completed issues, in-progress work, and carried-over items grouped by milestone and labeled by contributor.

**Version:** 1.0.0 | **Author:** @julian | **Category:** linear

---

## When to use

Run this at the end of a sprint or week to get a structured summary of what your team accomplished. Useful for:

- **Weekly standups / status meetings**
- **Sprint retrospectives**
- **Stakeholder updates**
- **Milestone progress tracking**

---

## Usage

```
/linear-report
```

The skill will ask which project and which week if you don't specify them.

**Examples:**

```
/linear-report
Project: Backend API  Week: last week
```

```
/linear-report
Give me the report for the Mobile App project, milestone "Q2 Launch"
```

```
/linear-report
What did the team ship this week in the Platform project?
```

---

## What it does

1. **Identifies parameters** — project, week range, milestone filter, granularity
2. **Fetches metadata** — milestones, cycles, statuses, labels from Linear
3. **Fetches issues** — completed, in-progress, and cancelled issues for the period
4. **Groups and analyzes** — buckets by status, sub-groups by milestone, computes stats
5. **Renders report** — markdown table with clickable issue links, summary metrics, contributors
6. **Offers follow-ups** — filter, compare, export, or create tasks

---

## Report sections

| Section | What it shows |
|---------|---------------|
| Summary | Counts: completed / in-progress / carried-over / cancelled + contributors |
| Completed This Week | Issues finished, grouped by milestone |
| In Progress | Active issues with current status |
| Carried Over | Issues that started before the week and are still open |
| Cancelled | Issues cancelled during the week |
| Highlights | Top completions, milestone progress, risks |

---

## Requirements

- Linear MCP server connected (`linear-server`)
- Linear API key configured in MCP settings
- At least one project with issues in Linear

---

## Related skills

- [`linear-task`](../linear-task/README.md) — Create issues in industry-standard format
