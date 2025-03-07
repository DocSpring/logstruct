import { RubyCodeExample } from '@/components/ruby-code-example';
import { EditPageLink } from '@/components/edit-page-link';
import { CodeBlock } from '@/components/code-block';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import Link from 'next/dist/client/link';

export default function ConfigurationPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="configuration" level={1}>
        Configuration
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-400">
        LogStruct is designed to be highly configurable while working with
        sensible defaults. You can customize how and where logs are generated,
        which integrations are enabled, and how errors are handled.
      </p>

      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        Create a file at
        <code className="px-1 py-0.5 bg-neutral-100 dark:bg-neutral-800 rounded">
          config/initializers/logstruct.rb
        </code>{' '}
        with your desired configuration.
      </p>

      <RubyCodeExample name="basic_configuration" />

      <HeadingWithAnchor id="environment-configuration">
        Environment Configuration
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct supports different environments and handles them
        appropriately:
      </p>

      <RubyCodeExample name="environment_configuration" />

      <HeadingWithAnchor id="integration-configuration">
        Integration Configuration
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct integrates with many popular gems. You can enable or disable
        specific integrations:
      </p>

      <RubyCodeExample name="integrations_configuration" />

      <HeadingWithAnchor id="filtering-sensitive-data">
        Filtering Sensitive Data
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct includes robust filtering for sensitive data to ensure privacy
        and security:
      </p>

      <RubyCodeExample name="filter_configuration" />

      <HeadingWithAnchor id="error-handling-configuration">
        Error Handling Configuration
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct provides customizable error handling modes to control how
        errors are processed. You probably don&apos;t want type-checking errors
        or internal logging-related errors to crash your application, so our
        default behavior is to log and report those errors without crashing. We
        automatically detect which error reporting service you use (Sentry,
        Bugsnag, Rollbar, etc.). If you use a service that we don&apos;t support
        yet, you can configure a{' '}
        <Link
          className="text-gray-200 hover:underline"
          href="#custom-error-reporting"
        >
          custom error handler
        </Link>
        . (Or you can send a PR!)
      </p>

      <RubyCodeExample name="error_handling_modes" />

      <HeadingWithAnchor id="custom-lograge-options">
        Custom Lograge Options
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        You can extend Lograge request logging with custom fields:
      </p>

      <RubyCodeExample name="lograge_custom_options" />

      <HeadingWithAnchor id="custom-string-scrubbing">
        Custom String Scrubbing
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        You can implement custom string scrubbers to filter out sensitive data
        that isn&apos;t caught by the built-in filters:
      </p>

      <RubyCodeExample name="custom_string_scrubber" />

      <HeadingWithAnchor id="custom-error-reporting">
        Custom Error Reporting
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        You can customize how errors are reported by implementing your own error
        reporting handler:
      </p>

      <RubyCodeExample name="error_reporting_handler" />

      <HeadingWithAnchor id="sorbet-integration">
        Sorbet Integration
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct integrates with Sorbet to handle type checking errors based on
        the environment. We raise type errors or logging-related errors in
        test/development so you can catch them early, but we only log or report
        them in production. You can configure a different error handling mode to
        change this behavior.
      </p>

      <CodeBlock language="ruby">
        {`# Enable Sorbet error handling
config.integrations.enable_sorbet_error_handlers = true

# This configures the following error handlers:
# - T::Configuration.inline_type_error_handler
# - T::Configuration.call_validation_error_handler
# - T::Configuration.sig_builder_error_handler
# - T::Configuration.sig_validation_error_handler`}
      </CodeBlock>

      <EditPageLink />
    </div>
  );
}
