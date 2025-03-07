import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';
import { RubyCodeExample } from '@/components/ruby-code-example';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { LogGenerator } from '@/lib/log-generation';
import { LogType, AllLogTypes } from '@/lib/log-generation/log-types';

// Helper to format logs as JSON strings for display
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function formatLog(log: Record<string, any>): string {
  return JSON.stringify(log, null, 2);
}

// Create a single log generator with a fixed seed for consistent examples
const logGenerator = new LogGenerator(12345);

// Generate information for each log type
function getLogTypeInfo(logType: LogType): {
  title: string;
  description: string;
  configuration_code?: string;
} | null {
  switch (logType) {
    case LogType.ACTIONMAILER:
      return {
        title: 'ActionMailer Integration',
        description:
          "The ActionMailer integration automatically logs email delivery events and handles errors during email delivery. (If you're still on Rails 7.0.x, it also backports delivery callbacks from Rails 7.1.)",
      };

    case LogType.ACTIVEJOB:
      return {
        title: 'ActiveJob Integration',
        description:
          'The ActiveJob integration logs job enqueuing, execution, and completion events with detailed information about the job.',
      };

    case LogType.ACTIVESTORAGE:
      return {
        title: 'ActiveStorage Integration',
        description:
          'The ActiveStorage integration logs uploads, downloads, deletes, and other file operations with detailed information about the file and storage service.',
      };

    case LogType.CARRIERWAVE:
      return {
        title: 'CarrierWave Integration',
        description:
          'The CarrierWave integration adds structured logging for file upload operations, including file metadata and operation duration.',
      };

    case LogType.REQUEST:
      return {
        title: 'Request Logs (via Lograge)',
        description:
          'LogStruct configures Lograge to output request logs in a structured JSON format compatible with the rest of your logs. This includes parameters, response status, controller and action names, and request duration. You can log additional data by configuring a lograge_custom_options handler:',
        configuration_code: 'lograge_custom_options',
      };

    case LogType.SECURITY:
      return {
        title: 'Security Logging',
        description:
          'LogStruct includes security-focused logging for Rails applications. This captures security violations like IP spoofing attacks, CSRF token errors, blocked host attempts, and other security-related events.',
      };

    case LogType.SHRINE:
      return {
        title: 'Shrine Integration',
        description:
          'The Shrine integration adds structured logging for file uploads and other Shrine operations, including file metadata and operation duration.',
      };

    case LogType.SIDEKIQ:
      return {
        title: 'Sidekiq Integration',
        description:
          'The Sidekiq integration configures structured JSON logging for Sidekiq worker and client logs, maintaining consistent format with other logs.',
      };

    case LogType.ERROR:
      return {
        title: 'Error Handling',
        description:
          "LogStruct provides structured error logging across your application, capturing error class, message, backtrace, and contextual data for better debugging. (We don't interfere with or replace your existing error reporting library, such as Sentry, Bugsnag, etc.)",
      };

    case LogType.PLAIN:
      // Plain logs are not an integration
      return null;

    default:
      logType satisfies never;
      return {
        title: 'Unknown Integration',
        description: 'No information available for this integration.',
      };
  }
}

export default function IntegrationsPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="integrations" level={1}>
        Integrations
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-400">
        LogStruct integrates with many popular gems and Rails components to
        provide comprehensive structured logging throughout your application.
        These integrations automatically hook into important events and capture
        relevant context for better observability.
      </p>

      {/* Dynamically generate sections for each log type */}
      {AllLogTypes.map((logType) => {
        const logTypeInfo = getLogTypeInfo(logType);
        if (!logTypeInfo) return null; // Skip plain logs, etc.

        const { title, description, configuration_code } = logTypeInfo;

        return (
          <div key={logType} className="mt-10">
            <HeadingWithAnchor
              id={title
                .toLowerCase()
                .replace(/\s+/g, '-')
                .replace(/[^a-z0-9-]/g, '')}
            >
              {title}
            </HeadingWithAnchor>
            <p className="text-neutral-600 dark:text-neutral-400 mb-4">
              {description}
            </p>

            {/* Show Ruby code example if one is specified */}
            {configuration_code && (
              <>
                <HeadingWithAnchor
                  id={`${title
                    .toLowerCase()
                    .replace(/\s+/g, '-')
                    .replace(/[^a-z0-9-]/g, '')}-configuration`}
                  level={2}
                  className="text-xl font-semibold mt-6 mb-3"
                >
                  Configuration
                </HeadingWithAnchor>
                <div className="mb-4">
                  <RubyCodeExample name={configuration_code} />
                </div>
              </>
            )}

            {/* Generate a log example for this type */}
            <HeadingWithAnchor
              id={`${title
                .toLowerCase()
                .replace(/\s+/g, '-')
                .replace(/[^a-z0-9-]/g, '')}-example`}
              level={2}
              className="text-xl font-semibold mt-6 mb-3"
            >
              Example Log
            </HeadingWithAnchor>
            <CodeBlock language="json">
              {formatLog(logGenerator.generateLog(logType))}
            </CodeBlock>
          </div>
        );
      })}

      {/* Special case for Sorbet that doesn't fit the standard pattern */}
      <div className="mt-10">
        <HeadingWithAnchor id="sorbet-integration">
          Sorbet Integration
        </HeadingWithAnchor>
        <p className="text-neutral-600 dark:text-neutral-400 mb-4">
          LogStruct integrates with Sorbet to handle type checking errors
          appropriately based on the environment. We raise any logging-related
          errors in test/development and log or report them in production to
          avoid crashing your application.
        </p>

        <HeadingWithAnchor
          id="sorbet-configuration"
          level={2}
          className="text-xl font-semibold mt-6 mb-3"
        >
          Configuration
        </HeadingWithAnchor>
        <div className="rounded-lg bg-neutral-100 p-4 dark:bg-neutral-900">
          <CodeBlock language="ruby" unwrapped={true}>
            {`# Enable Sorbet error handling
config.integrations.enable_sorbet_error_handlers = true

# This configures the following error handlers:
# - T::Configuration.inline_type_error_handler
# - T::Configuration.call_validation_error_handler
# - T::Configuration.sig_builder_error_handler
# - T::Configuration.sig_validation_error_handler`}
          </CodeBlock>
        </div>
      </div>

      <EditPageLink />
    </div>
  );
}
