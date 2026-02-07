# Gotchas

> **For agents:** This file is loaded when starting unfamiliar tasks or debugging unexpected behavior.
>
> **Your task:** Discover the traps and non-obvious behaviors in this codebase. Each entry should explain what looks right but isn't, and what to do instead. The structure below shows categories to explore. The examples are from a Next.js/TypeScript/Prisma project — replace them with THIS project's actual gotchas.
>
> **How to discover gotchas:** 
> - Run the build and tests — what fails in non-obvious ways?
> - Check git history for repeated fixes of the same issue
> - Look for comments warning about specific approaches
> - Ask the team what catches new contributors off guard

## Build & Deploy

> **What to discover:** What's the difference between build and typecheck? What gets cached? What environment-specific issues exist?

**Current examples (REPLACE THESE):**

- **`pnpm build` silently hides type errors.** The build only checks JavaScript emit, not full type correctness. Always run `pnpm typecheck` separately before considering a build "clean." CI runs both.
- **Next.js caches aggressively in dev.** If your code changes aren't reflected, `rm -rf .next` and restart. This is especially common after modifying `next.config.js` or middleware.
- **Environment variables must be listed in `next.config.js`.** Server-side env vars need to be in `serverRuntimeConfig`. Client-side ones need the `NEXT_PUBLIC_` prefix. Missing this causes undefined values that only surface at runtime.

## Database

> **What to discover:** What database operations have surprising side effects? What commands are safe in dev but dangerous in prod? What causes connection issues?

**Current examples (REPLACE THESE):**

- **`prisma migrate dev` resets the database.** It drops and recreates when migrations diverge. Use `prisma db push` for safe schema iteration during development. Only use `migrate dev` when you're ready to create a migration file.
- **Prisma generates to `src/generated/`.** After any schema change, run `prisma generate`. If types look stale, this is why. The generated client is gitignored — CI runs generate as a build step.
- **Connection pooling in serverless.** Each Vercel function invocation creates a new Prisma client. Use the singleton pattern in `src/lib/db/client.ts` to avoid exhausting the connection pool. The `connection_limit` in the DATABASE_URL should be set to 1 for serverless.

## Auth / Security

> **What to discover:** What auth-related behaviors are surprising? What session management issues exist? What security checks run where?

**Current examples (REPLACE THESE):**

- **Session tokens expire at different rates.** 24 hours in dev, 7 days in production. Don't write tests that assume session persistence beyond a single test run.
- **NextAuth callbacks run on every request.** The `session` callback in `src/lib/auth.ts` adds custom fields. If you add a new field to the session, you must update both the callback and the `Session` type declaration in `types/next-auth.d.ts`.

## Testing

> **What to discover:** What test setup is required? What environment-specific test issues exist? What causes flaky tests?

**Current examples (REPLACE THESE):**

- **Integration tests require the database.** Run `docker compose up db` before running the test suite. CI handles this automatically. If tests fail locally with connection errors, this is the first thing to check.
- **Vitest runs in happy-dom by default.** Component tests that need real browser APIs (IntersectionObserver, ResizeObserver) must add `// @vitest-environment jsdom` at the top of the test file.

## Third-Party Services

> **What to discover:** What external service integrations have non-obvious requirements? What fails in dev vs prod? What has rate limits or requires special setup?

**Current examples (REPLACE THESE):**

- **Stripe webhooks fail in dev without the CLI.** Run `stripe listen --forward-to localhost:3000/api/webhooks/stripe` in a separate terminal. The webhook signing secret changes each time you restart the listener — update `.env.local` if signature verification fails.
- **Cloudinary transforms are cached by URL.** If you change a transform (resize, crop), the old cached version persists. Append a version parameter or use a different public ID.

## Performance / Timing

> **What to discover:** What timing-related issues exist? What causes race conditions? What appears instant but isn't?

**Current examples (REPLACE THESE — or delete this section if not relevant):**

- [Document timing-related gotchas here]
- [Or remove this section if there are none]
