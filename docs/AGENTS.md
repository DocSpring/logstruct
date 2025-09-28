# Repository Guidelines

## Project Structure & Module Organization

- This directory contains the Next.js docs (TypeScript, React 19, Next 15).
- Key paths:
  - `app/` – routes, server and client components
  - `components/` – shared UI components
  - `lib/` – helpers, data utilities, MD/MDX processing
  - `public/` – static assets
  - `e2e/` – integration and Playwright tests
  - `scripts/` – build/test utilities (favicons, fixtures, link checks)

## Build, Test, and Development Commands

- Install dependencies: `pnpm i`
- Dev server: `pnpm dev` (NEVER RUN THIS. The user will be the one who starts it in their own terminal tab.)
- Typecheck: `pnpm typecheck`
- Lint: `pnpm lint`
- Build: `pnpm build` (runs favicon generation, Next build, post-build link check)
- Unit tests (Jest, jsdom): `npm test` or `pnpm test:watch`
- Integration tests (Node/Jest): `pnpm test:integration`
- E2E (Playwright, static server on 3011): `pnpm e2e`
- Full local gate: `pnpm check` (typecheck → lint → build → integration → e2e)

## Coding Style & Naming Conventions

- TypeScript with strict types. Prefer explicit return types for exported functions.
- Components: PascalCase files in `components/`; hooks start with `use*`.
- Route segments and non-component utilities: kebab-case or lowerCamelCase as idiomatic for Next.js.
- 2-space indentation; avoid default exports for shared components.
- ESLint config: `eslint.config.mjs`. Fix issues as reported by `pnpm lint`.
- Styling via Tailwind CSS v4; keep atomic classes close to components.

## Testing Guidelines

- Unit tests live under `__tests__/` with `.test.ts(x)` (see `jest.config.ts`).
- Integration tests live under `e2e/*.test.ts` (see `jest.integration.config.ts`).
- Playwright specs live under `e2e/playwright/` (see `playwright.config.ts`).
- Use realistic data via `scripts/prepare-integration-fixtures.js` (runs automatically where needed).

## Commit & Pull Request Guidelines

- Commits: imperative subject, concise body explaining motivation and scope.
- PRs: include clear description, screenshots for UI, and reproduction steps if relevant.
- Only mark ready when `pnpm check` passes locally.

## Configuration Tips

- Local env: copy `.env.example` to `.env.local` as needed.
- Static E2E server uses `scripts/serve-static.js`; base URL is configured in `playwright.config.ts`.
