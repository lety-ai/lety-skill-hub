# Frontend Test Patterns

Reference for React custom hooks, Zustand stores, Zod schemas, and TanStack Query hooks.

The frontend uses **Vitest** (not Jest) with `@testing-library/react` for hooks and components.

---

## Custom Hook Tests (`renderHook`)

Use `renderHook` from `@testing-library/react` to test hooks in isolation. Never test hooks inside a full component render.

### File: `src/features/<domain>/hooks/__tests__/use-<hook>.test.ts`

```typescript
import { renderHook, act } from '@testing-library/react';
import { useFileUpload } from '../use-file-upload';

describe('useFileUpload', () => {
  it('should start in idle state', () => {
    const { result } = renderHook(() => useFileUpload());

    expect(result.current.uploading).toBe(false);
    expect(result.current.error).toBeNull();
    expect(result.current.progress).toBe(0);
    expect(result.current.file).toBeNull();
  });

  it('should set file on setFile', () => {
    const { result } = renderHook(() => useFileUpload());
    const file = new File(['content'], 'test.pdf', { type: 'application/pdf' });

    act(() => {
      result.current.setFile(file);
    });

    expect(result.current.file).toBe(file);
  });

  it('should set uploading=true while uploading and false after', async () => {
    // Mock the uploadFile dependency
    vi.mock('../upload-file', () => ({
      uploadFile: vi.fn().mockResolvedValue(undefined),
    }));

    const { result } = renderHook(() => useFileUpload());
    const file = new File([''], 'doc.pdf');

    act(() => { result.current.setFile(file); });

    // Don't await — check uploading=true during the upload
    const uploadPromise = act(async () => { await result.current.upload(); });
    
    await uploadPromise;
    expect(result.current.uploading).toBe(false); // reset after done
    expect(result.current.error).toBeNull();
  });

  it('should set error and reset uploading on failure', async () => {
    vi.mock('../upload-file', () => ({
      uploadFile: vi.fn().mockRejectedValue(new Error('Network error')),
    }));

    const { result } = renderHook(() => useFileUpload());
    act(() => { result.current.setFile(new File([''], 'doc.pdf')); });

    await act(async () => { await result.current.upload(); });

    expect(result.current.uploading).toBe(false);
    expect(result.current.error).toBe('Network error');
  });
});
```

**Rules:**
- Always wrap state-changing calls in `act()` — React will warn otherwise
- Use `await act(async () => { ... })` for async operations
- Mock external dependencies with `vi.mock()` at the top of the file
- `renderHook` re-renders when the hook's deps change — use `rerender` for that
- Test the hook's **contract** (inputs/outputs), not its internal state variables

---

## Zustand Store Tests

Test stores by creating a fresh store instance per test — never share store state between tests.

### File: `src/features/<domain>/logic/store/__tests__/<domain>-store.test.ts`

```typescript
import { act, renderHook } from '@testing-library/react';
import { create } from 'zustand';

// Import the store factory (not the singleton) — or reset between tests
import { createLeadsUiStore } from '../leads-ui-store';

describe('useLeadsUiStore', () => {
  // Create a fresh store for each test — never use the singleton
  let useStore: ReturnType<typeof createLeadsUiStore>;

  beforeEach(() => {
    useStore = createLeadsUiStore();
  });

  it('should have correct initial state', () => {
    const { result } = renderHook(() => useStore());

    expect(result.current.selectedLeadId).toBeNull();
    expect(result.current.isDetailModalOpen).toBe(false);
    expect(result.current.activeTab).toBe('all');
  });

  it('should open modal and set selectedLeadId on setSelectedLead', () => {
    const { result } = renderHook(() => useStore());
    const leadId = 'lead-123';

    act(() => {
      result.current.setSelectedLead(leadId);
    });

    expect(result.current.selectedLeadId).toBe(leadId);
    expect(result.current.isDetailModalOpen).toBe(true);
  });

  it('should clear selectedLeadId and close modal on closeDetail', () => {
    const { result } = renderHook(() => useStore());

    act(() => { result.current.setSelectedLead('lead-123'); });
    act(() => { result.current.closeDetail(); });

    expect(result.current.selectedLeadId).toBeNull();
    expect(result.current.isDetailModalOpen).toBe(false);
  });

  it('should change activeTab on setTab', () => {
    const { result } = renderHook(() => useStore());

    act(() => { result.current.setTab('active'); });

    expect(result.current.activeTab).toBe('active');
  });
});
```

**If the store is exported as a singleton** (not a factory), reset it between tests:
```typescript
import { useLeadsUiStore } from '../leads-ui-store';

beforeEach(() => {
  // Reset to initial state — use getInitialState() if exported, or setState directly
  useLeadsUiStore.setState(useLeadsUiStore.getInitialState());
});
```

**Rules:**
- Always test stores with a fresh instance or explicit reset — shared state causes order-dependent failures
- Test state transitions, not implementation details (don't assert `set()` was called)
- Persisted stores: test the `partialize` output separately if the logic is complex

---

## Zod Schema Tests

Schema tests are pure — no React, no mocks needed. Test valid inputs, invalid inputs, and transformations.

### File: `src/features/<domain>/logic/__tests__/<schema>.schema.test.ts`

```typescript
import { createLeadSchema, type CreateLeadInput } from '../create-lead.schema';

describe('createLeadSchema', () => {
  const validInput: CreateLeadInput = {
    name: 'Acme Corp',
    email: 'contact@acme.com',
    phone: '+52 55 1234 5678',
  };

  describe('valid inputs', () => {
    it('should parse a complete valid object', () => {
      const result = createLeadSchema.safeParse(validInput);
      expect(result.success).toBe(true);
    });

    it('should allow optional phone to be absent', () => {
      const { phone: _, ...withoutPhone } = validInput;
      const result = createLeadSchema.safeParse(withoutPhone);
      expect(result.success).toBe(true);
    });
  });

  describe('invalid inputs', () => {
    it('should fail when name is empty', () => {
      const result = createLeadSchema.safeParse({ ...validInput, name: '' });
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues[0].path).toContain('name');
      }
    });

    it('should fail when email is malformed', () => {
      const result = createLeadSchema.safeParse({ ...validInput, email: 'not-an-email' });
      expect(result.success).toBe(false);
    });

    it('should fail when required field is missing', () => {
      const { name: _, ...withoutName } = validInput;
      const result = createLeadSchema.safeParse(withoutName);
      expect(result.success).toBe(false);
    });
  });

  describe('transformations', () => {
    it('should trim whitespace from name', () => {
      const result = createLeadSchema.safeParse({ ...validInput, name: '  Acme Corp  ' });
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Acme Corp');
      }
    });

    it('should lowercase email', () => {
      const result = createLeadSchema.safeParse({ ...validInput, email: 'CONTACT@ACME.COM' });
      if (result.success) {
        expect(result.data.email).toBe('contact@acme.com');
      }
    });
  });
});
```

**Rules:**
- Always check `result.success` before accessing `result.data` — TypeScript will require it
- For error assertions, check `result.error.issues[0].path` to verify the right field is flagged
- Test transformations (`.trim()`, `.toLowerCase()`) explicitly — they're behavior, not implementation

---

## TanStack Query Hook Tests

Use `QueryClient` + a `QueryClientProvider` wrapper to test query hooks in isolation.

### File: `src/features/<domain>/services/__tests__/use-leads-query.test.ts`

```typescript
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { renderHook, waitFor } from '@testing-library/react';
import React from 'react';
import { vi } from 'vitest';
import { useLeadsQuery } from '../use-leads-query';
import { sdk } from '@/lib/sdk'; // adjust to your SDK path

// Mock the SDK
vi.mock('@/lib/sdk', () => ({
  sdk: {
    leads: {
      findAll: vi.fn(),
    },
  },
}));

function makeWrapper() {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        retry: false, // Don't retry on failure in tests — makes failures deterministic
        gcTime: 0,    // Don't cache between tests
      },
    },
  });
  return ({ children }: { children: React.ReactNode }) =>
    React.createElement(QueryClientProvider, { client: queryClient }, children);
}

describe('useLeadsQuery', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should return leads on success', async () => {
    const leads = [{ id: '1', name: 'Acme' }];
    vi.mocked(sdk.leads.findAll).mockResolvedValue({ items: leads, meta: { total: 1 } });

    const { result } = renderHook(() => useLeadsQuery(), { wrapper: makeWrapper() });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(result.current.data?.items).toEqual(leads);
    expect(sdk.leads.findAll).toHaveBeenCalledTimes(1);
  });

  it('should set isError when fetch fails', async () => {
    vi.mocked(sdk.leads.findAll).mockRejectedValue(new Error('API error'));

    const { result } = renderHook(() => useLeadsQuery(), { wrapper: makeWrapper() });

    await waitFor(() => expect(result.current.isError).toBe(true));
    expect(result.current.error?.message).toBe('API error');
  });

  it('should show loading state initially', () => {
    vi.mocked(sdk.leads.findAll).mockReturnValue(new Promise(() => {})); // never resolves

    const { result } = renderHook(() => useLeadsQuery(), { wrapper: makeWrapper() });

    // Before the promise resolves — should be loading
    expect(result.current.isLoading).toBe(true);
    expect(result.current.data).toBeUndefined();
  });
});
```

**Rules:**
- Always set `retry: false` in the test `QueryClient` — default retry=3 makes failures slow and confusing
- Set `gcTime: 0` to prevent cached results bleeding between tests
- Use `waitFor()` for async state transitions — never `setTimeout`
- Create a **new** `QueryClient` per test wrapper — never reuse across tests
- Mock at the SDK layer, not at `fetch` — more maintainable and closer to reality

---

## Mutation Hook Tests

```typescript
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { renderHook, act, waitFor } from '@testing-library/react';

describe('useCreateLeadMutation', () => {
  it('should invalidate leads query on success', async () => {
    vi.mocked(sdk.leads.create).mockResolvedValue({ id: '1', name: 'New Lead' });

    const wrapper = makeWrapper();
    const { result } = renderHook(() => useCreateLeadMutation(), { wrapper });

    await act(async () => {
      result.current.mutate({ name: 'New Lead', email: 'new@test.com' });
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    // The mutation's onSuccess should have invalidated the 'leads' queryKey
    // Verify by checking if sdk.leads.create was called with the correct args
    expect(sdk.leads.create).toHaveBeenCalledWith({ name: 'New Lead', email: 'new@test.com' });
  });

  it('should expose error on mutation failure', async () => {
    vi.mocked(sdk.leads.create).mockRejectedValue(new Error('Validation failed'));

    const { result } = renderHook(() => useCreateLeadMutation(), { wrapper: makeWrapper() });

    await act(async () => { result.current.mutate({ name: '', email: '' }); });
    await waitFor(() => expect(result.current.isError).toBe(true));

    expect(result.current.error?.message).toBe('Validation failed');
  });
});
```
