# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`lety-skill-hub` is the official Claude Code plugin for the Lety AI team. It distributes all Claude Code skills as a single installable plugin via `/plugin install github:lety-ai/lety-skill-hub`.

## Plugin structure

The repo is a single plugin with all skills at the root level:

```
.claude-plugin/
  plugin.json           # Plugin manifest (name, version, keywords, "skills": "./skills")
  marketplace.json      # Marketplace manifest (points to this repo)

skills/
  <skill-name>/
    SKILL.md            # Skill prompt — MUST be uppercase SKILL.md
```

Templates for both files are at `.github/templates/plugin.json` and `.github/templates/SKILL.md`.

## Adding a new skill

1. Create `skills/<name>/SKILL.md` (copy from `.github/templates/SKILL.md`)
2. **Update `README.md`** — add a row to the Skills table and a `/skill-name` entry in the usage section

## SKILL.md conventions

- Frontmatter is required: `name` and `description` fields
- Steps are numbered (`## STEP 1`, `## STEP 2`, ...) and end with `## RULES` or `## ABSOLUTE RULES`
- Include a `## DOCUMENTATION` section with links to official docs when the skill touches external APIs or frameworks
- Skills must follow official best practices — not blindly replicate existing code if that code has issues. Flag anti-patterns.

## Deploying

Push to `main` on `github.com:lety-ai/lety-skill-hub` — Claude Code pulls directly from GitHub when users run `/plugin`.
