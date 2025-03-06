import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { atomDark } from 'react-syntax-highlighter/dist/esm/styles/prism';
import { EditPageLink } from '@/components/edit-page-link';

export default function TypeSafetyPage() {
  return (
    <div className="space-y-6">
      <h1 className="text-4xl font-bold">Type Safety</h1>
      <p className="text-lg text-neutral-600 dark:text-neutral-400">
        LogStruct is built with type safety in mind and provides full type
        checking support through Sorbet. This helps catch errors at development
        time and provides better documentation and IDE support.
      </p>

      <h2 className="text-2xl font-bold mt-10 mb-4">
        Using LogStruct with Sorbet
      </h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct includes predefined log structures with strict typing. These
        structures ensure your logs have a consistent format and that required
        fields are always present.
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
          {`# Create a typed request log entry
request_log = LogStruct::Log::Request.new(
  method: "GET",
  path: "/users",
  status: 200,
  duration_ms: 45.2,
  source: LogStruct::Source::Rails
)

# Log the typed struct
Rails.logger.info(request_log)

# Create a typed error log entry
error_log = LogStruct::Log::Error.new(
  exception: StandardError.new("Something went wrong"),
  message: "An error occurred during processing",
  source: LogStruct::Source::App
)

# Log the error
Rails.logger.error(error_log)`}
        </SyntaxHighlighter>
      </div>

      <h2 className="text-2xl font-bold mt-10 mb-4">
        Available Log Structures
      </h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct provides several typed log structures for different use cases:
      </p>

      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-400">
        <li>
          <code className="px-1 py-0.5 bg-neutral-100 dark:bg-neutral-800 rounded">
            LogStruct::Log::Plain
          </code>{' '}
          - For general purpose logging with a message and context
        </li>
        <li>
          <code className="px-1 py-0.5 bg-neutral-100 dark:bg-neutral-800 rounded">
            LogStruct::Log::Request
          </code>{' '}
          - For HTTP request details
        </li>
        <li>
          <code className="px-1 py-0.5 bg-neutral-100 dark:bg-neutral-800 rounded">
            LogStruct::Log::Error
          </code>{' '}
          - For exception details with stack traces
        </li>
        <li>
          <code className="px-1 py-0.5 bg-neutral-100 dark:bg-neutral-800 rounded">
            LogStruct::Log::ActionMailer
          </code>{' '}
          - For email delivery events
        </li>
        <li>
          <code className="px-1 py-0.5 bg-neutral-100 dark:bg-neutral-800 rounded">
            LogStruct::Log::ActiveJob
          </code>{' '}
          - For background job execution
        </li>
        <li>
          <code className="px-1 py-0.5 bg-neutral-100 dark:bg-neutral-800 rounded">
            LogStruct::Log::ActiveStorage
          </code>{' '}
          - For file storage operations
        </li>
        <li>
          <code className="px-1 py-0.5 bg-neutral-100 dark:bg-neutral-800 rounded">
            LogStruct::Log::Shrine
          </code>{' '}
          - For Shrine file upload events
        </li>
        <li>
          <code className="px-1 py-0.5 bg-neutral-100 dark:bg-neutral-800 rounded">
            LogStruct::Log::CarrierWave
          </code>{' '}
          - For CarrierWave upload events
        </li>
        <li>
          <code className="px-1 py-0.5 bg-neutral-100 dark:bg-neutral-800 rounded">
            LogStruct::Log::Sidekiq
          </code>{' '}
          - For Sidekiq job processing
        </li>
        <li>
          <code className="px-1 py-0.5 bg-neutral-100 dark:bg-neutral-800 rounded">
            LogStruct::Log::Security
          </code>{' '}
          - For security-related events
        </li>
      </ul>

      <h2 className="text-2xl font-bold mt-10 mb-4">Enums and Constants</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct provides typed enums for common values used in logs:
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
          {`# Log levels
LogStruct::LogLevel::Debug
LogStruct::LogLevel::Info
LogStruct::LogLevel::Warn
LogStruct::LogLevel::Error
LogStruct::LogLevel::Fatal

# Log sources
LogStruct::Source::Rails
LogStruct::Source::App
LogStruct::Source::Job
LogStruct::Source::Mailer
LogStruct::Source::Security
LogStruct::Source::TypeChecking

# Error handling modes
LogStruct::ErrorHandlingMode::Ignore       # Completely ignore errors
LogStruct::ErrorHandlingMode::Log          # Log errors but don't report them
LogStruct::ErrorHandlingMode::LogProduction # Log in production, raise in development
LogStruct::ErrorHandlingMode::Report       # Log and report errors to error service
LogStruct::ErrorHandlingMode::Raise        # Always raise errors`}
        </SyntaxHighlighter>
      </div>

      <h2 className="text-2xl font-bold mt-10 mb-4">
        Adding Sorbet to Your Application
      </h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        To fully utilize LogStruct&apos;s type safety features, you should add
        Sorbet to your application:
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
          {`# In your Gemfile
gem 'sorbet', group: :development
gem 'sorbet-runtime'

# Then run
bundle install
bundle exec srb init`}
        </SyntaxHighlighter>
      </div>

      <h2 className="text-2xl font-bold mt-10 mb-4">Benefits of Type Safety</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        Using LogStruct&apos;s typed structures provides several benefits:
      </p>

      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-400">
        <li>Catches errors at development time, not at runtime</li>
        <li>Ensures consistent log structure</li>
        <li>Provides better IDE autocompletion</li>
        <li>
          Makes it easier to understand which fields are required and which are
          optional
        </li>
        <li>Improves code documentation through type annotations</li>
        <li>Prevents inappropriate use of undocumented fields</li>
      </ul>

      <h2 className="text-2xl font-bold mt-10 mb-4">
        Error Handling for Type Errors
      </h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct installs appropriate error handlers for Sorbet type checking
        errors.
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
          {`# In development and test environments, type errors will raise exceptions
# In production, type errors will be logged but won't crash your application

# Enable the Sorbet error handler in your LogStruct configuration
LogStruct.configure do |config|
  config.integrations.enable_sorbet_error_handler = true
end`}
        </SyntaxHighlighter>
      </div>

      <h2 className="text-2xl font-bold mt-10 mb-4">
        Creating Custom Log Structures
      </h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        You can create your own typed log structures by extending
        LogStruct&apos;s base classes:
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
          {`# Define a custom log structure with type checking
module MyApp
  module Logs
    class PaymentProcessed < T::Struct
      include LogStruct::Log::Interfaces::CommonFields
      include LogStruct::Log::SerializeCommon
      
      prop :payment_id, String
      prop :amount, Float
      prop :currency, String
      prop :status, String
      prop :user_id, T.nilable(Integer)
      prop :source, LogStruct::Source, default: LogStruct::Source::App
      
      # Use LogStruct::Log::MergeDataFields to automatically include these fields
      # in the log output in a "data" field
      include LogStruct::Log::MergeDataFields
      
      # Use LogStruct::Log::AddRequestFields to add request-related fields
      # to this log structure
      include LogStruct::Log::AddRequestFields
    end
  end
end

# Then use it in your code
payment_log = MyApp::Logs::PaymentProcessed.new(
  payment_id: "pay_123456",
  amount: 99.99,
  currency: "USD",
  status: "succeeded"
)

Rails.logger.info(payment_log)`}
        </SyntaxHighlighter>
      </div>

      <EditPageLink />
    </div>
  );
}
