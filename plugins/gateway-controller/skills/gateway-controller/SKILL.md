---
name: gateway-controller
description: Scaffold a complete API Gateway feature for Lety 2.0 Backend: proto service + interface files, REST controller with Swagger/Permissions, gRPC gateway service with lastValueFrom, and NestJS module with ClientsModule.registerAsync. Triggered when the user needs to add a new endpoint or feature to the api-gateway.
---

You are scaffolding a new **API Gateway feature** for the Lety 2.0 Backend. The gateway bridges HTTP REST (Fastify) → gRPC to downstream microservices.

> **Priority rule**: Always follow official proto3, NestJS, and gRPC documentation and best practices. If existing code in the project deviates, generate the correct version and flag the discrepancy.

---

## DOCUMENTATION — consult before generating

- **Proto3 language guide**: https://protobuf.dev/programming-guides/proto3/
- **NestJS gRPC**: https://docs.nestjs.com/microservices/grpc
- **NestJS ClientsModule**: https://docs.nestjs.com/microservices/basics#client
- **NestJS Swagger**: https://docs.nestjs.com/openapi/introduction
- **NestJS Controllers**: https://docs.nestjs.com/controllers
- **RxJS lastValueFrom**: https://rxjs.dev/api/index/function/lastValueFrom

Fetch the relevant page when uncertain about any decorator, option, or proto syntax.

---

## STEP 1 — Gather specification

Ask the user for missing information. Required:

- **Domain name** (singular PascalCase): e.g. `Invoice`, `Lead`, `Conversation`
- **Target microservice**: `tenant` | `platform` | `auth-service` (default: `tenant`)
- **Endpoints**: for each endpoint:
  - HTTP method: `GET` | `POST` | `PATCH` | `DELETE`
  - Route: e.g. `/`, `/:id`, `/:id/activate`
  - What it does (maps to which gRPC RPC)
  - Request body DTO (if POST/PATCH)
  - Response type (DTO or Entity class)
  - Permission: `Actions.READ` | `WRITE` | `UPDATE` | `DELETE` and which `TenantResourceObjectEnum` value
  - Requires file upload? (multipart/form-data)
  - Needs rate limiting? (`@Throttle`)
  - Accessible via API key? (`@ApiKeyEnabled` + `TenantApiKeyGuard`)

- **Proto messages needed**: for each RPC — request message name + fields, response message name + fields
  - Use `commonTypes.GetById` for single-ID lookups (already defined)
  - Use `paginationCommon.SearchablePagination` for paginated lists (already defined)
  - Use `google.protobuf.Empty` for no-input or no-output RPCs

Optional:
- **Max message size** (default: 15MB for file-heavy services, 4MB otherwise)
- **Additional modules to import** (e.g. `UsersModule`, `ApiKeysModule`)

---

## STEP 2 — Derive naming conventions

From domain name (e.g. `Invoice`):
- `domainPlural` → `invoices`
- `tableName` → `invoice`
- `packageName` → `invoiceService` (camelCase + Service)
- `packageCommon` → `invoiceCommon`
- `SERVICE_NAME` constant → `INVOICES_SERVICE_NAME`
- `PACKAGE_NAME` constant → `INVOICES_SERVICE_PACKAGE_NAME`

File paths:
- Proto service: `proto/tenant/<domainPlural>-service.proto`
- Proto interface: `proto/tenant/<domainPlural>/<tableName>-interface.proto`
- Gateway controller: `apps/api-gateway/src/tenant/<domainPlural>/<domainPlural>.controller.ts`
- Gateway service: `apps/api-gateway/src/tenant/<domainPlural>/<domainPlural>.service.ts`
- Gateway module: `apps/api-gateway/src/tenant/<domainPlural>/<domainPlural>.module.ts`

---

## STEP 3 — Generate the Proto Interface File

### File: `proto/tenant/<domainPlural>/<tableName>-interface.proto`

Rules:
- `syntax = "proto3"` always first line
- Package: `package <domainPlural>Common;` (camelCase + Common)
- Import only what is actually used
- Standard imports available:
  - `"common/common-requests.proto"` → `commonTypes.GetById`, `GetByEmail`, `FileUpload`
  - `"common/pagination-interface.proto"` → `paginationCommon.SearchablePagination`, `PaginationMeta`
  - `"google/protobuf/timestamp.proto"` → `google.protobuf.Timestamp` for date fields
  - `"google/protobuf/empty.proto"` → `google.protobuf.Empty`
  - `"google/protobuf/struct.proto"` → `google.protobuf.Struct` for dynamic JSON objects
- Field numbering: start at 1, never reuse numbers, add new fields at the end
- Field naming: `snake_case` (proto convention) — TypeScript generated types will be camelCase
- Types:
  - `string` for text, UUIDs, enums-as-string
  - `int32` / `int64` for integers
  - `double` / `float` for decimals
  - `bool` for booleans
  - `bytes` for binary data
  - `google.protobuf.Timestamp` for dates
  - `google.protobuf.Struct` for arbitrary JSON objects
  - `repeated <Type>` for arrays
  - `optional <Type>` for nullable fields (proto3)
- Always include timestamps in response messages: `created_at`, `updated_at`, `deleted_at`
- `<Domain>Data` = the main response message (mirrors `toResponseDto()`)
- `Create<Domain>Request` = input for create RPC
- `Update<Domain>Request` = input for update RPC (include `id` as field 1)
- `Get<Domain>sResponse` = paginated list response with `items` + `meta`

```proto
syntax = "proto3";
package <domainPlural>Common;

import "common/common-requests.proto";
import "common/pagination-interface.proto";
import "google/protobuf/timestamp.proto";
import "google/protobuf/empty.proto";

message <Domain>Data {
    string id = 1;
    string name = 2;
    // ... domain fields
    google.protobuf.Timestamp created_at = 10;
    google.protobuf.Timestamp updated_at = 11;
    optional google.protobuf.Timestamp deleted_at = 12;
}

message Create<Domain>Request {
    string name = 1;
    // ... required fields (NO id, NO agencyId — those come from context)
}

message Update<Domain>Request {
    string id = 1;
    optional string name = 2;
    // ... updatable fields (all optional except id)
}

message Get<Domain>sResponse {
    repeated <Domain>Data items = 1;
    paginationCommon.PaginationMeta meta = 2;
}
```

---

## STEP 4 — Generate the Proto Service File

### File: `proto/tenant/<domainPlural>-service.proto`

Rules:
- Package: `package <domainSingular>Service;`
- Service name: `<Domain>Service`
- Import the interface file for this domain
- Import common files for shared types
- Standard RPCs for a CRUD resource:
  - `rpc GetById(commonTypes.GetById) returns (<domainPlural>Common.<Domain>Data);`
  - `rpc Create(<domainPlural>Common.Create<Domain>Request) returns (<domainPlural>Common.<Domain>Data);`
  - `rpc Update(<domainPlural>Common.Update<Domain>Request) returns (<domainPlural>Common.<Domain>Data);`
  - `rpc FindAll(paginationCommon.SearchablePagination) returns (<domainPlural>Common.Get<Domain>sResponse);`
  - `rpc Delete(commonTypes.GetById) returns (google.protobuf.Empty);`
- Only include RPCs that are actually needed — do not add unused ones

```proto
syntax = "proto3";
package <domainSingular>Service;

import "common/common-requests.proto";
import "tenant/<domainPlural>/<tableName>-interface.proto";
import "google/protobuf/empty.proto";
import "common/pagination-interface.proto";

service <Domain>Service {
    rpc GetById(commonTypes.GetById) returns (<domainPlural>Common.<Domain>Data);
    rpc Create(<domainPlural>Common.Create<Domain>Request) returns (<domainPlural>Common.<Domain>Data);
    rpc Update(<domainPlural>Common.Update<Domain>Request) returns (<domainPlural>Common.<Domain>Data);
    rpc FindAll(paginationCommon.SearchablePagination) returns (<domainPlural>Common.Get<Domain>sResponse);
    rpc Delete(commonTypes.GetById) returns (google.protobuf.Empty);
}
```

---

## STEP 5 — Generate the Gateway Controller

### File: `apps/api-gateway/src/tenant/<domainPlural>/<domainPlural>.controller.ts`

Rules:
- `@Controller()` — no route string (routes are defined in the module router)
- Always add `@HttpCode(HttpStatus.XXX)` explicitly on every method
- `@ApiOperation({ summary: '...', operationId: '<camelCaseUnique>' })` on every method
  - `operationId` must be globally unique across the gateway — use pattern `<verb><Domain>` e.g. `createInvoice`, `getInvoiceById`
- `@ApiResponse(...)` for every possible status code (200/201, 400, 404, 409, etc.)
- `@Permissions({ action: Actions.XXX, resource: TenantResourceObjectEnum.XXX })` on every method
- UUID params: always `@Param('id', ParseUUIDPipe) id: string`
- Non-UUID params: `@Param('name') name: string`
- Pagination: `@Query() query: PaginationDto` or domain-specific query DTO
- List endpoints: use `@ApiPaginatedResponse(EntityClass)` instead of `@ApiResponse`
- DELETE endpoints: `@HttpCode(HttpStatus.NO_CONTENT)` + return `Promise<void>`
- File uploads:
  - Single file: `@UseInterceptors(FileInterceptor('fieldName'))` + `@UploadedFile() file?: File`
  - Multiple files: `@UseInterceptors(FilesInterceptor('fieldName', MAX_COUNT, { fileFilter }))` + `@UploadedFiles() files: File[]`
  - Add `@ApiConsumes('multipart/form-data')` for file endpoints
- Rate limiting: `@Throttle({ default: { ttl: 60000, limit: 100 } })`
- API key access: `@UseGuards(TenantApiKeyGuard)` + `@ApiKeyEnabled()` + `@ApiSecurity(API_KEY_HEADER)`
- No business logic in controller — delegate everything to the service

```typescript
import {
  Body, Controller, Delete, Get, HttpCode, HttpStatus,
  Param, ParseUUIDPipe, Patch, Post, Query,
} from '@nestjs/common';
import { ApiOperation, ApiResponse } from '@nestjs/swagger';
import { Permissions } from '@app/common/decorators/permisssions.decorator';
import { ApiPaginatedResponse } from '@app/common/decorators/responses.decorators';
import { Create<Domain>Dto } from '@app/common/dto/tenant/<domainPlural>/create-<tableName>.dto';
import { Update<Domain>Dto } from '@app/common/dto/tenant/<domainPlural>/update-<tableName>.dto';
import { PaginationDto } from '@app/common/dto/api-responses.dto';
import { <Domain>Entity } from '@app/common/entities/tenant/<domainPlural>/<tableName>.entity';
import { Actions } from '@app/common/enums/action.enum';
import { TenantResourceObjectEnum } from '@app/common/enums/object.enum';
import { <Domain>sService } from './<domainPlural>.service';

@Controller()
export class <Domain>sController {
  constructor(private readonly <domainSingular>sService: <Domain>sService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a new <domain>', operationId: 'create<Domain>' })
  @ApiResponse({ status: 201, description: '<Domain> created successfully', type: <Domain>Entity })
  @ApiResponse({ status: 400, description: 'Bad request' })
  @ApiResponse({ status: 409, description: '<Domain> already exists' })
  @Permissions({ action: Actions.WRITE, resource: TenantResourceObjectEnum.<DOMAINS> })
  async create(@Body() dto: Create<Domain>Dto) {
    return this.<domainSingular>sService.create(dto);
  }

  @Get()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Get all <domain>s', operationId: 'findAll<Domain>s' })
  @ApiPaginatedResponse(<Domain>Entity)
  @Permissions({ action: Actions.READ, resource: TenantResourceObjectEnum.<DOMAINS> })
  async findAll(@Query() query: PaginationDto) {
    return this.<domainSingular>sService.findAll(query);
  }

  @Get(':id')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Get a <domain> by ID', operationId: 'get<Domain>ById' })
  @ApiResponse({ status: 200, description: '<Domain> found', type: <Domain>Entity })
  @ApiResponse({ status: 404, description: '<Domain> not found' })
  @Permissions({ action: Actions.READ, resource: TenantResourceObjectEnum.<DOMAINS> })
  async findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.<domainSingular>sService.findOne({ id });
  }

  @Patch(':id')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Update a <domain>', operationId: 'update<Domain>ById' })
  @ApiResponse({ status: 200, description: '<Domain> updated successfully', type: <Domain>Entity })
  @ApiResponse({ status: 400, description: 'Bad request' })
  @ApiResponse({ status: 404, description: '<Domain> not found' })
  @Permissions({ action: Actions.UPDATE, resource: TenantResourceObjectEnum.<DOMAINS> })
  async update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: Update<Domain>Dto) {
    return this.<domainSingular>sService.update(id, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete a <domain>', operationId: 'delete<Domain>ById' })
  @ApiResponse({ status: 204, description: '<Domain> deleted successfully' })
  @ApiResponse({ status: 404, description: '<Domain> not found' })
  @ApiResponse({ status: 403, description: 'Forbidden' })
  @Permissions({ action: Actions.DELETE, resource: TenantResourceObjectEnum.<DOMAINS> })
  async remove(@Param('id', ParseUUIDPipe) id: string): Promise<void> {
    await this.<domainSingular>sService.delete(id);
  }
}
```

---

## STEP 6 — Generate the Gateway Service

### File: `apps/api-gateway/src/tenant/<domainPlural>/<domainPlural>.service.ts`

Rules:
- Always `implements OnModuleInit`
- Inject gRPC client with `@Inject(<DOMAIN>_SERVICE_NAME) private readonly grpcClient: ClientGrpc`
- Inject `GrpcRequestInterceptor` for metadata enrichment (context propagation)
- `onModuleInit()`: initialize service client with `this.grpcClient.getService<ServiceClient>(SERVICE_NAME)`
- **Every gRPC call must**:
  1. Get metadata: `const md = this.grpcRequestInterceptor.enrichMetadata();`
  2. Wrap with `lastValueFrom(this.service.rpcMethod(request, md))`
- Map HTTP DTOs to proto request messages explicitly — never pass the DTO object directly if field names differ
- Validation at the gateway level (e.g. file size checks) goes in the service, not controller

```typescript
import { Inject, Injectable, OnModuleInit } from '@nestjs/common';
import { ClientGrpc } from '@nestjs/microservices';
import { lastValueFrom } from 'rxjs';
import { Create<Domain>Dto } from '@app/common/dto/tenant/<domainPlural>/create-<tableName>.dto';
import { Update<Domain>Dto } from '@app/common/dto/tenant/<domainPlural>/update-<tableName>.dto';
import { PaginationDto } from '@app/common/dto/api-responses.dto';
import { GetById } from '@app/common/types/proto/common/common-requests';
import {
  <DOMAIN>S_SERVICE_NAME,
  <Domain>sServiceClient,
} from '@app/common/types/proto/tenant/<domainPlural>-service';
import { GrpcRequestInterceptor } from '@app/gateway/request-context/interceptors/grpc-request.interceptor';

@Injectable()
export class <Domain>sService implements OnModuleInit {
  private <domainSingular>sService: <Domain>sServiceClient;

  constructor(
    @Inject(<DOMAIN>S_SERVICE_NAME) private readonly grpcClient: ClientGrpc,
    private readonly grpcRequestInterceptor: GrpcRequestInterceptor,
  ) {}

  onModuleInit() {
    this.<domainSingular>sService = this.grpcClient.getService<<Domain>sServiceClient>(<DOMAIN>S_SERVICE_NAME);
  }

  async findOne(request: GetById) {
    const md = this.grpcRequestInterceptor.enrichMetadata();
    return lastValueFrom(this.<domainSingular>sService.getById(request, md));
  }

  async findAll(query: PaginationDto) {
    const md = this.grpcRequestInterceptor.enrichMetadata();
    return lastValueFrom(
      this.<domainSingular>sService.findAll(
        { pagination: { page: query.page, limit: query.limit } },
        md,
      ),
    );
  }

  async create(dto: Create<Domain>Dto) {
    const md = this.grpcRequestInterceptor.enrichMetadata();
    return lastValueFrom(this.<domainSingular>sService.create(dto, md));
  }

  async update(id: string, dto: Update<Domain>Dto) {
    const md = this.grpcRequestInterceptor.enrichMetadata();
    return lastValueFrom(this.<domainSingular>sService.update({ id, ...dto }, md));
  }

  async delete(id: string) {
    const md = this.grpcRequestInterceptor.enrichMetadata();
    return lastValueFrom(this.<domainSingular>sService.delete({ id }, md));
  }
}
```

---

## STEP 7 — Generate the Gateway Module

### File: `apps/api-gateway/src/tenant/<domainPlural>/<domainPlural>.module.ts`

Rules:
- Use `ClientsModule.registerAsync` — never `ClientsModule.register` (config must come from `ConfigService`)
- Proto path: `join(__dirname, '../proto/tenant/<domainPlural>-service.proto')` — relative to compiled output
- Always include `loader: GRPC_LOADER_OPTIONS` (shared loader config from `@app/common/constants`)
- URL from config: `config.get<string>(API_GATEWAY_CONFIG_KEY.TENANT_SERVICE_URL)` (or `PLATFORM_SERVICE_URL`/`AUTH_SERVICE_URL` depending on target)
- Max message size: 15MB for file-heavy services, 4MB default
- Export the service if other modules will call it

```typescript
import { join } from 'path';
import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ClientsModule, Transport } from '@nestjs/microservices';
import { GRPC_LOADER_OPTIONS } from '@app/common/constants';
import {
  <DOMAIN>S_SERVICE_NAME,
  <DOMAIN>S_SERVICE_PACKAGE_NAME,
} from '@app/common/types/proto/tenant/<domainPlural>-service';
import { API_GATEWAY_CONFIG_KEY } from 'apps/api-gateway/config/key_mapping.const';
import { <Domain>sController } from './<domainPlural>.controller';
import { <Domain>sService } from './<domainPlural>.service';

@Module({
  imports: [
    ClientsModule.registerAsync([
      {
        name: <DOMAIN>S_SERVICE_NAME,
        inject: [ConfigService],
        useFactory: (config: ConfigService) => ({
          transport: Transport.GRPC,
          options: {
            package: <DOMAIN>S_SERVICE_PACKAGE_NAME,
            url: config.get<string>(API_GATEWAY_CONFIG_KEY.TENANT_SERVICE_URL),
            protoPath: join(__dirname, '../proto/tenant/<domainPlural>-service.proto'),
            loader: GRPC_LOADER_OPTIONS,
            maxReceiveMessageLength: 4 * 1024 * 1024,
            maxSendMessageLength: 4 * 1024 * 1024,
          },
        }),
      },
    ]),
  ],
  controllers: [<Domain>sController],
  providers: [<Domain>sService],
  exports: [<Domain>sService],
})
export class <Domain>sModule {}
```

---

## STEP 8 — Show draft and confirm

Present all 5 files with full paths. Ask:

> "¿Todo correcto? ¿Quieres cambiar algo antes de crear los archivos?"

Wait for confirmation.

---

## STEP 9 — Write files and show next steps

After writing, display:

```
✅ Gateway feature scaffolded: <Domain>

Files created:
  proto/tenant/<domainPlural>-service.proto
  proto/tenant/<domainPlural>/<tableName>-interface.proto
  apps/api-gateway/src/tenant/<domainPlural>/<domainPlural>.controller.ts
  apps/api-gateway/src/tenant/<domainPlural>/<domainPlural>.service.ts
  apps/api-gateway/src/tenant/<domainPlural>/<domainPlural>.module.ts

Required next steps:
  1. Run proto code generation:
       pnpm generate:proto
     This creates @app/common/types/proto/tenant/<domainPlural>-service.ts
     with <DOMAIN>S_SERVICE_NAME, <DOMAIN>S_SERVICE_PACKAGE_NAME, and <Domain>sServiceClient

  2. Register <Domain>sModule in the gateway TenantModule or AppModule

  3. Add route prefix in the gateway routing config:
       { path: '<domainPlural>', module: <Domain>sModule }

  4. Implement the gRPC service in apps/api or apps/platform:
       /nest-module can scaffold the downstream microservice
```

---

## ABSOLUTE RULES

- `lastValueFrom()` on every gRPC call — never `.toPromise()` (deprecated)
- Always `enrichMetadata()` before every gRPC call — this propagates auth context between services
- `ClientsModule.registerAsync` — never `ClientsModule.register`
- Proto field names in `snake_case` — TypeScript generated types auto-convert to `camelCase`
- `optional` keyword for nullable proto3 fields — never use default value tricks
- Never access `google.protobuf.Empty` fields — it's a no-op response
- Never pass DTO directly to gRPC if field names differ — always map explicitly
- `operationId` in `@ApiOperation` must be globally unique across the entire gateway
- UUID route params always use `ParseUUIDPipe`
- DELETE endpoints always return `void` + `HttpStatus.NO_CONTENT`
- Proto field numbers are permanent — once assigned, never change or reuse them
