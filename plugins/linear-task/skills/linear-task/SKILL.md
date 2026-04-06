---
name: linear-task
description: Create a Linear issue with industry-standard user story format, acceptance criteria (Gherkin/checklist), labels, project, cycle, and priority. Triggered when the user wants to create a task/issue in Linear.
---

You are creating a Linear issue following **industry-standard Agile/Scrum format**. Follow every step in order.

> **Always write the entire issue — title, user story, acceptance criteria, and all sections — in English, regardless of the language used in the conversation.**

---

## STEP 1 — Gather context from the user

Ask the user for any missing pieces. Required:
- **Title**: Short, action-oriented title (imperative mood, max 80 chars)
- **User Story**: "As a [role], I want [feature/action], so that [benefit/outcome]"
  - If the user doesn't provide the full format, extract role, want, and benefit from what they describe and construct it
- **Type**: Story | Bug | Task | Spike | Chore (default: Story)
- **Priority**: Urgent | High | Medium | Low | No Priority (default: Medium)

Required (always ask if not provided):
- **Labels/Tags**: Every issue must have at least one label. Before asking the user, look up existing labels with `mcp__linear-server__list_issue_labels` and suggest the most relevant ones. If no existing label fits, propose creating a new one — but ask the user for confirmation before creating it (see STEP 5).

Optional (ask only if user hasn't mentioned them):
- **Project**: Which Linear project to assign to
- **Milestone**: Which milestone this belongs to
  - For **Bug** and **Task/Chore** types: always ask — default suggestion is "Improvements and Bugfixes"
  - For **Story** (feature) type: always ask — a milestone is required; do not create a feature issue without one
- **Cycle/Sprint**: Which cycle or sprint
- **Assignee**: Who should own this
- **Estimate**: Story points or t-shirt size (XS/S/M/L/XL)
- **Parent issue**: If this is a sub-task

Do NOT invent these values — if the user doesn't provide them, omit optional fields.
> Milestone and Labels are exceptions: always ask for them explicitly. For bugs/improvements, suggest "Improvements and Bugfixes" as milestone. For features, milestone is required.

---

## STEP 2 — Assess Complexity and Subtask Split

Before drafting the issue body, evaluate whether the task is simple enough to be a single issue or complex enough to warrant splitting into sub-tasks. This is important because overly large issues are hard to estimate, hard to review, and block the team unnecessarily.

### 2a — Determine scope

Ask yourself (based on what the user described):
- Does this task touch **both backend and frontend**?
- Does it span **multiple modules or services** (e.g., API + queue + UI)?
- Does it involve **research/spike + implementation** as separate phases?
- Would a single developer realistically finish it in **more than 3 days**?

If the answer to any of these is yes, the task is likely **complex** and should be split.

### 2b — Classify complexity

| Level | Criteria | Action |
|---|---|---|
| **Simple** | Single layer (only UI or only API), ≤ 1 day | Create a single issue |
| **Medium** | Touches 2 layers (e.g., API + UI), 2–3 days | Create a single issue with clear scope notes |
| **Complex** | Spans 3+ layers, multiple services, or > 3 days | Propose a parent issue + sub-tasks |

### 2c — If Complex: propose a breakdown

Present the proposed split to the user **before drafting the full issue body**. Use this format:

```
This task looks complex — it touches [X layers/modules]. I suggest splitting it:

📦 Parent: [parent title] — tracks the full feature, no code assigned directly
  └─ Sub-task 1: [title] — [backend/frontend/infra] — est. [XS/S/M/L]
  └─ Sub-task 2: [title] — [backend/frontend/infra] — est. [XS/S/M/L]
  └─ Sub-task 3: [title] — [backend/frontend/infra] — est. [XS/S/M/L]

Should I create them this way, or would you like to adjust the breakdown?
```

Wait for user confirmation before proceeding. The user may:
- **Approve** → proceed to STEP 3 for each issue (parent first, then sub-tasks)
- **Adjust** → modify the breakdown as requested, then confirm again
- **Reject split** → create a single issue and continue to STEP 3

If creating a parent + sub-tasks, follow the full STEP 3–7 flow for the **parent first**, then repeat for each sub-task, linking each to the parent via `parentId`.

---

## STEP 3 — Draft the full issue body

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

## STEP 4 — Show draft to user and confirm

Present the full drafted issue (title, metadata, body) to the user. Ask:

> "Does this look good? Any changes before I create it in Linear?"

Wait for approval. Apply any changes the user requests. Do not create the issue until explicitly confirmed.

---

## STEP 5 — Resolve Linear metadata

Before creating, resolve IDs for any named entities the user provided:

- If a **project** was named: use `mcp__linear-server__list_projects` to find it and get its `id`
- If a **team** is needed: use `mcp__linear-server__list_teams` to find it
- **Labels (always required)**:
  1. Use `mcp__linear-server__list_issue_labels` (with `teamId`) to fetch existing labels
  2. Match the issue's domain/module against existing labels and resolve their IDs
  3. If no existing label fits, propose a new label name to the user and ask: *"No existing label matches this issue. Should I create a `[proposed-label]` label?"*
  4. Wait for confirmation, then use `mcp__linear-server__create_issue_label` to create it before proceeding
  5. Never create a label without explicit user confirmation
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

## STEP 6 — Create the issue in Linear

Call `mcp__linear-server__save_issue` with all resolved fields:

```
title: [issue title]
description: [full markdown body from Step 3]
teamId: [resolved team ID]
priority: [0-4]
projectId: [if provided]
labelIds: [array of resolved label IDs, if provided]
assigneeId: [if provided]
cycleId: [if provided]
stateId: [if provided]
estimate: [if provided]
parentId: [if provided — required for sub-tasks]
```

---

## STEP 7 — Report success

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
  Sub-tasks: [list of sub-task IDs and titles, or —]
```

---

## RULES

- **Always write the entire issue in English** — title, body, acceptance criteria, all sections — regardless of the language the user is writing in
- **Acceptance criteria is mandatory** — never create an issue without at least one scenario or checklist; there are no exceptions
- **Always assess complexity before drafting** — if the task is complex, propose a subtask split and wait for user confirmation before proceeding
- **Labels are mandatory** — every issue must have at least one label; look up existing labels first, and if none fit, propose a new label and wait for user confirmation before creating it
- Never create the issue without explicit user confirmation (Step 4)
- Never fabricate IDs — always resolve via MCP lookup tools
- Never leave placeholder text in the description
- Keep acceptance criteria testable and concrete — no vague assertions
- If the user provides a raw feature description (not a user story), extract role/want/benefit intelligently
- The Definition of Done is always included; do not remove it
- Story type → use full Gherkin scenarios; Bug type → replace User Story with **Bug Report** (steps to reproduce, expected vs actual behavior); Task/Chore → replace User Story with **Goal** and simplify AC to a checklist
- For parent issues in a subtask split, the description summarizes the full feature and links to sub-tasks; no code is assigned directly to the parent
