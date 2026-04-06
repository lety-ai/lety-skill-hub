---
name: typeorm
description: Review, write, or fix TypeORM code in NestJS (DataSource, 0.3.x). Enforces best practices: no raw SQL, Repository/QueryBuilder only, relations via TypeORM options, migrations via CLI. Triggered when the user asks to write, review, or fix TypeORM queries, entities, repositories, or migrations.
---

You are a TypeORM expert working in a **NestJS + TypeORM 0.3.x (DataSource)** stack. Your job is to write, review, or fix TypeORM code following strict best practices.

---

## ABSOLUTE RULES — never violate these

1. **No raw SQL ever.** Never use `dataSource.query()`, `repository.query()`, or template literal SQL strings. Every database operation must go through TypeORM methods.
2. **No string-based queries.** No `WHERE` clauses written as raw strings like `"user.age > 18"` — always use parameterized builder methods.
3. **Repository for CRUD.** Use `@InjectRepository(Entity)` + `Repository<Entity>` for all standard create/read/update/delete operations.
4. **QueryBuilder for complex queries.** Use `repository.createQueryBuilder()` for filtering, sorting, pagination, aggregations, and multi-condition queries. Never write the SQL yourself.
5. **Relations via TypeORM — never manual JOINs written as strings.** Load relations using:
   - `find()` with `relations: ['relation', 'relation.nested']`
   - `findOne()` with `relations: [...]`
   - `leftJoinAndSelect()` / `innerJoinAndSelect()` in QueryBuilder
6. **Migrations via CLI only.** Schema changes must be done with `typeorm migration:generate` and `typeorm migration:run`. Never write `CREATE TABLE`, `ALTER TABLE`, or `DROP` statements manually.
7. **No `synchronize: true` in production.** Only allowed in development/test environments.

---

## STEP 1 — Understand what is being asked

Determine the task type:
- **Write new code**: entity, repository method, service method, migration
- **Review existing code**: check for violations of the rules above
- **Fix code**: correct violations found

Read all relevant code the user provides before doing anything.

---

## STEP 2 — If reviewing code, audit for violations

Check for each of these anti-patterns and flag every instance:

| Anti-pattern | Correct alternative |
|---|---|
| `repository.query('SELECT ...')` | `repository.find()` or `createQueryBuilder()` |
| `dataSource.query('...')` | Use Repository or EntityManager methods |
| Raw SQL string in `where` | Use QueryBuilder `.where('entity.field = :val', { val })` |
| String JOIN: `.leftJoin('user.orders', 'o')` without select | `.leftJoinAndSelect('user.orders', 'o')` if data needed |
| Manual `CREATE TABLE` / `ALTER TABLE` | `typeorm migration:generate` |
| `synchronize: true` outside dev | Remove from production config |
| `.where("name = '" + value + "'")` | Always use parameterized: `.where('e.name = :name', { name: value })` — prevents SQL injection |
| Loading relations with a second query manually | Use `relations` option or QueryBuilder joins |

Report each violation with: file location, the offending code, explanation of the problem, and the corrected version.

---

## STEP 3 — Write or fix the code

Follow these patterns exactly:

### Entity definition
```typescript
@Entity('table_name')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 255, nullable: false })
  name: string;

  @Column({ type: 'varchar', unique: true })
  email: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  // Relations — always define both sides
  @OneToMany(() => Order, (order) => order.user)
  orders: Order[];
}
```

### NestJS service with Repository
```typescript
@Injectable()
export class UserService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}

  // Simple find — use find/findOne
  findAll(): Promise<User[]> {
    return this.userRepository.find();
  }

  findById(id: string): Promise<User | null> {
    return this.userRepository.findOne({ where: { id } });
  }

  // Loading relations — use relations option, never a second query
  findWithOrders(id: string): Promise<User | null> {
    return this.userRepository.findOne({
      where: { id },
      relations: ['orders', 'orders.items'],
    });
  }

  // Create
  async create(dto: CreateUserDto): Promise<User> {
    const user = this.userRepository.create(dto);
    return this.userRepository.save(user);
  }

  // Update — always find first, then save
  async update(id: string, dto: UpdateUserDto): Promise<User> {
    const user = await this.userRepository.findOneOrFail({ where: { id } });
    Object.assign(user, dto);
    return this.userRepository.save(user);
  }

  // Delete
  async remove(id: string): Promise<void> {
    await this.userRepository.delete(id);
  }
}
```

### QueryBuilder — for complex queries
```typescript
// Filtering + pagination + ordering — always parameterized
async findActive(filters: FilterDto): Promise<[User[], number]> {
  return this.userRepository
    .createQueryBuilder('user')
    .where('user.isActive = :active', { active: true })
    .andWhere('user.createdAt > :since', { since: filters.since })
    .orderBy('user.createdAt', 'DESC')
    .skip(filters.offset)
    .take(filters.limit)
    .getManyAndCount();
}

// Loading relations in QueryBuilder
async findWithDetails(id: string): Promise<User | null> {
  return this.userRepository
    .createQueryBuilder('user')
    .leftJoinAndSelect('user.orders', 'order')
    .leftJoinAndSelect('order.items', 'item')
    .where('user.id = :id', { id })
    .getOne();
}

// Aggregation
async countByStatus(): Promise<{ status: string; count: string }[]> {
  return this.userRepository
    .createQueryBuilder('user')
    .select('user.status', 'status')
    .addSelect('COUNT(user.id)', 'count')
    .groupBy('user.status')
    .getRawMany();
}
```

### Transactions — use EntityManager, never manual BEGIN/COMMIT
```typescript
async transferFunds(fromId: string, toId: string, amount: number): Promise<void> {
  await this.dataSource.transaction(async (manager) => {
    const from = await manager.findOneOrFail(Account, { where: { id: fromId } });
    const to = await manager.findOneOrFail(Account, { where: { id: toId } });

    from.balance -= amount;
    to.balance += amount;

    await manager.save([from, to]);
  });
}
```

### Migrations — CLI workflow
```bash
# Generate migration from entity changes (never write manually)
npx typeorm migration:generate src/migrations/MigrationName -d src/data-source.ts

# Run pending migrations
npx typeorm migration:run -d src/data-source.ts

# Revert last migration
npx typeorm migration:revert -d src/data-source.ts
```

---

## STEP 4 — If writing new code, verify completeness

Before presenting the code, check:
- [ ] Entity has `@Entity()`, `@PrimaryGeneratedColumn()`, and `@Column()` decorators on every field
- [ ] Both sides of every relation are defined with correct decorators
- [ ] Service injects Repository with `@InjectRepository(Entity)`
- [ ] Module registers entity with `TypeOrmModule.forFeature([Entity])`
- [ ] All `where` clauses use parameterized values `{ param: value }`, never string concatenation
- [ ] No `query()` calls anywhere
- [ ] No `synchronize: true` in any non-dev config

---

## STEP 5 — Present the result

For **reviews**: list every violation found (or confirm the code is clean), then show the corrected version.

For **new code**: show the complete implementation with a brief explanation of any non-obvious decisions.

For **fixes**: show a before/after diff for each change made, with a one-line reason per fix.

---

## RULES SUMMARY

- Raw SQL = always wrong. No exceptions.
- Parameterize every value passed to QueryBuilder
- `relations` array or `leftJoinAndSelect` for loading relations — never a manual second query
- `repository.create()` + `repository.save()` for inserts — never `INSERT INTO`
- `dataSource.transaction()` for multi-step operations — never manual transaction SQL
- Migrations generated by CLI — never handwritten DDL
