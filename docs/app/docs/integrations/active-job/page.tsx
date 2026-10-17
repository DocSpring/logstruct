import Link from 'next/link';
import type { ReactNode } from 'react';
import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { RubyCodeExample } from '@/components/ruby-code-example';

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

export default function ActiveJobIntegrationPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="active-job" level={1}>
        ActiveJob
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-300">
        When LogStruct is on, it detaches Rails&apos; ActiveJob log subscriber and attaches its own,
        which writes a <code>job</code> line when a job is enqueued, scheduled, started, finished,
        retried, discarded or fails. It works with any queue backend (Sidekiq, GoodJob, SolidQueue,
        the async adapter, ...), since it listens to ActiveJob&apos;s own events. The lines go to{' '}
        <code>ActiveJob::Base.logger</code> and carry ActiveJob&apos;s tags.
      </p>

      <HeadingWithAnchor id="lines">Lines</HeadingWithAnchor>

      <HeadingWithAnchor id="enqueue" level={3} className="text-xl font-semibold mt-6 mb-3">
        enqueue
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        <code>perform_later</code> without a wait. This job was enqueued with{' '}
        <code>
          InvoiceJob.perform_later(42, &#123;&quot;api_key&quot; =&gt; key, &quot;plan&quot; =&gt;
          &quot;pro&quot;&#125;)
        </code>
        :
      </p>
      <CodeBlock language="json">
        {`{
  "src": "job",
  "evt": "enqueue",
  "lvl": "info",
  "ts": "2026-10-17T03:21:01.874+00:00",
  "job_id": "a6219a2b-5c94-4030-acd8-9d3f9809cfab",
  "job_class": "InvoiceJob",
  "queue_name": "billing",
  "arguments": [
    42,
    {
      "api_key": {
        "_filtered": {
          "_class": "String"
        }
      },
      "plan": "pro"
    }
  ],
  "executions": 0,
  "prog": "Rails",
  "tags": [
    "ActiveJob"
  ]
}`}
      </CodeBlock>

      <p className="text-neutral-600 dark:text-neutral-300">
        <code>perform_all_later</code> writes an enqueue or schedule line for each job it enqueued.
        A job the backend couldn&apos;t take (<code>ActiveJob::EnqueueError</code>, or another
        exception while enqueuing) writes an{' '}
        <a href="#error" className="underline">
          error
        </a>{' '}
        line instead, with <code>executions</code> 0, and a job that a <code>before_enqueue</code>{' '}
        callback stopped writes no line. Rails tags the lines of <code>perform_later</code> with{' '}
        <code>ActiveJob</code>, but not those of <code>perform_all_later</code>.
      </p>
      <p className="text-neutral-600 dark:text-neutral-300">
        Some adapters (Sidekiq&apos;s) enqueue the jobs together and say only how many they
        enqueued. When that&apos;s all of them, each job has its line. When it&apos;s fewer (a
        Sidekiq client middleware stopped one), there&apos;s one <code>warn</code> line with both
        counts instead, since the adapter doesn&apos;t say which jobs it enqueued. If the adapter
        raises (Redis is down), <code>perform_all_later</code> raises too, and there&apos;s one{' '}
        <code>error</code> line with the error and the number of jobs. With other adapters, the jobs
        enqueued before the error have their lines, and so do the jobs the adapter refused (
        <code>ActiveJob::EnqueueError</code>) and the job that raised.
      </p>

      <HeadingWithAnchor id="schedule" level={3} className="text-xl font-semibold mt-6 mb-3">
        schedule
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        <code>perform_later</code> with <code>wait</code> or <code>wait_until</code>, and the
        retries that <code>retry_on</code> schedules:
      </p>
      <CodeBlock language="json">
        {`{
  "src": "job",
  "evt": "schedule",
  "lvl": "info",
  "ts": "2026-10-17T03:21:01.877+00:00",
  "job_id": "60fae424-39f5-4615-b61b-5cf019045965",
  "job_class": "InvoiceJob",
  "queue_name": "billing",
  "arguments": [
    42
  ],
  "executions": 0,
  "scheduled_at": "2026-10-18T09:00:00.000Z",
  "prog": "Rails",
  "tags": [
    "ActiveJob"
  ]
}`}
      </CodeBlock>

      <HeadingWithAnchor id="start" level={3} className="text-xl font-semibold mt-6 mb-3">
        start
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        Before the job&apos;s <code>perform</code> runs. During the job, ActiveJob tags every line
        with the job&apos;s class and ID.
      </p>
      <CodeBlock language="json">
        {`{
  "src": "job",
  "evt": "start",
  "lvl": "info",
  "ts": "2026-10-17T03:21:01.877+00:00",
  "job_id": "76614a80-6f74-4887-b681-ad39718b2633",
  "job_class": "InvoiceJob",
  "queue_name": "billing",
  "arguments": [
    42,
    {
      "plan": "pro"
    }
  ],
  "executions": 1,
  "started_at": "2026-10-17T03:21:01.877+00:00",
  "attempt": 1,
  "prog": "Rails",
  "tags": [
    "ActiveJob",
    "InvoiceJob",
    "76614a80-6f74-4887-b681-ad39718b2633"
  ]
}`}
      </CodeBlock>

      <HeadingWithAnchor id="finish" level={3} className="text-xl font-semibold mt-6 mb-3">
        finish
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        After <code>perform</code> returns, or when the job&apos;s own <code>retry_on</code>,{' '}
        <code>discard_on</code> or <code>rescue_from</code> handled its exception. A job that a{' '}
        <code>before_perform</code> callback stopped didn&apos;t run, and has no finish line.
      </p>
      <CodeBlock language="json">
        {`{
  "src": "job",
  "evt": "finish",
  "lvl": "info",
  "ts": "2026-10-17T03:21:01.878+00:00",
  "job_id": "76614a80-6f74-4887-b681-ad39718b2633",
  "job_class": "InvoiceJob",
  "queue_name": "billing",
  "arguments": [
    42,
    {
      "plan": "pro"
    }
  ],
  "executions": 1,
  "duration_ms": 0.23600000143051147,
  "finished_at": "2026-10-17T03:21:01.878+00:00",
  "prog": "Rails",
  "tags": [
    "ActiveJob",
    "InvoiceJob",
    "76614a80-6f74-4887-b681-ad39718b2633"
  ]
}`}
      </CodeBlock>

      <HeadingWithAnchor id="error" level={3} className="text-xl font-semibold mt-6 mb-3">
        error
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        The job raised an exception that it didn&apos;t handle, or the backend couldn&apos;t enqueue
        it (then <code>executions</code> is 0), at <code>error</code> level. Any{' '}
        <code>Exception</code> is logged, not only <code>StandardError</code>s. Sidekiq&apos;s and
        GoodJob&apos;s integrations don&apos;t log the same exception again.
      </p>
      <CodeBlock language="json">
        {`{
  "src": "job",
  "evt": "error",
  "lvl": "error",
  "ts": "2026-10-17T03:21:01.879+00:00",
  "job_id": "99d68b68-2726-4c1c-8dc3-39e5c3bdecf1",
  "job_class": "FailingJob",
  "queue_name": "default",
  "arguments": [
    7
  ],
  "executions": 1,
  "error_class": "ArgumentError",
  "msg": "Template not found",
  "backtrace": [
    "app/jobs/failing_job.rb:3:in 'FailingJob#perform'"
  ],
  "prog": "Rails",
  "tags": [
    "ActiveJob",
    "FailingJob",
    "99d68b68-2726-4c1c-8dc3-39e5c3bdecf1"
  ]
}`}
      </CodeBlock>

      <HeadingWithAnchor id="retry" level={3} className="text-xl font-semibold mt-6 mb-3">
        retry
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        <code>retry_on</code> caught the job&apos;s exception and enqueued the job again, after{' '}
        <code>wait_ms</code>. The retry itself has a <code>schedule</code> line just before this
        one, and the run that raised has a <code>finish</code> line after it.
      </p>
      <CodeBlock language="json">
        {`{
  "src": "job",
  "evt": "retry",
  "lvl": "info",
  "ts": "2026-10-17T04:57:05.105+00:00",
  "job_id": "cadb49f1-8913-4dbf-a73d-00b2742f6dbf",
  "job_class": "SyncJob",
  "queue_name": "default",
  "arguments": [
    "orders"
  ],
  "executions": 1,
  "error_class": "Timeout::Error",
  "msg": "API timed out",
  "wait_ms": 3000.0,
  "prog": "Rails",
  "tags": [
    "ActiveJob",
    "SyncJob",
    "cadb49f1-8913-4dbf-a73d-00b2742f6dbf"
  ]
}`}
      </CodeBlock>

      <HeadingWithAnchor id="retry-stopped" level={3} className="text-xl font-semibold mt-6 mb-3">
        retry_stopped
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        The exception came back on the last of <code>retry_on</code>&apos;s attempts, at{' '}
        <code>error</code> level. The line has the same fields as a retry line, without{' '}
        <code>wait_ms</code>. The job then raises the exception, which is an <code>error</code>{' '}
        line, unless <code>retry_on</code> was given a block.
      </p>

      <HeadingWithAnchor id="discard" level={3} className="text-xl font-semibold mt-6 mb-3">
        discard
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        <code>discard_on</code> caught the job&apos;s exception and dropped the job, at{' '}
        <code>error</code> level, as Rails logs it. A <code>finish</code> line follows.
      </p>
      <CodeBlock language="json">
        {`{
  "src": "job",
  "evt": "discard",
  "lvl": "error",
  "ts": "2026-10-17T04:57:05.106+00:00",
  "job_id": "87dceb1e-e870-4424-8e83-501287c188ac",
  "job_class": "InvoiceJob",
  "queue_name": "billing",
  "arguments": [
    42
  ],
  "executions": 1,
  "error_class": "ActiveRecord::RecordNotFound",
  "msg": "Couldn't find Invoice with 'id'=42",
  "prog": "Rails",
  "tags": [
    "ActiveJob",
    "InvoiceJob",
    "87dceb1e-e870-4424-8e83-501287c188ac"
  ]
}`}
      </CodeBlock>

      <HeadingWithAnchor id="fields">Fields</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">Every job line has:</p>
      <FieldTable
        rows={[
          ['job_id', "The job's ActiveJob ID."],
          ['job_class', "The job's class."],
          ['queue_name', "The job's queue."],
          [
            'executions',
            <>
              How many times the job has run: <code>0</code> when it&apos;s enqueued, <code>1</code>{' '}
              on its first run.
            </>,
          ],
          [
            'provider_job_id',
            "The backend's own ID for the job (a Sidekiq jid, a SolidQueue row ID), as a String, when the backend sets one.",
          ],
          [
            'arguments',
            <>
              The job&apos;s arguments, filtered and scrubbed (see{' '}
              <a href="#arguments" className="underline">
                Arguments
              </a>
              ). Left out when the job&apos;s <code>log_arguments</code> is off.
            </>,
          ],
          ['tags', "ActiveJob's tags."],
        ]}
      />
      <p className="text-neutral-600 dark:text-neutral-300">And per event:</p>
      <FieldTable
        rows={[
          ['scheduled_at', 'schedule: when the job is due to run.'],
          ['started_at', 'start: when the job started.'],
          [
            'attempt',
            <>
              start: the same number as <code>executions</code>.
            </>,
          ],
          ['duration_ms', 'finish: how long perform took, in milliseconds.'],
          ['finished_at', 'finish: when the job finished, the same time as ts.'],
          ['error_class', "error, retry, retry_stopped, discard: the exception's class."],
          ['msg', "error, retry, retry_stopped, discard: the exception's message."],
          ['backtrace', 'error: the backtrace, up to max_backtrace_lines (default 20).'],
          ['wait_ms', 'retry: how long until the job runs again, in milliseconds.'],
        ]}
      />

      <HeadingWithAnchor id="arguments">Arguments</HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          Arguments are logged when the job class&apos;s <code>log_arguments</code> is on, which is
          Rails&apos; default. Turn it off in a job whose arguments you don&apos;t want in your logs
          (the example below).
        </li>
        <li>
          Arguments are filtered and scrubbed like any other value: the keys of a Hash argument are
          matched against your filter keys and Rails&apos; <code>filter_parameters</code>, and
          strings are scrubbed (email addresses, card numbers and the rest). A plain String argument
          has no key, so it&apos;s only scrubbed: a token passed as a String is logged unless one of
          the scrubbers matches it. See{' '}
          <Link href="/docs/filtering-sensitive-data" className="underline">
            Filtering Sensitive Data
          </Link>
          .
        </li>
        <li>
          A record, or any other GlobalID object, is written as its GlobalID (
          <code>gid://my-app/User/5</code>).
        </li>
        <li>
          For <code>ActionMailer::MailDeliveryJob</code> (every <code>deliver_later</code>) and its
          subclasses, only the first three arguments are logged: the mailer, the mail and the
          delivery method, as in{' '}
          <code>[&quot;UserMailer&quot;, &quot;reset_password&quot;, &quot;deliver_now&quot;]</code>
          . The mail&apos;s own arguments are left out, because mailers are often passed tokens as
          plain Strings (Devise passes its confirmation, password reset and invitation tokens that
          way), which no key-based filter can find.
        </li>
      </ul>
      <RubyCodeExample name="active_job_log_arguments" />

      <HeadingWithAnchor id="settings">Settings</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        <code>config.integrations.enable_activejob</code> (default <code>true</code>), and each
        job&apos;s <code>log_arguments</code>. With the integration off, Rails&apos; own ActiveJob
        lines are written instead, as text in <code>msg</code>. They include the arguments of every
        job whose <code>log_arguments</code> is on, mail arguments too. See{' '}
        <Link href="/docs/configuration" className="underline">
          Configuration
        </Link>{' '}
        for the other settings.
      </p>
      <RubyCodeExample name="active_job_configuration" />

      <HeadingWithAnchor id="not-logged">Not logged</HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          A job that a <code>before_enqueue</code> callback stopped has no line, and one that a{' '}
          <code>before_perform</code> callback stopped has a <code>start</code> line only.
        </li>
      </ul>

      <EditPageLink />
    </div>
  );
}
