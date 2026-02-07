# Code Conventions

> **For agents:** This file is loaded only when a task involves writing or modifying code.
> 
> **Your task:** Study the existing codebase to discover the actual conventions, then document them here. The structure below shows what to look for. The examples are from a Next.js/TypeScript project — replace them with patterns from THIS codebase.

## Naming

> **What to discover:** How are files, components, functions, variables, types, constants, and tests named? Look at 10-20 examples across different parts of the codebase to find the pattern.

**Current examples (REPLACE THESE):**
- **Files:** kebab-case (`user-profile.tsx`, `api-client.ts`)
- **Components:** PascalCase (`UserProfile`, `DataTable`)
- **Functions/variables:** camelCase (`getUserById`, `isLoading`)
- **Types/interfaces:** PascalCase, no `I` prefix (`UserProfile`, not `IUserProfile`)
- **Constants:** UPPER_SNAKE for true constants (`MAX_RETRIES`), camelCase for derived values
- **Test files:** `[source-name].test.ts` inside `__tests__/` directory adjacent to source

## File Structure

> **What to discover:** How is code organized? Where do different types of files live? What's the relationship between source and test files? When is code shared vs. colocated?

**Current examples (REPLACE THESE):**
- One component per file. File name matches the export name.
- Co-locate tests: `src/lib/errors.ts` → `src/lib/__tests__/errors.test.ts`
- Co-locate page-specific components: `src/app/dashboard/components/StatsCard.tsx`
- Shared components go in `src/components/` only when used by 2+ routes.

## Patterns to Follow

> **What to discover:** What coding patterns are used consistently? Look for patterns in: exports, error handling, validation, data access, component structure, API design.
> 
> Format: Brief description, then point to a real file as the reference example.

**Current examples (REPLACE THESE):**

- **Named exports everywhere.** `export function Button()`, never `export default`. This makes renames trackable and tree-shaking reliable. See `src/components/Button.tsx`.
- **Result types for fallible operations.** Return `{ok: true, data}` or `{ok: false, error}` instead of throwing. Callers handle both paths explicitly. See `src/lib/errors.ts`.
- **Zod schemas at API boundaries.** Every route handler validates input with a Zod schema before processing. See `src/app/api/users/route.ts`.

## Patterns to Avoid

> **What to discover:** What patterns are explicitly avoided? Look for comments warning against certain approaches, linter rules, code review feedback patterns.

**Current examples (REPLACE THESE):**

- **No `any` types.** Use `unknown` and narrow, or define a proper type. The only exception is test mocks, and even then prefer `as unknown as Type`.
- **No inline styles.** Use Tailwind classes. Keeps styling consistent and grep-able.
- **No barrel exports (`index.ts` re-exports).** They break tree-shaking and make imports ambiguous. Import from the specific file.

## Examples

> **What to discover:** Find 3-5 exemplary files that demonstrate good patterns. Point to them rather than copying code.

**Current examples (REPLACE THESE):**

- Good component pattern: see `src/components/Button.tsx` — named export, props interface, Tailwind only
- Good API route pattern: see `src/app/api/users/route.ts` — Zod validation, Result return, Prisma helper
- Good error handling: see `src/lib/errors.ts` — Result type definition and utility functions
