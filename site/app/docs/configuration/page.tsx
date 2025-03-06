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

      <h2 className="text-2xl font-bold mt-10 mb-4">Basic Configuration</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        While LogStruct works out of the box with minimal configuration, you may
        want to customize it to suit your application&apos;s needs. Create a
        file at
        <code className="px-1 py-0.5 bg-neutral-100 dark:bg-neutral-800 rounded">
          config/initializers/logstruct.rb
        </code>{' '}
        with your desired configuration.
      </p>

      <RubyCodeExample
        name="basic_configuration"
        title="Basic Configuration Example"
      />

      <h2 className="text-2xl font-bold mt-10 mb-4">
        Environment Configuration
      </h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct supports different environments and handles them
        appropriately:
      </p>

      <div className="rounded-lg bg-neutral-100 p-4 dark:bg-neutral-900">
        <SyntaxHighlighter
          language="ruby"
          style={atomDark}
          customStyle={{
            fontSize: '0.875rem',
            fontFamily:
              'ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace',
            backgroundColor: 'transparent',
            padding: '0',
            borderRadius: '0px',
          }}
        >
          {`# Enable LogStruct in specific environments
config.environments = [:development, :test, :production]

# Specify which environments are considered local/development
# This affects error handling behavior (fail hard in dev, soft in prod)
config.local_environments = [:development, :test]`}
        </SyntaxHighlighter>
      </div>

      <h2 className="text-2xl font-bold mt-10 mb-4">
        Integration Configuration
      </h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct integrates with many popular gems. You can enable or disable
        specific integrations:
      </p>

      <div className="rounded-lg bg-neutral-100 p-4 dark:bg-neutral-900">
        <RubyCodeExample
          name="integrations_configuration"
          title="Integrations Configuration"
        />
      </div>

      <h2 className="text-2xl font-bold mt-10 mb-4">
        Filtering Sensitive Data
      </h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct includes robust filtering for sensitive data to ensure privacy
        and security:
      </p>

      <div className="rounded-lg bg-neutral-100 p-4 dark:bg-neutral-900">
        <RubyCodeExample
          name="filter_configuration"
          title="Sensitive Data Filtering Configuration"
        />
      </div>

      <h2 className="text-2xl font-bold mt-10 mb-4">
        Error Handling Configuration
      </h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct provides different error handling modes to control how errors
        are processed:
      </p>

      <div className="rounded-lg bg-neutral-100 p-4 dark:bg-neutral-900">
        <RubyCodeExample
          name="error_handling_modes"
          title="Error Handling Modes Configuration"
        />
      </div>

      <h2 className="text-2xl font-bold mt-10 mb-4">Custom Lograge Options</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        You can extend Lograge request logging with custom fields:
      </p>

      <div className="rounded-lg bg-neutral-100 p-4 dark:bg-neutral-900">
        <RubyCodeExample
          name="lograge_custom_options"
          title="Lograge Custom Options Configuration"
        />
      </div>

      <h2 className="text-2xl font-bold mt-10 mb-4">Custom String Scrubbing</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        You can implement custom string scrubbers to filter out sensitive data
        that isn&apos;t caught by the built-in filters:
      </p>

      <div className="rounded-lg bg-neutral-100 p-4 dark:bg-neutral-900">
        <RubyCodeExample
          name="custom_string_scrubber"
          title="Custom String Scrubber Example"
        />
      </div>

      <h2 className="text-2xl font-bold mt-10 mb-4">Custom Error Reporting</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        You can customize how errors are reported by implementing your own error
        reporting handler:
      </p>

      <div className="rounded-lg bg-neutral-100 p-4 dark:bg-neutral-900">
        <RubyCodeExample
          name="error_reporting_handler"
          title="Custom Error Reporter Example"
        />
      </div>

      <EditPageLink />
    </div>
  );
}
