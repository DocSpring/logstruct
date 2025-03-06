import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { RubyCodeExample } from '@/components/ruby-code-example';
import {
  getActionMailerDeliverLog,
  getActionMailerErrorLog,
  getActiveJobLog,
  getSidekiqProcessLog,
  getSidekiqErrorLog,
  getRackErrorLog,
  getHostAuthorizationLog,
  getLogRageLog,
  getShrineLog,
  getCarrierWaveLog,
  getActiveStorageLog,
} from '@/lib/log-generation';

export default function IntegrationsPage() {
  return (
    <div className="space-y-6">
      <h1 className="text-4xl font-bold">Integrations</h1>
      <p className="text-lg text-neutral-600 dark:text-neutral-400">
        LogStruct integrates with many popular gems and Rails components to
        provide comprehensive structured logging throughout your application.
        These integrations automatically hook into important events and capture
        relevant context for better observability.
      </p>

      <h2 className="text-2xl font-bold mt-10 mb-4">
        ActionMailer Integration
      </h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        The ActionMailer integration automatically logs email delivery events
        and handles errors during email delivery. (If you&apos;re still on Rails
        7.0.x, it also backports delivery callbacks from Rails 7.1.)
      </p>

      <h3 className="text-xl font-semibold mt-6 mb-3">Example Logs</h3>

      <Tabs defaultValue="deliver">
        <TabsList className="mb-0">
          <TabsTrigger value="deliver">Deliver Log</TabsTrigger>
          <TabsTrigger value="error">Error Log</TabsTrigger>
        </TabsList>
        <TabsContent
          value="deliver"
          className="mt-0 rounded-tl-none bg-neutral-100 p-4 dark:bg-neutral-900"
        >
          <CodeBlock language="json" unwrapped={true}>
            {getActionMailerDeliverLog()}
          </CodeBlock>
        </TabsContent>
        <TabsContent
          value="error"
          className="mt-0 rounded-tl-none bg-neutral-100 p-4 dark:bg-neutral-900"
        >
          <CodeBlock language="json" unwrapped={true}>
            {getActionMailerErrorLog()}
          </CodeBlock>
        </TabsContent>
      </Tabs>

      <h2 className="text-2xl font-bold mt-10 mb-4">ActiveJob Integration</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        The ActiveJob integration logs job enqueuing, execution, and completion
        events with detailed information about the job.
      </p>

      <CodeBlock language="json">{getActiveJobLog()}</CodeBlock>

      <h2 className="text-2xl font-bold mt-10 mb-4">Sidekiq Integration</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        The Sidekiq integration configures structured JSON logging for Sidekiq
        worker and client logs, maintaining consistent format with other logs.
      </p>

      <h3 className="text-xl font-semibold mt-6 mb-3">Example Logs</h3>

      <Tabs defaultValue="process" className="mt-4">
        <TabsList>
          <TabsTrigger value="process">Process Log</TabsTrigger>
          <TabsTrigger value="error">Error Log</TabsTrigger>
        </TabsList>

        <TabsContent value="process" className="mt-4">
          <div className="rounded-lg bg-neutral-100 p-4 dark:bg-neutral-900">
            <CodeBlock language="json" unwrapped={true}>
              {getSidekiqProcessLog()}
            </CodeBlock>
          </div>
        </TabsContent>

        <TabsContent value="error" className="mt-4">
          <div className="rounded-lg bg-neutral-100 p-4 dark:bg-neutral-900">
            <CodeBlock language="json" unwrapped={true}>
              {getSidekiqErrorLog()}
            </CodeBlock>
          </div>
        </TabsContent>
      </Tabs>

      <h2 className="text-2xl font-bold mt-10 mb-4">Lograge Integration</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct configures Lograge to output request logs in a structured JSON
        format compatible with the rest of your logs. This includes parameters,
        response status, controller and action names, and request duration.
      </p>

      <RubyCodeExample name="lograge_custom_options" />

      <div className="mt-4">
        <CodeBlock language="json">{getLogRageLog()}</CodeBlock>
      </div>

      <h2 className="text-2xl font-bold mt-10 mb-4">Shrine Integration</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        The Shrine integration adds structured logging for file uploads and
        other Shrine operations, including file metadata and operation duration.
      </p>

      <CodeBlock language="json">{getShrineLog()}</CodeBlock>

      <h2 className="text-2xl font-bold mt-10 mb-4">CarrierWave Integration</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        Similar to the Shrine integration, the CarrierWave integration adds
        structured logging for file upload operations.
      </p>

      <CodeBlock language="json">{getCarrierWaveLog()}</CodeBlock>

      <h2 className="text-2xl font-bold mt-10 mb-4">
        ActiveStorage Integration
      </h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        The ActiveStorage integration logs uploads, downloads, deletes, and
        other file operations with detailed information about the file and
        storage service.
      </p>

      <CodeBlock language="json">{getActiveStorageLog()}</CodeBlock>

      <h2 className="text-2xl font-bold mt-10 mb-4">Rack Error Handler</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct includes a Rack middleware that enhances error logging for
        Rails applications. This middleware catches and logs security violations
        and other exceptions with detailed context. The rack error handler logs
        security violations like:
        <ul className="list-disc list-inside">
          <li>IP spoofing attacks</li>
          <li>CSRF token errors</li>
          <li>Blocked host attempts</li>
          <li>General exceptions during request processing</li>
        </ul>
      </p>

      <CodeBlock language="json">{getRackErrorLog()}</CodeBlock>

      <h2 className="text-2xl font-bold mt-10 mb-4">Host Authorization</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        This integration adds structured logging for blocked host attempts when
        using Rails&apos; host authorization feature, helping you detect
        potential security issues.
      </p>

      <CodeBlock language="json">{getHostAuthorizationLog()}</CodeBlock>

      <h2 className="text-2xl font-bold mt-10 mb-4">Sorbet Integration</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct integrates with Sorbet to handle type checking errors
        appropriately based on the environment. We raise any logging-related
        errors in test/development and log or report them in production to avoid
        crashing your application.
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
