# lety-skill-hub

Official Claude Code plugin for the Lety AI team. Distributes skills as a single installable plugin directly from Claude Code using the `/plugin` command.

## Skills

| Skill | Description |
|-------|-------------|
| `linear-task` | Create Linear issues with user story, Gherkin acceptance criteria, and Definition of Done |
| `linear-report` | Generate weekly activity reports from Linear grouped by project, milestone, and contributor |
| `pr-develop` | Create a PR from a feature/fix/chore branch to develop following GitFlow and Conventional Commits |
| `pr-staging` | Cut a release branch, bump version to RC, and create a PR to staging following GitFlow and semver |
| `pr-production` | Strip RC suffix and create a PR from staging to master for production release following GitFlow |
| `typeorm` | TypeORM best practices for NestJS + DataSource (0.3.x): no raw SQL, Repository/QueryBuilder only, migrations via CLI |
| `nest-module` | Scaffold a complete NestJS module: entity, DTOs, module, gRPC controller, service, unit test, and mock factory |
| `entity-dto` | Generate a TypeORM entity + Create/Update DTOs following official best practices — flags existing code issues |
| `gateway-controller` | Scaffold a complete API Gateway feature: proto files, REST controller, gRPC service, and NestJS module |
| `test-scaffold` | Generate unit tests for NestJS services — minimal mocks, `getRepositoryToken`, gRPC status code assertions |
| `migration-helper` | Guide TypeORM migration workflow — generate, review, run, revert across tenant/platform/auth schemas |
| `error-handler` | Write, review or fix error handling — BaseRpcException, TypeORM filters, RpcToHttpInterceptor, RMQ ack/nack |
| `security-review` | Review JWT strategies, auth guards, middleware, and security config — flags vulnerabilities against NestJS docs and OWASP |
| `nextjs-feature` | Scaffold a complete Next.js feature module: components, views, services, model, and logic following Screaming Architecture |
| `react-query` | Generate TanStack Query v5 useQuery/useMutation hooks with ApiSDK pattern, queryKey conventions, and cache invalidation |
| `zod-form` | Generate Zod schemas + react-hook-form setup — single and multi-step forms with standardSchemaResolver |
| `zustand` | Scaffold Zustand v5 stores — persisted with partialize/onRehydrateStorage, UI stores, and wizard stores |
| `ui-component` | Create React components following Atomic Design — atoms with CVA+cn()+Radix UI or feature-specific components |
| `casl` | Add or review CASL permission checks — usePermissionsStore, haveSomePermission, route and component-level guards |
| `websocket` | Scaffold NestJS WebSocket gateway with Socket.io, JWT auth guard, tenant room isolation, RabbitMQ broadcast, and Next.js client hook |
| `design-patterns` | Review and refactor code using design patterns — detect duplication, god services, mixed concerns; apply Strategy, Facade, Observer, Container/Presenter, Custom Hook patterns |
| `pr-review` | Review a PR for Lety 2.0 — auto-detects backend/frontend changes, dispatches specialist reviewers in parallel, produces tiered Critical/Important/Suggestion report |

## Install via Claude Code

**1. Add the plugin** (one-time setup):
```
/plugin install github:lety-ai/lety-skill-hub
```

**2. Use any skill:**
```
/linear-task
/linear-report
/pr-develop
/pr-staging
/pr-production
/typeorm
/nest-module
/entity-dto
/gateway-controller
/test-scaffold
/migration-helper
/error-handler
/security-review
/nextjs-feature
/react-query
/zod-form
/zustand
/ui-component
/casl
/websocket
/design-patterns
/pr-review
```

---

## Structure

```
.claude-plugin/
  plugin.json           # Plugin manifest (single plugin with all skills)
  marketplace.json      # Marketplace manifest (points to this repo)

skills/
  <skill-name>/
    SKILL.md            # Skill prompt content
```

## How to contribute a skill

1. Create a branch: `git checkout -b skill/<name>`
2. Create `skills/<name>/SKILL.md` (copy from `.github/templates/SKILL.md`)
3. Update the skills table in this README
4. Open a pull request

## Templates

- [plugin.json template](.github/templates/plugin.json)
- [SKILL.md template](.github/templates/SKILL.md)
