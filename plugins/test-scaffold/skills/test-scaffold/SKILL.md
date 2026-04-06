---
name: test-scaffold
description: Generate unit tests for NestJS services in Lety 2.0 Backend — minimal mocks, getRepositoryToken, mock factory, gRPC status code assertions. Triggered when the user wants to write or improve unit tests for a service.
---

You are writing unit tests for a **NestJS service** in the Lety 2.0 Backend using **Jest + @nestjs/testing**.

> **Priority rule**: Follow Jest and NestJS testing best practices. If existing tests in the project deviate, generate the correct version and flag the issue.

---

## DOCUMENTATION — consult before generating

- **NestJS Testing**: https://docs.nestjs.com/fundamentals/testing
- **Jest docs**: https://jestjs.io/docs/getting-started
- **Jest mock functions**: https://jestjs.io/docs/mock-function-api
- **TypeORM testing (getRepositoryToken)**: https://docs.nestjs.com/techniques/database#testing

---

## STEP 1 — Read the service to test

Before generating anything, read the service file the user provides (or asks you to test). Identify:

- All injected dependencies (`@InjectRepository`, other services, `DataSource`, `CACHE_MANAGER`, gRPC clients, etc.)
- All public methods
- Which methods throw `BaseRpcException` with which `status.*` code
- Which methods call `toResponseDto()` on entities
- Which methods use transactions (`QueryRunner` or `dataSource.transaction()`)
- Which methods use `RequestContextService` / `ctxService`

---

## STEP 2 — Gather test specification

Ask the user which methods to test (or default to all public methods). For each method, plan:
- Happy path (returns expected value)
- Not found path (throws `NOT_FOUND` if applicable)
- Permission denied path (throws `PERMISSION_DENIED` if applicable)
- Already exists path (throws `ALREADY_EXISTS` if applicable)
- Any domain-specific edge cases from the service logic

---

## STEP 3 — Generate the mock factory

### File: `apps/api/test/mocks/<domainPlural>-mocks.ts`

Rules:
- Export a `<Domain>EntityLike` type — mirrors only the fields actually used in tests
- Export a `make<Domain>Entity(partial?)` factory — builds a minimal valid entity
- `id` defaults to `randomUUID()`
- Required string fields default to a readable placeholder: `` `<Domain> ${id.slice(0, 8)}` ``
- Include `toResponseDto()` that returns a plain object with the same fields
- For Decimal fields: default to `new Decimal(0)` or a sensible value
- For boolean fields: default to `true` for active/enabled flags
- Keep it minimal — only fields the tests actually reference

```typescript
import { randomUUID } from 'crypto';

export type <Domain>EntityLike = {
  id: string;
  name: string;               // add fields used in tests
  isActive: boolean;
  toResponseDto: () => Record<string, unknown>;
};

export function make<Domain>Entity(
  partial: Partial<<Domain>EntityLike> = {},
): <Domain>EntityLike {
  const id = partial.id ?? randomUUID();
  const name = partial.name ?? `<Domain> ${id.slice(0, 8)}`;
  return {
    id,
    name,
    isActive: partial.isActive ?? true,
    toResponseDto: () => ({ id, name }),
    ...partial,
  };
}
```

---

## STEP 4 — Generate the spec file

### File: `apps/api/src/<domainPlural>/<domainPlural>.service.spec.ts`

### Rules

**Test module setup:**
- Use `Test.createTestingModule({ providers: [...] }).compile()`
- Mock ONLY the direct dependencies of the service — do not mock transitive deps
- Repository mock: declare typed object with only the methods used in the service
  ```typescript
  let repo: { findOneBy: jest.Mock; save: jest.Mock; softDelete: jest.Mock };
  repo = { findOneBy: jest.fn(), save: jest.fn(), softDelete: jest.fn() };
  { provide: getRepositoryToken(Entity), useValue: repo }
  ```
- Service mock: `{ provide: OtherService, useValue: {} }` for unused services; `{ provide: OtherService, useValue: { method: jest.fn() } }` for used ones
- `RequestContextService`: `{ provide: RequestContextService, useValue: { getRequestUser: jest.fn(), getRequest: jest.fn() } }`
- `DataSource`: `{ provide: DataSource, useValue: { createQueryRunner: jest.fn(), transaction: jest.fn() } }`
- `CACHE_MANAGER`: `{ provide: CACHE_MANAGER, useValue: { get: jest.fn(), set: jest.fn(), del: jest.fn() } }`
- gRPC client token: `{ provide: SERVICE_NAME, useValue: { getService: () => ({}) } }`
- Rebuild module in `beforeEach` — never share state between tests

**Assertions:**
- Happy path: `await expect(service.method(args)).resolves.toBe(entity)` or `.resolves.toEqual(dto)`
  - Use `.toBe()` for same object reference, `.toEqual()` for deep equality
- Not found: 
  ```typescript
  await expect(service.findById({ id })).rejects.toEqual(
    new RpcException({ code: status.NOT_FOUND, message: `<Domain> with id: ${id} not found.` }),
  );
  ```
- Verify mock was called:
  ```typescript
  expect(repo.findOneBy).toHaveBeenCalledWith({ id: entity.id });
  expect(repo.findOneBy).toHaveBeenCalledTimes(1);
  ```
- `toResponseDto()` delegation:
  ```typescript
  const dto = entity.toResponseDto();
  repo.findOneBy.mockResolvedValue(entity);
  await expect(service.findOne({ id: entity.id })).resolves.toEqual(dto);
  ```

**Test organization:**
- Top-level `describe('<Domain>Service')` for the file
- Nested `describe('methodName')` for each method
- One `it()` per scenario — descriptive: `'should return entity when found'`, `'should throw NOT_FOUND when entity does not exist'`
- `beforeEach` at the top level for module setup

**What NOT to test:**
- Don't test NestJS framework behavior (DI, decorators)
- Don't test TypeORM internals
- Don't test private methods directly — test via public API
- Don't mock implementations — mock return values only

**Template for a complete spec:**

```typescript
/* eslint-disable @typescript-eslint/no-unsafe-assignment */
import { randomUUID } from 'crypto';
import { status } from '@grpc/grpc-js';
import { RpcException } from '@nestjs/microservices';
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { <Domain>Entity } from '@app/common/entities/tenant/<domainPlural>/<tableName>.entity';
import { RequestContextService } from '../request-context/request-context.service';
import { <Domain>Service } from './<domainPlural>.service';
import { make<Domain>Entity } from '../../test/mocks/<domainPlural>-mocks';
// import other dependencies used in service...

describe('<Domain>Service', () => {
  let service: <Domain>Service;
  let repo: {
    findOneBy: jest.Mock;
    save: jest.Mock;
    softDelete: jest.Mock;
    // add other repo methods used
  };
  let ctxService: { getRequestUser: jest.Mock };

  beforeEach(async () => {
    repo = {
      findOneBy: jest.fn(),
      save: jest.fn(),
      softDelete: jest.fn(),
    };
    ctxService = { getRequestUser: jest.fn() };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        <Domain>Service,
        { provide: getRepositoryToken(<Domain>Entity), useValue: repo },
        { provide: RequestContextService, useValue: ctxService },
        { provide: DataSource, useValue: {} },
        // add other providers...
      ],
    }).compile();

    service = module.get<<Domain>Service>(<Domain>Service);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('findById', () => {
    it('should return entity when found', async () => {
      const entity = make<Domain>Entity();
      repo.findOneBy.mockResolvedValue(entity);

      await expect(service.findById({ id: entity.id })).resolves.toBe(entity);
      expect(repo.findOneBy).toHaveBeenCalledWith({ id: entity.id });
    });

    it('should throw NOT_FOUND when entity does not exist', async () => {
      const id = randomUUID();
      repo.findOneBy.mockResolvedValue(null);

      await expect(service.findById({ id })).rejects.toEqual(
        new RpcException({
          code: status.NOT_FOUND,
          message: `<Domain> with id: ${id} not found.`,
        }),
      );
    });
  });

  describe('findOne', () => {
    it('should return toResponseDto() result', async () => {
      const entity = make<Domain>Entity();
      repo.findOneBy.mockResolvedValue(entity);

      await expect(service.findOne({ id: entity.id })).resolves.toEqual(entity.toResponseDto());
    });
  });

  describe('create', () => {
    it('should save and return new entity', async () => {
      const entity = make<Domain>Entity();
      repo.save.mockResolvedValue(entity);
      jest.spyOn(repo, 'save').mockResolvedValue(entity);

      // mock repo.create if service calls it:
      Object.assign(repo, { create: jest.fn().mockReturnValue(entity) });

      const result = await service.create({ name: entity.name });
      expect(result).toBe(entity);
      expect(repo.save).toHaveBeenCalled();
    });
  });

  describe('remove', () => {
    it('should soft delete entity', async () => {
      const entity = make<Domain>Entity();
      repo.findOneBy.mockResolvedValue(entity);
      repo.softDelete.mockResolvedValue(undefined);

      await expect(service.remove({ id: entity.id })).resolves.toBeUndefined();
      expect(repo.softDelete).toHaveBeenCalledWith({ id: entity.id });
    });

    it('should throw NOT_FOUND if entity does not exist', async () => {
      const id = randomUUID();
      repo.findOneBy.mockResolvedValue(null);

      await expect(service.remove({ id })).rejects.toEqual(
        new RpcException({ code: status.NOT_FOUND, message: `<Domain> with id: ${id} not found.` }),
      );
      expect(repo.softDelete).not.toHaveBeenCalled();
    });
  });
});
```

---

## STEP 5 — Flag issues in existing tests

If the user shares existing tests, review for:

| Issue | What to tell the user |
|---|---|
| Mocking entire service instead of just methods used | "Mock only what is called — `useValue: {}` for unused deps, `useValue: { method: jest.fn() }` for used ones" |
| `toPromise()` instead of `lastValueFrom()` | "Use `lastValueFrom()` — `.toPromise()` is deprecated in RxJS 8" |
| Assertions on `rejects.toThrow()` for gRPC errors | "Use `rejects.toEqual(new RpcException({...}))` — `toThrow` doesn't deep-compare error payload" |
| `beforeAll` for module setup | "Use `beforeEach` — shared state between tests causes flaky failures" |
| Testing private methods directly via `service['_private']` | "Test behavior via public API instead" |
| Missing `expect(mock).toHaveBeenCalledWith(...)` | "Add call assertions — resolves/rejects alone don't verify correct arguments were passed" |
| `synchronize: true` in test DB config | "Use in-memory/test DB or mocks — never sync against a real DB in unit tests" |

---

## STEP 6 — Show draft and confirm

Present both files. Ask:

> "¿Todo correcto? ¿Quieres ajustar algún caso de prueba?"

Wait for confirmation, then write files.

---

## ABSOLUTE RULES

- Mock only direct dependencies — never deep/transitive mocks
- `beforeEach` for module — never `beforeAll`
- Error assertions: `rejects.toEqual(new RpcException({...}))` — not `toThrow()`
- One scenario per `it()` — no multi-assertion tests unless logically inseparable
- Verify mock calls after behavior assertions
- Never import real DB connections in unit tests
- `make<Domain>Entity()` factory must implement `toResponseDto()` 
