import { Prism as SyntaxHighlighter } from "react-syntax-highlighter";
import { atomDark } from "react-syntax-highlighter/dist/esm/styles/prism";
import { EditPageLink } from "@/components/edit-page-link";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";

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
          <SyntaxHighlighter
            language="json"
            style={atomDark}
            customStyle={{
              fontSize: "0.875rem",
              fontFamily:
                "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace",
              backgroundColor: "transparent",
              padding: "0",
              margin: "0",
              borderRadius: "0px",
            }}
          >
            {`{
  "ts": "2023-09-15T12:34:56.789Z",
  "src": "mailer",
  "evt": "deliver",
  "lvl": "info",
  "mailer": "UserMailer",
  "action": "welcome",
  "to": "[EMAIL:a1b2c3]",
  "subject": "Welcome to our app!",
  "message_id": "<abc123@example.com>",
  "duration_ms": 125.45
}`}
          </SyntaxHighlighter>
        </TabsContent>
        <TabsContent
          value="error"
          className="mt-0 rounded-tl-none bg-neutral-100 p-4 dark:bg-neutral-900"
        >
          <SyntaxHighlighter
            language="json"
            style={atomDark}
            customStyle={{
              fontSize: "0.875rem",
              fontFamily:
                "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace",
              backgroundColor: "transparent",
              padding: "0",
              margin: "0",
              borderRadius: "0px",
            }}
          >
            {`{
  "ts": "2023-09-15T12:34:56.789Z",
  "src": "mailer",
  "evt": "error",
  "lvl": "error",
  "mailer": "NotificationMailer",
  "action": "weekly_digest",
  "to": "[EMAIL:d4e5f6]",
  "error": "SMTP connection failed",
  "message": "Failed to connect to SMTP server",
  "backtrace": ["app/mailers/notification_mailer.rb:25:in 'weekly_digest'", "..."]
}`}
          </SyntaxHighlighter>
        </TabsContent>
      </Tabs>

      <h2 className="text-2xl font-bold mt-10 mb-4">ActiveJob Integration</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        The ActiveJob integration logs job enqueuing, execution, and completion
        events with detailed information about the job.
      </p>

      <div className="rounded-lg bg-neutral-100 p-4 dark:bg-neutral-900">
        <SyntaxHighlighter
          language="ruby"
          style={atomDark}
          customStyle={{
            fontSize: "0.875rem",
            fontFamily:
              "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace",
            backgroundColor: "transparent",
            padding: "0",
            borderRadius: "0px",
          }}
        >
          {`# Example of logged information for ActiveJob
{
  "ts": "2023-09-15T12:34:56.789Z",
  "src": "job",
  "evt": "perform",
  "lvl": "info",
  "job_id": "abc123def456",
  "job_class": "ProcessUserDataJob",
  "queue": "default",
  "arguments": ["user_123", {"action": "update"}],
  "duration_ms": 125.45
}`}
        </SyntaxHighlighter>
      </div>

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
            <SyntaxHighlighter
              language="json"
              style={atomDark}
              customStyle={{
                fontSize: "0.875rem",
                fontFamily:
                  "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace",
                backgroundColor: "transparent",
                padding: "0",
                borderRadius: "0px",
              }}
            >
              {`{
  "ts": "2023-09-15T12:34:56.789Z",
  "src": "sidekiq",
  "evt": "process",
  "lvl": "info",
  "pid": 12345,
  "tid": "abcd1234",
  "job_id": "ef678gh90ij",
  "class": "ImportJob",
  "queue": "default",
  "args": ["user_id_123", {"action": "import"}],
  "status": "success",
  "duration_ms": 234.56,
  "retry_count": 0
}`}
            </SyntaxHighlighter>
          </div>
        </TabsContent>

        <TabsContent value="error" className="mt-4">
          <div className="rounded-lg bg-neutral-100 p-4 dark:bg-neutral-900">
            <SyntaxHighlighter
              language="json"
              style={atomDark}
              customStyle={{
                fontSize: "0.875rem",
                fontFamily:
                  "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace",
                backgroundColor: "transparent",
                padding: "0",
                borderRadius: "0px",
              }}
            >
              {`{
  "ts": "2023-09-15T12:34:56.789Z",
  "src": "sidekiq",
  "evt": "error",
  "lvl": "error",
  "pid": 12345,
  "tid": "abcd1234",
  "job_id": "ef678gh90ij",
  "class": "ImportJob",
  "queue": "default",
  "args": ["user_id_123", {"action": "import"}],
  "error": "NoMethodError",
  "message": "undefined method 'import_data' for nil:NilClass",
  "backtrace": ["app/jobs/import_job.rb:25:in 'perform'", "..."],
  "retry_count": 2,
  "retry": true
}`}
            </SyntaxHighlighter>
          </div>
        </TabsContent>
      </Tabs>

      <h2 className="text-2xl font-bold mt-10 mb-4">Lograge Integration</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct configures Lograge to output request logs in a structured JSON
        format compatible with the rest of your logs. This includes parameters,
        response status, controller and action names, and request duration.
      </p>

      <div className="rounded-lg bg-neutral-100 p-4 dark:bg-neutral-900">
        <SyntaxHighlighter
          language="ruby"
          style={atomDark}
          customStyle={{
            fontSize: "0.875rem",
            fontFamily:
              "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace",
            backgroundColor: "transparent",
            padding: "0",
            borderRadius: "0px",
          }}
        >
          {`# Example of customizing Lograge options to add user ID to requests
LogStruct.configure do |config|
  config.lograge_custom_options = ->(event, options) do
    # Current user from Devise, for example
    user = event.payload[:request]&.env["warden"]&.user
    
    # Add user ID if available
    options[:user_id] = user.id if user
    
    # You can add any other fields from the request context
    options
  end
end`}
        </SyntaxHighlighter>
      </div>

      <h2 className="text-2xl font-bold mt-10 mb-4">Shrine Integration</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        The Shrine integration adds structured logging for file uploads and
        other Shrine operations, including file metadata and operation duration.
      </p>

      <h2 className="text-2xl font-bold mt-10 mb-4">CarrierWave Integration</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        Similar to the Shrine integration, the CarrierWave integration adds
        structured logging for file upload operations.
      </p>

      <h2 className="text-2xl font-bold mt-10 mb-4">
        ActiveStorage Integration
      </h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        The ActiveStorage integration logs uploads, downloads, deletes, and
        other file operations with detailed information about the file and
        storage service.
      </p>

      <h2 className="text-2xl font-bold mt-10 mb-4">Rack Error Handler</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct includes a Rack middleware that enhances error logging for
        Rails applications. This middleware catches and logs security violations
        and other exceptions with detailed context.
      </p>

      <div className="rounded-lg bg-neutral-100 p-4 dark:bg-neutral-900">
        <SyntaxHighlighter
          language="ruby"
          style={atomDark}
          customStyle={{
            fontSize: "0.875rem",
            fontFamily:
              "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace",
            backgroundColor: "transparent",
            padding: "0",
            borderRadius: "0px",
          }}
        >
          {`# The rack error handler logs security violations like:
# - IP spoofing attacks
# - CSRF token errors
# - Blocked host attempts
# - General exceptions during request processing

# Example log of an IP spoofing attempt
{
  "ts": "2023-09-15T12:34:56.789Z",
  "src": "security",
  "evt": "ip_spoof",
  "lvl": "error",
  "client_ip": "[IP]", 
  "x_forwarded_for": "[IP]",
  "path": "/api/users",
  "method": "GET"
}`}
        </SyntaxHighlighter>
      </div>

      <h2 className="text-2xl font-bold mt-10 mb-4">Host Authorization</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        This integration adds structured logging for blocked host attempts when
        using Rails' host authorization feature, helping you detect potential
        security issues.
      </p>

      <h2 className="text-2xl font-bold mt-10 mb-4">Sorbet Integration</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct integrates with Sorbet to handle type checking errors
        appropriately based on the environment, using the "fail hard in
        development, fail soft in production" philosophy.
      </p>

      <div className="rounded-lg bg-neutral-100 p-4 dark:bg-neutral-900">
        <SyntaxHighlighter
          language="ruby"
          style={atomDark}
          customStyle={{
            fontSize: "0.875rem",
            fontFamily:
              "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace",
            backgroundColor: "transparent",
            padding: "0",
            borderRadius: "0px",
          }}
        >
          {`# Enable Sorbet error handling
config.integrations.enable_sorbet_error_handler = true

# This configures the following error handlers:
# - T::Configuration.inline_type_error_handler
# - T::Configuration.call_validation_error_handler
# - T::Configuration.sig_builder_error_handler
# - T::Configuration.sig_validation_error_handler`}
        </SyntaxHighlighter>
      </div>

      <h2 className="text-2xl font-bold mt-10 mb-4">
        Enabling or Disabling Integrations
      </h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        You can enable or disable specific integrations in your LogStruct
        configuration:
      </p>

      <div className="rounded-lg bg-neutral-100 p-4 dark:bg-neutral-900">
        <SyntaxHighlighter
          language="ruby"
          style={atomDark}
          customStyle={{
            fontSize: "0.875rem",
            fontFamily:
              "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace",
            backgroundColor: "transparent",
            padding: "0",
            borderRadius: "0px",
          }}
        >
          {`LogStruct.configure do |config|
  # Enable only specific integrations
  config.integrations.enable_lograge = true
  config.integrations.enable_actionmailer = true
  config.integrations.enable_activejob = false # Disable ActiveJob integration
  config.integrations.enable_sidekiq = defined?(::Sidekiq) # Only enable if Sidekiq is available
  
  # Check for optional gems before enabling integrations
  if defined?(::Shrine)
    config.integrations.enable_shrine = true
  end
end`}
        </SyntaxHighlighter>
      </div>

      <EditPageLink />
    </div>
  );
}
