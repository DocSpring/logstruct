import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { Callout } from '@/components/ui/callout';

export default function TroubleshootingPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="troubleshooting" level={1}>
        Troubleshooting
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-300">
        Debugging missing logs, configuration issues, and understanding LogStruct internals.
      </p>

      <HeadingWithAnchor id="debug-mode" level={2}>
        Debug Mode
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct includes comprehensive internal debug logging. Enable it to trace exactly how logs
        flow through the system:
      </p>

      <CodeBlock language="bash">
        {`# Enable all debug topics
LOGSTRUCT_DEBUG=true rails server

# Enable specific topics only
LOGSTRUCT_DEBUG=true LOGSTRUCT_DEBUG_TOPICS=lograge,formatter rails server

# Also write debug logs to a file
LOGSTRUCT_DEBUG=true LOGSTRUCT_LOG_FILE=/tmp/logstruct.log rails server`}
      </CodeBlock>

      <HeadingWithAnchor id="debug-topics" level={3}>
        Available Debug Topics
      </HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300 mb-6">
        <li>
          <code>formatter</code> - SemanticLogger formatter processing (most useful for missing
          logs)
        </li>
        <li>
          <code>lograge</code> - Lograge integration and request formatting
        </li>
        <li>
          <code>puma</code> - Puma lifecycle events and patching
        </li>
        <li>
          <code>log_methods</code> - How logs are routed through LogMethods
        </li>
        <li>
          <code>setup</code> - SemanticLogger setup and appender configuration
        </li>
        <li>
          <code>railtie</code> - Rails integration initialization
        </li>
        <li>
          <code>active_job</code> - ActiveJob integration
        </li>
        <li>
          <code>active_storage</code> - ActiveStorage integration
        </li>
        <li>
          <code>shrine</code> - Shrine integration
        </li>
        <li>
          <code>sql</code> - SQL query logging
        </li>
      </ul>

      <HeadingWithAnchor id="missing-request-logs" level={2}>
        Missing Request Logs
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        If request logs (from Lograge) aren&apos;t appearing, check these in order:
      </p>

      <HeadingWithAnchor id="check-1-lograge-enabled" level={3}>
        1. Verify Lograge Integration is Enabled
      </HeadingWithAnchor>
      <CodeBlock language="ruby">
        {`# In rails console
LogStruct.config.integrations.enable_lograge
# => should be true

# Check if Lograge is actually loaded
defined?(Lograge)
# => should return "constant"`}
      </CodeBlock>

      <HeadingWithAnchor id="check-2-lograge-logger" level={3}>
        2. Verify Lograge Logger
      </HeadingWithAnchor>
      <CodeBlock language="ruby">
        {`# Lograge should use Rails.logger (which is our SemanticLogger)
Lograge.logger.class
# => should be LogStruct::SemanticLogger::Logger

# If it's nil or a different logger, LogStruct integration may have failed
Lograge.logger`}
      </CodeBlock>

      <HeadingWithAnchor id="check-3-formatter" level={3}>
        3. Check Lograge Formatter
      </HeadingWithAnchor>
      <CodeBlock language="ruby">
        {`# The formatter should return a Log::Request struct, not a string
Rails.application.config.lograge.formatter
# => should be a Proc

# Test the formatter
Rails.application.config.lograge.formatter.call({
  method: "GET",
  path: "/test",
  status: 200,
  duration: 100.0
})
# => should return a LogStruct::Log::Request instance`}
      </CodeBlock>

      <HeadingWithAnchor id="check-4-subscribers" level={3}>
        4. Check ActionController Subscribers
      </HeadingWithAnchor>
      <CodeBlock language="ruby">
        {`# Lograge subscribes to process_action.action_controller
subs = ActiveSupport::Notifications.notifier.listeners_for("process_action.action_controller")
subs.size
# => should be at least 1

# If 0 or missing Lograge subscriber, call setup manually:
Lograge.setup(Rails.application)`}
      </CodeBlock>

      <HeadingWithAnchor id="missing-logs-forking" level={2}>
        Missing Logs After Fork
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        If logs work in single-process mode but disappear in cluster mode (Puma workers, Unicorn),
        the issue is almost certainly async logging with forking:
      </p>

      <HeadingWithAnchor id="diagnosis" level={3}>
        Diagnosis
      </HeadingWithAnchor>
      <CodeBlock language="ruby">
        {`# Check if SemanticLogger is in sync mode
SemanticLogger.sync?
# => should be true for Puma cluster mode

# Check appender configuration
SemanticLogger.appenders.each do |appender|
  puts "#{appender.class}: async=#{appender.async?}"
end
# => all should show async=false`}
      </CodeBlock>

      <HeadingWithAnchor id="fix-forking" level={3}>
        Fix
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct should handle this automatically for Puma. If it&apos;s not working:
      </p>

      <CodeBlock language="ruby">
        {`# Force sync mode in your initializer
SemanticLogger.sync!

# Or add to puma.rb
on_worker_boot do
  SemanticLogger.reopen
end`}
      </CodeBlock>

      <Callout type="warning">
        See the <a href="/docs/forking-servers">Forking Web Servers</a> documentation for detailed
        information about this issue.
      </Callout>

      <HeadingWithAnchor id="log-flow-architecture" level={2}>
        Log Flow Architecture
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        Understanding how logs flow through LogStruct helps debug issues:
      </p>

      <CodeBlock language="text">
        {`┌─────────────────────────────────────────────────────────────────┐
│                        YOUR APPLICATION                         │
│  Rails.logger.info("message")   or   LogStruct.info(struct)     │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                LogStruct::SemanticLogger::Logger                │
│                                                                 │
│  • Extends SemanticLogger::Logger                               │
│  • Wraps structs/hashes in payload for SemanticLogger           │
│  • Topic: log_methods                                           │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SemanticLogger Core                          │
│                                                                 │
│  • Processes log through appenders                              │
│  • In sync mode: immediate processing                           │
│  • In async mode: queues to Processor thread                    │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│              LogStruct::SemanticLogger::Formatter               │
│                                                                 │
│  • Extracts LogStruct from payload                              │
│  • Calls LogStruct::Formatter for JSON serialization            │
│  • Topic: formatter                                             │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    LogStruct::Formatter                         │
│                                                                 │
│  • Applies filters (sensitive data scrubbing)                   │
│  • Serializes struct to JSON                                    │
│  • Adds metadata (prog, timestamp format)                       │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                         STDOUT / File                           │
│                                                                 │
│  {"src":"app","evt":"log","msg":"Hello",...}                    │
└─────────────────────────────────────────────────────────────────┘`}
      </CodeBlock>

      <HeadingWithAnchor id="lograge-flow" level={3}>
        Lograge Request Flow
      </HeadingWithAnchor>
      <CodeBlock language="text">
        {`┌─────────────────────────────────────────────────────────────────┐
│              ActionController processes request                 │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│       ActiveSupport::Notifications                              │
│       "process_action.action_controller"                        │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Lograge Subscriber                           │
│                                                                 │
│  • Receives event notification                                  │
│  • Calls custom_options proc                                    │
│  • Calls formatter proc                                         │
│  • Topic: lograge                                               │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│              LogStruct Lograge Formatter                        │
│                                                                 │
│  • Creates Log::Request struct from event data                  │
│  • Returns struct (NOT string)                                  │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│         Lograge.logger.info(struct)                             │
│         (which is Rails.logger / SemanticLogger)                │
└─────────────────────────────────────────────────────────────────┘
                                  │
                            (continues to normal log flow above)`}
      </CodeBlock>

      <HeadingWithAnchor id="common-issues" level={2}>
        Common Issues
      </HeadingWithAnchor>

      <HeadingWithAnchor id="issue-duplicate-logs" level={3}>
        Duplicate Request Logs
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        If you see duplicate request logs, Lograge.setup() may have been called twice:
      </p>
      <CodeBlock language="ruby">
        {`# Check subscriber count
ActiveSupport::Notifications.notifier
  .listeners_for("process_action.action_controller").size
# => should be 1, not 2+

# If duplicated, Lograge was likely setup both by:
# 1. config.lograge.enabled = true in environment
# 2. LogStruct calling Lograge.setup()

# Fix: Don't set config.lograge.enabled = true when using LogStruct`}
      </CodeBlock>

      <HeadingWithAnchor id="issue-wrong-json" level={3}>
        Logs Appear But Wrong Format
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        If logs appear but aren&apos;t in LogStruct JSON format:
      </p>
      <CodeBlock language="ruby">
        {`# Check Rails.logger class
Rails.logger.class
# => should be LogStruct::SemanticLogger::Logger

# Check appender formatter
SemanticLogger.appenders.first.formatter.class
# => should be LogStruct::SemanticLogger::Formatter

# If using default SemanticLogger formatter, LogStruct setup failed`}
      </CodeBlock>

      <HeadingWithAnchor id="issue-no-logs" level={3}>
        No Logs At All
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">If no logs appear:</p>
      <CodeBlock language="ruby">
        {`# Check if LogStruct is enabled
LogStruct.config.enabled
# => should be true

# Check if appenders exist
SemanticLogger.appenders.size
# => should be > 0

# Check log level
SemanticLogger.default_level
# => :info, :debug, etc.

# Try logging directly
SemanticLogger["Test"].info("Direct test")
# => should appear in output`}
      </CodeBlock>

      <HeadingWithAnchor id="getting-help" level={2}>
        Getting Help
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        If you&apos;re still stuck after trying these steps:
      </p>
      <ol className="list-decimal list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300 mb-6">
        <li>
          Enable debug mode with <code>LOGSTRUCT_DEBUG=true</code>
        </li>
        <li>Capture the debug output</li>
        <li>
          Open an issue on{' '}
          <a
            href="https://github.com/docspring/logstruct"
            className="text-blue-400 hover:text-blue-300"
          >
            GitHub
          </a>{' '}
          with the debug output and your configuration
        </li>
      </ol>

      <EditPageLink />
    </div>
  );
}
