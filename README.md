# lety-skill-hub

Official Claude Code plugin marketplace for the Lety AI team. Distributes skills as installable plugins directly from Claude Code using the `/plugin` command.

## Plugins

| Plugin | Skills | Description |
|--------|--------|-------------|
| `linear` | `linear-task`, `linear-report` | Linear issue management & weekly reports |
| `dev` | `pr-develop`, `pr-staging`, `pr-production` | GitFlow PRs for all environments |

## Install via Claude Code

**1. Add this marketplace** (one-time setup):
```
/plugin marketplace add lety-ai/claude-skills
```

**2. Browse and install plugins:**
```
/plugin
```
Opens the plugin manager — go to **Discover**, select the plugins you want, choose `user` (global) or `project` (local), and install.

**3. Use the skills:**
```
/linear:linear-task
/linear:linear-report
/dev:pr-develop
/dev:pr-staging
/dev:pr-production
```

---

## Structure

```
.claude-plugin/
  marketplace.json          # Marketplace manifest (lists all plugins)

plugins/
  linear/                   # Plugin: linear
    .claude-plugin/
      plugin.json           # Plugin manifest
    skills/
      linear-task/
        SKILL.md
      linear-report/
        SKILL.md

  dev/                      # Plugin: dev
    .claude-plugin/
      plugin.json
    skills/
      pr-develop/
        SKILL.md
      pr-staging/
        SKILL.md
      pr-production/
        SKILL.md
```

## How to contribute a plugin

1. Create a branch: `git checkout -b plugin/<name>`
2. Add your plugin under `plugins/<name>/`
3. Create `.claude-plugin/plugin.json` and `skills/<skill-name>/SKILL.md`
4. Register it in `.claude-plugin/marketplace.json`
5. Open a pull request

## Templates

- [plugin.json template](.github/templates/plugin.json)
- [SKILL.md template](.github/templates/SKILL.md)
