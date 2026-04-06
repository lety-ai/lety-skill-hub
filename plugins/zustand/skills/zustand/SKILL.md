---
name: fe-zustand-store
description: Scaffold Zustand v5 stores for Lety 2.0 Frontend — persisted stores with partialize and onRehydrateStorage, and non-persisted UI stores. Triggered when the user needs client-side state management for a feature.
---

You are generating a **Zustand v5 store** for the Lety 2.0 Frontend (Zustand v5 + TypeScript + Next.js 15 App Router).

> **Priority rule**: Always follow the Zustand v5 docs. Use the `create` API with explicit TypeScript types. For persisted stores, always include `partialize` to control what gets serialized and `onRehydrateStorage` for stores that need to reconstruct non-serializable values (like CASL abilities).

---

## DOCUMENTATION — consult before answering if uncertain

- **Zustand v5**: https://zustand.docs.pmnd.rs/getting-started/introduction
- **Zustand persist middleware**: https://zustand.docs.pmnd.rs/integrations/persisting-store-data
- **Zustand TypeScript guide**: https://zustand.docs.pmnd.rs/guides/typescript

---

## Architecture context

```
features/<feature>/logic/store/
  <feature>-store.ts           # Non-persisted UI store (modals, selection, filters)
  <feature>-list-store.ts      # Pagination + search store (usually persisted)

features/auth/logic/
  auth-store.ts                # Persisted: user session
features/permissions/logic/
  permissions-store.ts         # Persisted with onRehydrateStorage (CASL PureAbility)
```

Store files live in `features/<feature>/logic/store/`. Shared stores used across features go in `src/shared/`.

---

## STEP 1 — Identify store type

Ask the user if not provided:
- **What state does it hold?** (pagination? UI flags? auth? domain data?)
- **Needs persistence?** (survives page refresh — stored in localStorage)
- **Has non-serializable values?** (class instances like `PureAbility` need `onRehydrateStorage`)

---

## STEP 2 — Non-persisted UI store

Use for: modal open/close, selected item IDs, loading flags, temp form state.

```typescript
// features/<feature>/logic/store/<feature>-store.ts
import { create } from 'zustand';

type <Feature>State = {
  isCreateModalOpen: boolean;
  selectedId: string | null;
};

type <Feature>Actions = {
  openCreateModal: () => void;
  closeCreateModal: () => void;
  setSelectedId: (id: string | null) => void;
  reset: () => void;
};

type <Feature>StoreType = <Feature>State & <Feature>Actions;

const initialState: <Feature>State = {
  isCreateModalOpen: false,
  selectedId: null,
};

export const use<Feature>Store = create<<Feature>StoreType>()((set) => ({
  ...initialState,
  openCreateModal: () => set({ isCreateModalOpen: true }),
  closeCreateModal: () => set({ isCreateModalOpen: false }),
  setSelectedId: (id) => set({ selectedId: id }),
  reset: () => set(initialState),
}));
```

---

## STEP 3 — Persisted pagination + search store

Use for: list views with pagination, search, and filters that should survive navigation.

```typescript
// features/<feature>/logic/store/<feature>-list-store.ts
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

type PaginationMeta = {
  currentPage: number;
  itemsPerPage: number;
  totalItems: number;
  totalPages: number;
};

type <Feature>ListState = {
  paginationMeta: PaginationMeta;
  query: string;
};

type <Feature>ListActions = {
  setCurrentPage: (page: number) => void;
  setItemsPerPage: (limit: number) => void;
  setTotalItems: (total: number) => void;
  setQuery: (query: string) => void;
  resetPagination: () => void;
};

type <Feature>ListStoreType = <Feature>ListState & <Feature>ListActions;

const initialPagination: PaginationMeta = {
  currentPage: 1,
  itemsPerPage: 10,
  totalItems: 0,
  totalPages: 0,
};

export const use<Feature>ListStore = create<<Feature>ListStoreType>()(
  persist(
    (set) => ({
      paginationMeta: initialPagination,
      query: '',

      setCurrentPage: (page) =>
        set((state) => ({ paginationMeta: { ...state.paginationMeta, currentPage: page } })),

      setItemsPerPage: (limit) =>
        set((state) => ({
          paginationMeta: { ...state.paginationMeta, itemsPerPage: limit, currentPage: 1 },
        })),

      setTotalItems: (total) =>
        set((state) => ({ paginationMeta: { ...state.paginationMeta, totalItems: total } })),

      setQuery: (query) =>
        set({ query, paginationMeta: { ...initialPagination } }), // reset page on new search

      resetPagination: () => set({ paginationMeta: initialPagination }),
    }),
    {
      name: '<feature>-list-storage',
      partialize: (state) => ({
        paginationMeta: state.paginationMeta,
        query: state.query,
      }),
    },
  ),
);
```

---

## STEP 4 — Persisted store with non-serializable values

Use for: stores that hold class instances (CASL `PureAbility`, Date objects) that cannot be JSON-serialized.

```typescript
// Pattern from permissions-store.ts
import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { PureAbility } from '@casl/ability';

type PermissionsState = {
  permissions: PureAbility;   // NOT serializable
  rules: Permission[];         // Serializable — stored in localStorage
};

export const usePermissionsStore = create<PermissionsState>()(
  persist(
    (set) => ({
      permissions: new PureAbility([]),
      rules: [],
      setPermissions: (rules: Permission[]) =>
        set({ permissions: new PureAbility(rules as any), rules }),
    }),
    {
      name: 'permissions-storage',
      // Only persist serializable data
      partialize: (state) => ({ rules: state.rules }),
      // Reconstruct non-serializable values on hydration
      onRehydrateStorage: () => (state) => {
        if (state) {
          state.permissions = new PureAbility((state.rules as any) ?? []);
        }
      },
    },
  ),
);
```

---

## STEP 5 — Multi-step wizard store (non-persisted)

Use for: tracking current step, completed steps, and wizard navigation.

```typescript
// features/<feature>/logic/store/<feature>-wizard-store.ts
import { create } from 'zustand';

const TOTAL_STEPS = 3;

type WizardState = {
  currentStep: number;
  completedSteps: Set<number>;
};

type WizardActions = {
  nextStep: () => void;
  prevStep: () => void;
  goToStep: (step: number) => void;
  markStepCompleted: (step: number) => void;
  reset: () => void;
};

export const use<Feature>WizardStore = create<WizardState & WizardActions>()((set) => ({
  currentStep: 0,
  completedSteps: new Set(),

  nextStep: () =>
    set((state) => ({
      currentStep: Math.min(state.currentStep + 1, TOTAL_STEPS - 1),
      completedSteps: new Set([...state.completedSteps, state.currentStep]),
    })),

  prevStep: () =>
    set((state) => ({ currentStep: Math.max(state.currentStep - 1, 0) })),

  goToStep: (step) => set({ currentStep: step }),

  markStepCompleted: (step) =>
    set((state) => ({ completedSteps: new Set([...state.completedSteps, step]) })),

  reset: () => set({ currentStep: 0, completedSteps: new Set() }),
}));
```

---

## STEP 6 — Accessing store outside React components

```typescript
// Access current state synchronously (outside hooks)
const { user } = useAuthStore.getState();

// Subscribe to changes outside React
const unsubscribe = useAuthStore.subscribe(
  (state) => state.user,
  (user) => console.log('User changed:', user),
);
```

---

## ANTI-PATTERNS to flag

| Anti-pattern | Fix |
|---|---|
| Storing server state in Zustand | Use TanStack Query for server data — Zustand is for client/UI state only |
| No `partialize` in persisted store | Always `partialize` to avoid persisting functions or stale data |
| Non-serializable values without `onRehydrateStorage` | Class instances break JSON serialization — add `onRehydrateStorage` |
| `set({ ...state, field: val })` spreading whole state | Just `set({ field: val })` — Zustand merges automatically |
| Single massive store for everything | Split by domain — one store per concern |
| `persist` storage key clash | Use unique `name` per store (e.g., `'agent-list-storage'`, not `'storage'`) |
| Reading store in server component | Zustand stores are client-only — only read in `'use client'` components |

## ABSOLUTE RULES

- Separate State type from Actions type — always define both explicitly
- Always define `initialState` as a constant and reference it in `reset()`
- Always `partialize` persisted stores — never serialize the entire state
- Never store server/API response data in Zustand — that belongs in TanStack Query cache
- Store files live in `features/<feature>/logic/store/` with `-store.ts` suffix
- Shared stores used across features go in `src/shared/`
