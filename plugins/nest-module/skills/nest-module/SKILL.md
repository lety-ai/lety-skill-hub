---
name: nest-module
description: Scaffold a complete NestJS module for the Lety 2.0 Backend following project conventions (gRPC controller, service with BaseRpcException, TypeORM entity extending BaseEntity, Create/Update DTOs, unit test with mock factory). Triggered when the user wants to create a new module, domain, or feature in the backend.
---

You are scaffolding a new NestJS module for the **Lety 2.0 Backend** monorepo. This is a microservices project using NestJS + TypeORM 0.3 + gRPC + RabbitMQ. Follow every step in order.

---

## DOCUMENTATION — consult before generating code

When in doubt about any decorator, option, or NestJS/TypeORM API:
- **NestJS Modules**: https://docs.nestjs.com/modules
- **NestJS Controllers**: https://docs.nestjs.com/microservices/grpc
- **NestJS Testing**: https://docs.nestjs.com/fundamentals/testing
- **TypeORM Entities**: https://typeorm.io/entities
- **TypeORM Relations**: https://typeorm.io/relations
- **class-validator**: https://github.com/typestack/class-validator#readme

Fetch the relevant page before answering if uncertain about an API.

---

## STEP 1 — Gather module specification

Ask the user for any missing information. Required:
- **Domain name** (singular, PascalCase): e.g. `Conversation`, `Lead`, `Invoice`
- **Fields**: name, type (string | number | boolean | Date | enum | Decimal | uuid | jsonb), nullable?, unique?
- **Relations**: entity name, type (OneToMany | ManyToOne | OneToOne | ManyToMany), other side?
- **Service** (`apps/api` | `apps/platform` | `apps/auth-service`): default `apps/api`
- **Global module?** (default: false — only use `@Global()` if service is widely shared)
- **Needs RabbitMQ events?** If yes, which event names?
- **Needs RequestContextService?** (default: yes for apps/api — multi-tenant context)

Do NOT invent fields. If the user gives a vague description, ask for clarification.

---

## STEP 2 — Derive naming conventions

From the domain name (e.g. `Conversation`), derive:
- `domainPlural` → `conversations` (camelCase plural)
- `DomainPlural` → `Conversations` (PascalCase plural)
- `tableName` → `conversation` (snake_case singular)
- `entityFile` → `conversation.entity.ts`
- `serviceFile` → `conversations.service.ts`
- `controllerFile` → `conversations.controller.ts`
- `moduleFile` → `conversations.module.ts`
- `specFile` → `conversations.service.spec.ts`
- `createDtoFile` → `create-conversation.dto.ts`
- `updateDtoFile` → `update-conversation.dto.ts`
- `mockFile` → `conversations-mocks.ts`

File paths:
- Entity: `libs/common/src/entities/tenant/<domainPlural>/<tableName>.entity.ts`
- DTOs: `libs/common/src/dto/tenant/<domainPlural>/create-<tableName>.dto.ts`
- Module/Controller/Service: `apps/api/src/<domainPlural>/`
- Mocks: `apps/api/test/mocks/<domainPlural>-mocks.ts`

---

## STEP 3 — Generate all files

Generate all 7 files below. Do not omit any. Use the exact patterns from the codebase.

---

### FILE 1 — Entity (`libs/common/src/entities/tenant/<domainPlural>/<tableName>.entity.ts`)

Rules:
- Always `extends BaseEntity` (from `@app/common/database`)
- `@Entity('table_name')` with snake_case singular name
- Add `@Index(['id'])` — add composite index if there is a unique combination of fields
- Each column: `@ApiProperty(...)` (or `@ApiHideProperty()` + `@Exclude()` for sensitive/internal fields) + `@Column(...)`
- Column names always in `snake_case` via `{ name: 'snake_case' }`
- Decimal fields: use `type: 'decimal'` with `precision` + `scale` + `transformer: new DecimalColumnTransformer()`
- Sensitive fields (tokens, keys, passwords): add `transformer: new EncryptionTransformer()` + `@ApiHideProperty()` + `@Exclude()`
- jsonb fields: `type: 'jsonb'`
- Enum fields: `type: 'enum', enum: EnumType`
- Soft delete is handled by `BaseEntity` (`deletedAt`) — never add it manually
- Always implement `toResponseDto(): DomainData` that returns a plain object (proto type)
- Relations: define both sides, use `@JoinColumn` on the owning side

```typescript
import { ApiHideProperty, ApiProperty } from '@nestjs/swagger';
import { Exclude } from 'class-transformer';
import { Column, Entity, Index, ManyToOne, OneToMany, JoinColumn } from 'typeorm';
import { BaseEntity } from '@app/common/database';
import { SomeRelatedEntity } from '../related/related.entity';
import { SomeDomainData } from '@app/common/types/proto/tenant/<domainPlural>/<tableName>-interface';

@Entity('<tableName>')
@Index(['id'])
export class <Domain>Entity extends BaseEntity {
  @ApiProperty({ description: 'Field description', required: true, nullable: false })
  @Column({ name: 'field_name', nullable: false })
  fieldName: string;

  // Sensitive field pattern:
  @ApiHideProperty()
  @Exclude()
  @Column({ name: 'secret_field', nullable: true })
  secretField: string | null;

  // Relation pattern:
  @ManyToOne(() => SomeRelatedEntity, related => related.<domainPlural>)
  @JoinColumn({ name: 'related_id' })
  related: SomeRelatedEntity;

  @Column({ name: 'related_id', type: 'uuid', nullable: false })
  relatedId: string;

  toResponseDto(): <Domain>Data {
    return {
      id: this.id,
      // map only public fields
      createdAt: this.createdAt,
      updatedAt: this.updatedAt,
    };
  }
}
```

---

### FILE 2 — Create DTO (`libs/common/src/dto/tenant/<domainPlural>/create-<tableName>.dto.ts`)

Rules:
- One decorator per validation concern — don't stack redundant decorators
- Required fields: `@ApiProperty()` + validators (`@IsString()`, `@IsNotEmpty()`, etc.)
- Optional fields: `@ApiPropertyOptional()` + `@IsOptional()` + validators
- Enum fields: `@IsEnum(EnumType)`
- Decimal/number fields: `@IsNumber()`
- URL fields: `@IsUrl()`
- Boolean fields: `@IsBoolean()`
- Never use `@IsNotEmpty()` alone without a type validator
- Never use `@IsOptional()` without also adding it before the type validators

```typescript
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsNotEmpty, IsOptional, IsString, IsUrl } from 'class-validator';

export class Create<Domain>Dto {
  @ApiProperty({ description: 'Field description' })
  @IsNotEmpty()
  @IsString()
  fieldName: string;

  @ApiPropertyOptional({ nullable: true })
  @IsOptional()
  @IsString()
  @IsUrl()
  optionalUrl?: string | null;
}
```

---

### FILE 3 — Update DTO (`libs/common/src/dto/tenant/<domainPlural>/update-<tableName>.dto.ts`)

Make all fields from Create DTO optional using `PartialType`:

```typescript
import { PartialType } from '@nestjs/swagger';
import { Create<Domain>Dto } from './create-<tableName>.dto';

export class Update<Domain>Dto extends PartialType(Create<Domain>Dto) {}
```

---

### FILE 4 — Module (`apps/api/src/<domainPlural>/<domainPlural>.module.ts`)

Rules:
- Only add `@Global()` if the service is injected by many other modules
- Always register entity in `TypeOrmModule.forFeature([<Domain>Entity])`
- Export the service if other modules will use it
- Only include `PublisherConfigModule` if RabbitMQ events are needed

```typescript
import { Module } from '@nestjs/common'; // add @Global() only if needed
import { TypeOrmModule } from '@nestjs/typeorm';
import { <Domain>Entity } from '@app/common/entities/tenant/<domainPlural>/<tableName>.entity';
import { <Domain>Controller } from './<domainPlural>.controller';
import { <Domain>Service } from './<domainPlural>.service';

@Module({
  imports: [TypeOrmModule.forFeature([<Domain>Entity])],
  controllers: [<Domain>Controller],
  providers: [<Domain>Service],
  exports: [<Domain>Service],
})
export class <Domain>Module {}
```

---

### FILE 5 — Controller (`apps/api/src/<domainPlural>/<domainPlural>.controller.ts`)

Rules:
- `@Controller()` (no route — gRPC services don't use HTTP routes)
- `@<Domain>ServiceControllerMethods()` — proto decorator
- `implements <Domain>ServiceController` — generated from proto
- gRPC methods: delegate directly to service, no business logic in controller
- RabbitMQ event handlers: use `@MessagePattern` or `@EventPattern`, always ack/nack with try/catch
- RMQ pattern: get channel + originalMsg from `RmqContext`, ack on success, nack on error

```typescript
import { Controller } from '@nestjs/common';
import { Ctx, MessagePattern, Payload, RmqContext } from '@nestjs/microservices';
import type { Channel, ConsumeMessage } from 'amqplib';
import { GetById } from '@app/common/types/proto/common/common-requests';
import {
  <Domain>ServiceController,
  <Domain>ServiceControllerMethods,
} from '@app/common/types/proto/tenant/<domainPlural>-service';
import { <Domain>Service } from './<domainPlural>.service';

@Controller()
@<Domain>ServiceControllerMethods()
export class <Domain>Controller implements <Domain>ServiceController {
  constructor(private readonly <domainSingular>Service: <Domain>Service) {}

  async get<Domain>ById(request: GetById) {
    return this.<domainSingular>Service.findOne(request);
  }

  // RMQ event example — only if events are needed:
  @MessagePattern('<DOMAIN>_EVENTS.SOME_EVENT')
  async handleSomeEvent(@Payload() payload: SomeDto, @Ctx() ctx: RmqContext) {
    const channel = ctx.getChannelRef() as Channel;
    const originalMsg = ctx.getMessage() as ConsumeMessage;
    try {
      await this.<domainSingular>Service.handleSomeEvent(payload);
      channel.ack(originalMsg);
    } catch (error) {
      console.error('Error processing SOME_EVENT message:', error);
      channel.nack(originalMsg, false, false);
    }
  }
}
```

---

### FILE 6 — Service (`apps/api/src/<domainPlural>/<domainPlural>.service.ts`)

Rules:
- Always `private readonly logger = new Logger(<Domain>Service.name)`
- `@InjectRepository(<Domain>Entity)` for the primary repository
- Inject `DataSource` if transactions are needed (use `dataSource.transaction()` or `QueryRunner`)
- Inject `RequestContextService` for multi-tenant context (get `agencyId` / `userId` from context)
- Always throw `BaseRpcException` (NEVER `HttpException`, `NotFoundException`, etc.)
- Use gRPC status codes: `status.NOT_FOUND`, `status.ALREADY_EXISTS`, `status.PERMISSION_DENIED`, `status.INVALID_ARGUMENT`
- `findById` pattern: `findOneBy({ id })` → throw NOT_FOUND if null → return entity
- `findOne` pattern: call `findById` → return `entity.toResponseDto()`
- Soft deletes: `this.repository.softDelete({ id })`
- Pagination: `createQueryBuilder` with `.skip()` + `.take()` + `.getManyAndCount()`
- Search: use `ILike` for case-insensitive string search or `Brackets` for multi-field search
- QueryRunner transactions: always `connect()` → `startTransaction()` → try/commit → catch/rollback → finally/release

```typescript
import { status } from '@grpc/grpc-js';
import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { <Domain>Entity } from '@app/common/entities/tenant/<domainPlural>/<tableName>.entity';
import { BaseRpcException } from '@app/common/exceptions/base-rpc.exception';
import { GetById } from '@app/common/types/proto/common/common-requests';
import { <Domain>Data } from '@app/common/types/proto/tenant/<domainPlural>/<tableName>-interface';
import { RequestContextService } from '../request-context/request-context.service';
import { Create<Domain>Dto } from '@app/common/dto/tenant/<domainPlural>/create-<tableName>.dto';

@Injectable()
export class <Domain>Service {
  private readonly logger = new Logger(<Domain>Service.name);

  constructor(
    @InjectRepository(<Domain>Entity)
    private readonly <domainSingular>Repository: Repository<<Domain>Entity>,
    private readonly ctxService: RequestContextService,
    private readonly dataSource: DataSource,
  ) {}

  async findById({ id }: GetById): Promise<<Domain>Entity> {
    const entity = await this.<domainSingular>Repository.findOneBy({ id });
    if (!entity)
      throw new BaseRpcException({
        code: status.NOT_FOUND,
        message: `<Domain> with id: ${id} not found.`,
      });
    return entity;
  }

  async findOne(request: GetById): Promise<<Domain>Data> {
    const entity = await this.findById(request);
    return entity.toResponseDto();
  }

  async create(dto: Create<Domain>Dto): Promise<<Domain>Entity> {
    const entity = this.<domainSingular>Repository.create(dto);
    return this.<domainSingular>Repository.save(entity);
  }

  async update({ id, ...dto }: { id: string } & Partial<Create<Domain>Dto>): Promise<<Domain>Entity> {
    const entity = await this.findById({ id });
    Object.assign(entity, dto);
    return this.<domainSingular>Repository.save(entity);
  }

  async remove({ id }: GetById): Promise<void> {
    await this.findById({ id });
    await this.<domainSingular>Repository.softDelete({ id });
  }
}
```

---

### FILE 7 — Unit test (`apps/api/src/<domainPlural>/<domainPlural>.service.spec.ts`)

Rules:
- Only mock the direct dependencies of the service being tested
- Use `getRepositoryToken(<Domain>Entity)` for repository mock
- Mock only the methods actually called in the test
- Create a `make<Domain>Entity()` factory in `apps/api/test/mocks/<domainPlural>-mocks.ts`
- Test at minimum: defined, findById (found), findById (not found → NOT_FOUND), findOne (delegates to toResponseDto)
- Error assertions: `rejects.toEqual(new RpcException({ code: status.NOT_FOUND, message: '...' }))`

```typescript
import { randomUUID } from 'crypto';
import { status } from '@grpc/grpc-js';
import { RpcException } from '@nestjs/microservices';
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { <Domain>Entity } from '@app/common/entities/tenant/<domainPlural>/<tableName>.entity';
import { RequestContextService } from '../request-context/request-context.service';
import { <Domain>Service } from './<domainPlural>.service';
import { make<Domain>Entity } from '../../test/mocks/<domainPlural>-mocks';

describe('<Domain>Service', () => {
  let service: <Domain>Service;
  let repo: { findOneBy: jest.Mock; save: jest.Mock; softDelete: jest.Mock };

  beforeEach(async () => {
    repo = {
      findOneBy: jest.fn(),
      save: jest.fn(),
      softDelete: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        <Domain>Service,
        { provide: getRepositoryToken(<Domain>Entity), useValue: repo },
        { provide: RequestContextService, useValue: { getRequestUser: jest.fn() } },
        { provide: 'DataSource', useValue: {} },
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
    });

    it('should throw NOT_FOUND when entity does not exist', async () => {
      const id = randomUUID();
      repo.findOneBy.mockResolvedValue(null);
      await expect(service.findById({ id })).rejects.toEqual(
        new RpcException({ code: status.NOT_FOUND, message: `<Domain> with id: ${id} not found.` }),
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
});
```

---

### MOCK FILE — (`apps/api/test/mocks/<domainPlural>-mocks.ts`)

```typescript
import { randomUUID } from 'crypto';

export type <Domain>EntityLike = {
  id: string;
  // add fields matching the entity
  toResponseDto: () => Record<string, unknown>;
};

export function make<Domain>Entity(partial: Partial<<Domain>EntityLike> = {}): <Domain>EntityLike {
  const id = partial.id ?? randomUUID();
  return {
    id,
    // fill required fields with sensible defaults
    toResponseDto: () => ({ id }),
    ...partial,
  };
}
```

---

## STEP 4 — Show all files to the user before writing

Present each generated file with its full path and content. Ask:

> "¿Todo correcto? ¿Quieres cambiar algo antes de crear los archivos?"

Wait for confirmation. Apply any requested changes.

---

## STEP 5 — Write all files

On confirmation, write every file to disk using the Write tool.

After writing, show the summary:

```
✅ Module scaffolded: <Domain>

Files created:
  libs/common/src/entities/tenant/<domainPlural>/<tableName>.entity.ts
  libs/common/src/dto/tenant/<domainPlural>/create-<tableName>.dto.ts
  libs/common/src/dto/tenant/<domainPlural>/update-<tableName>.dto.ts
  apps/api/src/<domainPlural>/<domainPlural>.module.ts
  apps/api/src/<domainPlural>/<domainPlural>.controller.ts
  apps/api/src/<domainPlural>/<domainPlural>.service.ts
  apps/api/src/<domainPlural>/<domainPlural>.service.spec.ts
  apps/api/test/mocks/<domainPlural>-mocks.ts

Next steps:
  1. Register <Domain>Module in the AppModule or parent module
  2. Create the proto file: proto/tenant/<domainPlural>.proto
  3. Run: pnpm generate:proto
  4. Run migration: pnpm migration:generate:tenant Add<Domain>Table
```

---

## RULES

- Never use `HttpException` / `NotFoundException` / `BadRequestException` — always `BaseRpcException` with gRPC `status.*` codes
- Never write raw SQL — all DB operations through TypeORM Repository or QueryBuilder
- Never add `synchronize: true` anywhere
- Never skip `toResponseDto()` on entities — this is the serialization contract
- Always use `@ApiHideProperty()` + `@Exclude()` for sensitive fields (tokens, keys, secrets)
- The Update DTO must always extend `PartialType(CreateDto)` — never duplicate validators
- RabbitMQ handlers must always ack/nack — never leave messages unacknowledged
- All column names in snake_case via `{ name: 'snake_case' }` — TypeORM does NOT auto-convert
- `BaseEntity` provides `id`, `createdAt`, `updatedAt`, `deletedAt` — never re-declare these
