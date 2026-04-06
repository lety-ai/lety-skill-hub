# dev

Skills for development workflows: Git, PRs, releases, and code management.

| Skill | Description |
|-------|-------------|
| [pr-develop](./pr-develop/) | Create a PR from a feature/fix branch to `develop` (GitFlow) |
| [pr-staging](./pr-staging/) | Cut a release branch and create a PR to `staging` (GitFlow) |
| [pr-production](./pr-production/) | Finalize RC version and create a PR to `master` for production (GitFlow) |

## GitFlow overview

These three skills cover the full GitFlow release cycle:

```
feature/* ──► develop ──► release/vX.X.X ──► staging ──► master
               /pr-develop    /pr-staging              /pr-production
```
