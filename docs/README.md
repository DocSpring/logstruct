# LogStruct Documentation Site

This is the documentation website for the LogStruct gem, built with Next.js and shadcn/ui. It showcases the gem's features and provides comprehensive documentation for users.

## Features

- Interactive examples of LogStruct's JSON logging capabilities
- Comprehensive documentation of all gem features
- Mobile-responsive design with shadcn/ui components
- Dark mode support

## Development

### Prerequisites

- Node.js (version 18 or higher)
- npm (version 8 or higher)

### Getting Started

1. Install dependencies:

```bash
npm install
```

2. Start the development server:

```bash
npm run dev
```

3. Open [http://localhost:3001](http://localhost:3001) to view the docs in your browser.

### Building for Production

To build the static docs for production:

```bash
npm run build
```

This will generate static HTML files in the `out` directory that can be deployed to any static web hosting service.

## Deployment

This site is configured to deploy to GitHub Pages automatically through GitHub Actions. Any changes pushed to the main branch will trigger a deployment.

To manually deploy:

1. Build the docs:

```bash
npm run build
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
