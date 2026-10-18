import Link from 'next/link';
import type { ReactNode } from 'react';
import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { RubyCodeExample } from '@/components/ruby-code-example';
import { Callout } from '@/components/ui/callout';

function FieldTable({ rows }: { rows: [string, ReactNode][] }) {
  return (
    <div className="relative overflow-x-auto">
      <table className="w-full text-sm text-left text-neutral-600 dark:text-neutral-300">
        <thead className="text-neutral-700 dark:text-neutral-300 border-b border-neutral-200 dark:border-neutral-700">
          <tr>
            <th scope="col" className="px-4 py-2 font-medium">
              Field
            </th>
            <th scope="col" className="px-4 py-2 font-medium">
              Value
            </th>
          </tr>
        </thead>
        <tbody>
          {rows.map(([field, value]) => (
            <tr key={field} className="border-b border-neutral-200 dark:border-neutral-700">
              <td className="px-4 py-2 font-mono text-xs align-top whitespace-nowrap">{field}</td>
              <td className="px-4 py-2">{value}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export default function GoodJobIntegrationPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="good-job" level={1}>
        GoodJob
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-300">
        GoodJob runs ActiveJob jobs, so its jobs are logged by the{' '}
        <Link href="/docs/integrations/active-job" className="underline">
          ActiveJob integration
        </Link>{' '}
        (enqueue, schedule, start, finish and error lines). This integration covers GoodJob itself.
        When LogStruct is on, <code>GoodJob.logger</code> is a LogStruct logger, so GoodJob&apos;s
        own messages are JSON lines. Each error GoodJob passes to its thread error handler is one
        structured <code>error</code> line, and then your app&apos;s <code>on_thread_error</code>{' '}
        handler runs as before. LogStruct also turns itself on in the <code>good_job start</code>{' '}
        process.
      </p>

      <HeadingWithAnchor id="setup">What LogStruct changes</HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          <strong>The logger.</strong> <code>GoodJob.logger</code> is replaced with a LogStruct
          logger named <code>GoodJob</code> (written as <code>prog</code>).
        </li>
        <li>
          <strong>Thread errors.</strong> GoodJob passes the errors from its background threads (job
          tasks, the poller, the notifier, the cron manager, the probe server and the systemd
          watchdog) to <code>GoodJob._on_thread_error</code>. LogStruct logs each one, then calls
          your app&apos;s handler, so an error tracker that handler reports to still gets it. It
          works whether the app sets the handler in <code>config.good_job.on_thread_error</code>{' '}
          (which GoodJob applies after LogStruct&apos;s setup) or with{' '}
          <code>GoodJob.on_thread_error =</code> at any time. The app&apos;s handler runs even if
          LogStruct&apos;s line fails.
        </li>
        <li>
          <strong>GoodJob&apos;s own error lines.</strong> GoodJob&apos;s log subscriber writes
          these errors as text with the whole backtrace in the message. LogStruct turns those lines
          off for the errors that reach the thread error handler, so each error is logged once.
        </li>
        <li>
          <strong>
            <code>good_job start</code>.
          </strong>{' '}
          LogStruct counts GoodJob&apos;s executable as a server process, like Puma and Sidekiq, so
          LogStruct is on there in its enabled environments (<code>test</code> and{' '}
          <code>production</code> by default). It stops the executable adding a plain text STDOUT
          logger beside LogStruct&apos;s (<code>GoodJob::CLI.log_to_stdout = false</code>), so each
          line is written once, as JSON. In async mode GoodJob runs inside your web server&apos;s
          process, where LogStruct is on because it&apos;s a server.
        </li>
      </ul>

      <HeadingWithAnchor id="lines">Lines</HeadingWithAnchor>

      <HeadingWithAnchor
        id="goodjob-messages"
        level={3}
        className="text-xl font-semibold mt-6 mb-3"
      >
        GoodJob&apos;s messages
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        GoodJob&apos;s own messages are <code>job</code> <code>log</code> lines, with GoodJob&apos;s
        tags in <code>tags</code>:
      </p>
      <CodeBlock language="json">
        {`{
  "src": "job",
  "evt": "log",
  "lvl": "info",
  "ts": "2026-10-17T03:23:11.213+00:00",
  "msg": "GoodJob 3.23.0 started scheduler with queues=* max_threads=5.",
  "pid": 72705,
  "tid": "4sg",
  "prog": "GoodJob",
  "tags": [
    "GoodJob",
    "1234"
  ]
}`}
      </CodeBlock>
      <p className="text-neutral-600 dark:text-neutral-300">
        A line GoodJob&apos;s logger writes while a job runs also has the job&apos;s{' '}
        <code>job_id</code>, <code>job_class</code>, <code>queue_name</code>,{' '}
        <code>executions</code>, <code>scheduled_at</code> and <code>priority</code>.
      </p>

      <HeadingWithAnchor id="thread-errors" level={3} className="text-xl font-semibold mt-6 mb-3">
        Thread errors
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        Each thread error is a <code>job</code> <code>error</code> line at <code>error</code> level:
      </p>
      <CodeBlock language="json">
        {`{
  "src": "job",
  "evt": "error",
  "lvl": "error",
  "ts": "2026-10-17T03:23:11.212+00:00",
  "error_class": "ActiveRecord::ConnectionTimeoutError",
  "error_message": "could not obtain a connection from the pool within 5.000 seconds (waited 5.001 seconds); all pooled connections were in use",
  "pid": 72705,
  "tid": "4sg",
  "backtrace": [
    "lib/good_job/notifier.rb:250:in 'GoodJob::Notifier#with_connection'",
    "lib/good_job/notifier.rb:198:in 'block in GoodJob::Notifier#create_listen_task'"
  ],
  "prog": "GoodJob"
}`}
      </CodeBlock>
      <p className="text-neutral-600 dark:text-neutral-300">
        GoodJob also passes every failed job&apos;s exception to the thread error handler. The
        ActiveJob integration has already logged it, with the job&apos;s ID and class, so LogStruct
        doesn&apos;t log it again here; your handler still gets it. Exceptions that aren&apos;t{' '}
        <code>StandardError</code>s (GoodJob&apos;s <code>handled_exceptions</code> setting can let
        them through) are logged and passed on too.
      </p>

      <HeadingWithAnchor id="notifier-errors" level={3} className="text-xl font-semibold mt-6 mb-3">
        Notifier connection errors
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        GoodJob&apos;s notifier passes database connection errors to the thread error handler only
        once they repeat. Until then GoodJob logs each one itself, and LogStruct keeps that line,
        without the backtrace:
      </p>
      <CodeBlock language="json">
        {`{
  "src": "job",
  "evt": "log",
  "lvl": "error",
  "ts": "2026-10-17T03:23:11.213+00:00",
  "msg": "Notifier errored: ActiveRecord::ConnectionNotEstablished: connection to server failed",
  "pid": 72705,
  "tid": "4sg",
  "prog": "GoodJob",
  "tags": [
    "GoodJob"
  ]
}`}
      </CodeBlock>

      <HeadingWithAnchor id="fields">Fields</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        <code>job</code> <code>log</code> lines from <code>GoodJob.logger</code>:
      </p>
      <FieldTable
        rows={[
          ['msg', "GoodJob's message."],
          ['pid', 'The process ID.'],
          ['tid', "The thread's object ID, in base 36."],
          ['tags', "GoodJob's tags, such as the process ID."],
          ['job_id', "During a job: the job's ActiveJob ID."],
          ['job_class', "During a job: the job's class."],
          ['queue_name', "During a job: the job's queue."],
          ['executions', 'During a job: how many times the job has run.'],
          ['scheduled_at', 'During a job: when the job was scheduled to run.'],
          ['priority', "During a job: the job's priority."],
        ]}
      />
      <p className="text-neutral-600 dark:text-neutral-300">
        <code>job</code> <code>error</code> lines (thread errors):
      </p>
      <FieldTable
        rows={[
          ['error_class', "The exception's class."],
          [
            'error_message',
            <>
              The exception&apos;s message (these lines have no <code>msg</code>).
            </>,
          ],
          ['backtrace', 'The backtrace, up to max_backtrace_lines (default 20).'],
          ['pid', 'The process ID.'],
          ['tid', "The thread's object ID, in base 36."],
        ]}
      />

      <HeadingWithAnchor id="versions">GoodJob versions</HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          Thread errors are logged on GoodJob 3.0 and later, which pass every thread error through{' '}
          <code>GoodJob._on_thread_error</code>.
        </li>
        <li>
          The job fields come from GoodJob 4&apos;s <code>GoodJob::CurrentThread.job</code> or
          GoodJob 3&apos;s <code>GoodJob::CurrentThread.execution</code>.
        </li>
        <li>
          LogStruct&apos;s tests use a stand-in for GoodJob&apos;s API, not the gem. The lines on
          this page were written with GoodJob 3.23.
        </li>
      </ul>

      <HeadingWithAnchor id="settings">Settings</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        <code>config.integrations.enable_goodjob</code> (default <code>true</code>). The job lines
        come from the ActiveJob integration (<code>config.integrations.enable_activejob</code>). See{' '}
        <Link href="/docs/configuration" className="underline">
          Configuration
        </Link>{' '}
        for the other settings.
      </p>
      <RubyCodeExample name="good_job_configuration" />

      <HeadingWithAnchor id="not-logged">Not logged</HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          GoodJob&apos;s own text lines for job task errors, systemd watchdog errors and notifier
          errors other than connection errors. Each of those errors is in LogStruct&apos;s thread
          error line instead (or, for a failed job, in the ActiveJob integration&apos;s error line).
        </li>
        <li>
          Loggers your app added to <code>GoodJob::LogSubscriber.loggers</code> no longer get job
          errors; they&apos;re in the structured lines.
        </li>
        <li>
          There are no GoodJob-specific enqueue, start or finish lines: those are the ActiveJob
          integration&apos;s lines.
        </li>
      </ul>

      <Callout type="info">
        Values in every line are filtered and scrubbed as described in{' '}
        <Link href="/docs/filtering-sensitive-data" className="underline">
          Filtering Sensitive Data
        </Link>
        .
      </Callout>

      <EditPageLink />
    </div>
  );
}
