import { RubyCodeExample } from '@/components/ruby-code-example';
import { EditPageLink } from '@/components/edit-page-link';
import { CodeBlock } from '@/components/code-block';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import Link from 'next/dist/client/link';
import { getCodeExample } from '@/lib/codeExamples';
import { Callout } from '@/components/ui/callout';

export default function ConfigurationPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="configuration" level={1}>
        Configuration
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-300">
        LogStruct is designed to be highly configurable while working with
        sensible defaults. You can customize how and where logs are generated,
        which integrations are enabled, and how errors are handled.
      </p>

      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        Create a file at{' '}
        <code className="px-1 py-0.5 bg-neutral-100 dark:bg-neutral-800 rounded">
          config/initializers/logstruct.rb
        </code>{' '}
        with your desired configuration.
      </p>

      <RubyCodeExample name="basic_configuration" />

      <HeadingWithAnchor id="enabling-logstruct">
        Enabling LogStruct
      </HeadingWithAnchor>

      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct follows a simple philosophy:{' '}
        <strong>machines get JSON, humans get readable logs</strong>. By
        default:
      </p>

      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300 mb-6">
        <li>
          <strong>Production servers</strong> → JSON logs (for parsing and
          analysis)
        </li>
        <li>
          <strong>CI test runs</strong> → JSON logs (to catch production bugs)
        </li>
        <li>
          <strong>Local development</strong> → Human-readable logs (disabled by
          default)
        </li>
        <li>
          <strong>Rails console</strong> → Human-readable logs (always)
        </li>
        <li>
          <strong>Rake tasks</strong> → Human-readable logs
        </li>
        <li>
          <strong>Local test runs</strong> → Human-readable logs (for debugging)
        </li>
      </ul>

      <HeadingWithAnchor id="overriding-defaults" level={3}>
        Overriding the Defaults
      </HeadingWithAnchor>

      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        You can override this behavior in several ways, with the following
        precedence (highest to lowest):
      </p>

      <ol className="list-decimal list-outside ml-6 space-y-3 text-neutral-600 dark:text-neutral-300 mb-6">
        <li>
          <strong>Environment variable override</strong>
          <br />
          Set <code>LOGSTRUCT_ENABLED=true</code> to force JSON logs, or{' '}
          <code>LOGSTRUCT_ENABLED=false</code> to disable completely.
          <div className="mt-2">
            <CodeBlock language="bash">
              {`# Force JSON logs in console for debugging\nLOGSTRUCT_ENABLED=true rails console\n\n# Force JSON logs in local tests\nLOGSTRUCT_ENABLED=true rails test`}
            </CodeBlock>
          </div>
        </li>
        <li>
          <strong>Initializer configuration</strong>
          <br />
          Manually set <code>config.enabled = true</code> in your initializer to
          enable in all development processes.
          <div className="mt-2">
            <CodeBlock language="ruby">
              {`LogStruct.configure do |c|\n  c.enabled = true\nend`}
            </CodeBlock>
          </div>
        </li>
        <li>
          <strong>Environment list</strong>
          <br />
          Modify <code>config.enabled_environments</code> to change which
          environments have JSON logs by default (currently{' '}
          <code>[:test, :production]</code>).
        </li>
      </ol>

      <Callout type="info">
        The <code>CI</code> environment variable is automatically detected by
        most CI systems (GitHub Actions, GitLab CI, CircleCI, Travis, etc.). If
        your CI doesn&apos;t set it, add <code>CI=true</code> to your CI
        configuration.
      </Callout>

      <HeadingWithAnchor id="environment-configuration">
        Environment Configuration
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct supports different environments and handles them
        appropriately:
      </p>

      <RubyCodeExample name="environment_configuration" />

      <HeadingWithAnchor id="development-preview">
        Preview Production Logs in Development
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct is disabled by default in development. When you explicitly
        enable it (for example, <code>LOGSTRUCT_ENABLED=true rails s</code> or
        setting <code>config.enabled = true</code>), LogStruct uses the same
        JSON formatter as production so you can validate structured logs
        locally. If you prefer the colorful human formatter for day‑to‑day
        debugging, set:
      </p>

      <CodeBlock language="ruby">
        {`LogStruct.configure do |c|
  c.prefer_json_in_development = false
  c.enable_color_output = true
end`}
      </CodeBlock>

      <Callout type="info">
        The <code>ActiveSupport::TaggedLogging</code> compatibility patch is
        only applied when LogStruct is enabled. This ensures third‑party gems
        that write Hashes to <code>Rails.logger</code> (e.g., dotenv‑rails) do
        not affect your default development logging when LogStruct is disabled.
      </Callout>

      <Callout type="info">
        We enable LogStruct in <code>test</code> as well as production by
        default. Keeping test and production behavior as close as possible helps
        catch logging issues early (for example, unexpected serialization
        errors, missing fields, or broken integrations) before they reach prod.
        If you prefer to disable it in test, remove <code>:test</code> from{' '}
        <code>config.enabled_environments</code>.
      </Callout>

      <Callout type="info">
        To force JSON logs in console, local test runs, or other Rake tasks
        (e.g., for debugging or inspecting the exact JSON output), set{' '}
        <code>LOGSTRUCT_ENABLED=true</code> when running the command:
        <br />
        <code>LOGSTRUCT_ENABLED=true rails console</code>
        <br />
        <code>LOGSTRUCT_ENABLED=true rails test</code>
      </Callout>

      <HeadingWithAnchor id="integration-configuration">
        Integration Configuration
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct integrates with many popular gems. You can enable or disable
        specific integrations:
      </p>

      <RubyCodeExample name="integrations_configuration" />

      <HeadingWithAnchor id="filtering-sensitive-data">
        Filtering Sensitive Data
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct includes robust filtering for sensitive data to ensure privacy
        and security:
      </p>

      <RubyCodeExample name="filter_configuration" />

      <Callout type="info">
        See the{' '}
        <Link
          href="/docs/filtering-sensitive-data"
          className="text-blue-200 hover:text-white"
        >
          Filtering Sensitive Data
        </Link>{' '}
        docs for more information.
      </Callout>

      <HeadingWithAnchor id="error-handling-configuration">
        Error Handling Configuration
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct provides customizable error handling modes to control how
        errors are processed. You probably don&apos;t want type-checking errors
        or internal logging-related errors to crash your application, so our
        default behavior is to log and report those errors without crashing. We
        automatically detect which error reporting service you use (Sentry,
        Bugsnag, Rollbar, etc.). If you use a service that we don&apos;t support
        yet, you can configure a{' '}
        <Link href="#custom-error-reporting">custom error handler</Link>. (Or
        you can send a PR!)
      </p>

      <RubyCodeExample name="error_handling_modes" />

      <HeadingWithAnchor id="custom-lograge-options">
        Custom Lograge Options
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        You can extend Lograge request logging with custom fields:
      </p>

      <RubyCodeExample name="lograge_custom_options" />

      <HeadingWithAnchor id="custom-string-scrubbing">
        Custom String Scrubbing
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        You can implement custom string scrubbers to filter out sensitive data
        that isn&apos;t caught by the built-in filters:
      </p>

      <RubyCodeExample name="custom_string_scrubber" />

      <HeadingWithAnchor id="custom-error-reporting">
        Custom Error Reporting
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        {/* cspell:ignore doesn */}
        If LogStruct doesn&apos;t support your error reporting service, you can
        register a custom error reporting handler. (Or submit a PR!)
      </p>

      <RubyCodeExample name="error_reporting_handler" />

      <HeadingWithAnchor id="sorbet-integration">
        Sorbet Integration
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct integrates with Sorbet to handle type checking errors based on
        the environment. We raise type errors or logging-related errors in
        test/development so you can catch them early, but we only log or report
        them in production. You can configure a different error handling mode to
        change this behavior.
      </p>

      <CodeBlock language="ruby">
        {getCodeExample('sorbet_error_handlers_configuration').code}
      </CodeBlock>

      <EditPageLink />
    </div>
  );
}
