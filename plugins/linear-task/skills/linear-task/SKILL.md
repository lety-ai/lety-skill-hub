---
name: linear-task
description: Create a Linear issue with industry-standard user story format, acceptance criteria (Gherkin/checklist), labels, project, cycle, and priority. Triggered when the user wants to create a task/issue in Linear.
---

You are creating a Linear issue following **industry-standard Agile/Scrum format**. Follow every step in order.

---

## STEP 1 — Gather context from the user

Ask the user for any missing pieces. Required:
- **Title**: Short, action-oriented title (imperative mood, max 80 chars)
- **User Story**: "As a [role], I want [feature/action], so that [benefit/outcome]"
  - If the user doesn't provide the full format, extract role, want, and benefit from what they describe and construct it
- **Type**: Story | Bug | Task | Spike | Chore (default: Story)
- **Priority**: Urgent | High | Medium | Low | No Priority (default: Medium)

Optional (ask only if user hasn't mentioned them):
- **Project**: Which Linear project to assign to
- **Cycle/Sprint**: Which cycle or sprint
- **Labels/Tags**: Feature area, team, component, etc.
- **Assignee**: Who should own this
- **Estimate**: Story points or t-shirt size (XS/S/M/L/XL)
- **Parent issue**: If this is a sub-task

Do NOT invent these values — if the user doesn't provide them, omit optional fields.

---

## STEP 2 — Draft the full issue body

Build the issue description using this exact template. Fill in every section from what the user provided. Never leave placeholder text.

```
## User Story

As a **[role]**, I want **[feature/action]**, so that **[benefit/outcome]**.

---

## Acceptance Criteria

<!-- Use Gherkin format for behavior-driven criteria -->

**Scenario 1: [Happy path name]**
- **Given** [initial context / precondition]
- **When** [action or trigger]
- **Then** [expected outcome]
- **And** [additional assertion, if needed]

**Scenario 2: [Edge case or error path name]**
- **Given** [initial context]
- **When** [action or trigger]
- **Then** [expected outcome]

<!-- Add more scenarios as needed based on the story complexity -->

---

## Definition of Done

- [ ] Code is written and peer-reviewed (PR approved)
- [ ] Unit tests cover the new behavior
- [ ] Acceptance criteria verified by QA or the author
- [ ] Documentation updated (if applicable)
- [ ] Feature deployed to staging and smoke-tested
- [ ] No new linting or build warnings introduced

---

## Technical Notes

<!-- Optional: implementation hints, API references, constraints, risks -->
[Add technical context if the user provided it, otherwise remove this section]

---

## Out of Scope

<!-- What this story explicitly does NOT cover -->
[List exclusions if the user specified them, otherwise remove this section]
```

Rules for Acceptance Criteria:
- Write at minimum 1 happy-path scenario and 1 edge/error scenario
- Use concrete, testable language — no "should work" or "is correct"
- Each "Then" must be verifiable by a human or automated test
- If the story involves UI, include a visual/UX criterion
- If the story involves an API, include a contract/response criterion

---

## STEP 3 — Show draft to user and confirm

Present the full drafted issue (title, metadata, body) to the user. Ask:

> "Does this look good? Any changes before I create it in Linear?"

Wait for approval. Apply any changes the user requests. Do not create the issue until explicitly confirmed.

---

## STEP 4 — Resolve Linear metadata

Before creating, resolve IDs for any named entities the user provided:

- If a **project** was named: use `mcp__linear-server__list_projects` to find it and get its `id`
- If a **team** is needed: use `mcp__linear-server__list_teams` to find it
- If a **label** was named: use `mcp__linear-server__list_issue_labels` (with `teamId`) to find matching label IDs
- If a **cycle** was named: use `mcp__linear-server__list_cycles` to find it
- If an **assignee** was named: use `mcp__linear-server__list_users` to find their `id`
- If a **status** was specified: use `mcp__linear-server__list_issue_statuses` to resolve it

Run all independent lookups in parallel.

Map priority names to Linear priority numbers:
- No Priority → 0
- Urgent → 1
- High → 2
- Medium → 3
- Low → 4

---

## STEP 5 — Create the issue in Linear

Call `mcp__linear-server__save_issue` with all resolved fields:

```
title: [issue title]
description: [full markdown body from Step 2]
teamId: [resolved team ID]
priority: [0-4]
projectId: [if provided]
labelIds: [array of resolved label IDs, if provided]
assigneeId: [if provided]
cycleId: [if provided]
stateId: [if provided]
estimate: [if provided]
parentId: [if provided]
```

---

## STEP 6 — Report success

After creation, report:

```
✅ Issue created in Linear

  Title:    [title]
  ID:       [issue identifier, e.g. ENG-123]
  URL:      [issue URL]
  Project:  [project name or —]
  Priority: [priority label]
  Labels:   [label names or —]
  Assignee: [name or Unassigned]
  Cycle:    [cycle name or —]
```

---

## RULES

- Never create the issue without explicit user confirmation (Step 3)
- Never fabricate IDs — always resolve via MCP lookup tools
- Never leave placeholder text in the description
- Keep acceptance criteria testable and concrete — no vague assertions
- If the user provides a raw feature description (not a user story), extract role/want/benefit intelligently
- The Definition of Done is always included; do not remove it
- Story type → use full Gherkin scenarios; Bug type → replace User Story with **Bug Report** (steps to reproduce, expected vs actual behavior); Task/Chore → replace User Story with **Goal** and simplify AC to a checklist
