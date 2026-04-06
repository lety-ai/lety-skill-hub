---
name: fe-feature-module
description: Scaffold a complete Lety 2.0 Frontend feature module following Screaming Architecture + Atomic Design. Triggered when the user wants to create a new feature, page, or domain module in the frontend.
---

You are scaffolding a **feature module** for the Lety 2.0 Frontend (Next.js 15 App Router + TypeScript).

> **Priority rule**: Always follow the project's `architecture_guide.md` and official Next.js 15 docs. The folder structure must scream the intent — organized by domain, not by file type.

---

## DOCUMENTATION — consult before answering if uncertain

- **Next.js 15 App Router**: https://nextjs.org/docs/app
- **Next.js routing**: https://nextjs.org/docs/app/building-your-application/routing
- **architecture_guide.md**: `/home/lockd/lety/Lety-2.0_Frontend/architecture_guide.md`

---

## Architecture context

```
src/
├── app/<feature>/page.tsx         # Thin route — only imports the View
├── features/<feature>/
│   ├── components/                # UI components specific to this feature
│   ├── views/                     # Full page screens composed from components + logic
│   ├── services/                  # TanStack Query hooks + API calls
│   ├── model/
│   │   ├── interfaces/            # *.d.ts
│   │   ├── enums/                 # *.enum.ts
│   │   └── consts/                # *.const.ts
│   └── logic/
│       ├── store/                 # Zustand stores
│       ├── handlers/              # Action handlers
│       └── <name>.schema.ts       # Zod schemas
```

---

## STEP 1 — Gather information

Ask the user if not provided:
- **Feature name** (e.g., `agents`, `billing`, `onboarding`) — becomes the folder name in kebab-case
- **Has a list view?** (needs pagination store + list service hook)
- **Has a create/edit form?** (needs Zod schema + mutation hook)
- **Has permissions?** (needs CASL checks)
- **Has real-time data?** (needs Socket.io hook)

---

## STEP 2 — Generate folder structure

Show the complete folder tree before writing any file:

```
src/
├── app/<feature>/
│   └── page.tsx
├── features/<feature>/
│   ├── components/
│   │   └── (feature-specific UI components)
│   ├── views/
│   │   └── <Feature>View.tsx
│   ├── services/
│   │   └── get-<feature>.ts
│   ├── model/
│   │   ├── interfaces/
│   │   │   └── <feature>.d.ts
│   │   ├── enums/
│   │   │   └── <feature>.enum.ts
│   │   └── consts/
│   │       └── <feature>.const.ts
│   └── logic/
│       └── store/
│           └── <feature>-store.ts
```

---

## STEP 3 — Generate each file

### `app/<feature>/page.tsx` — thin route, always `'use client'`
```tsx
'use client';

import { <Feature>View } from '@/features/<feature>/views/<Feature>View';

export default function <Feature>Page() {
  return <<Feature>View />;
}
```

### `features/<feature>/views/<Feature>View.tsx`
```tsx
'use client';

import { use<Feature>Store } from '@/features/<feature>/logic/store/<feature>-store';
import { useGet<Feature>List } from '@/features/<feature>/services/get-<feature>-list';

export function <Feature>View() {
  const { } = use<Feature>Store();
  const { items, isLoading } = useGet<Feature>List();

  return (
    <div>
      {/* View content */}
    </div>
  );
}
```

### `features/<feature>/model/interfaces/<feature>.d.ts`
```typescript
export interface <Feature> {
  id: string;
  // fields from OpenAPI types — import from @/shared/types/openapi
  createdAt: string;
  updatedAt: string;
}
```

### `features/<feature>/model/enums/<feature>.enum.ts`
```typescript
export enum <Feature>StatusEnum {
  ACTIVE = 'active',
  INACTIVE = 'inactive',
}
```

### `features/<feature>/model/consts/<feature>.const.ts`
```typescript
export const <FEATURE>_QUERY_KEY = '<feature>' as const;
```

---

## STEP 4 — Add optional files based on answers from STEP 1

**If has list view** → add pagination store (see `fe-zustand-store` skill pattern)

**If has create/edit form** → add:
- `logic/<feature>-create.schema.ts` (see `fe-zod-form` skill pattern)
- `services/create-<feature>.ts` (see `fe-service-hook` skill pattern)

**If has permissions** → add permission checks in view (see `fe-permissions` skill pattern)

---

## STEP 5 — Remind about OpenAPI types

> **Never define domain types manually if they exist in OpenAPI.**
> Check `src/shared/types/openapi.d.ts` first. Import response/request types from there:
> ```typescript
> import type { components } from '@/shared/types/openapi';
> type <Feature> = components['schemas']['<FeatureResponse>'];
> ```
> Regenerate types when the backend changes: `pnpm generate:types`

---

## NAMING RULES

| Element | Convention | Example |
|---------|-----------|---------|
| Folder names | kebab-case | `wallet-billing/` |
| File names | kebab-case | `get-agents.ts` |
| React components | PascalCase | `AgentCard.tsx` |
| Type/interface files | `.d.ts` | `agent.d.ts` |
| Enum files | `.enum.ts` | `agentStatus.enum.ts` |
| Constant files | `.const.ts` | `agent.const.ts` |
| Zod schema files | `.schema.ts` in `logic/` | `createAgent.schema.ts` |
| Zustand stores | `-store.ts` in `logic/store/` | `agent-list-store.ts` |

## ABSOLUTE RULES

- `app/*/page.tsx` is always thin — only imports the View, zero logic
- Never put business logic in `app/` — it belongs in `features/`
- Never put feature-specific components in `shared/` — promote only when used by 2+ features
- Always use `@/` path aliases, never relative `../../` imports across feature boundaries
- OpenAPI types are the source of truth for domain shapes — never duplicate them manually
