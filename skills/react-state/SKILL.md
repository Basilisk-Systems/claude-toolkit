---
name: react-state
description: Redux Toolkit and RTK Query patterns for React state management. Use when setting up stores, creating slices, or building API integrations.
---

# React State Management

## Store Setup

```typescript
// app/store.ts
import { configureStore } from '@reduxjs/toolkit';
import { setupListeners } from '@reduxjs/toolkit/query';
import { api } from './api';
import { authSlice } from '@/features/auth/slice';

export const store = configureStore({
  reducer: {
    [api.reducerPath]: api.reducer,
    auth: authSlice.reducer,
  },
  middleware: (getDefaultMiddleware) =>
    getDefaultMiddleware().concat(api.middleware),
});

setupListeners(store.dispatch);

export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;
```

---

## Typed Hooks

```typescript
// app/hooks.ts
import { useDispatch, useSelector, TypedUseSelectorHook } from 'react-redux';
import type { RootState, AppDispatch } from './store';

export const useAppDispatch = () => useDispatch<AppDispatch>();
export const useAppSelector: TypedUseSelectorHook<RootState> = useSelector;
```

---

## Documentation Standards

**All RTK Query endpoints and Redux slices must have JSDoc comments.**

### API File Header

```typescript
/**
 * RTK Query endpoints for user management.
 *
 * Handles CRUD operations for users with cache invalidation.
 *
 * @module store/api/usersApi
 */
```

### Endpoint Documentation

```typescript
export const usersApi = api.injectEndpoints({
  endpoints: (builder) => ({
    /**
     * Fetch all users with optional filtering.
     * Results are cached and invalidated on user mutations.
     */
    getUsers: builder.query<User[], GetUsersParams | void>({
      query: (params) => ({ url: '/users', params }),
      providesTags: ['User'],
    }),

    /**
     * Create a new user account.
     * Invalidates the user list cache on success.
     */
    createUser: builder.mutation<User, CreateUserRequest>({
      query: (body) => ({ url: '/users', method: 'POST', body }),
      invalidatesTags: ['User'],
    }),

    /**
     * Upload file to S3 using presigned URL.
     * Uses queryFn for external AWS call (not our API base URL).
     */
    uploadToS3: builder.mutation<void, UploadToS3Request>({
      queryFn: async ({ uploadUrl, file }) => {
        // Implementation...
      },
    }),
  }),
});
```

### Redux Slice Documentation

```typescript
/**
 * Authentication state management.
 *
 * Manages user session, tokens, and auth status.
 * Works with Cognito service for token refresh.
 *
 * @module store/slices/authSlice
 */

/**
 * Authentication state shape.
 */
interface AuthState {
  /** Current authenticated user or null */
  user: User | null;
  /** JWT tokens for API authentication */
  tokens: AuthTokens;
  /** Current authentication status */
  status: AuthStatus;
}

export const authSlice = createSlice({
  name: 'auth',
  initialState,
  reducers: {
    /**
     * Store credentials after successful login.
     * Called by useAuthInit after Cognito authentication.
     */
    setCredentials: (state, action: PayloadAction<SetCredentialsPayload>) => {
      // ...
    },

    /**
     * Clear all auth state on logout.
     * Also clears Cognito session via service.
     */
    logout: (state) => {
      // ...
    },
  },
});
```

### Hook Wrapper Documentation

```typescript
/**
 * Hook for managing contact form submission.
 *
 * Wraps RTK Query mutation with form-specific state management.
 * Handles loading, success, and error states.
 *
 * @returns Form state and submit handler
 *
 * @example
 * ```tsx
 * const { submit, isLoading, isSuccess, error } = useContactForm();
 *
 * const handleSubmit = (data: FormData) => {
 *   submit(data);
 * };
 * ```
 */
export function useContactForm(): UseContactFormReturn {
  // ...
}
```

---

## RTK Query Base API

```typescript
// app/api.ts
import { createApi, fetchBaseQuery } from '@reduxjs/toolkit/query/react';
import type { RootState } from './store';

export const api = createApi({
  baseQuery: fetchBaseQuery({
    baseUrl: import.meta.env.VITE_API_URL,
    prepareHeaders: (headers, { getState }) => {
      const token = (getState() as RootState).auth.token;
      if (token) {
        headers.set('Authorization', `Bearer ${token}`);
      }
      return headers;
    },
  }),
  tagTypes: ['User', 'Post', 'Document'],
  endpoints: () => ({}),
});
```

---

## Feature API Endpoints

```typescript
// features/users/api.ts
import { api } from '@/app/api';
import type { User, CreateUserDto, UpdateUserDto } from './types';

export const usersApi = api.injectEndpoints({
  endpoints: (builder) => ({
    getUsers: builder.query<User[], void>({
      query: () => '/users',
      providesTags: (result) =>
        result
          ? [...result.map(({ id }) => ({ type: 'User' as const, id })), 'User']
          : ['User'],
    }),

    getUser: builder.query<User, string>({
      query: (id) => `/users/${id}`,
      providesTags: (_result, _error, id) => [{ type: 'User', id }],
    }),

    createUser: builder.mutation<User, CreateUserDto>({
      query: (body) => ({
        url: '/users',
        method: 'POST',
        body,
      }),
      invalidatesTags: ['User'],
    }),

    updateUser: builder.mutation<User, { id: string; data: UpdateUserDto }>({
      query: ({ id, data }) => ({
        url: `/users/${id}`,
        method: 'PATCH',
        body: data,
      }),
      invalidatesTags: (_result, _error, { id }) => [{ type: 'User', id }],
    }),
  }),
});

export const {
  useGetUsersQuery,
  useGetUserQuery,
  useCreateUserMutation,
  useUpdateUserMutation,
} = usersApi;
```

---

## Redux Slice Pattern

```typescript
// features/auth/slice.ts
import { createSlice, PayloadAction } from '@reduxjs/toolkit';

interface AuthState {
  token: string | null;
  user: User | null;
  status: 'idle' | 'loading' | 'authenticated' | 'error';
}

const initialState: AuthState = {
  token: null,
  user: null,
  status: 'idle',
};

export const authSlice = createSlice({
  name: 'auth',
  initialState,
  reducers: {
    setCredentials: (state, action: PayloadAction<{ token: string; user: User }>) => {
      state.token = action.payload.token;
      state.user = action.payload.user;
      state.status = 'authenticated';
    },
    logout: (state) => {
      state.token = null;
      state.user = null;
      state.status = 'idle';
    },
  },
});

export const { setCredentials, logout } = authSlice.actions;
```

---

## Testing RTK Query

```typescript
import { describe, it, expect } from 'vitest';
import { renderHook, waitFor } from '@testing-library/react';
import { Provider } from 'react-redux';
import { setupServer } from 'msw/node';
import { http, HttpResponse } from 'msw';
import { store } from '@/app/store';
import { useGetUsersQuery } from './api';

const server = setupServer(
  http.get('/api/users', () => {
    return HttpResponse.json([{ id: '1', name: 'Test User' }]);
  })
);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

describe('useGetUsersQuery', () => {
  it('fetches users successfully', async () => {
    const { result } = renderHook(() => useGetUsersQuery(), {
      wrapper: ({ children }) => <Provider store={store}>{children}</Provider>,
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toHaveLength(1);
  });
});
```

---

## Component Test with Redux

```typescript
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Provider } from 'react-redux';
import { store } from '@/app/store';
import { MyComponent } from './MyComponent';

function renderWithProviders(ui: React.ReactElement) {
  return render(<Provider store={store}>{ui}</Provider>);
}

describe('MyComponent', () => {
  it('renders correctly', () => {
    renderWithProviders(<MyComponent title="Test" />);
    expect(screen.getByText('Test')).toBeInTheDocument();
  });

  it('calls onAction when clicked', async () => {
    const user = userEvent.setup();
    const onAction = vi.fn();

    renderWithProviders(<MyComponent title="Test" onAction={onAction} />);
    await user.click(screen.getByRole('button'));

    expect(onAction).toHaveBeenCalledOnce();
  });
});
```

---

## Type Organization for RTK Query

**Principle:** Business logic files export only business logic. All exported types/interfaces belong in types files.

```typescript
// lib/types.ts - ALL exported types go here
export interface User { id: string; name: string; email: string; }
export interface CreateUserRequest { name: string; email: string; password: string; }
export interface CreateUserResponse { user: User; message: string; }

// features/users/api.ts - Only exports hooks/business logic
import type { User, CreateUserRequest, CreateUserResponse } from '@/lib/types';

// Internal types (not exported) can stay local
interface ApiErrorShape {
  success: false;
  error: string;
}

export const usersApi = api.injectEndpoints({
  endpoints: (builder) => ({
    createUser: builder.mutation<CreateUserResponse, CreateUserRequest>({
      query: (body) => ({ url: '/users', method: 'POST', body }),
    }),
  }),
});

// Only export hooks - no type exports from this file
export const { useCreateUserMutation } = usersApi;
```

**Guidelines:**
- **Exported types** → Always in a types file (`lib/types.ts`, `store/types.ts`, etc.)
- **Internal types** → Can stay local if truly private (not exported)
- **Business logic files** → Export only functions, hooks, constants
- **Never** `export type` or `export interface` from API/slice/service files

---

## Multiple API Slices (Auth Separation)

```typescript
// store/api/baseApi.ts - Authenticated endpoints
export const baseApi = createApi({
  reducerPath: 'api',
  baseQuery: fetchBaseQuery({
    baseUrl: import.meta.env.VITE_API_URL,
    prepareHeaders: (headers, { getState }) => {
      const token = (getState() as RootState).auth.tokens.accessToken;
      if (token) headers.set('Authorization', `Bearer ${token}`);
      return headers;
    },
  }),
  endpoints: () => ({}),
});

// store/api/publicApi.ts - Unauthenticated endpoints
export const publicApi = createApi({
  reducerPath: 'publicApi',
  baseQuery: fetchBaseQuery({ baseUrl: import.meta.env.VITE_API_URL }),
  endpoints: (builder) => ({
    sendContactForm: builder.mutation<Response, ContactFormData>({
      query: (data) => ({ url: '/contact', method: 'POST', body: data }),
    }),
  }),
});

// Store must include both
reducer: {
  [baseApi.reducerPath]: baseApi.reducer,
  [publicApi.reducerPath]: publicApi.reducer,
},
middleware: (getDefault) => getDefault().concat(baseApi.middleware, publicApi.middleware),
```

---

## Common Gotchas

1. **Stale closures**: Always include deps in useCallback/useMemo
2. **RTK Query refetch**: Use `refetch()` or invalidate tags, not manual state
3. **TypeScript + Redux**: Always type state and action payloads
4. **skipToken**: Use to conditionally skip RTK Query calls
5. **Cache invalidation**: Design tag structure upfront
6. **Test environment URLs**: RTK Query needs absolute URLs in Node.js tests - set `VITE_API_URL` in test setup
7. **Separate API slices**: Use separate `createApi()` calls for auth vs public endpoints
