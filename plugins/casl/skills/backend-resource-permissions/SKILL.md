---
name: backend-resource-permissions
description: Use when adding a new resource/entity to the Backend application that needs RBAC permissions. Covers the full flow: enum registration, CASL mapping, auth database migration, role constants, and gateway permission decorators. Triggers when creating new feature modules, new entity types, or when a 403 error occurs because a resource is missing from the permissions system.
---

# Add Resource Permissions

Guide for registering a new resource in the RBAC permission system of this NestJS monorepo. This must be done whenever a new feature introduces endpoints protected by `@Permissions()`.

## When to Use

- Creating a new feature module with protected endpoints (e.g., custom-tools, invoices, campaigns)
- Getting `403 You do not have permission to perform this action` on a new resource
- Adding `@Permissions({ action: Actions.X, resource: TenantResourceObjectEnum.NEW_RESOURCE })` to a controller

## Architecture Overview

The permission system spans **two databases** and **three layers**:

```
┌─────────────────────────────────────────────────────────────┐
│ API Gateway (HTTP)                                          │
│  PermissionsGuard → AbilityFactory → CASL                  │
│  Reads: ObjectCapabilitiesEntities (casl.constants.ts)      │
└────────────────────────┬────────────────────────────────────┘
                         │ gRPC (JWT carries user + role)
┌────────────────────────▼────────────────────────────────────┐
│ Auth Service (auth DB)                                      │
│  Tables: resource_objects → permissions → role_permissions   │
│  Seeds: ObjectSeeder → PermissionSeeder → RoleSeeder        │
└─────────────────────────────────────────────────────────────┘
```

**Key tables (auth DB):**

| Table | Purpose |
|-------|---------|
| `resource_objects` | Registry of resources (name + domain). Column `name` is a PostgreSQL enum. |
| `permissions` | One row per action×resource (e.g., `read` × `custom_tools`). FK to `resource_objects`. |
| `role_permissions` | Junction table linking roles to permissions. |
| `roles` | Role definitions (Agency Owner, Subaccount User, etc.). |

## Step-by-Step Checklist

### Step 1: Add the resource to the TypeScript enum

**File:** `libs/common/src/enums/object.enum.ts`

```typescript
export enum TenantResourceObjectEnum {
  // ... existing resources
  MY_NEW_RESOURCE = 'my_new_resource', // <-- add here
}
```

Use snake_case for the value. This string must match exactly what goes into the `resource_objects.name` column.

### Step 2: Map the resource in CASL constants

**File:** `libs/common/src/constants/casl.constants.ts`

```typescript
import { MyNewResourceEntity } from '../entities/tenant/my-resource/my-resource.entity';

export const ObjectCapabilitiesEntities = {
  // ... existing mappings
  [TenantResourceObjectEnum.MY_NEW_RESOURCE]: MyNewResourceEntity, // <-- add here
};
```

**This is critical.** Without this mapping, `PermissionsGuard` cannot evaluate the permission and will always throw 403, even if the database has the correct role_permissions.

The entity class is used by CASL as a "subject" type. Pick the primary entity of the feature (not a junction table or DTO).

### Step 3: Configure role limits (optional restrictions)

**File:** `libs/common/src/constants/role.constants.ts`

By default, **all tenant roles** receive **all 4 permissions** (read, write, update, delete) for a new resource. To restrict specific roles, add entries to the limits arrays:

```typescript
// Restrict Agency User and Subaccount User to read-only
const TENANT_BASE_USER_LIMITS = [
  // ... existing limits
  { resource: TenantResourceObjectEnum.MY_NEW_RESOURCE, action: Actions.WRITE },
  { resource: TenantResourceObjectEnum.MY_NEW_RESOURCE, action: Actions.UPDATE },
  { resource: TenantResourceObjectEnum.MY_NEW_RESOURCE, action: Actions.DELETE },
];
```

**Roles and their limit arrays:**

| Role | Limits Array | Default Behavior |
|------|-------------|-----------------|
| Agency Owner | `[]` (empty) | Gets ALL permissions always |
| Agency Admin | `[]` (empty) | Gets ALL permissions always |
| Agency User | `TENANT_BASE_LIMITS + TENANT_BASE_USER_LIMITS` | Restricted |
| Subaccount Owner | `BASE_SUBACCOUNT_LIMITS` | Restricted (agencies/subaccounts/custom_plans blocked) |
| Subaccount Admin | `BASE_SUBACCOUNT_LIMITS` | Same as Subaccount Owner |
| Subaccount User | `BASE_SUBACCOUNT_LIMITS + TENANT_BASE_USER_LIMITS` | Most restricted |

A permission in the limits array means the role **does NOT get** that permission.

### Step 4: Create the auth database migration

**File:** `libs/common/src/migrations/auth/<timestamp>-Add<Resource>Permissions.ts`

This migration must:

1. **Alter the PostgreSQL enum** to include the new value (requires a transaction commit/restart because `ALTER TYPE ... ADD VALUE` cannot run inside a transaction in PostgreSQL < 12, and this pattern is safest across versions).
2. **Insert the resource_object** row.
3. **Insert 4 permissions** (read, write, update, delete).
4. **Insert role_permissions** for each role according to limits.

```typescript
/* eslint-disable @typescript-eslint/no-unsafe-assignment */
import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddMyNewResourcePermissions<TIMESTAMP> implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    // 1. Extend the PostgreSQL enum (must happen outside transaction)
    await queryRunner.query(
      `ALTER TYPE "resource_objects_name_enum" ADD VALUE IF NOT EXISTS 'my_new_resource'`,
    );

    // Commit + restart transaction (required for ALTER TYPE to take effect)
    await queryRunner.commitTransaction();
    await queryRunner.startTransaction();

    // 2. Insert resource_object (idempotent)
    const existingObject = await queryRunner.query(
      `SELECT id FROM "resource_objects" WHERE "name" = 'my_new_resource'`,
    );

    if (existingObject.length === 0) {
      await queryRunner.query(
        `INSERT INTO "resource_objects" ("id", "name", "domain", "created_at", "updated_at")
         VALUES (gen_random_uuid(), 'my_new_resource', 'TENANT', NOW(), NOW())`,
      );
    }

    const [resourceObject] = await queryRunner.query(
      `SELECT id FROM "resource_objects" WHERE "name" = 'my_new_resource'`,
    );

    // 3. Insert 4 permissions (idempotent)
    const actions = ['read', 'write', 'update', 'delete'];
    for (const action of actions) {
      const existing = await queryRunner.query(
        `SELECT id FROM "permissions" WHERE "action" = $1 AND "object_id" = $2`,
        [action, resourceObject.id],
      );
      if (existing.length === 0) {
        await queryRunner.query(
          `INSERT INTO "permissions" ("id", "action", "object_id", "domain", "created_at", "updated_at")
           VALUES (gen_random_uuid(), $1, $2, 'TENANT', NOW(), NOW())`,
          [action, resourceObject.id],
        );
      }
    }

    const permissions = await queryRunner.query(
      `SELECT p.id, p.action FROM "permissions" p WHERE p."object_id" = $1`,
      [resourceObject.id],
    );

    // 4. Assign permissions to roles
    //    Full access roles: get all 4 permissions
    //    Read-only roles: get only 'read'
    //    Adjust these arrays based on your Step 3 limits

    const fullAccessRoles = [
      'Agency Owner',
      'Agency Admin',
      'Subaccount Owner',
      'Subaccount Admin',
    ];

    const readOnlyRoles = ['Agency User', 'Subaccount User'];

    // Full access
    const fullAccessRolesResult = await queryRunner.query(
      `SELECT id FROM "roles" WHERE "name" = ANY($1)`,
      [fullAccessRoles],
    );

    for (const role of fullAccessRolesResult) {
      for (const permission of permissions) {
        const exists = await queryRunner.query(
          `SELECT id FROM "role_permissions" WHERE "role_id" = $1 AND "permission_id" = $2`,
          [role.id, permission.id],
        );
        if (exists.length === 0) {
          await queryRunner.query(
            `INSERT INTO "role_permissions" ("id", "role_id", "permission_id", "created_at", "updated_at")
             VALUES (gen_random_uuid(), $1, $2, NOW(), NOW())`,
            [role.id, permission.id],
          );
        }
      }
    }

    // Read-only
    const readOnlyRolesResult = await queryRunner.query(
      `SELECT id FROM "roles" WHERE "name" = ANY($1)`,
      [readOnlyRoles],
    );

    const readPermission = permissions.find((p: { action: string }) => p.action === 'read');

    if (readPermission) {
      for (const role of readOnlyRolesResult) {
        const exists = await queryRunner.query(
          `SELECT id FROM "role_permissions" WHERE "role_id" = $1 AND "permission_id" = $2`,
          [role.id, readPermission.id],
        );
        if (exists.length === 0) {
          await queryRunner.query(
            `INSERT INTO "role_permissions" ("id", "role_id", "permission_id", "created_at", "updated_at")
             VALUES (gen_random_uuid(), $1, $2, NOW(), NOW())`,
            [role.id, readPermission.id],
          );
        }
      }
    }
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    const [resourceObject] = await queryRunner.query(
      `SELECT id FROM "resource_objects" WHERE "name" = 'my_new_resource'`,
    );

    if (resourceObject) {
      const permissions = await queryRunner.query(
        `SELECT id FROM "permissions" WHERE "object_id" = $1`,
        [resourceObject.id],
      );

      const permissionIds = permissions.map((p: { id: string }) => p.id);

      if (permissionIds.length > 0) {
        await queryRunner.query(
          `DELETE FROM "role_permissions" WHERE "permission_id" = ANY($1)`,
          [permissionIds],
        );
      }

      await queryRunner.query(
        `DELETE FROM "permissions" WHERE "object_id" = $1`,
        [resourceObject.id],
      );

      await queryRunner.query(
        `DELETE FROM "resource_objects" WHERE "id" = $1`,
        [resourceObject.id],
      );
    }
    // Note: PostgreSQL does not support removing values from an enum type.
    // The enum value will remain but is harmless.
  }
}
```

### Step 5: Register the migration

**File:** `libs/common/src/migrations/auth/index.ts`

```typescript
import { AddMyNewResourcePermissions<TIMESTAMP> } from './<timestamp>-AddMyNewResourcePermissions';

export const AUTH_MIGRATIONS = [
  // ... existing migrations
  AddMyNewResourcePermissions<TIMESTAMP>,
];
```

The migration runs automatically on auth-service startup (`migrationsRun: true` in `AuthDatabaseModule`). For manual execution: `pnpm migration:run:auth`.

### Step 6: Use the permission decorator in controllers

**File:** Gateway controller

```typescript
import { Permissions } from '@app/common/decorators';
import { Actions } from '@app/common/enums/action.enum';
import { TenantResourceObjectEnum } from '@app/common/enums/object.enum';

@Get()
@Permissions({ action: Actions.READ, resource: TenantResourceObjectEnum.MY_NEW_RESOURCE })
async findAll() { ... }

@Post()
@Permissions({ action: Actions.WRITE, resource: TenantResourceObjectEnum.MY_NEW_RESOURCE })
async create() { ... }

@Patch(':id')
@Permissions({ action: Actions.UPDATE, resource: TenantResourceObjectEnum.MY_NEW_RESOURCE })
async update() { ... }

@Delete(':id')
@Permissions({ action: Actions.DELETE, resource: TenantResourceObjectEnum.MY_NEW_RESOURCE })
async remove() { ... }
```

## Files Modified (Summary)

| # | File | Change |
|---|------|--------|
| 1 | `libs/common/src/enums/object.enum.ts` | Add enum value |
| 2 | `libs/common/src/constants/casl.constants.ts` | Add CASL entity mapping |
| 3 | `libs/common/src/constants/role.constants.ts` | Add role limits (if restricting) |
| 4 | `libs/common/src/migrations/auth/<ts>-Add<X>Permissions.ts` | New migration file |
| 5 | `libs/common/src/migrations/auth/index.ts` | Register migration |
| 6 | Gateway controller(s) | Add `@Permissions()` decorators |

## Common Pitfalls

1. **Forgot CASL mapping** → 403 even with correct DB data. Always add to `ObjectCapabilitiesEntities`.
2. **Forgot ALTER TYPE** → migration INSERT fails because the PostgreSQL enum does not know the new value yet.
3. **ALTER TYPE inside transaction** → PostgreSQL error. Must commit and restart the transaction before inserting.
4. **Missing `ON CONFLICT` / idempotency** → migration fails on re-run. Always check existence before inserting (there are no UNIQUE constraints on these tables).
5. **Seeds won't pick up new resources** → The ObjectSeeder only runs when the table is empty. For existing environments, a migration is mandatory.
6. **Forgot role limits** → All roles get full CRUD. This may not be desired for User-level roles.
7. **Down migration cannot remove enum values** → PostgreSQL limitation. The value stays in the enum but is harmless once the data rows are deleted.
