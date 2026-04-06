---
name: security-review
description: Review JWT strategies, auth guards, middleware, and security config for Lety 2.0 Backend. Flags vulnerabilities against NestJS docs and OWASP best practices. Triggered when the user asks to review, audit, or fix auth/security code.
---

You are performing a **security audit** of the Lety 2.0 Backend (NestJS + Fastify + gRPC + RabbitMQ).

> **Priority rule**: Always follow NestJS official docs, OWASP, and JWT best practices. If existing code has a vulnerability or misconfiguration, flag it with severity and provide the corrected version — even if it's in production today.

---

## DOCUMENTATION — fetch before answering if uncertain

- **NestJS Security**: https://docs.nestjs.com/security/authentication
- **NestJS Guards**: https://docs.nestjs.com/guards
- **NestJS Middleware**: https://docs.nestjs.com/middleware
- **NestJS Rate Limiting**: https://docs.nestjs.com/security/rate-limiting
- **NestJS Helmet**: https://docs.nestjs.com/security/helmet
- **NestJS CORS**: https://docs.nestjs.com/security/cors
- **NestJS CSRF**: https://docs.nestjs.com/security/csrf
- **OWASP JWT Cheat Sheet**: https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_for_Java_Cheat_Sheet.html
- **OWASP Auth Cheat Sheet**: https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html
- **OWASP API Security Top 10**: https://owasp.org/www-project-api-security/

---

## Architecture context

```
HTTP Request
  └── Fastify middleware (CORS, Helmet, Cookie, CSRF)
        └── DomainResolutionMiddleware (multi-tenant routing)
              └── JwtAuthGuard (global) — validates access token
                    └── PermissionsGuard (global) — CASL ability check
                          └── ThrottlerGuard (global) — rate limiting
                                └── Controller → gRPC → Microservice
```

- **JWT tokens**: extracted from `Authentication` cookie or `Authorization: Bearer` header
- **Refresh tokens**: hashed (PBKDF2 SHA512) before storage in Redis session
- **Sensitive fields**: encrypted with AES-256-GCM (`EncryptionTransformer`)
- **Microservices**: never handle HTTP auth — only receive enriched gRPC metadata from the gateway

---

## STEP 1 — Identify the scope of the review

Determine what the user has provided:

| Scope | What to check |
|-------|--------------|
| `main.ts` | CORS, Helmet, Cookie config, CSRF, ValidationPipe, global guards order |
| JWT strategy (`jwt.strategy.ts`) | Token extraction sources, signature algorithm, expiration check, session validation |
| Auth guard (`jwt-auth.guard.ts`, `permissions.guard.ts`) | canActivate logic, public route bypass, impersonation handling |
| API key guard | Plaintext vs hashed comparison, timing-safe equality |
| Token generation (`auth.service.ts`) | Payload claims, algorithm, expiration, session storage |
| Refresh token flow | Hash comparison, device binding, rotation |
| WebSocket guard | Token extraction from handshake, fallback risks |
| Webhook guard | HMAC signature verification, timing-safe comparison |
| Generic service/controller | Missing `@UseGuards`, exposed endpoints, improper error leakage |

---

## STEP 2 — Security checklist by area

### 2.1 — Global security setup (`main.ts`)

- [ ] **Helmet registered** — `@fastify/helmet` with strict CSP, `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`
- [ ] **CORS locked down** — `origin: true` is a critical vulnerability; must whitelist specific domains:
  ```typescript
  app.enableCors({
    origin: configService.get<string>('ALLOWED_ORIGINS').split(','),
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  });
  ```
- [ ] **Cookie `secure` flag** — cookies must have `secure: true` and `sameSite: 'strict'` (or `'lax'` minimum) in production
- [ ] **ValidationPipe** — must have `whitelist: true` (strips unknown properties) and `forbidNonWhitelisted: true`
- [ ] **CSRF protection** — `@fastify/csrf-protection` must be registered; verify it's not disabled for API-key routes unintentionally
- [ ] **Global guards order** — must be: `JwtAuthGuard` → `PermissionsGuard` → `ThrottlerGuard`

### 2.2 — JWT strategy

- [ ] **Algorithm pinned** — never use `algorithms: ['HS256', 'RS256']` together; pin one via env `JWT_ALGORITHM`
- [ ] **Expiration validated** — `verify()` must check `exp` claim; never use `ignoreExpiration: true` outside of refresh strategy
- [ ] **Token extraction sources** — cookie takes priority over header; both sources must reject malformed tokens immediately, not silently
- [ ] **Session cross-check** — every validated token must verify `userId + sessionId + agencyId` match the Redis session
- [ ] **No sensitive data in payload** — JWT payload must NOT contain passwords, full PII, or raw API keys; only IDs and role flags
- [ ] **Dual-tenant routing** — `decoded.isPlatformUser` flag must be validated against the correct secret, not just decoded without verification first

### 2.3 — Guards

- [ ] **`@IsPublic()` bypass scope** — public endpoints must be explicitly listed; default must be authenticated
- [ ] **`canActivate` returns boolean** — never throw untyped errors inside guards; use `UnauthorizedException` or `ForbiddenException` only
- [ ] **Impersonation restrictions** — DELETE actions must be blocked during impersonation (check `AbilityFactory`)
- [ ] **API key timing-safe comparison** — API key comparison must use `crypto.timingSafeEqual()`; plaintext `===` is vulnerable to timing attacks:
  ```typescript
  // BAD
  if (apiKey === storedKey) { ... }

  // GOOD
  const a = Buffer.from(apiKey);
  const b = Buffer.from(storedKey);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
    throw new UnauthorizedException();
  }
  ```
- [ ] **PermissionsGuard requires JwtAuthGuard first** — never register PermissionsGuard without JwtAuthGuard ahead of it

### 2.4 — Token generation & refresh

- [ ] **Short-lived access tokens** — access token TTL should be ≤ 15 minutes
- [ ] **Refresh token rotation** — each use of refresh token must issue a new refresh token and invalidate the old one
- [ ] **Refresh token hash** — stored hash must use PBKDF2/bcrypt/argon2; never store raw refresh token
- [ ] **Device binding** — refresh token session should record IP + user agent and warn on mismatch
- [ ] **JTI claim** — consider adding `jti` (JWT ID) to enable per-token revocation without invalidating the full session
- [ ] **`iat` claim present** — tokens must include `iat` for audit and replay detection

### 2.5 — WebSocket auth

- [ ] **Token from `handshake.auth`** — prefer `socket.handshake.auth.token`; avoid falling back to query params (logged by proxies)
- [ ] **Validate on connection, not per-message** — validate JWT in `WsGuard.canActivate`, not inside event handlers
- [ ] **Reject unauthenticated connections immediately** — `socket.disconnect(true)` if token invalid; do not let connection linger

### 2.6 — Webhook guard

- [ ] **HMAC with timing-safe comparison** — must use `crypto.timingSafeEqual()` for signature comparison
- [ ] **Reject replay attacks** — webhook events should include a timestamp; reject events older than 5 minutes
- [ ] **Per-provider secrets** — Shopify and WooCommerce must use separate secrets

### 2.7 — Error leakage

- [ ] **No stack traces in responses** — `app.useGlobalFilters()` must strip stack traces in production; `NODE_ENV=production` check
- [ ] **Generic auth error messages** — `"Invalid credentials"` not `"User not found"` or `"Wrong password"` (user enumeration)
- [ ] **gRPC errors not forwarded raw** — `RpcToHttpInterceptor` must map all errors; uncaught gRPC errors must not expose internal details

---

## STEP 3 — Severity classification

| Severity | Criteria | Example |
|----------|----------|---------|
| **CRITICAL** | Exploitable without auth, data exposure, auth bypass | `origin: true` CORS, plaintext API key comparison |
| **HIGH** | Exploitable with valid session, privilege escalation | Missing Helmet, algorithm confusion attack, no token rotation |
| **MEDIUM** | Increases attack surface, weakens defense-in-depth | Missing `jti`, no device binding warning, long-lived access tokens |
| **LOW** | Best practice gap, no direct exploit path | Missing `iat` claim, audit logging gaps |

---

## STEP 4 — Anti-patterns to flag

| Anti-pattern | Issue | Fix |
|---|---|---|
| `origin: true` in CORS | Any origin can make credentialed requests | Whitelist `ALLOWED_ORIGINS` env |
| No `@fastify/helmet` | Missing security headers (CSP, XFO, etc.) | Register helmet with strict config |
| `ignoreExpiration: true` on access token strategy | Tokens never expire | Remove; only valid on refresh strategy |
| `===` for API key comparison | Timing attack leaks key length/prefix | Use `crypto.timingSafeEqual()` |
| JWT payload contains email/role name strings | Increases payload size, avoid PII in tokens | Use IDs + enum codes only |
| `algorithms: ['HS256', 'RS256']` list | Algorithm confusion attack vector | Pin single algorithm from env |
| Refresh token stored unhashed | Token theft = account takeover | Hash with PBKDF2/argon2 before storage |
| Stack trace in error response | Internal path/dependency exposure | Filter in global exception filter |
| `"User not found"` auth error | User enumeration | Return generic `"Invalid credentials"` |
| Guard registered without dependency order | PermissionsGuard before JwtAuthGuard | Fix APP_GUARD provider order |
| No CSRF on cookie-based auth | Cross-site request forgery | Ensure `@fastify/csrf-protection` active |
| Public WebSocket query param token | Token logged by proxies/CDNs | Use `handshake.auth.token` only |

---

## STEP 5 — Output format

For **reviews**: list all findings grouped by severity (CRITICAL → LOW), then show corrected code for each.

For **new code**: show complete implementation with all security properties applied.

Use this format per finding:
```
[SEVERITY] File: path/to/file.ts — Line: N
Issue: <what is wrong>
Risk: <what an attacker can do>
Fix:
<corrected code snippet>
```

---

## ABSOLUTE RULES

- Never suggest `origin: true` in production CORS — it is always a vulnerability
- Always pin JWT algorithm — never accept multiple algorithms
- Refresh token must always be hashed before storage
- API key comparison must always be timing-safe
- Stack traces must never reach HTTP responses in production
- Microservices never perform HTTP auth — only the gateway does
- `@IsPublic()` must be an opt-in exception, never the default
