---
name: fe-component
description: Create React components for Lety 2.0 Frontend following Atomic Design — shared/ui atoms with CVA+cn()+Radix UI, feature-specific components, and composite shared components. Triggered when the user needs a new UI component.
---

You are creating a **React component** for the Lety 2.0 Frontend (Next.js 15 + Tailwind CSS 4 + Radix UI + TypeScript).

> **Priority rule**: Follow the Atomic Design hierarchy. Place components in the right layer. Use CVA for variants, `cn()` for conditional classes, and Radix UI primitives for interactive components that need accessibility.

---

## DOCUMENTATION — consult before answering if uncertain

- **Radix UI Primitives**: https://www.radix-ui.com/primitives
- **CVA (Class Variance Authority)**: https://cva.style/docs
- **Tailwind CSS v4**: https://tailwindcss.com/docs
- **Next.js Server vs Client Components**: https://nextjs.org/docs/app/building-your-application/rendering/client-components

---

## Architecture context — where to place the component

```
shared/ui/              # ATOMS — base primitives: Button, Input, Badge, Spinner
                        #   Reusable everywhere, no business logic, no API calls
shared/components/      # MOLECULES/ORGANISMS — composed reusable blocks
                        #   Used by 2+ features, may have simple shared logic
features/<f>/components/ # FEATURE-SPECIFIC — organisms for this domain only
                        #   May call feature service hooks, access feature stores
features/<f>/views/     # PAGES — full screens composed from components
```

**Decision rule:**
- Used only in one feature → `features/<feature>/components/`
- Used by 2+ features → `shared/components/`
- Pure UI primitive with variants → `shared/ui/`

---

## STEP 1 — Identify component type

Ask the user if not provided:
- **What does it do?** (display data, capture input, layout, interactive widget?)
- **Where does it live?** (shared atom, shared composite, or feature-specific?)
- **Has variants?** (size, color, state — use CVA)
- **Needs accessibility?** (dialogs, dropdowns, tooltips → use Radix UI)
- **Is it interactive?** (`'use client'` directive required)
- **Receives async data?** (server component or Suspense boundary)

---

## STEP 2 — Atom component (`shared/ui/`)

Use for: Button, Badge, Spinner, Input, Label, Avatar, Tooltip, Card shell.

```tsx
// shared/ui/badge.tsx
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/shared/utils/styles';

const badgeVariants = cva(
  'inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium transition-colors',
  {
    variants: {
      variant: {
        default: 'bg-accent-teal/10 text-accent-teal',
        success: 'bg-green-100 text-green-700',
        warning: 'bg-yellow-100 text-yellow-700',
        destructive: 'bg-red-100 text-red-700',
        outline: 'border border-neutral-200 text-neutral-700',
      },
      size: {
        sm: 'text-xs px-2 py-0.5',
        md: 'text-sm px-2.5 py-0.5',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'md',
    },
  },
);

export interface BadgeProps
  extends React.HTMLAttributes<HTMLSpanElement>,
    VariantProps<typeof badgeVariants> {}

export function Badge({ className, variant, size, ...props }: BadgeProps) {
  return (
    <span className={cn(badgeVariants({ variant, size }), className)} {...props} />
  );
}
```

---

## STEP 3 — Interactive atom with Radix UI

Use Radix for: Dropdown, Dialog/Modal, Tooltip, Select, Checkbox, Tabs, Accordion.

```tsx
// shared/ui/tooltip.tsx
'use client';

import * as TooltipPrimitive from '@radix-ui/react-tooltip';
import { cn } from '@/shared/utils/styles';

export function Tooltip({
  children,
  content,
  side = 'top',
}: {
  children: React.ReactNode;
  content: React.ReactNode;
  side?: 'top' | 'right' | 'bottom' | 'left';
}) {
  return (
    <TooltipPrimitive.Provider delayDuration={300}>
      <TooltipPrimitive.Root>
        <TooltipPrimitive.Trigger asChild>{children}</TooltipPrimitive.Trigger>
        <TooltipPrimitive.Portal>
          <TooltipPrimitive.Content
            side={side}
            className={cn(
              'z-50 rounded-md bg-neutral-900 px-3 py-1.5 text-xs text-white shadow-md',
              'animate-in fade-in-0 zoom-in-95',
            )}
          >
            {content}
            <TooltipPrimitive.Arrow className="fill-neutral-900" />
          </TooltipPrimitive.Content>
        </TooltipPrimitive.Portal>
      </TooltipPrimitive.Root>
    </TooltipPrimitive.Provider>
  );
}
```

---

## STEP 4 — Composite component (`shared/components/`)

Use for: DataTable, Pagination, SearchBar, EmptyState, ConfirmDialog.

```tsx
// shared/components/empty-state.tsx
import { cn } from '@/shared/utils/styles';

interface EmptyStateProps {
  title: string;
  description?: string;
  icon?: React.ReactNode;
  action?: React.ReactNode;
  className?: string;
}

export function EmptyState({ title, description, icon, action, className }: EmptyStateProps) {
  return (
    <div className={cn('flex flex-col items-center justify-center py-16 text-center', className)}>
      {icon && <div className="mb-4 text-neutral-400">{icon}</div>}
      <h3 className="text-base font-semibold text-neutral-900">{title}</h3>
      {description && (
        <p className="mt-1 text-sm text-neutral-500">{description}</p>
      )}
      {action && <div className="mt-6">{action}</div>}
    </div>
  );
}
```

---

## STEP 5 — Feature component (`features/<feature>/components/`)

May call service hooks and access feature stores directly.

```tsx
// features/agents/components/agent-card.tsx
'use client';

import { cn } from '@/shared/utils/styles';
import { Badge } from '@/shared/ui/badge';
import { AgentStatusEnum } from '@/features/agents/model/enums/agent-status.enum';
import type { components } from '@/shared/types/openapi';

type Agent = components['schemas']['AgentResponse'];

interface AgentCardProps {
  agent: Agent;
  onClick?: () => void;
  className?: string;
}

export function AgentCard({ agent, onClick, className }: AgentCardProps) {
  return (
    <div
      role={onClick ? 'button' : undefined}
      tabIndex={onClick ? 0 : undefined}
      onClick={onClick}
      className={cn(
        'rounded-xl border border-neutral-200 bg-white p-4 shadow-sm',
        onClick && 'cursor-pointer hover:border-accent-teal/50 transition-colors',
        className,
      )}
    >
      <div className="flex items-center justify-between">
        <span className="font-medium text-neutral-900">{agent.name}</span>
        <Badge variant={agent.status === AgentStatusEnum.ACTIVE ? 'success' : 'outline'}>
          {agent.status}
        </Badge>
      </div>
    </div>
  );
}
```

---

## STEP 6 — `cn()` utility usage

```tsx
// Always use cn() for conditional/merged classes — never template literals
import { cn } from '@/shared/utils/styles';

// ✅ Correct
<div className={cn('base-classes', isActive && 'active-class', className)} />

// ❌ Wrong
<div className={`base-classes ${isActive ? 'active-class' : ''} ${className}`} />
```

---

## ANTI-PATTERNS to flag

| Anti-pattern | Fix |
|---|---|
| Inline style objects for layout | Use Tailwind classes |
| Hardcoded color values (`text-[#123456]`) | Use design token classes (`text-accent-teal`) |
| CSS modules for new components | Use Tailwind; CSS modules only for animations/overrides |
| Feature-specific logic in `shared/ui/` | Move to `shared/components/` or `features/` |
| Radix primitive used without Portal for overlays | Always use `Portal` for Dialogs, Tooltips, Dropdowns |
| `'use client'` on every component by default | Only add when using hooks, events, or browser APIs |
| Missing `className` prop on reusable components | Always accept and merge `className` via `cn()` |
| Non-accessible interactive divs | Use `role`, `tabIndex`, `onKeyDown`, or a semantic element |

## ABSOLUTE RULES

- Use `cn()` from `@/shared/utils/styles` for all conditional class merging
- Use CVA for any component with 2+ visual variants
- Use Radix UI for dialogs, dropdowns, tooltips, selects — never build from scratch
- Only add `'use client'` when the component uses hooks, browser events, or browser APIs
- Accept `className` prop on every reusable component and merge it with `cn()`
- Use OpenAPI types from `@/shared/types/openapi` for domain shapes — never redefine them
