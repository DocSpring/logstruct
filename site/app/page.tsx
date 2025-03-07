import { LogScroller } from '@/components/log-scroller';
import { Button } from '@/components/ui/button';
import Link from 'next/link';
import { CodeBlock } from '@/components/code-block';
import {
  FilterX,
  Tag,
  Puzzle,
  AlertCircle,
  Globe,
  IceCream,
  PieChart,
  Github,
  Loader2,
} from 'lucide-react';
import fs from 'fs';
import path from 'path';
import { RubyGemsIcon } from '@/components/icons';
import { GitHubStatus } from '@/components/github-status';

// Get code coverage percentage from JSON file
function getCodeCoverage() {
  const coverageFilePath = path.join(
    process.cwd(),
    'public/coverage/coverage.json',
  );
  const coverageData = JSON.parse(fs.readFileSync(coverageFilePath, 'utf8'));
  return coverageData.metrics.covered_percent.toFixed(1);
}

// Get gem version from the version file
function getGemVersion() {
  const versionFilePath = path.join(
    process.cwd(),
    '../lib/log_struct/version.rb',
  );
  const versionFileContent = fs.readFileSync(versionFilePath, 'utf8');
  const versionMatch = versionFileContent.match(/VERSION\s*=\s*"([^"]+)"/);

  if (!versionMatch) {
    throw new Error('Version not found in version.rb file');
  }

  return versionMatch[1];
}

export default function Home() {
  // These functions will be executed at build time in server component
  const coveragePercentage = getCodeCoverage();
  const gemVersion = getGemVersion();

  return (
    <div className="container mx-auto px-4 pt-8 pb-16 md:py-16">
      {/* Hero Section */}
      <div className="grid grid-cols-1 xl:grid-cols-[42fr_58fr] gap-24 2xl:gap-36 pt-1 sm:pt-4 pb-12 xl:py-12 px-2">
        <div className="space-y-6 max-w-xl mx-auto xl:mx-0">
          <h1 className="text-4xl font-bold tracking-tight sm:text-5xl leading-tight xl:mt-2">
            Zero-configuration JSON logging for Ruby on Rails
          </h1>
          <p className="text-lg text-neutral-600 dark:text-neutral-400 my-10">
            LogStruct is a new way to add type-safe, structured JSON logging to
            any Rails app. Just add the gem to your Gemfile, and your Rails app
            will print beautiful JSON logs that are easy to search, filter, and
            visualize.
          </p>

          <div className="flex flex-col space-y-4 sm:flex-row sm:space-x-4 sm:space-y-0 mt-6">
            <Button asChild size="lg">
              <Link href="/docs/getting-started">Get Started</Link>
            </Button>
            <Button variant="secondary" size="lg" asChild>
              <Link
                href="https://github.com/DocSpring/logstruct"
                target="_blank"
                rel="noopener noreferrer"
              >
                View on GitHub
              </Link>
            </Button>
            <Button variant="secondary" size="lg" asChild>
              <a
                href="/yard/index.html"
                target="_blank"
                rel="noopener noreferrer"
              >
                YARD Docs
              </a>
            </Button>
          </div>
        </div>
        <div className="hidden md:block">
          <LogScroller />
        </div>
      </div>

      {/* Installation Section */}
      <section className="py-16">
        <h2 className="mb-8 text-3xl font-bold">Installation</h2>

        <p className="my-6 text-lg text-neutral-600 dark:text-neutral-400">
          Enable JSON structured logging for test and production environments:
        </p>
        <div className="grid gap-8 md:grid-cols-2">
          <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
            <h3 className="mb-4 text-xl font-semibold">
              1. Add to your Gemfile
            </h3>
            <CodeBlock language="ruby">{`gem "logstruct"`}</CodeBlock>
          </div>
          <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
            <h3 className="mb-4 text-xl font-semibold">2. Bundle install</h3>
            <CodeBlock language="bash">bundle install</CodeBlock>
          </div>
        </div>
      </section>

      {/* Project Status Section */}
      <section className="py-16">
        <h2 className="mb-8 text-3xl font-bold text-center">Project Status</h2>
        <div className="grid gap-8 md:grid-cols-2 lg:grid-cols-4">
          <GitHubStatus />

          <a
            href="/coverage/index.html"
            target="_blank"
            rel="noopener noreferrer"
            className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800 hover:border-purple-300 dark:hover:border-purple-700 transition-colors"
          >
            <div className="flex items-center mb-4">
              <div
                className="mr-3 flex h-10 w-10 items-center justify-center rounded-full"
                style={{ backgroundColor: 'rgba(79, 67, 151, 0.15)' }}
              >
                <PieChart className="h-5 w-5" style={{ color: '#997afc' }} />
              </div>
              <h3 className="text-xl font-semibold">Code Coverage</h3>
            </div>
            <p className="text-neutral-600 dark:text-neutral-400">
              Test suite covers{' '}
              <span className="font-semibold" style={{ color: '#997afc' }}>
                {coveragePercentage}%
              </span>{' '}
              of the codebase
            </p>
          </a>

          <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
            <div className="flex items-center mb-4">
              <div
                className="mr-3 flex h-10 w-10 items-center justify-center rounded-full"
                style={{ backgroundColor: 'rgba(79, 67, 151, 0.15)' }}
              >
                <IceCream className="h-5 w-5" style={{ color: '#997afc' }} />
              </div>
              <h3 className="text-xl font-semibold">Type Coverage</h3>
            </div>
            <p className="text-neutral-600 dark:text-neutral-400">
              <span className="font-semibold" style={{ color: '#997afc' }}>
                100%
              </span>{' '}
              type-checked with Sorbet
            </p>
          </div>

          <a
            href="https://rubygems.org/gems/logstruct"
            target="_blank"
            rel="noopener noreferrer"
            className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800 hover:border-red-300 dark:hover:border-red-700 transition-colors"
          >
            <div className="flex items-center mb-4">
              <div className="mr-3 flex h-10 w-10 items-center justify-center rounded-full bg-red-100 dark:bg-red-900/30">
                <RubyGemsIcon className="h-5 w-5 text-red-500 dark:text-red-400" />
              </div>
              <h3 className="text-xl font-semibold">RubyGems</h3>
            </div>
            <p className="text-neutral-600 dark:text-neutral-400">
              Latest release:{' '}
              <span className="text-red-600 dark:text-red-400 font-semibold">
                v{gemVersion}
              </span>
            </p>
          </a>
        </div>
      </section>

      {/* Features Grid */}
      <section className="py-16">
        <h2 className="mb-12 text-center text-3xl font-bold">Features</h2>
        <div className="grid gap-8 sm:grid-cols-2 lg:grid-cols-3">
          <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
            <div className="flex items-center mb-4">
              <div className="mr-3 flex h-10 w-10 items-center justify-center rounded-full border border-neutral-200 dark:border-neutral-700">
                <IceCream className="h-5 w-5 text-neutral-700 dark:text-neutral-300" />
              </div>
              <h3 className="text-xl font-semibold">Type-safe with Sorbet</h3>
            </div>
            <p className="text-neutral-600 dark:text-neutral-400">
              LogStruct is fully type-checked with Sorbet so your logs are
              guaranteed to have the correct structure. And no risk of{' '}
              <code>undefined method `[]&apos; for nil:NilClass</code>.
            </p>
          </div>
          <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
            <div className="flex items-center mb-4">
              <div className="mr-3 flex h-10 w-10 items-center justify-center rounded-full border border-neutral-200 dark:border-neutral-700">
                <FilterX className="h-5 w-5 text-neutral-700 dark:text-neutral-300" />
              </div>
              <h3 className="text-xl font-semibold">
                Advanced Filtering and Scrubbing
              </h3>
            </div>
            <p className="text-neutral-600 dark:text-neutral-400">
              Parameter and string filtering for security and privacy, hiding
              sensitive data.
            </p>
          </div>
          <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
            <div className="flex items-center mb-4">
              <div className="mr-3 flex h-10 w-10 items-center justify-center rounded-full border border-neutral-200 dark:border-neutral-700">
                <Tag className="h-5 w-5 text-neutral-700 dark:text-neutral-300" />
              </div>
              <h3 className="text-xl font-semibold">Tagged Logging</h3>
            </div>
            <p className="text-neutral-600 dark:text-neutral-400">
              Full support for tagged logging with both string and hash tags.
            </p>
          </div>
          <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
            <div className="flex items-center mb-4">
              <div className="mr-3 flex h-10 w-10 items-center justify-center rounded-full border border-neutral-200 dark:border-neutral-700">
                <Puzzle className="h-5 w-5 text-neutral-700 dark:text-neutral-300" />
              </div>
              <h3 className="text-xl font-semibold">Gem Integrations</h3>
            </div>
            <p className="text-neutral-600 dark:text-neutral-400">
              Built-in integrations with Sidekiq, Carrierwave, Shrine,
              ActiveStorage, and more.
            </p>
          </div>
          <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
            <div className="flex items-center mb-4">
              <div className="mr-3 flex h-10 w-10 items-center justify-center rounded-full border border-neutral-200 dark:border-neutral-700">
                <AlertCircle className="h-5 w-5 text-neutral-700 dark:text-neutral-300" />
              </div>
              <h3 className="text-xl font-semibold">Error Handling</h3>
            </div>
            <p className="text-neutral-600 dark:text-neutral-400">
              Configurable error handling with multiple reporting options.
            </p>
          </div>
          <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
            <div className="flex items-center mb-4">
              <div className="mr-3 flex h-10 w-10 items-center justify-center rounded-full border border-neutral-200 dark:border-neutral-700">
                <Globe className="h-5 w-5 text-neutral-700 dark:text-neutral-300" />
              </div>
              <h3 className="text-xl font-semibold">Universal Compatibility</h3>
            </div>
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
