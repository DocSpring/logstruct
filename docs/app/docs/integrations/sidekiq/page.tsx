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

export default function SidekiqIntegrationPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="sidekiq" level={1}>
        Sidekiq
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-300">
        When LogStruct is on and Sidekiq is loaded, Sidekiq&apos;s logger is a LogStruct logger, so
        Sidekiq&apos;s own lines and your <code>Sidekiq.logger</code> calls are JSON lines. In the
        Sidekiq process, every line logged while a job runs has the job&apos;s ID and class in{' '}
        <code>ctx</code>, and a failed job is one <code>warn</code> line with the error instead of
        Sidekiq&apos;s three text lines.
      </p>

      <HeadingWithAnchor id="setup">What LogStruct changes</HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          <strong>The logger.</strong> LogStruct replaces Sidekiq&apos;s logger as soon as it
          replaces Rails&apos; logger, before <code>config/initializers</code> run, so the lines
          Sidekiq logs while an initializer configures it are JSON too. The logger is named{' '}
          <code>Sidekiq-Server</code> in the Sidekiq process and <code>Sidekiq-Client</code>{' '}
          everywhere else, and the name is written as <code>prog</code>.
        </li>
        <li>
          <strong>The job context.</strong> In the Sidekiq process, LogStruct adds a server
          middleware at the front of the chain. While a job runs, every line (from{' '}
          <code>Rails.logger</code>, <code>Sidekiq.logger</code> or any other SemanticLogger logger)
          gets the job&apos;s <code>jid</code> and <code>class</code> in <code>ctx</code>, so a
          query on <code>ctx.jid</code> returns every line of one job run. For an ActiveJob job,{' '}
          <code>class</code> is the job&apos;s own class, not Sidekiq&apos;s wrapper.
        </li>
        <li>
          <strong>The error handler.</strong> In the Sidekiq process, LogStruct replaces
          Sidekiq&apos;s default error handler with one that writes a structured line. Handlers that
          your app or an error tracker added stay and run as before.
        </li>
      </ul>

      <HeadingWithAnchor id="lines">Lines</HeadingWithAnchor>

      <HeadingWithAnchor id="job-lines" level={3} className="text-xl font-semibold mt-6 mb-3">
        Sidekiq&apos;s job lines
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        Sidekiq logs <code>start</code> when it starts a job, and <code>done</code> or{' '}
        <code>fail</code> when the job ends. Each is a <code>sidekiq</code> <code>log</code> line
        with Sidekiq&apos;s own job context in <code>ctx</code>; <code>done</code> and{' '}
        <code>fail</code> add <code>elapsed</code>, in seconds.
      </p>
      <CodeBlock language="json">
        {`{
  "src": "sidekiq",
  "evt": "log",
  "lvl": "info",
  "ts": "2026-10-17T03:21:00.200+00:00",
  "msg": "done",
  "ctx": {
    "class": "InvoiceJob",
    "jid": "b4a577edbccf1d805744efa9",
    "elapsed": 0.001
  },
  "pid": 70624,
  "tid": "1fu8",
  "prog": "Sidekiq-Server"
}`}
      </CodeBlock>

      <HeadingWithAnchor
        id="lines-during-a-job"
        level={3}
        className="text-xl font-semibold mt-6 mb-3"
      >
        Lines logged during a job
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        <code>Rails.logger.info(&quot;Rendering invoice PDF&quot;)</code> inside the job writes:
      </p>
      <CodeBlock language="json">
        {`{
  "src": "app",
  "evt": "log",
  "lvl": "info",
  "ts": "2026-10-17T03:21:00.199+00:00",
  "msg": "Rendering invoice PDF",
  "prog": "Rails",
  "ctx": {
    "jid": "b4a577edbccf1d805744efa9",
    "class": "InvoiceJob"
  }
}`}
      </CodeBlock>
      <p className="text-neutral-600 dark:text-neutral-300">
        A Hash logged with its own <code>ctx</code> keeps its keys and gains the job&apos;s.
      </p>

      <HeadingWithAnchor id="sidekiq-logger" level={3} className="text-xl font-semibold mt-6 mb-3">
        Sidekiq.logger calls
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        A String passed to <code>Sidekiq.logger</code> is a <code>sidekiq</code> <code>log</code>{' '}
        line with the message in <code>msg</code>, Sidekiq&apos;s context in <code>ctx</code>, and
        the process and thread IDs. A Hash, a LogStruct log struct or an exception is logged as it
        is, like on <code>Rails.logger</code>: a Hash&apos;s keys are the line&apos;s fields and are
        filtered like any other Hash, and its <code>src</code> is <code>app</code> unless the Hash
        sets one. Sidekiq logs some of its settings as a Hash, so their keys are filtered too. This
        line came from{' '}
        <code>
          Sidekiq.logger.info(&#123;msg: &quot;Synced invoice&quot;, invoice_id: 42, api_token:
          token&#125;)
        </code>{' '}
        during a job:
      </p>
      <CodeBlock language="json">
        {`{
  "msg": "Synced invoice",
  "invoice_id": 42,
  "api_token": {
    "_filtered": {
      "_class": "String"
    }
  },
  "src": "app",
  "evt": "log",
  "ts": "2026-10-17T03:21:00.200+00:00",
  "lvl": "info",
  "prog": "Sidekiq-Server",
  "ctx": {
    "jid": "b4a577edbccf1d805744efa9",
    "class": "InvoiceJob"
  }
}`}
      </CodeBlock>

      <HeadingWithAnchor id="failed-jobs" level={3} className="text-xl font-semibold mt-6 mb-3">
        Failed jobs
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        When a job raises, Sidekiq calls its error handlers. LogStruct&apos;s handler writes one{' '}
        <code>sidekiq</code> <code>error</code> line at <code>warn</code> level, the level
        Sidekiq&apos;s default handler uses. It doesn&apos;t include the job&apos;s arguments:
        Sidekiq&apos;s handler logged the whole job, arguments included, as a JSON string, which
        LogStruct can&apos;t filter.
      </p>
      <CodeBlock language="json">
        {`{
  "src": "sidekiq",
  "evt": "error",
  "lvl": "warn",
  "ts": "2026-10-17T03:21:00.205+00:00",
  "error_class": "ArgumentError",
  "msg": "Template not found",
  "backtrace": [
    "app/sidekiq/invoice_job.rb:9:in 'InvoiceJob#perform'"
  ],
  "error_context": "Job raised exception",
  "queue_name": "default",
  "retry_count": 2,
  "prog": "Rails",
  "ctx": {
    "jid": "2f1c9e0d7a6b5c4d3e2f1a0b",
    "class": "InvoiceJob"
  }
}`}
      </CodeBlock>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          Errors Sidekiq reports outside a job (from its fetcher, for example) are the same line
          without the job&apos;s fields. <code>error_context</code> says what Sidekiq was doing.
        </li>
        <li>
          For an ActiveJob job, the{' '}
          <Link href="/docs/integrations/active-job" className="underline">
            ActiveJob integration
          </Link>{' '}
          logs the error as a <code>job</code> <code>error</code> line with the job&apos;s ID and
          arguments, and this line is skipped for that error. It&apos;s still written for errors
          raised before ActiveJob ran the job, such as a job class that a deploy removed.
        </li>
        <li>
          LogStruct replaces only Sidekiq&apos;s default handler. If your app already removed it,
          LogStruct doesn&apos;t add its own.
        </li>
      </ul>

      <HeadingWithAnchor id="fields">Fields</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        <code>sidekiq</code> <code>log</code> lines (a String logged with{' '}
        <code>Sidekiq.logger</code>):
      </p>
      <FieldTable
        rows={[
          ['msg', 'The message.'],
          [
            'ctx',
            <>
              Sidekiq&apos;s context: <code>class</code>, <code>jid</code>, and <code>elapsed</code>{' '}
              (seconds) on <code>done</code> and <code>fail</code>. Left out outside a job.
            </>,
          ],
          ['pid', 'The process ID.'],
          ['tid', "Sidekiq's thread ID, as Sidekiq writes it in its own logs."],
          [
            'prog',
            <>
              <code>Sidekiq-Server</code> or <code>Sidekiq-Client</code>.
            </>,
          ],
        ]}
      />
      <p className="text-neutral-600 dark:text-neutral-300">
        <code>sidekiq</code> <code>error</code> lines:
      </p>
      <FieldTable
        rows={[
          ['error_class', "The exception's class."],
          ['msg', "The exception's message."],
          ['backtrace', 'The backtrace, up to max_backtrace_lines (default 20).'],
          [
            'error_context',
            <>
              What Sidekiq was doing, e.g. <code>Job raised exception</code>.
            </>,
          ],
          ['queue_name', "The job's queue."],
          [
            'retry_count',
            <>
              The job&apos;s <code>retry_count</code> when Sidekiq fetched it: not there on the
              first run, <code>0</code> on the first retry.
            </>,
          ],
          [
            'ctx',
            <>
              The job&apos;s <code>jid</code> and <code>class</code>.
            </>,
          ],
        ]}
      />

      <HeadingWithAnchor id="versions">Sidekiq versions</HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          <strong>Sidekiq 7:</strong> everything on this page. LogStruct&apos;s tests run against
          Sidekiq 7.
        </li>
        <li>
          <strong>Sidekiq 6:</strong> LogStruct sets the logger on the <code>Sidekiq</code> module
          and adds the job context. Sidekiq 6 has no <code>Sidekiq::Config::ERROR_HANDLER</code>, so
          its own error handler stays: a failed job is three <code>warn</code> lines (the job as a
          JSON string with its arguments, the error, and the backtrace), written through
          LogStruct&apos;s logger.
        </li>
        <li>
          <strong>Sidekiq 8</strong> isn&apos;t tested.
        </li>
      </ul>

      <HeadingWithAnchor id="settings">Settings</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        <code>config.integrations.enable_sidekiq</code> (default <code>true</code>). With it off, or
        with LogStruct off, Sidekiq keeps its own logger and error handler. If an initializer turns
        either off after LogStruct replaced the logger, LogStruct puts Sidekiq&apos;s logger back.
        See{' '}
        <Link href="/docs/configuration" className="underline">
          Configuration
        </Link>{' '}
        for the other settings.
      </p>
      <RubyCodeExample name="sidekiq_configuration" />

      <HeadingWithAnchor id="limits">Limits</HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>Job arguments aren&apos;t in any Sidekiq line.</li>
        <li>
          The job context is added in the Sidekiq process only. Lines logged where a job is enqueued
          don&apos;t have its <code>jid</code>.
        </li>
        <li>
          LogStruct writes no line of its own when Sidekiq schedules a retry; the error line&apos;s{' '}
          <code>retry_count</code> says which run failed.
        </li>
      </ul>

      <Callout type="info">
        Values in every line, <code>ctx</code> included, are filtered and scrubbed as described in{' '}
        <Link href="/docs/filtering-sensitive-data" className="underline">
          Filtering Sensitive Data
        </Link>
        .
      </Callout>

      <EditPageLink />
    </div>
  );
}
