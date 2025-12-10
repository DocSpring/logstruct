import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { Callout } from '@/components/ui/callout';

export default function ForkingServersPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="forking-servers" level={1}>
        Forking Web Servers
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-300">
        How LogStruct handles forking web servers like Puma and Unicorn, and why logs might go
        missing without proper configuration.
      </p>

      <HeadingWithAnchor id="the-problem" level={2}>
        The Problem
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct uses SemanticLogger as its logging engine. By default, SemanticLogger processes
        logs asynchronously in a background thread for maximum performance. However, this creates a
        problem with forking web servers:
      </p>

      <ol className="list-decimal list-outside ml-6 space-y-3 text-neutral-600 dark:text-neutral-300 mb-6">
        <li>
          <strong>Master process starts</strong> - SemanticLogger creates its async processor thread
        </li>
        <li>
          <strong>Master forks worker processes</strong> - Workers inherit a reference to the
          (now-dead) parent thread
        </li>
        <li>
          <strong>Workers write logs</strong> - Logs go to a dead thread and never appear
        </li>
      </ol>

      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        This affects any forking server: Puma (cluster mode), Unicorn, Passenger, and others.
      </p>

      <HeadingWithAnchor id="how-logstruct-handles-it" level={2}>
        How LogStruct Handles It
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct automatically detects when Puma is being used and switches SemanticLogger to
        synchronous mode. In sync mode, logs are processed immediately in the calling thread instead
        of being queued to a background thread.
      </p>

      <CodeBlock language="ruby">
        {`# This happens automatically when LogStruct detects Puma
SemanticLogger.sync!`}
      </CodeBlock>

      <p className="text-neutral-600 dark:text-neutral-300 mt-4 mb-4">
        Additionally, LogStruct configures all appenders with <code>async: false</code> to ensure no
        background threads are used for log processing.
      </p>

      <HeadingWithAnchor id="puma-integration" level={2}>
        Puma Integration
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct provides deep Puma integration:
      </p>

      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300 mb-6">
        <li>
          <strong>Lifecycle events</strong> - Structured logs for server start and shutdown
        </li>
        <li>
          <strong>Sync mode</strong> - Automatic switch to synchronous logging
        </li>
        <li>
          <strong>Output interception</strong> - Captures Puma&apos;s startup messages and converts
          them to structured JSON
        </li>
      </ul>

      <p className="text-neutral-600 dark:text-neutral-300 mb-4">Example Puma start log:</p>

      <CodeBlock language="json">
        {`{
  "src": "puma",
  "evt": "start",
  "lvl": "info",
  "ts": "2025-01-15T10:30:00.000Z",
  "mode": "cluster",
  "puma_version": "6.4.2",
  "ruby_version": "3.3.0",
  "min_threads": 5,
  "max_threads": 5,
  "environment": "production",
  "pid": 12345,
  "listening_addresses": ["tcp://0.0.0.0:3000"]
}`}
      </CodeBlock>

      <HeadingWithAnchor id="unicorn" level={2}>
        Unicorn
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        For Unicorn, you need to manually configure SemanticLogger to restart after fork. Add this
        to your <code>config/unicorn.rb</code>:
      </p>

      <CodeBlock language="ruby">
        {`after_fork do |server, worker|
  # Reopen file handles after fork
  SemanticLogger.reopen

  # Or use sync mode instead
  # SemanticLogger.sync!
end`}
      </CodeBlock>

      <HeadingWithAnchor id="passenger" level={2}>
        Passenger
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        Passenger handles forking differently and typically works without special configuration.
        However, if you experience missing logs, add to your initializer:
      </p>

      <CodeBlock language="ruby">
        {`if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    if forked
      SemanticLogger.reopen
    end
  end
end`}
      </CodeBlock>

      <HeadingWithAnchor id="performance-considerations" level={2}>
        Performance Considerations
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        Synchronous logging means each log call blocks until the log is written. For most
        applications, this overhead is negligible (microseconds per log). However, for extremely
        high-throughput applications, consider:
      </p>

      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300 mb-6">
        <li>Using buffered IO for file appenders</li>
        <li>Logging to local sockets (faster than files)</li>
        <li>Reducing log verbosity in hot paths</li>
      </ul>

      <Callout type="info">
        The synchronous overhead is typically far less important than the bugs caused by missing
        logs in async mode with forking servers.
      </Callout>

      <EditPageLink />
    </div>
  );
}
