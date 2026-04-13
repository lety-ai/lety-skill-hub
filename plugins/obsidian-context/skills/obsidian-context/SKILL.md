---
name: obsidian-context
description: Search and read the Obsidian vault for relevant context. Use when the user asks "what do I have on X", "search vault", "find in vault", "check my notes", "what did I write about", or when working on a specific project/topic that may have notes in the vault. Do NOT use at the start of every session — only when the task requires detailed vault context beyond what's in Claude Code memory.
---

# Obsidian Context Reader

The Obsidian vault is the user's knowledge base — it contains projects, people, notes, research, and standing context that should inform your work. Checking here first avoids asking the user for information they've already written down, and produces more relevant, grounded responses.

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
- Multiple vaults → list them and ask the user which one to search
- Command not found → tell the user: "The Obsidian CLI is required. Install it with `npm install -g obsidian-cli` (see https://github.com/kepano/obsidian-cli)." Stop here.

## STEP 2 — Discover vault structure

Before searching, understand what this vault contains. Run:

```bash
obsidian folders
```

This tells you what top-level sections exist (e.g. Projects/, Context/, General/, Archive/, Templates/). Don't assume any folder exists — adapt your search strategy to what's actually there.

If the vault has a `Context/` folder, check for a `Context MOC.md` or similar index — these contain standing context the user wants loaded every session. Read it and follow its links.

## STEP 3 — Search for relevant context

Choose your search strategy based on what you're looking for:

**Know the topic but not the note?** Use the CLI's built-in search — it's fast and vault-aware:
```bash
obsidian search query="keyword"
```
Or for context around matches: `obsidian search:context query="keyword"`

**Browsing a domain area?** Use Glob to list files in a section:
```bash
# List all projects
Glob for Projects/*/ in $VAULT
# List people within a project
Glob for Projects/[ProjectName]/People/* in $VAULT
```

**Need deep content search?** Grep is better for regex patterns across files:
```bash
# Find all person notes
Grep for tags:.*person in $VAULT
# Find all research notes
Grep for tags:.*research in $VAULT
```

**Looking for MOCs (Maps of Content)?** These are index notes that link to related content. Check for them in each section — they typically share the folder name (e.g. `Projects/Projects MOC.md`, `General/General MOC.md`).

## STEP 4 — Present results

- **Summarize** relevant findings before proceeding — the user shouldn't have to dig through raw vault output
- **Show vault paths** so the user can open notes directly in Obsidian
- **Use the context** to inform your work — don't re-ask for info that's in the vault
- If nothing relevant was found, say so briefly and move on

## RULES

- This is a **read-only** skill. To create or edit vault notes, use `obsidian-memory`
- Notes use Obsidian Flavored Markdown: wikilinks `[[]]`, YAML frontmatter, callouts `> [!info]`
- Check the vault before asking the user for information — the vault exists precisely to avoid repeating known context
- Vault discovery via CLI is mandatory because it handles multiple vaults and provides accurate paths regardless of platform
