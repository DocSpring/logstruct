import { RubyCodeExample } from '@/components/ruby-code-example';
import { EditPageLink } from '@/components/edit-page-link';
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { atomDark } from 'react-syntax-highlighter/dist/esm/styles/prism';

export default function ConfigurationPage() {
  return (
    <div className="space-y-6">
      <h1 className="text-4xl font-bold">Configuration</h1>
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

      <h2 className="text-2xl font-bold mt-10 mb-4">
        Environment Configuration
      </h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct supports different environments and handles them
        appropriately:
      </p>

      <RubyCodeExample name="environment_configuration" />

      <h2 className="text-2xl font-bold mt-10 mb-4">
        Integration Configuration
      </h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct integrates with many popular gems. You can enable or disable
        specific integrations:
      </p>

      <RubyCodeExample name="integrations_configuration" />

      <h2 className="text-2xl font-bold mt-10 mb-4">
        Filtering Sensitive Data
      </h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct includes robust filtering for sensitive data to ensure privacy
        and security:
      </p>

      <RubyCodeExample name="filter_configuration" />

      <h2 className="text-2xl font-bold mt-10 mb-4">
        Error Handling Configuration
      </h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct provides different error handling modes to control how errors
        are processed:
      </p>

      <RubyCodeExample name="error_handling_modes" />

      <h2 className="text-2xl font-bold mt-10 mb-4">Custom Lograge Options</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        You can extend Lograge request logging with custom fields:
      </p>

      <RubyCodeExample name="lograge_custom_options" />

      <h2 className="text-2xl font-bold mt-10 mb-4">Custom String Scrubbing</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        You can implement custom string scrubbers to filter out sensitive data
        that isn&apos;t caught by the built-in filters:
      </p>

      <RubyCodeExample name="custom_string_scrubber" />

      <h2 className="text-2xl font-bold mt-10 mb-4">Custom Error Reporting</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        You can customize how errors are reported by implementing your own error
        reporting handler:
      </p>

      <RubyCodeExample name="error_reporting_handler" />

      <EditPageLink />
    </div>
  );
}
