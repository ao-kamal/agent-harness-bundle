---
name: react-component-generator
display_name: React Component Generator
description: >-
  Generate production-ready React components with TypeScript, accessibility,
  and testing built-in. Creates consistent, well-structured components following
  modern React 19 patterns.
triggers:
  - create component
  - new component
  - generate component
  - react component
  - component scaffold
version: 2.0.0
author: jeffrey
category: code-generation
tags:
  - ctx-react
  - ctx-typescript
  - tool-testing-library
  - workflow-scaffolding
difficulty: intermediate
---

# React Component Generator

Generate production-ready React components that follow modern best practices: TypeScript, functional components, prop typing with defaults, accessibility baked in, and unit tests included.

## Prerequisites

- React 19+ project with TypeScript
- Testing Library + Vitest (or Jest) for tests
- Optional: Storybook for stories

## Output Structure

When you generate a component (e.g., `UserProfile`), this skill creates:

```
src/components/UserProfile/
├── UserProfile.tsx          # Main component
├── UserProfile.test.tsx     # Unit tests
├── UserProfile.stories.tsx  # Storybook stories (if project uses Storybook)
├── index.ts                 # Barrel export
└── types.ts                 # TypeScript interfaces
```

---

## Generation Checklist

When generating a component, ensure ALL of the following:

### TypeScript Requirements

- [ ] Props interface defined in `types.ts`
- [ ] Props extend `HTMLAttributes<HTMLElement>` where appropriate
- [ ] Optional props have defaults
- [ ] Export types for consumers

### Component Requirements

- [ ] Functional component (not class)
- [ ] Use `memo()` when component is pure (no internal state)
- [ ] Support `className` prop with `cn()` helper
- [ ] Support `ref` forwarding with `forwardRef`
- [ ] Use proper HTML semantics

### Accessibility Requirements

- [ ] Proper heading hierarchy
- [ ] Alt text for images
- [ ] Aria labels for interactive elements
- [ ] Keyboard navigation for interactive elements
- [ ] Focus management where needed

### Testing Requirements

- [ ] Test renders without crashing
- [ ] Test renders with required props
- [ ] Test interactive behaviors (clicks, etc.)
- [ ] Test accessibility attributes
- [ ] Use Testing Library best practices (query by role/label)

---

## Component Template

Use this template for generating components:

```tsx
// src/components/{ComponentName}/{ComponentName}.tsx
import { forwardRef, memo } from 'react'
import { cn } from '@/lib/utils'
import type { {ComponentName}Props } from './types'

/**
 * {ComponentDescription}
 */
export const {ComponentName} = memo(forwardRef<HTMLDivElement, {ComponentName}Props>(
  function {ComponentName}({ className, ...props }, ref) {
    return (
      <div
        ref={ref}
        className={cn(
          // Base styles
          'relative',
          className
        )}
        {...props}
      >
        {/* Component content */}
      </div>
    )
  }
))
```

---

## Types Template

```typescript
// src/components/{ComponentName}/types.ts
import type { HTMLAttributes } from 'react'

/**
 * Props for {ComponentName}
 */
export interface {ComponentName}Props extends HTMLAttributes<HTMLDivElement> {
  /**
   * Variant style
   * @default 'default'
   */
  variant?: 'default' | 'primary' | 'secondary'

  /**
   * Size variant
   * @default 'md'
   */
  size?: 'sm' | 'md' | 'lg'
}
```

---

## Test Template

```tsx
// src/components/{ComponentName}/{ComponentName}.test.tsx
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, it, expect } from 'vitest'
import { {ComponentName} } from './{ComponentName}'

describe('{ComponentName}', () => {
  it('renders without crashing', () => {
    render(<{ComponentName} />)
  })

  it('applies custom className', () => {
    render(<{ComponentName} className="custom-class" data-testid="component" />)
    expect(screen.getByTestId('component')).toHaveClass('custom-class')
  })

  it('forwards ref', () => {
    const ref = { current: null }
    render(<{ComponentName} ref={ref} />)
    expect(ref.current).toBeInstanceOf(HTMLElement)
  })

  it('applies variant styles', () => {
    render(<{ComponentName} variant="primary" data-testid="component" />)
    // Assert variant-specific classes or styles
  })
})
```

---

## Index Template

```typescript
// src/components/{ComponentName}/index.ts
export { {ComponentName} } from './{ComponentName}'
export type { {ComponentName}Props } from './types'
```

---

## Storybook Template (Optional)

```tsx
// src/components/{ComponentName}/{ComponentName}.stories.tsx
import type { Meta, StoryObj } from '@storybook/react'
import { {ComponentName} } from './{ComponentName}'

const meta = {
  title: 'Components/{ComponentName}',
  component: {ComponentName},
  parameters: {
    layout: 'centered',
  },
  tags: ['autodocs'],
  argTypes: {
    variant: {
      control: 'select',
      options: ['default', 'primary', 'secondary'],
    },
    size: {
      control: 'select',
      options: ['sm', 'md', 'lg'],
    },
  },
} satisfies Meta<typeof {ComponentName}>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  args: {},
}

export const Primary: Story = {
  args: {
    variant: 'primary',
  },
}
```

---

## Common Patterns

### Card Component

```tsx
export interface CardProps extends HTMLAttributes<HTMLDivElement> {
  title: string;
  description?: string;
  footer?: ReactNode;
}

export const Card = memo(
  forwardRef<HTMLDivElement, CardProps>(function Card(
    { title, description, footer, className, children, ...props },
    ref
  ) {
    return (
      <article ref={ref} className={cn("rounded-lg border bg-card p-6", className)} {...props}>
        <header>
          <h3 className="text-lg font-semibold">{title}</h3>
          {description && <p className="text-sm text-muted-foreground">{description}</p>}
        </header>
        <div className="mt-4">{children}</div>
        {footer && <footer className="mt-4 border-t pt-4">{footer}</footer>}
      </article>
    );
  })
);
```

### Button Component

```tsx
export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: "default" | "primary" | "outline" | "ghost" | "destructive";
  size?: "sm" | "md" | "lg";
  loading?: boolean;
}

export const Button = memo(
  forwardRef<HTMLButtonElement, ButtonProps>(function Button(
    { variant = "default", size = "md", loading, disabled, className, children, ...props },
    ref
  ) {
    return (
      <button
        ref={ref}
        disabled={disabled || loading}
        className={cn(
          "inline-flex items-center justify-center rounded-md font-medium",
          "transition-colors focus-visible:outline-none focus-visible:ring-2",
          variants[variant],
          sizes[size],
          className
        )}
        {...props}
      >
        {loading ? <Spinner className="mr-2" /> : null}
        {children}
      </button>
    );
  })
);
```

### Form Input Component

```tsx
export interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label: string;
  error?: string;
  hint?: string;
}

export const Input = forwardRef<HTMLInputElement, InputProps>(function Input(
  { label, error, hint, id, className, ...props },
  ref
) {
  const inputId = id || useId();
  const errorId = `${inputId}-error`;
  const hintId = `${inputId}-hint`;

  return (
    <div className="space-y-1">
      <label htmlFor={inputId} className="text-sm font-medium">
        {label}
      </label>
      <input
        ref={ref}
        id={inputId}
        aria-invalid={!!error}
        aria-describedby={error ? errorId : hint ? hintId : undefined}
        className={cn(
          "w-full rounded-md border px-3 py-2",
          error && "border-destructive",
          className
        )}
        {...props}
      />
      {error && (
        <p id={errorId} className="text-sm text-destructive" role="alert">
          {error}
        </p>
      )}
      {hint && !error && (
        <p id={hintId} className="text-sm text-muted-foreground">
          {hint}
        </p>
      )}
    </div>
  );
});
```

---

## Best Practices

### Do

- Use semantic HTML elements (`<article>`, `<header>`, `<nav>`, etc.)
- Support `className` for style customization
- Forward refs for parent access to DOM
- Use `memo()` for pure components
- Export types alongside components
- Write tests for key behaviors

### Don't

- Use inline styles (prefer Tailwind/CSS)
- Hardcode text (accept as props for i18n)
- Forget accessibility attributes
- Skip prop validation (use TypeScript)
- Create components without tests

---

## Troubleshooting

| Issue                            | Cause                            | Solution                             |
| -------------------------------- | -------------------------------- | ------------------------------------ |
| `memo` causes stale props        | Callback props changing          | Use `useCallback` in parent          |
| Ref is null                      | Component not using `forwardRef` | Wrap with `forwardRef`               |
| TypeScript errors on `className` | Missing HTMLAttributes           | Extend `HTMLAttributes<HTMLElement>` |
| Tests fail on query              | Wrong query method               | Use `getByRole` or `getByLabelText`  |

---

## File Naming Conventions

| File Type | Convention            | Example                   |
| --------- | --------------------- | ------------------------- |
| Component | PascalCase            | `UserProfile.tsx`         |
| Types     | Same as component     | `types.ts`                |
| Tests     | Suffix `.test.tsx`    | `UserProfile.test.tsx`    |
| Stories   | Suffix `.stories.tsx` | `UserProfile.stories.tsx` |
| Index     | Lowercase             | `index.ts`                |

---

## Integration with Project

This skill assumes your project has:

```typescript
// lib/utils.ts - cn() helper (using clsx + tailwind-merge)
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

If your project uses a different pattern, adjust the imports accordingly.
