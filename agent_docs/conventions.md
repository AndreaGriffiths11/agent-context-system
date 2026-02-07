# Code Conventions

<!-- This file is loaded only when a task involves writing or modifying code. -->
<!-- Replace this example with your project's actual conventions. -->

## Naming

- **Files:** kebab-case (`user-profile.tsx`, `api-client.ts`)
- **Components:** PascalCase (`UserProfile`, `DataTable`)
- **Functions/variables:** camelCase (`getUserById`, `isLoading`)
- **Types/interfaces:** PascalCase, no `I` prefix (`UserProfile`, not `IUserProfile`)
- **Constants:** UPPER_SNAKE for true constants (`MAX_RETRIES`), camelCase for derived values
- **Test files:** `[source-name].test.ts` inside `__tests__/` directory adjacent to source

## File Structure

- One component per file. File name matches the export name.
- Co-locate tests: `src/lib/errors.ts` → `src/lib/__tests__/errors.test.ts`
- Co-locate page-specific components: `src/app/dashboard/components/StatsCard.tsx`
- Shared components go in `src/components/` only when used by 2+ routes.

## Patterns to Follow

- **Named exports everywhere.** `export function Button()`, never `export default`. This makes renames trackable and tree-shaking reliable. See `src/components/Button.tsx`.
- **Result types for fallible operations.** Return `{ok: true, data}` or `{ok: false, error}` instead of throwing. Callers handle both paths explicitly. See `src/lib/errors.ts`.
- **Zod schemas at API boundaries.** Every route handler validates input with a Zod schema before processing. See `src/app/api/users/route.ts`.
- **Prisma helpers in `src/lib/db/`.** Don't use Prisma client directly in routes or components. Write a typed function in the db module. See `src/lib/db/users.ts`.
- **Server-first components.** Start with server components. Add `'use client'` only when you need `useState`, `useEffect`, event handlers, or browser APIs.

## Patterns to Avoid

- **No `any` types.** Use `unknown` and narrow, or define a proper type. The only exception is test mocks, and even then prefer `as unknown as Type`.
- **No inline styles.** Use Tailwind classes. Keeps styling consistent and grep-able.
- **No barrel exports (`index.ts` re-exports).** They break tree-shaking and make imports ambiguous. Import from the specific file.
- **No `console.log` in committed code.** Use the structured logger at `src/lib/logger.ts`. It includes request IDs and respects log levels.
- **No direct `fetch` calls.** Use `src/lib/api-client.ts` which handles auth headers, base URL, and error normalization.

## Examples

<!-- Point to existing code rather than pasting snippets. Code changes; pointers are cheaper to maintain. -->

- Good component pattern: see `src/components/Button.tsx` — named export, props interface, Tailwind only
- Good API route pattern: see `src/app/api/users/route.ts` — Zod validation, Result return, Prisma helper
- Good error handling: see `src/lib/errors.ts` — Result type definition and utility functions
- Good test pattern: see `src/lib/__tests__/errors.test.ts` — describes grouped by function, edge cases covered
- Good store pattern: see `src/stores/counter.ts` — single domain, typed selectors, no side effects in store
