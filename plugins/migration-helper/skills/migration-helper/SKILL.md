---
name: migration-helper
description: Guide TypeORM migration workflow for Lety 2.0 Backend — generate, review, run, revert and register migrations across tenant/platform/auth schemas. Triggered when the user needs to create or manage a database migration.
---

You are guiding a **TypeORM migration** for the Lety 2.0 Backend. The project has three separate databases, each with its own migration config and scripts.

> **Priority rule**: Always follow TypeORM official documentation. Never write raw DDL SQL manually — always use `migration:generate` from entity changes. If existing migrations contain raw SQL that could have been generated, note it.

---

## DOCUMENTATION — consult before answering

- **TypeORM Migrations**: https://typeorm.io/migrations
- **TypeORM CLI**: https://typeorm.io/using-cli
- **QueryRunner API**: https://typeorm.io/query-runner

---

## Migration scripts (exact commands for this project)

### Tenant database (`libs/common/src/migrations/tenant/`)
```bash
# Generate from entity changes
pnpm migration:generate:tenant <MigrationName>

# Run pending
pnpm migration:run:tenant

# Revert last
pnpm migration:revert:tenant
```

### Platform database (`libs/common/src/migrations/platform/`)
```bash
pnpm migration:generate:platform <MigrationName>
pnpm migration:run:platform
pnpm migration:revert:platform
```

### Auth database (`libs/common/src/migrations/auth/`)
```bash
pnpm migration:generate:auth <MigrationName>
pnpm migration:run:auth
pnpm migration:revert:auth
```

---

## STEP 1 — Understand the request

Determine what the user needs:
- **New entity** → guide full generate + register flow
- **Entity change** (add/remove column, change type, add index) → guide generate + review flow
- **Run pending migrations** → guide run flow
- **Revert last migration** → guide revert flow
- **Review existing migration** → audit the migration file
- **Manual migration** (rare edge case) → write with QueryRunner, explain why generate couldn't be used

Ask: **which database?** (`tenant` | `platform` | `auth`) — required to pick the right script.

---

## STEP 2 — Generate flow (for entity changes)

### Pre-generate checklist

Before running `migration:generate`, verify with the user:

- [ ] Entity file is saved and TypeScript compiles without errors
- [ ] The entity is registered in `TypeOrmModule.forFeature([...])` in its module
- [ ] The entity is included in the datasource config for the target database
- [ ] No other uncommitted entity changes exist that shouldn't be in this migration (to avoid bundling unrelated changes)

### Generate command

```bash
pnpm migration:generate:<database> <DescriptiveName>
```

**Naming rules for `<DescriptiveName>`**:
- PascalCase, describes what changed: `AddInvoiceTable`, `AddStatusColumnToAgents`, `RemoveDeprecatedField`
- Never: `Migration1`, `Fix`, `Update` — too vague

**What TypeORM generates:**
- File: `libs/common/src/migrations/<database>/<timestamp>-<descriptiveName>.ts`
- Class: `<DescriptiveName><timestamp> implements MigrationInterface`
- `up()`: SQL to apply the change
- `down()`: SQL to reverse the change

---

## STEP 3 — Review the generated migration

After generating, read the file and verify:

**`up()` review:**
- Adds expected columns with correct types and constraints
- Creates expected indices
- Does NOT drop columns unless the entity field was removed
- Does NOT alter data types in a breaking way (e.g. varchar → uuid requires data migration)
- Default values are correct (match entity `default:` option)
- Foreign key constraints are correct

**`down()` review:**
- Reverses every operation in `up()` in reverse order
- If `up()` adds column X, `down()` drops column X
- If `up()` creates index, `down()` drops it
- The migration is reversible — if not, flag it explicitly

**Common generation issues to flag:**
| Issue | What to tell the user |
|---|---|
| `down()` is empty or missing | "Migration is irreversible — add manual `down()` if rollback is needed" |
| Column dropped unexpectedly | "Verify entity still has the field — TypeORM may have detected a rename as drop+add" |
| Data type change (e.g. int → decimal) | "This may truncate data — run on a test DB first and verify data migration is needed" |
| Multiple unrelated changes in one migration | "Consider splitting into separate migrations for clarity and safer rollback" |
| `synchronize` detected in config | "Remove `synchronize: true` from production config — use migrations exclusively" |

---

## STEP 4 — Register the migration

After generating, the migration must be registered in the migrations index:

**Tenant**: `libs/common/src/migrations/tenant/index.ts`
**Platform**: `libs/common/src/migrations/platform/index.ts`
**Auth**: `libs/common/src/migrations/auth/index.ts`

Pattern:
```typescript
import { ExistingMigration1234 } from './1234-existingMigration';
import { NewMigration5678 } from './5678-newMigration'; // add this

export const TENANT_MIGRATIONS = [
  ExistingMigration1234,
  NewMigration5678, // add this — order matters, keep chronological
];
```

> TypeORM runs migrations in array order. Always append at the end — never reorder existing entries.

---

## STEP 5 — Run the migration

```bash
pnpm migration:run:<database>
```

**Before running in production:**
- [ ] Run on a staging/dev environment first
- [ ] Verify `down()` works: run → revert → run again
- [ ] Back up the database if the migration alters existing data
- [ ] Confirm no active transactions or locks on affected tables

**After running:**
- TypeORM inserts a record in the `migrations` table marking the migration as applied
- Verify with: `SELECT * FROM migrations ORDER BY timestamp DESC LIMIT 5;`

---

## STEP 6 — Revert (if needed)

```bash
pnpm migration:revert:<database>
```

- Reverts only the **last applied** migration
- Runs the `down()` method of that migration
- To revert multiple: run `revert` multiple times

---

## STEP 7 — Manual migration (edge cases only)

Use manual migrations **only** when `migration:generate` cannot express the change:
- Data migrations (transforming existing rows)
- Renaming a column while preserving data
- Custom PostgreSQL features (extensions, custom types, triggers)

When writing manually, use `QueryRunner` methods — never raw string SQL:

```typescript
// PREFERRED — QueryRunner API
await queryRunner.addColumn('table_name', new TableColumn({
  name: 'new_column',
  type: 'varchar',
  isNullable: true,
}));

await queryRunner.createIndex('table_name', new TableIndex({
  name: 'IDX_table_field',
  columnNames: ['field'],
}));
```

**Only use `queryRunner.query()` for:**
- Data migrations: `await queryRunner.query('UPDATE table SET col = value WHERE condition')`
- PostgreSQL-specific operations not supported by QueryRunner API (e.g. `CREATE EXTENSION`)
- Never for schema changes (CREATE TABLE, ALTER TABLE, etc.) — use QueryRunner API

Always implement a correct `down()` that reverses every operation.

---

## ABSOLUTE RULES

- Never write `CREATE TABLE`, `ALTER TABLE`, `DROP TABLE` as raw SQL for schema migrations — use TypeORM CLI
- Never edit a migration that has already been run in production — create a new one
- Never reorder existing entries in the migrations index array
- `synchronize: true` is only for seed/dev modules — never in production
- Always verify `down()` reverses `up()` exactly
- Migration names must be descriptive — never `Migration123` or `Fix`
- Run on staging before production, always
