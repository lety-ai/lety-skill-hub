# Advanced Backend Test Patterns

Reference for RabbitMQ consumers, transactions, QueryBuilder, and multi-service dependencies.

---

## RabbitMQ Consumer Tests

Consumer handlers must verify: (1) the business logic ran, (2) the channel was **acked on success**, and (3) the channel was **nacked without requeue on failure**.

```typescript
// notifications-ws.consumer.spec.ts
import { randomUUID } from 'crypto';
import { Test, TestingModule } from '@nestjs/testing';
import { NotificationsWsConsumer } from './notifications-ws.consumer';
import { NotificationsGateway } from './notifications.gateway';

// Minimal RmqContext mock — only what the consumer calls
function makeRmqContext() {
  const ack = jest.fn();
  const nack = jest.fn();
  const channel = { ack, nack };
  const message = {}; // opaque — consumer just passes it to ack/nack
  const context = {
    getChannelRef: () => channel,
    getMessage: () => message,
  } as any;
  return { context, ack, nack, message };
}

describe('NotificationsWsConsumer', () => {
  let consumer: NotificationsWsConsumer;
  let gateway: { server: { to: jest.Mock } };

  beforeEach(async () => {
    // Mock the gateway's server.to().emit() chain
    const emit = jest.fn();
    const to = jest.fn().mockReturnValue({ emit });
    gateway = { server: { to } };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        NotificationsWsConsumer,
        { provide: NotificationsGateway, useValue: gateway },
      ],
    }).compile();

    consumer = module.get<NotificationsWsConsumer>(NotificationsWsConsumer);
  });

  describe('handleNotificationCreated', () => {
    it('should emit to tenant room and ack on success', () => {
      const { context, ack, nack } = makeRmqContext();
      const tenantId = randomUUID();
      const notification = { id: randomUUID(), message: 'Hello', type: 'info' };

      consumer.handleNotificationCreated({ tenantId, notification }, context);

      expect(gateway.server.to).toHaveBeenCalledWith(`tenant:${tenantId}`);
      expect(ack).toHaveBeenCalledTimes(1);
      expect(nack).not.toHaveBeenCalled();
    });

    it('should nack without requeue when emit throws', () => {
      const { context, ack, nack } = makeRmqContext();
      // Force the emit chain to throw
      gateway.server.to.mockImplementation(() => { throw new Error('Socket error'); });

      consumer.handleNotificationCreated(
        { tenantId: randomUUID(), notification: { id: randomUUID(), message: 'x', type: 'info' } },
        context,
      );

      expect(nack).toHaveBeenCalledWith(expect.anything(), false, false); // no requeue
      expect(ack).not.toHaveBeenCalled();
    });
  });
});
```

**Key rules for consumer tests:**
- Always verify `ack` on the success path — missing ack means the queue blocks
- Always verify `nack(msg, false, false)` on the failure path — the `false, false` (no multiple, no requeue) is critical
- Mock the channel separately from the context so you can assert on `ack`/`nack` directly
- Consumer methods are synchronous or `void async` — test them as fire-and-forget

---

## Transaction / QueryRunner Tests

When a service uses `dataSource.transaction(cb)` or manual `QueryRunner`, mock the `DataSource` to control what the callback receives.

### Pattern A — `dataSource.transaction(callback)`

```typescript
import { DataSource } from 'typeorm';

// In beforeEach:
let dataSource: { transaction: jest.Mock };
dataSource = {
  transaction: jest.fn().mockImplementation(async (cb) => {
    // The mock EntityManager — provide only the methods the callback uses
    const manager = {
      save: jest.fn().mockResolvedValue(entity),
      findOne: jest.fn().mockResolvedValue(entity),
    };
    return cb(manager); // Execute the callback with the mock manager
  }),
};

// Provider:
{ provide: DataSource, useValue: dataSource }

// Test:
it('should complete the transaction and return result', async () => {
  const result = await service.createWithTransaction(dto);
  expect(dataSource.transaction).toHaveBeenCalledTimes(1);
  expect(result).toEqual(entity.toResponseDto());
});

it('should propagate errors and roll back', async () => {
  dataSource.transaction.mockImplementation(async (cb) => {
    const manager = { save: jest.fn().mockRejectedValue(new Error('DB error')) };
    return cb(manager);
  });

  await expect(service.createWithTransaction(dto)).rejects.toThrow('DB error');
});
```

### Pattern B — Manual QueryRunner

```typescript
// Build a mock QueryRunner that the service can call
function makeQueryRunner(overrides: Partial<Record<string, jest.Mock>> = {}) {
  return {
    connect: jest.fn().mockResolvedValue(undefined),
    startTransaction: jest.fn().mockResolvedValue(undefined),
    commitTransaction: jest.fn().mockResolvedValue(undefined),
    rollbackTransaction: jest.fn().mockResolvedValue(undefined),
    release: jest.fn().mockResolvedValue(undefined),
    manager: {
      save: jest.fn(),
      findOne: jest.fn(),
      ...overrides,
    },
  };
}

// In beforeEach:
let qr: ReturnType<typeof makeQueryRunner>;
let dataSource: { createQueryRunner: jest.Mock };

qr = makeQueryRunner();
dataSource = { createQueryRunner: jest.fn().mockReturnValue(qr) };

// Provider:
{ provide: DataSource, useValue: dataSource }

// Tests:
it('should commit on success', async () => {
  qr.manager.save.mockResolvedValue(entity);
  qr.manager.findOne.mockResolvedValue(null);

  await service.createWithQueryRunner(dto);

  expect(qr.startTransaction).toHaveBeenCalled();
  expect(qr.commitTransaction).toHaveBeenCalled();
  expect(qr.rollbackTransaction).not.toHaveBeenCalled();
  expect(qr.release).toHaveBeenCalled(); // Always called — success or failure
});

it('should rollback and release on error', async () => {
  qr.manager.save.mockRejectedValue(new Error('DB error'));

  await expect(service.createWithQueryRunner(dto)).rejects.toThrow();

  expect(qr.rollbackTransaction).toHaveBeenCalled();
  expect(qr.release).toHaveBeenCalled(); // Must be called even after rollback
});
```

---

## QueryBuilder Tests

When a service calls `repository.createQueryBuilder()`, mock the entire fluent chain. Build the chain mock once and reuse it.

```typescript
// Build a mock QueryBuilder — only include methods the service calls
function makeQueryBuilder(results: unknown[] = []) {
  const qb = {
    leftJoinAndSelect: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    skip: jest.fn().mockReturnThis(),
    take: jest.fn().mockReturnThis(),
    getManyAndCount: jest.fn().mockResolvedValue([results, results.length]),
    getOne: jest.fn().mockResolvedValue(results[0] ?? null),
    getMany: jest.fn().mockResolvedValue(results),
  };
  // Every fluent method returns the same mock (this)
  return qb;
}

// In beforeEach — attach to repo:
let qb: ReturnType<typeof makeQueryBuilder>;

qb = makeQueryBuilder([entity]);
repo = {
  ...repo,
  createQueryBuilder: jest.fn().mockReturnValue(qb),
};

// Test:
it('should return paginated results', async () => {
  const result = await service.findAll({ search: 'test', page: 1, limit: 10 });

  expect(repo.createQueryBuilder).toHaveBeenCalledWith('lead'); // alias
  expect(qb.where).toHaveBeenCalledWith(expect.stringContaining('name'), expect.objectContaining({ search: '%test%' }));
  expect(qb.skip).toHaveBeenCalledWith(0); // (page - 1) * limit
  expect(qb.take).toHaveBeenCalledWith(10);
  expect(result.items).toHaveLength(1);
  expect(result.meta.total).toBe(1);
});
```

---

## Multi-Service Dependency Tests

When a service calls methods on another injected service:

```typescript
// In beforeEach:
let emailService: { sendWelcome: jest.Mock };
let analyticsService: { track: jest.Mock };

emailService = { sendWelcome: jest.fn().mockResolvedValue(undefined) };
analyticsService = { track: jest.fn().mockResolvedValue(undefined) };

// Providers:
{ provide: EmailService, useValue: emailService },
{ provide: AnalyticsService, useValue: analyticsService },

// Test — verify delegation:
it('should call email and analytics services after create', async () => {
  repo.save.mockResolvedValue(entity);
  repo.create.mockReturnValue(entity);

  await service.create(dto);

  expect(emailService.sendWelcome).toHaveBeenCalledWith(entity.email);
  expect(analyticsService.track).toHaveBeenCalledWith('lead_created', expect.objectContaining({ tenantId: expect.any(String) }));
});

it('should still throw if dependent service fails', async () => {
  repo.save.mockResolvedValue(entity);
  repo.create.mockReturnValue(entity);
  emailService.sendWelcome.mockRejectedValue(new Error('SMTP error'));

  // Depends on whether the service wraps the error or lets it propagate
  await expect(service.create(dto)).rejects.toThrow('SMTP error');
});
```

**Rule**: Mock only the methods actually called on the dependency — `useValue: {}` for unused ones. Over-mocking hides real integration problems.

---

## Pagination Tests

```typescript
describe('findAll', () => {
  it('should return items and meta for first page', async () => {
    const entities = [makeLeadEntity(), makeLeadEntity()];
    qb.getManyAndCount.mockResolvedValue([entities, 10]); // 10 total, 2 on this page

    const result = await service.findAll({ page: 1, limit: 2, search: '' });

    expect(result.items).toHaveLength(2);
    expect(result.meta.total).toBe(10);
    expect(result.meta.page).toBe(1);
    expect(result.meta.pageCount).toBe(5); // ceil(10/2)
  });

  it('should return empty list when no results', async () => {
    qb.getManyAndCount.mockResolvedValue([[], 0]);

    const result = await service.findAll({ page: 1, limit: 10, search: 'nomatch' });

    expect(result.items).toHaveLength(0);
    expect(result.meta.total).toBe(0);
  });
});
```
