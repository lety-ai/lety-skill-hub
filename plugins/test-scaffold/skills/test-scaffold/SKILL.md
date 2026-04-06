---
name: test-scaffold
description: Generate unit tests for Lety 2.0 — NestJS services, RabbitMQ consumers, gRPC controllers, React custom hooks, Zustand stores, and Zod schemas. Triggered when the user wants to write, improve, or review tests for any backend service or frontend hook/store. Also use it when the user says "write tests for X", "cover this with tests", or "my tests are failing".
---

You are writing tests for the **Lety 2.0** monorepo (NestJS + TypeORM + gRPC + RabbitMQ on backend; Next.js 15 + React + Zustand + TanStack Query on frontend).

> **Priority rule**: Follow Jest/NestJS/RTL best practices. If existing tests deviate, generate the correct version and flag the issue. Never copy broken patterns from the codebase — generate the correct version.

---

## DOCUMENTATION — consult before generating

- **NestJS Testing**: https://docs.nestjs.com/fundamentals/testing
- **Jest docs**: https://jestjs.io/docs/getting-started
- **TypeORM testing**: https://docs.nestjs.com/techniques/database#testing
- **Testing Library (React)**: https://testing-library.com/docs/react-testing-library/intro/
- **Vitest** (if frontend uses Vitest instead of Jest): https://vitest.dev/guide/

---

## STEP 1 — Identify what to test

Determine the target from what the user provides:

| Target | Go to |
|---|---|
| NestJS service (`*.service.ts`) | STEP 2 → STEP 5 (this file) |
| RabbitMQ consumer (`*.consumer.ts`) | STEP 2 → then read `references/rmq-and-advanced.md` |
| Service with transactions / QueryBuilder | STEP 2 → then read `references/rmq-and-advanced.md` |
| React custom hook (`use-*.ts`) | Read `references/frontend-tests.md` |
| Zustand store (`*-store.ts`) | Read `references/frontend-tests.md` |
| Zod schema (`*.schema.ts`) | Read `references/frontend-tests.md` |
| gRPC controller (`*.controller.ts`) | STEP 2 → STEP 5 (treat like a service with thin delegation) |

If the user hasn't provided the source file, ask for it. Never invent method signatures or field names.

---

## STEP 2 — Read the service under test

Read the file carefully and extract:

- All **injected dependencies** (`@InjectRepository`, other services, `DataSource`, `CACHE_MANAGER`, gRPC clients, `RequestContextService`)
- All **public methods** — return type and params for each
- Which methods throw `BaseRpcException` with which `status.*` code
- Which methods call `toResponseDto()` on entities
- Which methods use `dataSource.transaction()` or `QueryRunner`
- Which methods use `QueryBuilder` (`createQueryBuilder()`)
- Which methods call other services

Plan the test cases for each method before writing a line of code.

---

## STEP 3 — Generate the mock factory

### File: `apps/<service>/test/mocks/<domainPlural>-mocks.ts`

Rules:
- Export a `<Domain>EntityLike` type with only the fields used in tests
- Export a `make<Domain>Entity(partial?)` factory
- `id` defaults to `randomUUID()`
- `toResponseDto()` must be included — return a plain object with the same fields
- Add `Decimal` fields with `new Decimal('0')` default, not raw numbers
- Never use `as any` inside the factory — keep it fully typed

```typescript
import { randomUUID } from 'crypto';
import Decimal from 'decimal.js';

export type LeadEntityLike = {
  id: string;
  name: string;
  email: string;
  isActive: boolean;
  score: Decimal;
  toResponseDto: () => { id: string; name: string; email: string; score: string };
};

export function makeLeadEntity(partial: Partial<LeadEntityLike> = {}): LeadEntityLike {
  const id = partial.id ?? randomUUID();
  const name = partial.name ?? `Lead ${id.slice(0, 8)}`;
  const email = partial.email ?? `${id.slice(0, 8)}@test.com`;
  const score = partial.score ?? new Decimal('0');
  return {
    id,
    name,
    email,
    isActive: partial.isActive ?? true,
    score,
    toResponseDto: () => ({ id, name, email, score: score.toFixed(2) }),
    ...partial,
  };
}
```

---

## STEP 4 — Plan test cases per method

For each public method, plan these scenarios before writing code:

| Method type | Required scenarios |
|---|---|
| `findById` / `findOne` | ✅ found → returns entity; ❌ not found → `NOT_FOUND` |
| `findAll` / `search` | ✅ returns paginated list; ✅ empty list |
| `create` | ✅ saves and returns; ❌ duplicate → `ALREADY_EXISTS` |
| `update` | ✅ finds + updates + returns; ❌ not found → `NOT_FOUND` |
| `remove` | ✅ soft deletes; ❌ not found → `NOT_FOUND` |
| Permission-gated method | ❌ no permission → `PERMISSION_DENIED` |
| Business-rule method | ❌ rule violated → `FAILED_PRECONDITION` |

---

## STEP 5 — Generate the spec file

### File: `apps/<service>/src/<domainPlural>/<domainPlural>.service.spec.ts`

### Module setup

Declare mocks **before** `beforeEach` with their full type. Never use `Object.assign` inside tests to add missed mock methods — add them to the type and initializer.

```typescript
import { randomUUID } from 'crypto';
import { status } from '@grpc/grpc-js';
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { LeadEntity } from '@app/common/entities/tenant/leads/lead.entity';
import { RequestContextService } from '../request-context/request-context.service';
import { LeadsService } from './leads.service';
import { makeLeadEntity } from '../../test/mocks/leads-mocks';
import { BaseRpcException } from '@app/common/exceptions'; // ← always BaseRpcException

describe('LeadsService', () => {
  let service: LeadsService;
  let repo: {
    findOne: jest.Mock;
    findOneBy: jest.Mock;
    find: jest.Mock;
    save: jest.Mock;
    create: jest.Mock;
    softDelete: jest.Mock;
    // Add only methods the service actually calls
  };
  let ctxService: {
    getRequestUser: jest.Mock;
    getRequest: jest.Mock;
  };

  beforeEach(async () => {
    // Initialize ALL mock methods here — never add them mid-test
    repo = {
      findOne: jest.fn(),
      findOneBy: jest.fn(),
      find: jest.fn(),
      save: jest.fn(),
      create: jest.fn(),
      softDelete: jest.fn(),
    };
    ctxService = {
      getRequestUser: jest.fn().mockReturnValue({ id: randomUUID(), tenantId: randomUUID() }),
      getRequest: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        LeadsService,
        { provide: getRepositoryToken(LeadEntity), useValue: repo },
        { provide: RequestContextService, useValue: ctxService },
        // { provide: DataSource, useValue: { createQueryRunner: jest.fn(), transaction: jest.fn() } },
        // { provide: CACHE_MANAGER, useValue: { get: jest.fn(), set: jest.fn(), del: jest.fn() } },
        // { provide: OTHER_SERVICE, useValue: { method: jest.fn() } }, // only methods actually called
      ],
    }).compile();

    service = module.get<LeadsService>(LeadsService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  // ─── findById ────────────────────────────────────────────────────────────

  describe('findById', () => {
    it('should return the entity when found', async () => {
      const entity = makeLeadEntity();
      repo.findOneBy.mockResolvedValue(entity);

      await expect(service.findById({ id: entity.id })).resolves.toBe(entity);
      expect(repo.findOneBy).toHaveBeenCalledWith({ id: entity.id });
      expect(repo.findOneBy).toHaveBeenCalledTimes(1);
    });

    it('should throw NOT_FOUND when entity does not exist', async () => {
      const id = randomUUID();
      repo.findOneBy.mockResolvedValue(null);

      await expect(service.findById({ id })).rejects.toEqual(
        new BaseRpcException({ code: status.NOT_FOUND, message: `Lead with id: ${id} not found.` }),
      );
      expect(repo.findOneBy).toHaveBeenCalledWith({ id });
    });
  });

  // ─── findOne (returns DTO) ────────────────────────────────────────────────

  describe('findOne', () => {
    it('should return toResponseDto() result', async () => {
      const entity = makeLeadEntity();
      repo.findOneBy.mockResolvedValue(entity);

      // Use toEqual (deep equality) when comparing DTOs — not toBe (reference)
      await expect(service.findOne({ id: entity.id })).resolves.toEqual(entity.toResponseDto());
    });
  });

  // ─── create ──────────────────────────────────────────────────────────────

  describe('create', () => {
    it('should save and return the new entity', async () => {
      const entity = makeLeadEntity();
      repo.create.mockReturnValue(entity);   // create() is synchronous
      repo.save.mockResolvedValue(entity);   // save() is async

      const result = await service.create({ name: entity.name, email: entity.email });

      expect(result).toBe(entity);           // same reference — service returns what save() returns
      expect(repo.create).toHaveBeenCalledWith(expect.objectContaining({ name: entity.name }));
      expect(repo.save).toHaveBeenCalledWith(entity);
    });

    it('should throw ALREADY_EXISTS on duplicate unique field', async () => {
      const { QueryFailedError } = await import('typeorm');
      const dbError = new QueryFailedError('', [], new Error());
      (dbError as any).code = '23505'; // PostgreSQL unique violation
      repo.save.mockRejectedValue(dbError);
      repo.create.mockReturnValue(makeLeadEntity());

      await expect(service.create({ name: 'duplicate', email: 'dupe@test.com' })).rejects.toEqual(
        new BaseRpcException({ code: status.ALREADY_EXISTS, message: expect.stringContaining('already exists') }),
      );
    });
  });

  // ─── update ──────────────────────────────────────────────────────────────

  describe('update', () => {
    it('should find, update fields, save, and return entity', async () => {
      const entity = makeLeadEntity();
      const updated = makeLeadEntity({ id: entity.id, name: 'Updated Name' });
      repo.findOneBy.mockResolvedValue(entity);
      repo.save.mockResolvedValue(updated);

      const result = await service.update({ id: entity.id, name: 'Updated Name' });

      expect(result).toBe(updated);
      expect(repo.findOneBy).toHaveBeenCalledWith({ id: entity.id });
      expect(repo.save).toHaveBeenCalled();
    });

    it('should throw NOT_FOUND when entity does not exist', async () => {
      const id = randomUUID();
      repo.findOneBy.mockResolvedValue(null);

      await expect(service.update({ id, name: 'x' })).rejects.toEqual(
        new BaseRpcException({ code: status.NOT_FOUND, message: `Lead with id: ${id} not found.` }),
      );
      expect(repo.save).not.toHaveBeenCalled();
    });
  });

  // ─── remove ──────────────────────────────────────────────────────────────

  describe('remove', () => {
    it('should soft delete when entity exists', async () => {
      const entity = makeLeadEntity();
      repo.findOneBy.mockResolvedValue(entity);
      repo.softDelete.mockResolvedValue({ affected: 1 });

      await expect(service.remove({ id: entity.id })).resolves.toBeUndefined();
      expect(repo.softDelete).toHaveBeenCalledWith({ id: entity.id });
    });

    it('should throw NOT_FOUND without deleting when entity does not exist', async () => {
      const id = randomUUID();
      repo.findOneBy.mockResolvedValue(null);

      await expect(service.remove({ id })).rejects.toEqual(
        new BaseRpcException({ code: status.NOT_FOUND, message: `Lead with id: ${id} not found.` }),
      );
      expect(repo.softDelete).not.toHaveBeenCalled();
    });
  });

  // ─── permission-gated method ──────────────────────────────────────────────

  describe('sensitiveAction', () => {
    it('should throw PERMISSION_DENIED when user lacks permission', async () => {
      const entity = makeLeadEntity();
      ctxService.getRequestUser.mockReturnValue({ id: randomUUID(), role: 'viewer' }); // low-privilege user

      await expect(service.sensitiveAction({ id: entity.id })).rejects.toEqual(
        new BaseRpcException({ code: status.PERMISSION_DENIED, message: expect.any(String) }),
      );
    });
  });

  // ─── business rule method ─────────────────────────────────────────────────

  describe('activateLead', () => {
    it('should throw FAILED_PRECONDITION when lead is already active', async () => {
      const entity = makeLeadEntity({ isActive: true });
      repo.findOneBy.mockResolvedValue(entity);

      await expect(service.activateLead({ id: entity.id })).rejects.toEqual(
        new BaseRpcException({ code: status.FAILED_PRECONDITION, message: expect.stringContaining('already active') }),
      );
    });
  });
});
```

---

## STEP 6 — Review existing tests for anti-patterns

If the user shares existing tests, flag these:

| Anti-pattern | Correction |
|---|---|
| `new RpcException({...})` in assertions | Use `new BaseRpcException({...})` — that's what the service throws |
| `rejects.toThrow(...)` for gRPC errors | Use `rejects.toEqual(new BaseRpcException({...}))` — `toThrow` doesn't deep-compare the code |
| `jest.spyOn(repo, 'method').mockResolvedValue(...)` on an already-mocked object | Remove the spy — set the mock in `beforeEach` directly |
| `Object.assign(repo, { create: jest.fn() })` inside a test | Declare `create` in the repo type and initialize it in `beforeEach` |
| `beforeAll` for module setup | Use `beforeEach` — shared state causes flaky tests |
| `toHaveBeenCalled()` without `toHaveBeenCalledWith(...)` | Always assert the arguments, not just the call count |
| Empty `useValue: {}` for a service that actually calls methods on the dep | Mock only the methods called: `useValue: { method: jest.fn() }` |
| Testing private methods via `service['_method']()` | Test via public API only |
| `resolves.toBe()` for DTO comparison | Use `resolves.toEqual()` for deep equality; `toBe` is for same-reference checks |

---

## Advanced patterns

For these scenarios, read the relevant reference file before generating:

- **RabbitMQ consumer tests** (`@EventPattern` handlers, ack/nack verification) → `references/rmq-and-advanced.md`
- **Transaction tests** (`dataSource.transaction()` or `QueryRunner`) → `references/rmq-and-advanced.md`
- **QueryBuilder tests** (`createQueryBuilder()`) → `references/rmq-and-advanced.md`
- **Service calling other services** (multi-dependency mocking) → `references/rmq-and-advanced.md`
- **React custom hook tests** (`renderHook`) → `references/frontend-tests.md`
- **Zustand store tests** → `references/frontend-tests.md`
- **Zod schema tests** → `references/frontend-tests.md`
- **TanStack Query hook tests** → `references/frontend-tests.md`

---

## ABSOLUTE RULES

- **Always `BaseRpcException`** — never `RpcException` or any HTTP exception in service tests
- **Always `beforeEach`** for module setup — never `beforeAll`
- **Declare all mock methods in the type** — never `Object.assign` inside tests
- **`rejects.toEqual(new BaseRpcException({...}))`** — never `rejects.toThrow()`
- **One scenario per `it()`** — no multi-behavior tests
- **Assert mock arguments** with `toHaveBeenCalledWith()` after behavior assertions
- **`toBe`** for same-object reference; **`toEqual`** for DTOs and plain objects
- Never import real DB connections, external services, or Redis in unit tests
