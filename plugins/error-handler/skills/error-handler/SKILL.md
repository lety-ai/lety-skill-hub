---
name: error-handler
description: Write, review, or fix error handling in Lety 2.0 Backend — BaseRpcException with correct gRPC status codes, exception filters for TypeORM errors, RpcToHttpInterceptor mapping, and RabbitMQ ack/nack patterns. Triggered when the user needs to handle errors in a NestJS service, controller, or RMQ handler.
---

You are reviewing or writing **error handling code** for the Lety 2.0 Backend (NestJS + gRPC + RabbitMQ).

> **Priority rule**: Always follow NestJS and gRPC best practices. If existing code uses `HttpException` inside a microservice, or swallows errors silently, flag it and provide the correct version.

---

## DOCUMENTATION — consult before answering

- **NestJS Exception Filters**: https://docs.nestjs.com/exception-filters
- **NestJS Microservices Exceptions**: https://docs.nestjs.com/microservices/exception-filters
- **gRPC status codes**: https://grpc.github.io/grpc/core/md_doc_statuscodes.html
- **NestJS RpcException**: https://docs.nestjs.com/microservices/exception-filters#rpc-exception-filter

---

## Architecture of error handling in this project

```
Microservice (api / platform / auth)
  └── Service throws BaseRpcException({ code: status.X, message: '...' })
        ↓
  └── ExceptionFilter catches TypeORM errors → converts to BaseRpcException
        ↓
API Gateway
  └── RpcToHttpInterceptor catches gRPC error codes → maps to HTTP status codes
        ↓
  └── Client receives standard HTTP error response
```

---

## STEP 1 — Identify what needs to be handled

Read the code the user provides. Determine:
- Is this in a **microservice** (api/platform/auth) → use `BaseRpcException`
- Is this in the **api-gateway** → use `HttpException` or let `RpcToHttpInterceptor` handle it
- Is this a **TypeORM error** → use an exception filter
- Is this an **RMQ handler** → use ack/nack pattern

---

## STEP 2 — gRPC status code decision guide

When throwing in a microservice service, pick the correct `status` code:

| Situation | Status code | Example |
|---|---|---|
| Entity not found by ID | `status.NOT_FOUND` | `Agency with id: X not found.` |
| Duplicate unique constraint (PG code 23505) | `status.ALREADY_EXISTS` | `Agency already exists` |
| Invalid input value | `status.INVALID_ARGUMENT` | `Invalid OpenAI key: ...` |
| Caller lacks permission | `status.PERMISSION_DENIED` | `You do not have permission to update this agency` |
| Not authenticated | `status.UNAUTHENTICATED` | |
| Feature not implemented | `status.UNIMPLEMENTED` | |
| Business rule violated | `status.FAILED_PRECONDITION` | `Subscription is not active` |
| Transient failure, safe to retry | `status.UNAVAILABLE` | External service down |
| Unexpected server error | `status.INTERNAL` | Unhandled exception |

**How these map to HTTP at the gateway** (via `RpcToHttpInterceptor`):

| gRPC status | HTTP status |
|---|---|
| `NOT_FOUND` | 404 |
| `INVALID_ARGUMENT` | 400 |
| `FAILED_PRECONDITION` | 400 |
| `PERMISSION_DENIED` | 403 |
| `UNAUTHENTICATED` | 401 |
| `ALREADY_EXISTS` | 409 |
| `UNIMPLEMENTED` | 501 |
| anything else | 500 |

---

## STEP 3 — BaseRpcException patterns

### Not found
```typescript
import { status } from '@grpc/grpc-js';
import { BaseRpcException } from '@app/common/exceptions/base-rpc.exception';

// In service findById:
const entity = await this.repo.findOneBy({ id });
if (!entity)
  throw new BaseRpcException({
    code: status.NOT_FOUND,
    message: `<Domain> with id: ${id} not found.`,
  });
```

### Permission denied
```typescript
if (user.agencyId !== targetAgencyId)
  throw new BaseRpcException({
    code: status.PERMISSION_DENIED,
    message: 'You do not have permission to perform this action',
  });
```

### Invalid argument (external validation)
```typescript
try {
  await externalClient.validate(value);
} catch (error) {
  throw new BaseRpcException({
    code: status.INVALID_ARGUMENT,
    message: `Invalid value: ${error.message || 'Validation failed'}`,
  });
}
```

### Already exists (explicit check)
```typescript
const exists = await this.repo.exists({ where: { name } });
if (exists)
  throw new BaseRpcException({
    code: status.ALREADY_EXISTS,
    message: `<Domain> with name "${name}" already exists`,
  });
```

### Business rule violation
```typescript
if (!subscription.isActive)
  throw new BaseRpcException({
    code: status.FAILED_PRECONDITION,
    message: 'Active subscription required to perform this action',
  });
```

---

## STEP 4 — Exception filters for TypeORM errors

Add these at the service/controller level to automatically convert TypeORM errors:

### EntityNotFoundError → NOT_FOUND
```typescript
import { ArgumentsHost, Catch, ExceptionFilter } from '@nestjs/common';
import { EntityNotFoundError } from 'typeorm';
import { BaseRpcException } from '@app/common/exceptions/base-rpc.exception';
import { status } from '@grpc/grpc-js';

@Catch(EntityNotFoundError)
export class EntityNotFoundExceptionFilter implements ExceptionFilter {
  catch(_exception: EntityNotFoundError, _host: ArgumentsHost) {
    throw new BaseRpcException({ code: status.NOT_FOUND, message: 'Entity not found' });
  }
}
```

### QueryFailedError (duplicate key) → ALREADY_EXISTS
```typescript
import { ArgumentsHost, Catch, ExceptionFilter } from '@nestjs/common';
import { QueryFailedError } from 'typeorm';
import { BaseRpcException } from '@app/common/exceptions/base-rpc.exception';
import { status } from '@grpc/grpc-js';

@Catch(QueryFailedError)
export class EntityDuplicateExceptionFilter implements ExceptionFilter {
  catch(exception: QueryFailedError & { code: string }, _host: ArgumentsHost) {
    if (exception.code === '23505') {
      throw new BaseRpcException({
        code: status.ALREADY_EXISTS,
        message: 'Entity already exists',
      });
    }
    // Re-throw other QueryFailedErrors as INTERNAL
    throw new BaseRpcException({
      code: status.INTERNAL,
      message: 'Database error',
    });
  }
}
```

**PostgreSQL error codes reference:**
| Code | Meaning |
|------|---------|
| `23505` | Unique constraint violation |
| `23503` | Foreign key constraint violation |
| `23502` | Not null constraint violation |
| `22P02` | Invalid UUID format |

### Applying filters
```typescript
// On a specific controller:
@UseFilters(EntityNotFoundExceptionFilter, EntityDuplicateExceptionFilter)
@Controller()
export class SomeController {}

// Or globally in main.ts for the microservice:
app.useGlobalFilters(new EntityNotFoundExceptionFilter(), new EntityDuplicateExceptionFilter());
```

---

## STEP 5 — RabbitMQ ack/nack pattern

Every RMQ handler must explicitly ack or nack. Never leave a message unacknowledged.

```typescript
@MessagePattern(SOME_EVENT)
async handleEvent(@Payload() payload: SomeDto, @Ctx() ctx: RmqContext) {
  const channel = ctx.getChannelRef() as Channel;
  const originalMsg = ctx.getMessage() as ConsumeMessage;
  try {
    await this.service.processEvent(payload);
    channel.ack(originalMsg); // success → acknowledge
  } catch (error) {
    console.error('Error processing SOME_EVENT:', error);
    channel.nack(originalMsg, false, false); // failure → reject, don't requeue
  }
}
```

**ack/nack decision:**
| Scenario | Action |
|---|---|
| Success | `channel.ack(originalMsg)` |
| Business error (invalid data, not found) | `channel.ack(originalMsg)` — do not requeue, it will fail again |
| Transient error (DB down, external API timeout) | `channel.nack(originalMsg, false, true)` — requeue for retry |
| Poison message (crashes repeatedly) | `channel.nack(originalMsg, false, false)` — dead-letter it |

**`@EventPattern` vs `@MessagePattern`:**
- `@MessagePattern`: expects a response — use for request/reply
- `@EventPattern`: fire-and-forget — use for domain events that don't need a response
- Both need ack/nack for reliable delivery

---

## STEP 6 — Flag anti-patterns

When reviewing existing code, flag these:

| Anti-pattern | Correct approach |
|---|---|
| `throw new NotFoundException(...)` in microservice | Use `BaseRpcException({ code: status.NOT_FOUND })` |
| `throw new BadRequestException(...)` in microservice | Use `BaseRpcException({ code: status.INVALID_ARGUMENT })` |
| `throw new ForbiddenException(...)` in microservice | Use `BaseRpcException({ code: status.PERMISSION_DENIED })` |
| `catch (error) {}` swallowing errors silently | Always re-throw or log + nack |
| Missing `channel.nack` in catch block of RMQ handler | Message stays unacknowledged, blocks queue |
| `console.error` without re-throw in service method | Errors should propagate to caller |
| `status.INTERNAL` for all errors | Use the most specific status code available |
| `throw error` raw (non-BaseRpcException) in service | Wrap in `BaseRpcException` so the gateway can map it correctly |

---

## STEP 7 — Show corrected code

For **reviews**: list every issue found, then show the corrected version side by side.
For **new code**: show the complete implementation.

---

## ABSOLUTE RULES

- Microservices NEVER throw `HttpException` or its subclasses
- Always use `BaseRpcException` with a specific `status.*` code — never `status.INTERNAL` for known errors
- RMQ handlers must always ack or nack — no exceptions
- Exception filters must be applied at the right scope (global or per-controller)
- Never swallow errors silently — log + nack or re-throw
- The gateway's `RpcToHttpInterceptor` handles gRPC→HTTP mapping — don't duplicate this logic in controllers
