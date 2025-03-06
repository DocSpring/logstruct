import { EditPageLink } from '@/components/edit-page-link';
import { RubyCodeExample } from '@/components/ruby-code-example';

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
        <RubyCodeExample
          name="basic_typed_logging"
          title="Basic Typed Logging Example"
        />
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
        <RubyCodeExample
          name="log_enums"
          title="Log Levels and Enums"
        />
      </div>

      <h2 className="text-2xl font-bold mt-10 mb-4">
        Adding Sorbet to Your Application
      </h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        To fully utilize LogStruct&apos;s type safety features, you should add
        Sorbet to your application:
      </p>

      <div className="rounded-lg bg-neutral-100 p-4 dark:bg-neutral-900">
        <RubyCodeExample
          name="sorbet_setup"
          title="Setting Up Sorbet"
        />
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
        <RubyCodeExample
          name="sorbet_error_handler"
          title="Sorbet Error Handler Configuration"
        />
      </div>

      <h2 className="text-2xl font-bold mt-10 mb-4">
        Creating Custom Log Structures
      </h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        You can create your own typed log structures by extending
        LogStruct&apos;s base classes:
      </p>

      <div className="rounded-lg bg-neutral-100 p-4 dark:bg-neutral-900">
        <RubyCodeExample
          name="custom_log_structure"
          title="Creating Custom Log Structures"
        />
      </div>

      <EditPageLink />
    </div>
  );
}
