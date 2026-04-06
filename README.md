# lety-skill-hub

Internal marketplace for sharing and distributing Claude Code skills across the Lety AI team.

## What is a skill?

A skill is a reusable prompt or slash command for Claude Code that automates a specific workflow. Skills live in `~/.claude/skills/` and are invoked with `/skill-name` in any Claude Code session.

## Structure

```
skills/
  <category>/
    <skill-name>/
      skill.md        # The skill definition (required)
      README.md       # Usage, examples, and context (required)
      example/        # Optional: sample input/output files
```

## How to install a skill

**List all available skills:**
```bash
./install.sh
```

**Install one or more skills:**
```bash
./install.sh linear-task
./install.sh linear-task linear-report pr-develop
```

**Install everything:**
```bash
./install.sh --all
```

Skills are installed to `~/.claude/skills/`. Use them in Claude Code with `/<skill-name>`.

## How to contribute a skill

1. Create a branch: `git checkout -b skill/<your-skill-name>`
2. Add your skill under `skills/<category>/<skill-name>/`
3. Fill in `skill.md` and `README.md` using the templates below
4. Open a pull request

## Skill categories

| Category | Skills | Description |
|----------|--------|-------------|
| [`dev`](./skills/dev/) | pr-develop, pr-staging, pr-production | Git, PRs, releases (GitFlow) |
| `data` | — | Data processing and analysis |
| `ops` | — | DevOps, deployments, infrastructure |
| `docs` | — | Documentation generation |
| `general` | — | General purpose utilities |

## Templates

- [skill.md template](.github/templates/skill.md)
- [README.md template](.github/templates/skill-readme.md)
