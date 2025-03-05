import { LogScroller } from "@/components/log-scroller";
import { Button } from "@/components/ui/button";
import Link from "next/link";

export default function Home() {
  return (
    <div className="container mx-auto px-4 py-16">
      {/* Hero Section */}
      <div className="flex flex-col items-center justify-between py-12 lg:flex-row lg:space-x-12">
        <div className="max-w-2xl space-y-6">
          <h1 className="text-4xl font-bold tracking-tight sm:text-5xl">
            Zero-configuration JSON logging for Ruby on Rails
          </h1>
          <p className="text-lg text-neutral-600 dark:text-neutral-400">
            LogStruct adds structured JSON logging to any Rails app. Just add the gem
            to your Gemfile, and your Rails app prints beautiful JSON logs that are
            easy to search, filter, and visualize.
          </p>
          <div className="flex flex-col space-y-4 sm:flex-row sm:space-x-4 sm:space-y-0">
            <Button asChild size="lg">
              <Link href="/docs/getting-started">Get Started</Link>
            </Button>
            <Button variant="outline" size="lg" asChild>
              <Link href="https://github.com/DocSpring/logstruct" target="_blank" rel="noopener noreferrer">
                View on GitHub
              </Link>
            </Button>
            <Button variant="secondary" size="lg" asChild>
              <Link href="/api" target="_blank">
                API Documentation
              </Link>
            </Button>
          </div>
        </div>
        <div className="mt-12 lg:mt-0">
          <LogScroller />
        </div>
      </div>

      {/* Installation Section */}
      <section className="py-16">
        <h2 className="mb-8 text-3xl font-bold">Installation</h2>
        <div className="grid gap-8 md:grid-cols-2">
          <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
            <h3 className="mb-4 text-xl font-semibold">1. Add to your Gemfile</h3>
            <pre className="overflow-x-auto rounded-md bg-neutral-100 p-4 dark:bg-neutral-900">
              <code className="text-sm font-mono">gem "logstruct"</code>
            </pre>
          </div>
          <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
            <h3 className="mb-4 text-xl font-semibold">2. Bundle install</h3>
            <pre className="overflow-x-auto rounded-md bg-neutral-100 p-4 dark:bg-neutral-900">
              <code className="text-sm font-mono">bundle install</code>
            </pre>
          </div>
        </div>
        <p className="mt-6 text-lg text-neutral-600 dark:text-neutral-400">
          Now JSON structured logging is enabled by default for the test and production environments.
        </p>
      </section>

      {/* Features Grid */}
      <section className="py-16">
        <h2 className="mb-12 text-center text-3xl font-bold">Features</h2>
        <div className="grid gap-8 sm:grid-cols-2 lg:grid-cols-3">
          <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
            <h3 className="mb-4 text-xl font-semibold">Type-safe with Sorbet</h3>
            <p className="text-neutral-600 dark:text-neutral-400">
              Full type checking with Sorbet ensures your logs are correctly structured.
            </p>
          </div>
          <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
            <h3 className="mb-4 text-xl font-semibold">Advanced Filtering</h3>
            <p className="text-neutral-600 dark:text-neutral-400">
              Parameter and string filtering for security and privacy, hiding sensitive data.
            </p>
          </div>
          <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
            <h3 className="mb-4 text-xl font-semibold">Tagged Logging</h3>
            <p className="text-neutral-600 dark:text-neutral-400">
              Full support for tagged logging with both string and hash tags.
            </p>
          </div>
          <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
            <h3 className="mb-4 text-xl font-semibold">Gem Integrations</h3>
            <p className="text-neutral-600 dark:text-neutral-400">
              Built-in integrations with Sidekiq, Carrierwave, Shrine, ActiveStorage, and more.
            </p>
          </div>
          <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
            <h3 className="mb-4 text-xl font-semibold">Error Handling</h3>
            <p className="text-neutral-600 dark:text-neutral-400">
              Configurable error handling with multiple reporting options.
            </p>
          </div>
          <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
            <h3 className="mb-4 text-xl font-semibold">Universal Compatibility</h3>
            <p className="text-neutral-600 dark:text-neutral-400">
              Works with any gem - just use Rails.logger like normal.
            </p>
          </div>
        </div>
        <div className="mt-12 text-center">
          <Button asChild size="lg">
            <Link href="/docs">Read the Documentation</Link>
          </Button>
        </div>
      </section>
    </div>
  );
}
