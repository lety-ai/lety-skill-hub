---
name: fe-zod-form
description: Generate Zod schemas and react-hook-form setup for Lety 2.0 Frontend. Handles single forms and multi-step wizards with partial step validation. Triggered when the user needs to create or fix a form with validation.
---

You are generating a **form with Zod validation** for the Lety 2.0 Frontend (react-hook-form v7 + Zod v3 + TypeScript).

> **Priority rule**: Always follow react-hook-form and Zod official docs. Schemas go in `logic/` with `.schema.ts` suffix. Always use `standardSchemaResolver` (not `zodResolver`) — it is the project's configured resolver.

---

## DOCUMENTATION — consult before answering if uncertain

- **react-hook-form**: https://react-hook-form.com/docs
- **Zod**: https://zod.dev
- **Zod with react-hook-form**: https://react-hook-form.com/docs/useform#resolver

---

## Architecture context

```
features/<feature>/logic/
  <feature>-create.schema.ts    # Zod schema + inferred type + partial step schemas
  <feature>-update.schema.ts    # Separate schema for edit forms

features/<feature>/components/forms/
  <feature>-form.tsx            # Form component using useForm + FormProvider
  steps/                        # Multi-step form steps (if applicable)
    basic-info.tsx
    advanced.tsx
```

---

## STEP 1 — Identify the form type

Ask the user if not provided:
- **Single form or multi-step wizard?**
- **Create or edit?** (edit forms pre-populate with `defaultValues`)
- **Any file uploads?** (needs `z.instanceof(File)`)
- **Any cross-field validation?** (needs `.refine()` or `.superRefine()`)
- **Form fields** — get the list with types

---

## STEP 2 — Generate Zod schema

### Single-step schema (`logic/<feature>-create.schema.ts`)
```typescript
import { z } from 'zod';

export const Create<Feature>Schema = z.object({
  name: z.string().min(1, 'Name is required').max(100),
  description: z.string().min(10, 'Description must be at least 10 characters').optional(),
  status: z.nativeEnum(<Feature>StatusEnum),
  count: z.preprocess(
    (val) => (val === '' ? undefined : Number(val)),
    z.number().min(0).optional(),
  ),
  tags: z.array(z.string()).min(1, 'At least one tag is required'),
  avatar: z.instanceof(File).optional(),
});

export type Create<Feature>FormValues = z.infer<typeof Create<Feature>Schema>;
```

### Multi-step schema with partial exports
```typescript
import { z } from 'zod';

// Step schemas — exported individually for per-step validation
export const BasicInfoSchema = z.object({
  name: z.string().min(1, 'Name is required'),
  email: z.string().email('Invalid email address'),
});

export const ConfigSchema = z.object({
  maxTokens: z.preprocess(
    (val) => Number(val),
    z.number().min(1).max(4096),
  ),
  temperature: z.preprocess(
    (val) => Number(val),
    z.number().min(0).max(2),
  ),
});

export const KnowledgeSchema = z.object({
  knowledgeText: z.string().optional(),
  knowledgeFiles: z.array(z.instanceof(File)).optional(),
});

// Full schema — merge of all steps
export const Create<Feature>Schema = BasicInfoSchema
  .merge(ConfigSchema)
  .merge(KnowledgeSchema)
  .refine(
    (data) => data.knowledgeText || (data.knowledgeFiles && data.knowledgeFiles.length > 0),
    {
      message: 'Provide either text knowledge or at least one file',
      path: ['knowledgeText'],
    },
  );

export type Create<Feature>FormValues = z.infer<typeof Create<Feature>Schema>;
```

### Common Zod patterns
```typescript
// Required string
z.string().min(1, 'Field is required')

// Optional string (empty string → undefined)
z.string().optional().or(z.literal(''))

// Number from input (inputs return strings)
z.preprocess((val) => Number(val), z.number().min(0))

// UUID
z.string().uuid('Invalid ID format')

// Enum
z.nativeEnum(MyEnum)

// URL
z.string().url('Invalid URL').optional()

// Phone number
z.string().regex(/^\+?[1-9]\d{1,14}$/, 'Invalid phone number').optional()

// File upload
z.instanceof(File, { message: 'Please select a file' }).optional()

// Array with min items
z.array(z.string().uuid()).min(1, 'Select at least one item')

// Cross-field validation
.refine((data) => data.password === data.confirmPassword, {
  message: 'Passwords do not match',
  path: ['confirmPassword'],
})
```

---

## STEP 3 — Generate the form component

### Single-step form
```tsx
'use client';

import { useForm, FormProvider } from 'react-hook-form';
import { standardSchemaResolver } from '@hookform/resolvers/standard-schema';
import { Create<Feature>Schema, type Create<Feature>FormValues } from '@/features/<feature>/logic/<feature>-create.schema';
import { useCreate<Feature> } from '@/features/<feature>/services/create-<feature>';

export function Create<Feature>Form() {
  const { mutate, isPending } = useCreate<Feature>();

  const methods = useForm<Create<Feature>FormValues>({
    resolver: standardSchemaResolver(Create<Feature>Schema),
    mode: 'onChange',
    defaultValues: {
      name: '',
      description: '',
    },
  });

  const { handleSubmit, formState: { errors } } = methods;

  const onSubmit = (data: Create<Feature>FormValues) => {
    mutate(data, {
      onSuccess: () => {
        methods.reset();
        // handle success (close modal, show toast, navigate, etc.)
      },
    });
  };

  return (
    <FormProvider {...methods}>
      <form onSubmit={handleSubmit(onSubmit)} noValidate>
        {/* form fields */}
        <button type="submit" disabled={isPending}>
          {isPending ? 'Saving...' : 'Create'}
        </button>
      </form>
    </FormProvider>
  );
}
```

### Multi-step form with wizard store
```tsx
'use client';

import { useForm, FormProvider } from 'react-hook-form';
import { standardSchemaResolver } from '@hookform/resolvers/standard-schema';
import {
  Create<Feature>Schema,
  BasicInfoSchema,
  ConfigSchema,
  type Create<Feature>FormValues,
} from '@/features/<feature>/logic/<feature>-create.schema';
import { use<Feature>WizardStore } from '@/features/<feature>/logic/store/<feature>-wizard-store';

const STEP_SCHEMAS = [BasicInfoSchema, ConfigSchema];

export function Create<Feature>Wizard() {
  const { currentStep, nextStep, prevStep } = use<Feature>WizardStore();
  const { mutate, isPending } = useCreate<Feature>();

  const methods = useForm<Create<Feature>FormValues>({
    resolver: standardSchemaResolver(Create<Feature>Schema),
    mode: 'onChange',
  });

  const validateStep = async () => {
    const stepFields = Object.keys(STEP_SCHEMAS[currentStep].shape) as (keyof Create<Feature>FormValues)[];
    return methods.trigger(stepFields);
  };

  const handleNext = async () => {
    const valid = await validateStep();
    if (valid) nextStep();
  };

  const onSubmit = (data: Create<Feature>FormValues) => {
    mutate(data);
  };

  return (
    <FormProvider {...methods}>
      <form onSubmit={methods.handleSubmit(onSubmit)}>
        {currentStep === 0 && <BasicInfoStep />}
        {currentStep === 1 && <ConfigStep />}
      </form>
    </FormProvider>
  );
}
```

### Reading field values inside a step (use `useFormContext`)
```tsx
'use client';

import { useFormContext } from 'react-hook-form';
import type { Create<Feature>FormValues } from '@/features/<feature>/logic/<feature>-create.schema';

export function BasicInfoStep() {
  const { register, formState: { errors } } = useFormContext<Create<Feature>FormValues>();

  return (
    <div>
      <input {...register('name')} />
      {errors.name && <span>{errors.name.message}</span>}
    </div>
  );
}
```

---

## STEP 4 — Edit form (pre-populated)

```tsx
const methods = useForm<Update<Feature>FormValues>({
  resolver: standardSchemaResolver(Update<Feature>Schema),
  defaultValues: {
    name: existing<Feature>.name,
    description: existing<Feature>.description ?? '',
  },
});

// Re-populate when data loads asynchronously
useEffect(() => {
  if (existing<Feature>) {
    methods.reset({
      name: existing<Feature>.name,
      description: existing<Feature>.description ?? '',
    });
  }
}, [existing<Feature>]);
```

---

## ANTI-PATTERNS to flag

| Anti-pattern | Fix |
|---|---|
| `zodResolver` from `@hookform/resolvers/zod` | Use `standardSchemaResolver` from `@hookform/resolvers/standard-schema` |
| Zod schema defined inside the component | Move to `logic/<name>.schema.ts` |
| `z.any()` for typed fields | Use the proper Zod type |
| Validation only on submit (`mode: 'onSubmit'`) | Use `mode: 'onChange'` for real-time feedback |
| `useForm` without `defaultValues` | Always provide `defaultValues` to avoid uncontrolled→controlled warnings |
| No `noValidate` on form tag | Add `noValidate` to prevent browser native validation conflicting with Zod |
| `getValues()` for cross-step validation | Use `trigger(fields)` to validate specific fields per step |

## ABSOLUTE RULES

- Schemas always live in `features/<feature>/logic/` with `.schema.ts` suffix
- Always use `standardSchemaResolver` — never `zodResolver`
- Always export the inferred type: `export type XFormValues = z.infer<typeof XSchema>`
- Always export step schemas individually when using multi-step forms
- `FormProvider` wraps the `<form>` element — child components use `useFormContext`
- Never validate the full schema on intermediate steps — use `trigger(stepFields)`
