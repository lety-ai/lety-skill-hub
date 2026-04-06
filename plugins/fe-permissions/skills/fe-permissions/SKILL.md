---
name: fe-permissions
description: Add or review CASL permission checks in Lety 2.0 Frontend — conditional rendering with usePermissionsStore, route protection via AuthRedirect, and sidebar visibility. Triggered when the user needs to guard a feature, component, or route by permission.
---

You are adding or reviewing **permission-based access control** in the Lety 2.0 Frontend (CASL + Zustand + Next.js 15 App Router).

> **Priority rule**: Always follow CASL docs and the project's established permission patterns. Permissions are loaded from the backend at login and stored in `usePermissionsStore`. Never hardcode role names to guard access — always check CASL abilities.

---

## DOCUMENTATION — consult before answering if uncertain

- **CASL React**: https://casl.js.org/v6/en/package/casl-react
- **CASL ability**: https://casl.js.org/v6/en/guide/intro
- **Next.js middleware**: https://nextjs.org/docs/app/building-your-application/routing/middleware

---

## Architecture context

```
features/permissions/logic/
  permissions-store.ts         # Zustand store: PureAbility instance + raw rules

features/auth/components/
  auth-redirect.tsx            # Client component: guards routes and enforces onboarding

src/shared/enums/
  permissions.enum.ts          # Actions enum (READ, CREATE, UPDATE, DELETE, MANAGE)
  resources.enum.ts            # TenantResourceObjectEnum, PlatformResourceObjectEnum
```

**Permission flow:**
1. User logs in → backend returns `permissions[]` (array of `{ action, subject }` rules)
2. `usePermissionsStore.setPermissions(rules)` builds a `PureAbility` instance
3. Components check `permissions.can(action, subject)` or `haveSomePermission(rules)`
4. `AuthRedirect` uses sidebar config permissions to block entire routes

---

## STEP 1 — Identify what needs guarding

Ask the user if not provided:
- **What resource is being protected?** (e.g., `AGENTS`, `BILLING`, `SETTINGS`)
- **What action?** (`READ`, `CREATE`, `UPDATE`, `DELETE`, `MANAGE`)
- **Where is the check needed?**
  - Entire route/page → `AuthRedirect` + sidebar config
  - Component render (show/hide button, section) → `permissions.can()`
  - Multiple permissions (any of them) → `haveSomePermission()`

---

## STEP 2 — Check permission in a component

### Single permission check
```tsx
'use client';

import { usePermissionsStore } from '@/features/permissions/logic/permissions-store';
import { Actions } from '@/shared/enums/permissions.enum';
import { TenantResourceObjectEnum } from '@/shared/enums/resources.enum';

export function AgentActions({ agentId }: { agentId: string }) {
  const permissions = usePermissionsStore((state) => state.permissions);

  const canCreate = permissions.can(Actions.CREATE, TenantResourceObjectEnum.AGENTS);
  const canDelete = permissions.can(Actions.DELETE, TenantResourceObjectEnum.AGENTS);

  return (
    <div>
      {canCreate && <button>Create Agent</button>}
      {canDelete && <button>Delete</button>}
    </div>
  );
}
```

### Check any of multiple permissions (`haveSomePermission`)
```tsx
'use client';

import { usePermissionsStore } from '@/features/permissions/logic/permissions-store';
import { Actions } from '@/shared/enums/permissions.enum';
import { TenantResourceObjectEnum } from '@/shared/enums/resources.enum';

export function BillingSection() {
  const haveSomePermission = usePermissionsStore((state) => state.haveSomePermission);

  const canAccessBilling = haveSomePermission([
    { action: Actions.READ, subject: TenantResourceObjectEnum.BILLING },
    { action: Actions.MANAGE, subject: TenantResourceObjectEnum.BILLING },
  ]);

  if (!canAccessBilling) return null;

  return <div>{/* billing content */}</div>;
}
```

### Permission check outside React (in handlers or stores)
```typescript
import { usePermissionsStore } from '@/features/permissions/logic/permissions-store';
import { Actions } from '@/shared/enums/permissions.enum';
import { TenantResourceObjectEnum } from '@/shared/enums/resources.enum';

// Access store state synchronously outside React
const { permissions } = usePermissionsStore.getState();

if (!permissions.can(Actions.UPDATE, TenantResourceObjectEnum.AGENTS)) {
  // handle unauthorized
  return;
}
```

---

## STEP 3 — Protect an entire route

Route protection happens in `AuthRedirect` via the sidebar config. To protect a new route:

**1. Add permissions to the sidebar item config** (`features/auth/model/consts/sidebar.const.ts`):
```typescript
{
  path: '/billing',
  label: 'Billing',
  icon: CreditCardIcon,
  permissions: [
    { action: Actions.READ, subject: TenantResourceObjectEnum.BILLING },
  ],
},
```

**2. `AuthRedirect` will automatically block the route** if the user lacks the required permissions, redirecting to `/403`.

**If the route is NOT in the sidebar** (e.g., a detail page `/agents/:id`), add an explicit check in the view:
```tsx
'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { usePermissionsStore } from '@/features/permissions/logic/permissions-store';
import { Actions } from '@/shared/enums/permissions.enum';
import { TenantResourceObjectEnum } from '@/shared/enums/resources.enum';

export function AgentDetailView({ agentId }: { agentId: string }) {
  const router = useRouter();
  const permissions = usePermissionsStore((state) => state.permissions);

  useEffect(() => {
    if (!permissions.can(Actions.READ, TenantResourceObjectEnum.AGENTS)) {
      router.replace('/403');
    }
  }, [permissions, router]);

  // render view...
}
```

---

## STEP 4 — Impersonation restrictions

When a user is being impersonated, `DELETE` actions must be blocked even if the ability allows them. This is already enforced in `AbilityFactory` on the backend, but verify on the frontend:

```tsx
const isImpersonating = useAuthStore((state) => !!state.user?.impersonatedUserId);
const permissions = usePermissionsStore((state) => state.permissions);

const canDelete = !isImpersonating && permissions.can(Actions.DELETE, TenantResourceObjectEnum.AGENTS);
```

---

## STEP 5 — Review checklist

When reviewing existing code for permission issues:

- [ ] **No role-string comparisons** — `user.role === 'Admin'` is fragile; use `permissions.can()` instead
- [ ] **No hardcoded visibility** — `isAdmin && <Component />` bypasses CASL; use ability checks
- [ ] **Correct resource enum** — tenant resources use `TenantResourceObjectEnum`; platform resources use `PlatformResourceObjectEnum`
- [ ] **`haveSomePermission` for OR logic** — don't chain multiple `permissions.can()` with `||` manually
- [ ] **Sidebar config updated** — new routes must be registered in sidebar config if they need route-level protection
- [ ] **Impersonation check on destructive actions** — always block DELETE/hard mutations during impersonation

---

## ANTI-PATTERNS to flag

| Anti-pattern | Fix |
|---|---|
| `user.role === 'Agency Owner'` | `permissions.can(Actions.MANAGE, TenantResourceObjectEnum.X)` |
| Hiding UI without checking permissions | Always check ability — UI hiding is not access control |
| `permissions.can('read', 'all')` with strings | Use enums: `Actions.READ`, `TenantResourceObjectEnum.X` |
| Calling `setPermissions` anywhere other than login | Only set permissions once at login; never patch mid-session |
| Missing `null` guard on `permissions` before `can()` | Store always initializes with `new PureAbility([])` — safe to call directly |
| Route protection only via CSS `display: none` | Always redirect unauthorized users — never just hide the UI |

## ABSOLUTE RULES

- Never check permissions by comparing role strings — always use CASL `permissions.can()`
- Always use `Actions` enum and `TenantResourceObjectEnum` / `PlatformResourceObjectEnum` — never raw strings
- Route-level protection belongs in sidebar config (for sidebar routes) or an `useEffect` redirect (for non-sidebar routes)
- Impersonated users must never be able to perform DELETE or irreversible actions
- Permission checks are client-side UX only — the backend enforces the real authorization via `PermissionsGuard`
