import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { CodeBlock } from '@/components/code-block';
import { Callout } from '@/components/ui/callout';
import { EditPageLink } from '@/components/edit-page-link';

export default function LoggingDocsPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="logging-to-stdout" level={1}>
        Logging to STDOUT (12‑Factor)
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-400">
        LogStruct embraces{' '}
        <a
          className="underline"
          href="https://12factor.net/logs"
          target="_blank"
          rel="noreferrer"
        >
          The Twelve‑Factor App
        </a>{' '}
        approach to logs: write events as unbuffered lines to{' '}
        <code>STDOUT</code> and let the environment aggregate, ship, and store
        them. This section explains how Rails logs by default, how LogStruct
        integrates, and what to configure for a predictable developer
        experience.
      </p>

      <HeadingWithAnchor id="rails-defaults" level={2}>
        Rails Defaults vs. LogStruct
      </HeadingWithAnchor>
      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-400">
        <li>
          <b>Rails (development):</b> writes to <code>log/development.log</code>{' '}
          by default; the server console shows Puma boot lines, not application
          logs.
        </li>
        <li>
          <b>Rails (test):</b> most test runners capture logs; default logger
          often writes to a file.
        </li>
        <li>
          <b>Rails (production):</b> many deploy targets set{' '}
          <code>RAILS_LOG_TO_STDOUT=1</code>, so logs go to STDOUT.
        </li>
        <li>
          <b>LogStruct:</b> when enabled, replaces the logger with
          SemanticLogger and emits JSON to STDOUT in test/production by default.
          In development, you can opt‑in to the same JSON to avoid surprises.
        </li>
      </ul>

      <HeadingWithAnchor id="dev-parity" level={2}>
        Make Development Match Test/Production
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-400">
        Opt‑in locally so development behaves like test/production:
      </p>
      <CodeBlock language="bash">
        {`# One-off
LOGSTRUCT_ENABLED=true RAILS_LOG_TO_STDOUT=1 rails s

# Or set in your shell env for the session
export LOGSTRUCT_ENABLED=true
export RAILS_LOG_TO_STDOUT=1
rails s`}
      </CodeBlock>
      <Callout className="mt-4">
        You can also force STDOUT + debug in development via code (useful for
        teams):
      </Callout>
      <CodeBlock language="ruby">
        {`# config/environments/development.rb (or in your application template)
config.log_level = :debug
logger = ActiveSupport::Logger.new($stdout)
logger.formatter = config.log_formatter
config.logger = ActiveSupport::TaggedLogging.new(logger)`}
      </CodeBlock>

      <HeadingWithAnchor id="production-recommendations" level={2}>
        Production Recommendations
      </HeadingWithAnchor>
      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-400">
        <li>
          Ensure <code>RAILS_LOG_TO_STDOUT=1</code> (many platforms set this by
          default).
        </li>
        <li>
          Keep LogStruct enabled in production (default) to emit structured JSON
          for all integrations.
        </li>
        <li>
          Ship logs to your log aggregation system (e.g., CloudWatch, ELK,
          Datadog) as line‑delimited JSON.
        </li>
      </ul>

      <EditPageLink />
    </div>
  );
}
