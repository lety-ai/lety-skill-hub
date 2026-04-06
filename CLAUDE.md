# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`lety-skill-hub` is the official Claude Code plugin marketplace for the Lety AI team. It distributes Claude Code skills as installable plugins via `/plugin marketplace add lety-ai/claude-skills`.

## Plugin system structure

Each plugin is fully self-contained under `plugins/<plugin-name>/`:

```
plugins/<plugin-name>/
  .claude-plugin/
    plugin.json       # Plugin manifest (name, version, keywords, "skills": "./skills")
  skills/
    <plugin-name>/
      SKILL.md        # Skill prompt — MUST be uppercase SKILL.md
```

The marketplace manifest lives at `.claude-plugin/marketplace.json` and lists every plugin with its GitHub source path:
```json
{ "source": "github", "repo": "lety-ai/lety-skill-hub", "path": "plugins/<name>" }
```

Templates for both files are at `.github/templates/plugin.json` and `.github/templates/SKILL.md`.

## Adding a new plugin

1. Create `plugins/<name>/.claude-plugin/plugin.json` (copy from `.github/templates/plugin.json`)
2. Create `plugins/<name>/skills/<name>/SKILL.md` (copy from `.github/templates/SKILL.md`)
3. Register the plugin in `.claude-plugin/marketplace.json`
4. **Update `README.md`** — add a row to the Plugins table and a `/skill-name` entry in the usage section

README.md must always be kept in sync with marketplace.json. Any time a plugin is added, removed, or renamed, update both files in the same commit.

## SKILL.md conventions

- Frontmatter is required: `name` and `description` fields
- Steps are numbered (`## STEP 1`, `## STEP 2`, ...) and end with `## RULES` or `## ABSOLUTE RULES`
- Include a `## DOCUMENTATION` section with links to official docs when the skill touches external APIs or frameworks
- Skills must follow official best practices — not blindly replicate existing code if that code has issues. Flag anti-patterns.

## Deploying

Push to `main` on `github.com:lety-ai/lety-skill-hub` — Claude Code pulls directly from GitHub when users run `/plugin`.
