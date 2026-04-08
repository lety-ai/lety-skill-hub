---
name: fe-service-hook
description: Generate TanStack Query v5 useQuery or useMutation hooks for Lety 2.0 Frontend using the ApiSDK pattern. Triggered when the user needs to fetch data, create, update, or delete resources via the API.
---

You are generating a **service hook** for the Lety 2.0 Frontend (TanStack Query v5 + ApiSDK + TypeScript).

> **Priority rule**: Always follow TanStack Query v5 docs and the project's ApiSDK pattern. Never use `axios` directly — always go through `ApiSDK.getClient()`. Never use `.toPromise()` — use `async/await` inside `queryFn`/`mutationFn`.

---

## DOCUMENTATION — consult before answering if uncertain

- **TanStack Query v5**: https://tanstack.com/query/latest/docs/framework/react/overview
- **useQuery**: https://tanstack.com/query/latest/docs/framework/react/reference/useQuery
- **useMutation**: https://tanstack.com/query/latest/docs/framework/react/reference/useMutation
- **Query invalidation**: https://tanstack.com/query/latest/docs/framework/react/guides/query-invalidation

---

## Architecture context

```
features/<feature>/services/
  get-<feature>.ts         # useQuery hook
  get-<feature>-list.ts    # useQuery hook with pagination
  create-<feature>.ts      # useMutation hook
  update-<feature>.ts      # useMutation hook
  delete-<feature>.ts      # useMutation hook
```

**ApiSDK singleton** (`src/shared/config/api-client.ts`):
- `ApiSDK.getClient()` — returns the auto-generated OpenAPI Axios client (async)
- The client methods map 1:1 to OpenAPI operations
- Bearer token is attached automatically by the request interceptor
- 401 → auto logout, 402/403 → subscription error handling

**Query defaults** (set globally in root layout):
```typescript
staleTime: 1000 * 60 * 3,   // 3 minutes
gcTime: 1000 * 10 * 3,      // 30 seconds
retry: false,
refetchOnWindowFocus: true,
```

---

## STEP 1 — Identify what to generate

Ask the user if not provided:
- **Operation type**: query (read) or mutation (create/update/delete)?
- **Resource name**: what entity? (e.g., `agent`, `invoice`, `subaccount`)
- **OpenAPI method name**: check `src/shared/types/openapi.d.ts` for the exact operation ID
- **Depends on pagination store?** (list queries that use Zustand pagination)
- **Depends on filters/search?** (query params from store)

---

## STEP 2 — Generate useQuery hook

### Simple query (single resource by ID)
```typescript
// features/<feature>/services/get-<feature>.ts
import { useQuery } from '@tanstack/react-query';
import { ApiSDK } from '@/shared/config/api-client';
import type { components } from '@/shared/types/openapi';

type <Feature>Response = components['schemas']['<FeatureResponse>'];

export const useGet<Feature> = (id: string) => {
  const { data, isLoading, error } = useQuery({
    queryKey: ['<feature>', id],
    queryFn: async () => {
      const client = await ApiSDK.getClient();
      const response = await client.<operationId>(id);
      return response.data;
    },
    enabled: !!id,
  });

  return {
    <feature>: data,
    isLoading,
    error,
  };
};
```

### List query with pagination from Zustand store
```typescript
// features/<feature>/services/get-<feature>-list.ts
import { useQuery } from '@tanstack/react-query';
import { ApiSDK } from '@/shared/config/api-client';
import { use<Feature>ListStore } from '@/features/<feature>/logic/store/<feature>-list-store';
import type { components } from '@/shared/types/openapi';

type <Feature>ListResponse = components['schemas']['<FeatureListResponse>'];

export const useGet<Feature>List = () => {
  const { paginationMeta: { currentPage, itemsPerPage }, query } = use<Feature>ListStore();

  const { data, isLoading, error } = useQuery({
    queryKey: ['<feature>s', currentPage, itemsPerPage, query],
    queryFn: async () => {
      const client = await ApiSDK.getClient();
      const response = await client.getAll<Feature>s({
        page: currentPage,
        limit: itemsPerPage,
        query,
      });
      return response.data;
    },
  });

  return {
    items: data?.items ?? [],
    total: data?.total ?? 0,
    isLoading,
    error,
  };
};
```

---

## STEP 3 — Generate useMutation hook

### Create mutation
```typescript
// features/<feature>/services/create-<feature>.ts
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { AxiosError } from 'axios';
import { ApiSDK } from '@/shared/config/api-client';
import { handleAxiosErrorToast } from '@/shared/utils/handle-axios-error-toast';
import type { components } from '@/shared/types/openapi';
import type { Create<Feature>FormValues } from '@/features/<feature>/logic/<feature>-create.schema';

type Create<Feature>Response = components['schemas']['<FeatureResponse>'];

export const useCreate<Feature> = () => {
  const queryClient = useQueryClient();

  return useMutation<Create<Feature>Response, AxiosError, Create<Feature>FormValues>({
    mutationFn: async (data) => {
      const client = await ApiSDK.getClient();
      const response = await client.create<Feature>(null, data);
      return response.data;
    },
    onError: (error) => handleAxiosErrorToast(error, 'Failed to create <feature>'),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['<feature>s'] });
    },
  });
};
```

### Update mutation
```typescript
// features/<feature>/services/update-<feature>.ts
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { AxiosError } from 'axios';
import { ApiSDK } from '@/shared/config/api-client';
import { handleAxiosErrorToast } from '@/shared/utils/handle-axios-error-toast';
import type { components } from '@/shared/types/openapi';
import type { Update<Feature>FormValues } from '@/features/<feature>/logic/<feature>-update.schema';

type Update<Feature>Response = components['schemas']['<FeatureResponse>'];

export const useUpdate<Feature> = (id: string) => {
  const queryClient = useQueryClient();

  return useMutation<Update<Feature>Response, AxiosError, Update<Feature>FormValues>({
    mutationFn: async (data) => {
      const client = await ApiSDK.getClient();
      const response = await client.update<Feature>(id, data);
      return response.data;
    },
    onError: (error) => handleAxiosErrorToast(error, 'Failed to update <feature>'),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['<feature>s'] });
      queryClient.invalidateQueries({ queryKey: ['<feature>', id] });
    },
  });
};
```

### Delete mutation
```typescript
// features/<feature>/services/delete-<feature>.ts
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { AxiosError } from 'axios';
import { ApiSDK } from '@/shared/config/api-client';
import { handleAxiosErrorToast } from '@/shared/utils/handle-axios-error-toast';

export const useDelete<Feature> = () => {
  const queryClient = useQueryClient();

  return useMutation<void, AxiosError, string>({
    mutationFn: async (id) => {
      const client = await ApiSDK.getClient();
      await client.delete<Feature>(id);
    },
    onError: (error) => handleAxiosErrorToast(error, 'Failed to delete <feature>'),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['<feature>s'] });
    },
  });
};
```

### Multipart/file upload mutation
```typescript
mutationFn: async (data) => {
  const client = await ApiSDK.getClient();
  const formData = prepareFormData<Create<Feature>Request>(data);
  const response = await client.create<Feature>(null, formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
  return response.data;
},
```

---

## STEP 4 — queryKey conventions

| Pattern | queryKey |
|---------|----------|
| All items | `['<feature>s']` |
| All items with filters | `['<feature>s', page, limit, query]` |
| Single item by ID | `['<feature>', id]` |
| Nested resource | `['<feature>', featureId, '<subresource>s']` |

- `invalidateQueries` after mutations must target the correct key prefix
- Use `enabled: !!id` on queries that depend on a parameter that may be undefined

---

## ANTI-PATTERNS to flag

| Anti-pattern | Fix |
|---|---|
| `axios.get(...)` directly | Use `ApiSDK.getClient()` |
| `.toPromise()` on Observable | Use `async/await` in `queryFn` |
| Missing `onError` in mutation | Always add `handleAxiosErrorToast` |
| Hardcoded `queryKey: ['data']` | Use specific, scoped keys |
| `staleTime: 0` on every query | Only override when real-time freshness is required |
| `queryKey` without filter params | Stale data shown when filters change |
| Manual `refetch()` after mutation | Use `invalidateQueries` instead |

## ABSOLUTE RULES

- Always use `ApiSDK.getClient()` — never import axios directly in service hooks
- Always type mutations with `useMutation<TData, AxiosError, TVariables>`
- Always call `handleAxiosErrorToast` in `onError`
- Always `invalidateQueries` in `onSuccess` for mutations that change list state
- Never share mutable state between query hooks — each hook is self-contained
- OpenAPI types from `@/shared/types/openapi` are the source of truth — never duplicate them
