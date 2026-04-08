---
name: entity-dto
description: Generate a TypeORM entity (extending BaseEntity), Create DTO, and Update DTO for the Lety 2.0 Backend following official TypeORM and NestJS best practices. Triggered when the user needs to create or update an entity/DTO pair.
---

You are generating a TypeORM entity + DTOs for the **Lety 2.0 Backend** (NestJS + TypeORM 0.3.x + PostgreSQL).

> **Priority rule**: Always follow official documentation and industry best practices. If existing code in the project does not follow best practices, generate the correct version anyway and note the discrepancy so it can be improved.

---

## DOCUMENTATION — consult before generating

Fetch the relevant page whenever there is any doubt about a decorator, option, or behavior:

- **TypeORM Entities & decorators**: https://typeorm.io/entities
- **TypeORM Column types**: https://typeorm.io/entities#column-types-for-postgres
- **TypeORM Relations**: https://typeorm.io/relations
- **TypeORM Indices**: https://typeorm.io/indices
- **NestJS Swagger decorators**: https://docs.nestjs.com/openapi/types-and-parameters
- **class-validator decorators**: https://github.com/typestack/class-validator#validation-decorators
- **class-transformer**: https://github.com/typestack/class-transformer#readme
- **NestJS PartialType**: https://docs.nestjs.com/openapi/mapped-types#partial

---

## STEP 1 — Gather field specification

Ask the user for missing information. Required:
- **Domain name** (singular PascalCase): e.g. `Invoice`, `Lead`, `Conversation`
- **Fields**: for each field provide:
  - name (camelCase)
  - TypeScript type: `string` | `number` | `boolean` | `Date` | `Decimal` | `enum:EnumName` | `jsonb` | `uuid`
  - nullable? (default: false)
  - unique? (default: false)
  - default value? (optional)
  - sensitive? — tokens, keys, passwords (will add `EncryptionTransformer` + `@ApiHideProperty()` + `@Exclude()`)
  - in DTO? (default: true — set false for system-managed fields like `agencyId`)
- **Relations**: for each relation:
  - type: `ManyToOne` | `OneToMany` | `OneToOne` | `ManyToMany`
  - target entity (PascalCase)
  - owning side? (add `@JoinColumn` here)
  - cascade? onDelete behavior?
- **Which service**: `tenant` | `platform` | `auth` (default: `tenant`)
- **Needs indices?** Beyond the default `['id']` index — e.g. `['agencyId', 'status']` for frequent filters

Do NOT invent fields. If the description is vague, ask for clarification.

---

## STEP 2 — Derive naming and paths

From domain name (e.g. `Invoice`):
- `domainPlural` → `invoices`
- `tableName` → `invoice` (snake_case singular)
- Entity path: `libs/common/src/entities/tenant/<domainPlural>/<tableName>.entity.ts`
- Create DTO path: `libs/common/src/dto/tenant/<domainPlural>/create-<tableName>.dto.ts`
- Update DTO path: `libs/common/src/dto/tenant/<domainPlural>/update-<tableName>.dto.ts`

---

## STEP 3 — Generate the Entity

### Rules — strictly follow these

**Structure:**
- Always `extends BaseEntity` (from `@app/common/database`) — never redefine `id`, `createdAt`, `updatedAt`, `deletedAt`
- `@Entity('table_name')` — singular snake_case
- Always add `@Index(['id'])` as minimum — add composite indices for fields used together in WHERE clauses
- Use `@Unique([...])` for unique constraints across multiple columns (not just `unique: true` on column)

**Columns:**
- Always specify `{ name: 'snake_case_name' }` explicitly — TypeORM does NOT auto-convert camelCase
- `string` → `@Column({ name: 'field_name', nullable: false })` (default type is varchar)
- `string` with length → `@Column({ name: 'field_name', length: 255 })`
- `text` (no length limit) → `@Column({ name: 'field_name', type: 'text' })`
- `number` integer → `@Column({ name: 'field_name', type: 'int' })`
- `number` float → `@Column({ name: 'field_name', type: 'float' })`
- `Decimal` (money/precision) → `@Column({ name: 'field_name', type: 'decimal', precision: 12, scale: 6, transformer: new DecimalColumnTransformer() })`
- `boolean` → `@Column({ name: 'field_name', type: 'boolean', default: false })`
- `Date` timestamp → `@Column({ name: 'field_name', type: 'timestamp', nullable: true })`
- `enum` → `@Column({ name: 'field_name', type: 'enum', enum: SomeEnum, default: SomeEnum.VALUE })`
- `jsonb` → `@Column({ name: 'field_name', type: 'jsonb', nullable: true, default: {} })`
- `uuid` FK column → `@Column({ name: 'related_id', type: 'uuid', nullable: false })`
- Sensitive fields: add `transformer: new EncryptionTransformer()` + `@ApiHideProperty()` + `@Exclude()`

**Swagger:**
- `@ApiProperty({ description: '...', example: ..., required: true/false, nullable: true/false })` on every public column
- `@ApiHideProperty()` on sensitive/internal fields (tokens, keys, internal IDs not exposed)
- Never expose FK UUID columns directly if there is a relation — annotate the relation instead

**Relations:**
- Always define both sides
- Owning side (FK column exists here): add `@JoinColumn({ name: 'fk_name', referencedColumnName: 'id' })`
- Composite FK: use array in `@JoinColumn([{ name: 'fk1', referencedColumnName: 'field1' }, ...])`
- Add `onDelete: 'CASCADE'` only when parent deletion should cascade
- For `OneToMany`: no `@JoinColumn`, the FK is on the other side
- Always declare FK column separately (e.g. `agentId: string`) alongside the relation object

**`toResponseDto()`:**
- Always implement — returns a plain object matching the proto type `<Domain>Data`
- Use null-safe access for optional relations: `this.relation ? this.relation.toResponseDto() : undefined`
- Map `Date` fields as-is (not `.toISOString()`)
- Never expose sensitive fields (`@Exclude()` fields must not appear in toResponseDto)
- Arrays: use `.map()` with null guard: `this.items ? this.items.map(i => i.toResponseDto()) : []`

```typescript
import { ApiHideProperty, ApiProperty } from '@nestjs/swagger';
import { Exclude } from 'class-transformer';
import { Column, Entity, Index, JoinColumn, ManyToOne, OneToMany } from 'typeorm';
import { BaseEntity } from '@app/common/database';
import { EncryptionTransformer } from '@app/common/database/transformers/encryption.transformer';
import DecimalColumnTransformer from '@app/common/utils/decimal.util';
import { <Domain>Data } from '@app/common/types/proto/tenant/<domainPlural>/<tableName>-interface';
// import related entities...

@Entity('<tableName>')
@Index(['id'])
// Add composite indices for frequently filtered combinations:
// @Index(['agencyId', 'status'])
export class <Domain>Entity extends BaseEntity {

  // --- Public fields ---
  @ApiProperty({ description: 'Field description', example: 'example value', nullable: false })
  @Column({ name: 'field_name', nullable: false })
  fieldName: string;

  // --- Enum field ---
  @ApiProperty({ description: 'Status', enum: StatusEnum, example: StatusEnum.ACTIVE })
  @Column({ name: 'status', type: 'enum', enum: StatusEnum, default: StatusEnum.ACTIVE })
  status: StatusEnum;

  // --- Decimal (money/precision) field ---
  @ApiProperty({ description: 'Amount', example: 100.00 })
  @Column({ name: 'amount', type: 'decimal', precision: 12, scale: 6, default: 0,
    transformer: new DecimalColumnTransformer() })
  amount: Decimal;

  // --- Sensitive field (never in API response) ---
  @ApiHideProperty()
  @Exclude()
  @Column({ name: 'secret_token', nullable: true, transformer: new EncryptionTransformer() })
  secretToken: string | null;

  // --- FK column + relation ---
  @ApiProperty({ description: 'Parent agency ID' })
  @Column({ name: 'agency_id', type: 'uuid', nullable: false })
  agencyId: string;

  @ManyToOne(() => AgencyEntity, agency => agency.<domainPlural>, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'agency_id', referencedColumnName: 'id' })
  agency: AgencyEntity;

  // --- OneToMany (no @JoinColumn here, FK is on child) ---
  @OneToMany(() => Child<Domain>Entity, child => child.<domainSingular>)
  children: Child<Domain>Entity[];

  toResponseDto(): <Domain>Data {
    return {
      id: this.id,
      fieldName: this.fieldName,
      status: this.status,
      agencyId: this.agencyId,
      createdAt: this.createdAt,
      updatedAt: this.updatedAt,
      // Relations (null-safe):
      agency: this.agency ? this.agency.toResponseDto() : undefined,
      children: this.children ? this.children.map(c => c.toResponseDto()) : [],
      // NEVER include secretToken or other @Exclude() fields
    };
  }
}
```

---

## STEP 4 — Generate the Create DTO

### Rules

**Imports:**
- `ApiProperty` / `ApiPropertyOptional` from `@nestjs/swagger`
- Only import validators actually used — don't over-import

**Per field type:**
- Required `string` → `@ApiProperty()` + `@IsString()` + `@IsNotEmpty()`
- Required `string` with max length → add `@MaxLength(N, { message: '...' })`
- Optional `string` → `@ApiPropertyOptional()` + `@IsOptional()` + `@IsString()`
- `uuid` → `@IsUUID()` + `@IsNotEmpty()` (or `@IsOptional()`)
- `number` integer → `@IsInt()`, float → `@IsNumber()`
- `number` with range → add `@Min(N)` + `@Max(N)` with messages
- `boolean` → `@IsBoolean()`
- `enum` → `@IsEnum(EnumType, { message: '...' })`
- URL string → `@IsUrl()`
- Nested DTO → `@ValidateNested()` + `@Type(() => NestedDto)`
- Array of nested → `@IsArray()` + `@ValidateNested({ each: true })` + `@Type(() => ItemDto)`
- Complex proto/JSON field with string serialization → add `@Transform()` to parse JSON string → object

**Rules:**
- `@IsOptional()` must come BEFORE type validators — order matters
- Never stack `@IsNotEmpty()` on a field that also has `@IsOptional()`
- System-managed fields (`agencyId`, `subAccountId`, etc.) never go in the Create DTO — they come from context
- No duplicate validators (e.g. don't add `@IsString()` + `@IsNotEmpty()` + `@IsUUID()` — UUID already implies string)

```typescript
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsEnum, IsInt, IsNotEmpty, IsOptional, IsString, IsUUID,
  Max, MaxLength, Min, ValidateNested,
} from 'class-validator';

export class Create<Domain>Dto {
  @ApiProperty({ description: 'Required string field', example: 'value' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100, { message: 'fieldName cannot exceed 100 characters' })
  fieldName: string;

  @ApiPropertyOptional({ description: 'Optional UUID reference' })
  @IsOptional()
  @IsUUID()
  relatedId?: string;

  @ApiPropertyOptional({ description: 'Optional enum', enum: StatusEnum })
  @IsOptional()
  @IsEnum(StatusEnum, { message: 'status must be a valid StatusEnum value' })
  status?: StatusEnum;

  @ApiProperty({ description: 'Integer in range', example: 10 })
  @IsInt({ message: 'limit must be an integer' })
  @Min(1, { message: 'limit must be at least 1' })
  @Max(100, { message: 'limit must be at most 100' })
  limit: number;
}
```

---

## STEP 5 — Generate the Update DTO

Always use `PartialType` — never copy-paste validators from Create DTO:

```typescript
import { PartialType } from '@nestjs/swagger';
import { Create<Domain>Dto } from './create-<tableName>.dto';

export class Update<Domain>Dto extends PartialType(Create<Domain>Dto) {}
```

---

## STEP 6 — Flag any best-practice issues found

After generating, if the user's specification (or existing code they shared) contains any of these issues, flag them explicitly:

| Issue | What to tell the user |
|---|---|
| Missing `{ name: 'snake_case' }` on column | "Column name not explicit — TypeORM may use camelCase in DB which diverges from PostgreSQL conventions" |
| Sensitive field without `@Exclude()` | "This field may leak in serialized responses — add `@ApiHideProperty()` and `@Exclude()`" |
| Missing `toResponseDto()` | "Entity needs `toResponseDto()` — without it, the entity is serialized directly which exposes all columns" |
| `@IsNotEmpty()` on optional field | "`@IsNotEmpty()` conflicts with `@IsOptional()` — remove it" |
| FK column missing explicit `{ name: 'snake_case' }` | "FK column name will default to camelCase — add `{ name: 'related_id' }` explicitly" |
| `synchronize: true` in config | "Remove from non-development environments — use migrations instead" |
| Raw SQL in migration (manually written) | "Use `typeorm migration:generate` to generate migrations from entity changes" |
| `any` type on a column or DTO | "Avoid `any` — use a proper TypeScript type or interface" |

---

## STEP 7 — Show draft and confirm

Present all 3 files with full paths and content. Ask:

> "¿Todo correcto? ¿Quieres cambiar algo antes de crear los archivos?"

Wait for confirmation. Apply changes if requested.

---

## STEP 8 — Write files

On confirmation, write the 3 files. Then show:

```
✅ Entity + DTOs created: <Domain>

  libs/common/src/entities/tenant/<domainPlural>/<tableName>.entity.ts
  libs/common/src/dto/tenant/<domainPlural>/create-<tableName>.dto.ts
  libs/common/src/dto/tenant/<domainPlural>/update-<tableName>.dto.ts

Next steps:
  - Register entity in the module: TypeOrmModule.forFeature([<Domain>Entity])
  - Add to database config if using a new schema
  - Generate migration: pnpm migration:generate:tenant Add<Domain>Table
  - Define proto type <Domain>Data in proto/tenant/<domainPlural>.proto
```

---

## ABSOLUTE RULES

- `BaseEntity` provides `id`, `createdAt`, `updatedAt`, `deletedAt` — never redeclare these
- Every column MUST have explicit `{ name: 'snake_case' }` — no exceptions
- `toResponseDto()` is required — serialization must be explicit
- Sensitive fields MUST have `@ApiHideProperty()` + `@Exclude()` + `EncryptionTransformer`
- Update DTO MUST use `PartialType` — never duplicate validators
- System-managed fields (`agencyId`, `subAccountId`, `userId`) never in Create DTO
- `@IsOptional()` must be first among validators
- Never use `any` type — use proper TypeScript interfaces or types
- Never use `@IsNotEmpty()` on an optional field
