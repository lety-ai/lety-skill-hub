# linear

Skills for managing Linear issues, projects, and reporting. These skills work with any Linear workspace via the `linear-server` MCP.

---

## Skills

| Skill | Description |
|-------|-------------|
| [`/linear-task`](./linear-task/README.md) | Create issues with user story, Gherkin acceptance criteria, and Definition of Done |
| [`/linear-report`](./linear-report/README.md) | Weekly activity report by project and milestone |

---

## Requirements

All skills in this category require the **Linear MCP server** to be configured:

```json
{
  "mcpServers": {
    "linear-server": {
      "command": "...",
      "env": {
        "LINEAR_API_KEY": "your-api-key"
      }
    }
  }
}
```
