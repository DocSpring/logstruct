# LogStruct Documentation Site

This is the documentation website for the LogStruct gem, built with Next.js and shadcn/ui. It showcases the gem's features and provides comprehensive documentation for users.

## Features

- Interactive examples of LogStruct's JSON logging capabilities
- Comprehensive documentation of all gem features
- Mobile-responsive design with shadcn/ui components
- Dark mode support

## Development

### Prerequisites

- Node.js 22 and pnpm 10.18.3 (the versions used in CI)
- The repository's Ruby version, Bundler and Task, with `bundle install` completed at the repository root

### Getting Started

1. Generate the log types, test coverage and API documentation from the repository root:

```bash
task generate
task test
task yard:generate
```

The homepage reads `public/coverage/coverage.json`, and the navigation links to `public/yard/`. These are generated artifacts, so a clean checkout needs them before serving or building the site.

2. Install the docs dependencies from this directory:

```bash
pnpm install
```

3. Start the development server:

```bash
pnpm dev
```

4. Open [http://localhost:3001](http://localhost:3001) to view the docs in your browser.

### Building for Production

To build the static docs for production:

```bash
pnpm build
```

This will generate static HTML files in the `out` directory that can be deployed to any static web hosting service.

## Deployment

This site deploys to GitHub Pages through GitHub Actions after CI passes on `main`, using that CI run's coverage report.

To manually deploy:

1. Build the docs:

```bash
pnpm build
```

2. The static files will be in the `out` directory, which can be deployed to any static hosting service.

## Project Structure

- `app/` - The Next.js application
  - `app/page.tsx` - The homepage
  - `app/docs/` - Documentation pages
- `components/` - Reusable React components
- `public/` - Static assets (images, etc.)

## Contributing

To add or update documentation:

1. Create or edit files in the `app/docs` directory
2. Each page should be a React component that exports a default function
3. For new sections, update the sidebar in `app/docs/layout.tsx`
4. Keep Ruby examples in `test/code_examples/` and display them with `RubyCodeExample`, so the Ruby suite checks them
5. Run `task ci` from the repository root and `pnpm check` here (types, lint, static build, integration tests and browser tests)
