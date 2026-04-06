# linear-task

Create a Linear issue with industry-standard Agile format: user story, acceptance criteria (Gherkin scenarios), Definition of Done, labels, project, cycle, and priority.

**Version:** 1.0.0 | **Author:** @julian | **Category:** linear

---

## When to use

Run this when you want to create a well-structured Linear task that follows Agile/Scrum best practices. It handles:

- **Stories** — full user story + Gherkin acceptance criteria
- **Bugs** — bug report format with steps to reproduce
- **Tasks/Chores** — goal + checklist format
- **Spikes** — research tasks with a clear deliverable

---

## Usage

```
/linear-task
```

Then describe what you want to build. The skill will ask clarifying questions and draft the issue for your review before creating it.

**Examples:**

```
/linear-task
Add a dark mode toggle to the settings page
```

```
/linear-task
Bug: login button is unresponsive on mobile Safari when keyboard is open
```

```
/linear-task
As a marketing manager, I want to export campaign reports as PDF so I can share them with stakeholders offline
```

---

## What it does

1. **Gathers info** — title, user story, type, priority, project, labels, assignee, cycle
2. **Drafts the issue** — full description with user story, Gherkin scenarios, Definition of Done, technical notes
3. **Shows you the draft** — asks for confirmation before creating anything
4. **Resolves IDs** — looks up project, label, assignee, cycle IDs from Linear
5. **Creates the issue** — calls Linear API via MCP
6. **Reports** — shows ID, URL, and all metadata

---

## Issue format produced

```markdown
## User Story
As a **[role]**, I want **[action]**, so that **[benefit]**.

## Acceptance Criteria
**Scenario 1: Happy path**
- Given [context]
- When [action]
- Then [outcome]

**Scenario 2: Error path**
- Given [context]
- When [action]
- Then [outcome]

## Definition of Done
- [ ] Code reviewed
- [ ] Tests written
- [ ] QA verified
- [ ] Docs updated
```

---

## Requirements

- Linear MCP server connected (`linear-server`)
- Linear API key configured in MCP settings

---

## Related skills

- [`linear-report`](../linear-report/README.md) — Weekly activity report by project and milestone
