---
name: react-core
description: React core patterns with TypeScript, Vite, React Router, TailwindCSS, and ShadCN. Use when creating components, setting up routing, or styling.
---

# React Core Patterns

## Tech Stack
- **Build**: Vite + TypeScript (strict mode)
- **Routing**: React Router v6+
- **Styling**: TailwindCSS + ShadCN/ui
- **Testing**: Vitest + React Testing Library

---

## Project Structure

```
src/
├── app/                    # App-level setup
│   ├── store.ts           # Redux store
│   ├── hooks.ts           # Typed hooks
│   └── api.ts             # RTK Query base
├── components/
│   ├── ui/               # ShadCN components
│   └── common/           # Custom shared
├── features/             # Feature modules
│   └── [feature]/
│       ├── components/
│       ├── hooks/
│       ├── api.ts
│       └── slice.ts
├── pages/                # Route pages
├── routes/               # Route config
└── lib/                  # Utilities
```

---

## TypeScript Standards

```typescript
// Use interface for extendable objects
interface User {
  id: string;
  email: string;
  name: string;
}

// Use type for unions, intersections
type Status = 'idle' | 'loading' | 'success' | 'error';
type UserWithRole = User & { role: Role };

// Prefer unknown over any
function parseJSON(json: string): unknown {
  return JSON.parse(json);
}

// const assertions for literals
const ROUTES = {
  HOME: '/',
  DASHBOARD: '/dashboard',
} as const;

// Derive types from constants
type RouteKey = keyof typeof ROUTES;

// Component props pattern
interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'danger';
  isLoading?: boolean;
}
```

---

## Documentation Standards

**All exported code must have JSDoc comments.** This includes components, hooks, utilities, and types.

### Module Header

Every file should start with a module docstring:

```typescript
/**
 * User profile component with avatar and settings.
 *
 * Displays user information and provides quick access to
 * account settings and logout functionality.
 *
 * @module components/UserProfile
 */
```

### Component Documentation

```typescript
/**
 * Displays a file upload dropzone with drag-and-drop support.
 *
 * Features:
 * - Drag and drop file selection
 * - Click to browse files
 * - File type validation
 * - Preview for images
 *
 * @example
 * ```tsx
 * <FileUpload
 *   onFileSelect={(file) => handleFile(file)}
 *   accept={{ 'image/*': ['.png', '.jpg'] }}
 *   maxSize={5 * 1024 * 1024}
 * />
 * ```
 */
export function FileUpload({ onFileSelect, accept, maxSize }: FileUploadProps) {
  // ...
}
```

### Hook Documentation

```typescript
/**
 * Hook for managing form submission state and validation.
 *
 * Handles loading states, error collection, and success callbacks.
 * Integrates with RTK Query mutations for API calls.
 *
 * @param options - Configuration options
 * @param options.onSuccess - Callback fired after successful submission
 * @param options.onError - Callback fired on validation or API error
 * @returns Form state and handlers
 *
 * @example
 * ```tsx
 * const { submit, isLoading, errors } = useFormSubmit({
 *   onSuccess: () => navigate('/success'),
 * });
 * ```
 */
export function useFormSubmit(options: UseFormSubmitOptions): UseFormSubmitReturn {
  // ...
}
```

### Interface/Type Documentation

```typescript
/**
 * Configuration options for the useAuth hook.
 */
interface UseAuthOptions {
  /** Redirect path after successful login */
  redirectTo?: string;
  /** Whether to persist session across browser restarts */
  persistSession?: boolean;
}

/**
 * User authentication status.
 */
type AuthStatus = 'idle' | 'loading' | 'authenticated' | 'unauthenticated';
```

### Inline Comments

Use inline comments for non-obvious logic:

```typescript
function calculateDiscount(price: number, quantity: number): number {
  // Bulk discount: 10% off for 10+ items, 20% off for 50+
  const discountRate = quantity >= 50 ? 0.2 : quantity >= 10 ? 0.1 : 0;

  // Round to 2 decimal places to avoid floating point issues
  return Math.round(price * quantity * (1 - discountRate) * 100) / 100;
}
```

### Documentation Checklist

- [ ] Module docstring at top of file (`@module`)
- [ ] JSDoc for all exported functions, components, and hooks
- [ ] `@param` tags for function parameters
- [ ] `@returns` tag describing return value
- [ ] `@example` with usage code block
- [ ] Inline comments for complex logic
- [ ] Interface properties have `/** description */` comments

---

## Component Pattern

```typescript
/**
 * Reusable card component with action button.
 *
 * Displays a title and optional children with a configurable action.
 *
 * @module components/MyComponent
 */

import { memo, useCallback, useMemo } from 'react';
import { cn } from '@/lib/utils';

/**
 * Props for MyComponent.
 */
interface MyComponentProps {
  /** Card title text */
  title: string;
  /** Callback fired when action button is clicked */
  onAction?: () => void;
  /** Additional CSS classes */
  className?: string;
  /** Content to render inside the card */
  children?: React.ReactNode;
}

/**
 * Card component with title and action button.
 *
 * @example
 * ```tsx
 * <MyComponent title="Settings" onAction={() => openSettings()}>
 *   <p>Configure your preferences</p>
 * </MyComponent>
 * ```
 */
export const MyComponent = memo(function MyComponent({
  title,
  onAction,
  className,
  children,
}: MyComponentProps) {
  /** Handle action button click with optional callback */
  const handleClick = useCallback(() => {
    onAction?.();
  }, [onAction]);

  /** Transform title to uppercase for display */
  const processedData = useMemo(() => {
    return title.toUpperCase();
  }, [title]);

  return (
    <div className={cn('base-styles', className)}>
      <h2>{processedData}</h2>
      <button onClick={handleClick}>Action</button>
      {children}
    </div>
  );
});
```

---

## React Router v6

```typescript
import { createBrowserRouter, RouterProvider } from 'react-router-dom';
import { ProtectedRoute } from './ProtectedRoute';

const router = createBrowserRouter([
  {
    path: '/',
    element: <RootLayout />,
    errorElement: <ErrorPage />,
    children: [
      { index: true, element: <HomePage /> },
      { path: 'about', element: <AboutPage /> },
      {
        path: 'dashboard',
        element: <ProtectedRoute><DashboardLayout /></ProtectedRoute>,
        children: [
          { index: true, element: <DashboardHome /> },
          { path: 'settings', element: <Settings /> },
        ],
      },
    ],
  },
]);

export function AppRouter() {
  return <RouterProvider router={router} />;
}
```

### Protected Route

```typescript
import { Navigate, useLocation } from 'react-router-dom';
import { useAppSelector } from '@/app/hooks';

export function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { status } = useAppSelector((state) => state.auth);
  const location = useLocation();

  if (status !== 'authenticated') {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  return <>{children}</>;
}
```

---

## TailwindCSS + ShadCN

### cn() Utility

```typescript
import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

### Component Variants with cva

```typescript
import { cva, type VariantProps } from 'class-variance-authority';

const buttonVariants = cva(
  'inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors focus-visible:outline-none disabled:opacity-50',
  {
    variants: {
      variant: {
        default: 'bg-primary text-primary-foreground hover:bg-primary/90',
        destructive: 'bg-destructive text-destructive-foreground',
        outline: 'border border-input bg-background hover:bg-accent',
        ghost: 'hover:bg-accent hover:text-accent-foreground',
      },
      size: {
        default: 'h-10 px-4 py-2',
        sm: 'h-9 rounded-md px-3',
        lg: 'h-11 rounded-md px-8',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  }
);

interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {}

export function Button({ className, variant, size, ...props }: ButtonProps) {
  return <button className={cn(buttonVariants({ variant, size, className }))} {...props} />;
}
```

---

## Error Boundary

```typescript
import { Component, ErrorInfo, ReactNode } from 'react';

interface Props {
  children: ReactNode;
  fallback?: ReactNode;
}

interface State {
  hasError: boolean;
}

export class ErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false };

  static getDerivedStateFromError(): State {
    return { hasError: true };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('Error caught:', error, info);
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback ?? <div>Something went wrong</div>;
    }
    return this.props.children;
  }
}
```

---

## Performance Checklist

- [ ] Use `memo()` for components with object/function props
- [ ] Use `useCallback()` for callbacks to memoized children
- [ ] Use `useMemo()` for expensive computations
- [ ] Lazy load routes with `React.lazy()` + `Suspense`
- [ ] Avoid inline object/array in JSX props
