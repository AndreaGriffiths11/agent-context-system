# Gotchas

<!-- This file is loaded when starting unfamiliar tasks or debugging unexpected behavior. -->
<!-- Each entry: what looks right, what's actually wrong, and how to handle it. -->
<!-- Replace these examples with your project's actual gotchas. -->

## Build & Deploy

- **`pnpm build` silently hides type errors.** The build only checks JavaScript emit, not full type correctness. Always run `pnpm typecheck` separately before considering a build "clean." CI runs both.
- **Next.js caches aggressively in dev.** If your code changes aren't reflected, `rm -rf .next` and restart. This is especially common after modifying `next.config.js` or middleware.
- **Environment variables must be listed in `next.config.js`.** Server-side env vars need to be in `serverRuntimeConfig`. Client-side ones need the `NEXT_PUBLIC_` prefix. Missing this causes undefined values that only surface at runtime.
- **Vercel preview deploys use the `preview` environment.** Not `development`, not `production`. If something works locally but fails on preview, check that `preview` env vars are set in the Vercel dashboard.

## Database

- **`prisma migrate dev` resets the database.** It drops and recreates when migrations diverge. Use `prisma db push` for safe schema iteration during development. Only use `migrate dev` when you're ready to create a migration file.
- **Prisma generates to `src/generated/`.** After any schema change, run `prisma generate`. If types look stale, this is why. The generated client is gitignored — CI runs generate as a build step.
- **Connection pooling in serverless.** Each Vercel function invocation creates a new Prisma client. Use the singleton pattern in `src/lib/db/client.ts` to avoid exhausting the connection pool. The `connection_limit` in the DATABASE_URL should be set to 1 for serverless.

## Auth

- **Session tokens expire at different rates.** 24 hours in dev, 7 days in production. Don't write tests that assume session persistence beyond a single test run.
- **NextAuth callbacks run on every request.** The `session` callback in `src/lib/auth.ts` adds custom fields. If you add a new field to the session, you must update both the callback and the `Session` type declaration in `types/next-auth.d.ts`.
- **Middleware auth checks run at the edge.** The middleware in `src/middleware.ts` checks auth for protected routes. It cannot access the database — it only reads the JWT. If you need DB-backed authorization, do it in the route handler.

## Testing

- **Integration tests require the database.** Run `docker compose up db` before running the test suite. CI handles this automatically. If tests fail locally with connection errors, this is the first thing to check.
- **Vitest runs in happy-dom by default.** Component tests that need real browser APIs (IntersectionObserver, ResizeObserver) must add `// @vitest-environment jsdom` at the top of the test file.
- **Snapshot tests break on Prisma model changes.** If you update the Prisma schema, expect snapshot failures. Update snapshots with `pnpm test -- -u` after verifying the changes are correct.

## Third-Party APIs

- **Stripe webhooks fail in dev without the CLI.** Run `stripe listen --forward-to localhost:3000/api/webhooks/stripe` in a separate terminal. The webhook signing secret changes each time you restart the listener — update `.env.local` if signature verification fails.
- **Cloudinary transforms are cached by URL.** If you change a transform (resize, crop), the old cached version persists. Append a version parameter or use a different public ID.
- **Resend has rate limits in dev.** The free tier allows 100 emails/day. Tests that trigger emails should mock the Resend client using the helper in `tests/mocks/resend.ts`.
