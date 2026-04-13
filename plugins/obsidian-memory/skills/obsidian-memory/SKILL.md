---
name: obsidian-memory
description: Write to the Obsidian vault — create projects with people/notes/research, save general notes, update existing notes, move notes between sections, archive projects. Use when the user says "create project", "add person", "save note", "add research", "write to vault", "add to obsidian", "archive project", "update note", "move note", or asks to create/edit/organize anything in their Obsidian vault. This is the WRITE skill — for searching/reading the vault, see obsidian-context. Trigger even if the user doesn't mention "Obsidian" explicitly — if they want to save or organize knowledge, this is the tool.
---

# Obsidian Vault Writer

The Obsidian vault is the user's persistent knowledge base. This skill creates and organizes notes following the vault's own conventions, so everything stays consistent and discoverable. Reading the vault's CLAUDE.md and templates first is essential — they define the structure, and that structure may evolve over time.

## STEP 1 — Locate the vault

The Obsidian CLI is required. Run:

```bash
obsidian vaults verbose
```

This outputs vault names and paths (e.g. `Vault	C:\Users\lockd\Documents\Vault`).

**Resolve the path for your platform:**
- **WSL/Linux with Windows paths:** convert `C:\Users\x` → `/mnt/c/Users/x`
- **macOS/native Linux:** use the path as-is

**Handle results:**
- One vault → use it as `$VAULT`
- Multiple vaults → list them and ask the user which one to write to
- Command not found → tell the user: "The Obsidian CLI is required. Install it with `npm install -g obsidian-cli` (see https://github.com/kepano/obsidian-cli)." Stop here.

## STEP 2 — Read the vault's conventions

Every vault may have its own rules. Before writing anything:

1. **Check for `$VAULT/CLAUDE.md`** — if it exists, read it. It's the single source of truth for structure, conventions, tags, and frontmatter. If it doesn't exist, proceed using standard Obsidian Markdown conventions.

2. **Check for templates** — run `obsidian templates` or list `$VAULT/Templates/`. Common templates include:
   - `Project Template.md`, `Person Template.md`, `Note Template.md`, `Research Template.md`
   - If a template exists for what you're creating, read it and follow its structure.
   - If no template exists, use sensible defaults: YAML frontmatter with `title`, `tags`, and `date`.

3. **Understand the folder structure** — run `obsidian folders` to see what top-level sections exist. Adapt workflows below to match what's actually in the vault.

## STEP 3 — Execute the appropriate workflow

### Create a project

1. Read the project template if it exists
2. Create `$VAULT/Projects/[Name]/` with subfolders the template or CLAUDE.md specifies (commonly `People/`, `Notes/`, `Research/`)
3. Create the main project note from the template
4. Create person notes for each person mentioned
5. Update the Projects MOC if one exists

**If the project already exists:** tell the user, ask if they want to update it.

### Add a person to a project

1. Read the person template if it exists
2. Create `$VAULT/Projects/[Project]/People/[Name].md`
3. Add `project: "[[Project Name]]"` and project tag to frontmatter
4. Update the project's main note people table

**If the person already exists:** update their note instead of creating a duplicate.

### Add a note to a project

1. Read the note template if it exists
2. Create `$VAULT/Projects/[Project]/Notes/[Title].md`
3. Add project link and tag to frontmatter

### Add research to a project

1. Read the research template if it exists
2. Create `$VAULT/Projects/[Project]/Research/[Title].md`
3. Add project link and tag to frontmatter

### Add a general note

1. Read the note template if it exists
2. Create `$VAULT/General/[Title].md` with relevant topic tags
3. Update the General MOC if one exists

### Add a context note

Context notes contain things the user wants Claude to always know at session start:
1. Create `$VAULT/Context/[Title].md` with descriptive frontmatter
2. Update the Context MOC if one exists

### Edit/update existing notes

1. Read the existing note first
2. Preserve the frontmatter structure — don't drop or reorder existing fields
3. If moving to a different project, update both the old and new locations and any MOCs

### Archive a project

1. Move `$VAULT/Projects/[Name]/` to `$VAULT/Archive/[Name]/`
2. Remove from Projects MOC, add to Archive MOC (if they exist)
3. Set `status: archived` in the main note's frontmatter

## RULES

- **Match the user's language** — the vault content is typically in the user's preferred language. Don't translate unless asked.
- **Check for duplicates** before creating — use `obsidian search query="note name"` or Grep to verify a note doesn't already exist.
- **Cross-project people** are normal — the same person can have notes in multiple projects. A `People.base` at the vault root may aggregate them all.
- **Leave empty MOC sections** as placeholders — they serve as structure for future notes.
- **Vault conventions come from `$VAULT/CLAUDE.md` and templates**, not from this skill. If the vault's CLAUDE.md contradicts something here, follow the vault's CLAUDE.md.
