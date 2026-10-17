import fs from 'node:fs';
import path from 'node:path';
import { AlertCircle, FilterX, Globe, IceCream, PieChart, Puzzle, Tag } from 'lucide-react';
import Link from 'next/link';
import { CodeBlock } from '@/components/code-block';
import DashboardClientWrapper from '@/components/dashboard-client-wrapper';
import { GitHubStatus } from '@/components/github-status';
import { RubyGemsIcon } from '@/components/icons';
import { LogScroller } from '@/components/log-scroller';
import { Button } from '@/components/ui/button';

// Get code coverage percentage from JSON file
function getCodeCoverage() {
  const coverageFilePath = path.join(process.cwd(), 'public/coverage/coverage.json');
  const coverageData = JSON.parse(fs.readFileSync(coverageFilePath, 'utf8'));
  return coverageData.metrics.covered_percent.toFixed(2);
}

// Get gem version from the version file
function getGemVersion() {
  const versionFilePath = path.join(process.cwd(), '../lib/log_struct/version.rb');
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
    <div>
      {/* Hero Section with gradient background - edge to edge */}
      <div
        className="w-full py-20 md:py-28 mb-16"
        style={{
          background:
            'linear-gradient(135deg, rgba(79, 67, 151, 0.12) 0%, rgba(153, 122, 252, 0.08) 50%, rgba(79, 67, 151, 0.03) 100%)',
          boxShadow: 'inset 0 1px 0 0 rgba(255, 255, 255, 0.1)',
        }}
      >
        <div className="container mx-auto px-4">
          <div className="grid grid-cols-1 xl:grid-cols-[42fr_58fr] gap-16 md:gap-24 2xl:gap-36">
            <div className="space-y-6 max-w-xl mx-auto xl:mx-0">
              <h1 className="text-4xl font-bold tracking-tight sm:text-5xl leading-tight xl:mt-2">
                Zero-config structured logging for Ruby on Rails
              </h1>
              <p className="text-lg text-neutral-600 dark:text-neutral-300 my-10">
                LogStruct adds typed JSON logs to Ruby on Rails apps, and filters sensitive data out
                of them, which helps you meet SOC 2&apos;s logging requirements. Add the gem to your
                Gemfile, and in production your app writes JSON lines that are easy to search,
                filter, and turn into dashboards. To see them in development, start your server with{' '}
                <code>LOGSTRUCT_ENABLED=true</code>.
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
                    GitHub
                  </Link>
                </Button>
                <Button variant="secondary" size="lg" asChild>
                  <a href="/yard/index.html" target="_blank" rel="noopener noreferrer">
                    YARD Docs
                  </a>
                </Button>
              </div>
            </div>
            <div className="hidden md:block relative">
              <LogScroller />
            </div>
          </div>
        </div>
      </div>

      {/* Main content container for rest of the page */}
      <div className="container mx-auto px-4 pb-16">
        {/* Installation Section */}
        <section className="pt-4 pb-16">
          <h2 className="mb-8 text-3xl font-bold">Installation</h2>

          <p className="my-6 text-lg text-neutral-600 dark:text-neutral-300">
            Enable JSON structured logging for your application:
          </p>
          <div className="grid gap-8 md:grid-cols-2">
            <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
              <h3 className="mb-4 text-xl font-semibold">1. Add to your Gemfile</h3>
              <CodeBlock language="ruby">{`gem "logstruct"`}</CodeBlock>
            </div>
            <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
              <h3 className="mb-4 text-xl font-semibold">2. Bundle install</h3>
              <CodeBlock language="bash">bundle install</CodeBlock>
            </div>
          </div>
        </section>

        {/* Dashboard Examples Section */}
        <section className="py-16">
          <h2 className="mb-8 text-3xl font-bold">Monitoring and Dashboards</h2>
          <p className="my-6 text-lg text-neutral-600 dark:text-neutral-300">
            Structured JSON logs are easy to parse, so you can quickly set up metrics, alerts, and
            dashboards.
          </p>

          <DashboardClientWrapper />
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
              <p className="text-neutral-600 dark:text-neutral-300">
                Every built-in log line is a Sorbet struct. A field with the wrong type raises in
                development and test, and is reported in production.
              </p>
            </div>
            <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
              <div className="flex items-center mb-4">
                <div className="mr-3 flex h-10 w-10 items-center justify-center rounded-full border border-neutral-200 dark:border-neutral-700">
                  <FilterX className="h-5 w-5 text-neutral-700 dark:text-neutral-300" />
                </div>
                <h3 className="text-xl font-semibold">Filtering and Scrubbing</h3>
              </div>
              <p className="text-neutral-600 dark:text-neutral-300">
                Values under sensitive keys (passwords, tokens, API keys) are replaced, and emails
                (hashed), card numbers, phone numbers and SSNs are scrubbed from strings. IP and MAC
                address scrubbing is opt-in.
              </p>
            </div>
            <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
              <div className="flex items-center mb-4">
                <div className="mr-3 flex h-10 w-10 items-center justify-center rounded-full border border-neutral-200 dark:border-neutral-700">
                  <Puzzle className="h-5 w-5 text-neutral-700 dark:text-neutral-300" />
                </div>
                <h3 className="text-xl font-semibold">Integrations</h3>
              </div>
              <p className="text-neutral-600 dark:text-neutral-300">
                Structured lines for requests (Lograge), ActiveJob, ActionMailer, Sidekiq, GoodJob,
                Puma, ActiveStorage, Shrine, CarrierWave and more. (Open a PR to add support for
                your favorite gem!)
              </p>
            </div>
            <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
              <div className="flex items-center mb-4">
                <div className="mr-3 flex h-10 w-10 items-center justify-center rounded-full border border-neutral-200 dark:border-neutral-700">
                  <AlertCircle className="h-5 w-5 text-neutral-700 dark:text-neutral-300" />
                </div>
                <h3 className="text-xl font-semibold">Error Reporting</h3>
              </div>
              <p className="text-neutral-600 dark:text-neutral-300">
                Choose whether each kind of error is raised, logged or reported. Reports go to
                Sentry, Bugsnag, Rollbar, Honeybadger or your own reporter.
              </p>
            </div>
            <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
              <div className="flex items-center mb-4">
                <div className="mr-3 flex h-10 w-10 items-center justify-center rounded-full border border-neutral-200 dark:border-neutral-700">
                  <Globe className="h-5 w-5 text-neutral-700 dark:text-neutral-300" />
                </div>
                <h3 className="text-xl font-semibold">Cloud-Ready</h3>
              </div>
              <p className="text-neutral-600 dark:text-neutral-300">
                Works with AWS CloudWatch, Datadog, Grafana and other services that parse JSON logs.
                A Terraform provider checks the source and event names in your CloudWatch metric
                filters when you plan.
              </p>
            </div>
            <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
              <div className="flex items-center mb-4">
                <div className="mr-3 flex h-10 w-10 items-center justify-center rounded-full border border-neutral-200 dark:border-neutral-700">
                  <Tag className="h-5 w-5 text-neutral-700 dark:text-neutral-300" />
                </div>
                <h3 className="text-xl font-semibold">Request and Job Context</h3>
              </div>
              <p className="text-neutral-600 dark:text-neutral-300">
                Every line logged during a request has its request ID. Tags from{' '}
                <code>logger.tagged</code> and <code>config.log_tags</code> are written in each
                line, and Sidekiq lines include the job&apos;s context.
              </p>
            </div>
          </div>
        </section>

        {/* Project Status */}
        <section className="py-16">
          <h2 className="mb-8 text-3xl font-bold text-center">Project Status</h2>
          <div className="grid gap-8 md:grid-cols-2 lg:grid-cols-4">
            <GitHubStatus />

            <a
              href="/coverage/index.html"
              target="_blank"
              rel="noopener noreferrer"
              className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800 hover:border-gray-400 dark:hover:border-gray-500 transition-colors hover:no-underline"
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
              <p className="text-neutral-600 dark:text-neutral-300">
                Tests cover{' '}
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
              <p className="text-neutral-600 dark:text-neutral-300">
                LogStruct is{' '}
                <span className="font-semibold" style={{ color: '#997afc' }}>
                  100% typed
                </span>{' '}
                with Sorbet
              </p>
            </div>

            <a
              href="https://rubygems.org/gems/logstruct"
              target="_blank"
              rel="noopener noreferrer"
              className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800 hover:border-gray-400 dark:hover:border-gray-500 transition-colors hover:no-underline"
            >
              <div className="flex items-center mb-4">
                <div
                  className="mr-3 flex h-10 w-10 items-center justify-center rounded-full"
                  style={{ backgroundColor: 'rgba(215, 40, 40, 0.15)' }}
                >
                  <RubyGemsIcon className="h-5 w-5" style={{ color: '#d72828' }} />
                </div>
                <h3 className="text-xl font-semibold">RubyGems</h3>
              </div>
              <p className="text-neutral-600 dark:text-neutral-300">
                Latest version:{' '}
                <span className="font-semibold" style={{ color: '#d72828' }}>
                  {gemVersion}
                </span>
              </p>
            </a>
          </div>
        </section>

        {/* FAQ Section */}
        <section className="py-16">
          <h2 className="mb-12 text-center text-3xl font-bold">Frequently Asked Questions</h2>
          <div className="grid gap-8 md:grid-cols-2">
            <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
              <h3 className="mb-4 text-xl font-semibold">Do I need to use Sorbet?</h3>
              <p className="text-neutral-600 dark:text-neutral-300">
                No. Log with the regular Rails logger as usual.{' '}
                <a href="https://sorbet.org/docs/runtime">
                  <code>sorbet-runtime</code>
                </a>{' '}
                is a dependency, and if your app has its own Sorbet signatures, LogStruct handles
                their runtime type errors too, as{' '}
                <Link href="/docs/configuration/#error-handling-configuration">
                  <code>type_checking_errors</code>
                </Link>{' '}
                says (raise in development and test, log and report in production).
              </p>
            </div>
            <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
              <h3 className="mb-4 text-xl font-semibold">Is LogStruct free?</h3>
              <p className="text-neutral-600 dark:text-neutral-300">
                Yes, LogStruct is completely free and open source under the MIT license. Pull
                requests and contributions are welcome!
              </p>
            </div>

            <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
              <h3 className="mb-4 text-xl font-semibold">Why was LogStruct built?</h3>
              <p className="text-neutral-600 dark:text-neutral-300">
                DocSpring was originally using the{' '}
                <a
                  href="https://github.com/roidrage/lograge"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <code>lograge</code>
                </a>{' '}
                gem to format our request logs as JSON. We realized that we had a lot of other plain
                text logs that would be useful for CloudWatch metrics and dashboards. We wrote much
                of this code in our own app before deciding to extract it and release it as a gem.
                (It was also a great opportunity to learn more about Sorbet.)
              </p>
            </div>
            <div className="rounded-lg border border-neutral-200 p-6 dark:border-neutral-800">
              <h3 className="mb-4 text-xl font-semibold">What about other logging gems?</h3>
              <p className="text-neutral-600 dark:text-neutral-300">
                Several other gems provide structured logging for Rails apps, including{' '}
                <a
                  href="https://github.com/reidmorrison/rails_semantic_logger"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  Rails Semantic Logger
                </a>
                ,{' '}
                <a
                  href="https://github.com/roidrage/lograge"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  Lograge
                </a>
                ,{' '}
                <a
                  href="https://github.com/shadabahmed/logstasher"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  Logstasher
                </a>
                , and{' '}
                <a
                  href="https://github.com/zormandi/logcraft"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  Logcraft
                </a>
                . LogStruct focuses on filtering and scrubbing, structured error handling, and typed
                lines for each integration. See the{' '}
                <Link href="/docs/comparison" className="underline">
                  comparison page
                </Link>{' '}
                for a detailed breakdown.
              </p>
            </div>
          </div>
        </section>
      </div>
    </div>
  );
}
