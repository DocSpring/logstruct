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

// What each handler does with an error, for each standard_errors mode
const MODE_ROWS: [string, string, string, string][] = [
  ['Ignore', 'Logged', 'Logged', 'Logged, raised'],
  ['Log', 'Logged', 'Logged', 'Logged, raised'],
  ['Report', 'Logged', 'Logged, reported', 'Logged, reported, raised'],
  ['LogProduction', 'Logged', 'Production: logged. Local: logged, raised', 'Logged, raised'],
  [
    'ReportProduction',
    'Logged',
    'Production: logged, reported. Local: logged, raised',
    'Production: logged, reported, raised. Local: logged, raised',
  ],
  ['Raise (default)', 'Logged', 'Logged, raised', 'Logged, raised'],
];

export default function ActionMailerIntegrationPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="action-mailer" level={1}>
        ActionMailer
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-300">
        When LogStruct is on, every mail is logged twice: a <code>delivery</code> line just before
        it&apos;s sent and a <code>delivered</code> line once it has been sent. A delivery that
        fails is an <code>error</code> line. LogStruct gives every mailer a default handler for
        errors (<code>rescue_from StandardError, with: :log_and_reraise_error</code>) and two more
        handlers you can name in your own <code>rescue_from</code> calls. Rails&apos; own mail
        lines, which also log the whole mail at debug level, are turned off.
      </p>

      <HeadingWithAnchor id="lines">Lines</HeadingWithAnchor>

      <HeadingWithAnchor id="delivery" level={3} className="text-xl font-semibold mt-6 mb-3">
        delivery
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        Written before the mail is sent (ActionMailer&apos;s <code>before_deliver</code>), at{' '}
        <code>info</code> level. The mail has no Message-ID yet, so there&apos;s no{' '}
        <code>msg_id</code>.
      </p>
      <CodeBlock language="json">
        {`{
  "src": "mailer",
  "evt": "delivery",
  "lvl": "info",
  "ts": "2026-10-17T03:26:03.062+00:00",
  "to": [
    "[EMAIL:4a0c62b1a1a5a41c]"
  ],
  "from": "[EMAIL:e26577a2762ca45c]",
  "subject": "Welcome, [EMAIL:4a0c62b1a1a5a41c]",
  "mailer": "UserMailer",
  "mailer_action": "welcome",
  "attachments": 0,
  "account_id": 3,
  "user_id": 12,
  "prog": "Rails"
}`}
      </CodeBlock>

      <HeadingWithAnchor id="delivered" level={3} className="text-xl font-semibold mt-6 mb-3">
        delivered
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        Written after the mail was sent (<code>after_deliver</code>), at <code>info</code> level. It
        isn&apos;t written when the delivery fails.
      </p>
      <CodeBlock language="json">
        {`{
  "src": "mailer",
  "evt": "delivered",
  "lvl": "info",
  "ts": "2026-10-17T03:26:03.075+00:00",
  "to": [
    "[EMAIL:4a0c62b1a1a5a41c]"
  ],
  "from": "[EMAIL:e26577a2762ca45c]",
  "subject": "Welcome, [EMAIL:4a0c62b1a1a5a41c]",
  "msg_id": "[EMAIL:2e7b417e62a0c2f5]",
  "mailer": "UserMailer",
  "mailer_action": "welcome",
  "attachments": 0,
  "account_id": 3,
  "user_id": 12,
  "prog": "Rails"
}`}
      </CodeBlock>

      <HeadingWithAnchor id="error" level={3} className="text-xl font-semibold mt-6 mb-3">
        error
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        Written at <code>error</code> level by the mailer&apos;s error handler, once per failed
        delivery. It has the mail&apos;s fields, the error&apos;s class and backtrace, and a message
        that says which handler logged it:
      </p>
      <CodeBlock language="json">
        {`{
  "src": "mailer",
  "evt": "error",
  "lvl": "error",
  "ts": "2026-10-17T03:26:03.079+00:00",
  "to": [
    "[EMAIL:4a0c62b1a1a5a41c]"
  ],
  "from": "[EMAIL:e26577a2762ca45c]",
  "subject": "Welcome, [EMAIL:4a0c62b1a1a5a41c]",
  "msg_id": "[EMAIL:5e2fee655beb1b83]",
  "mailer": "RejectedMailer",
  "mailer_action": "welcome",
  "attachments": 0,
  "error_class": "Net::SMTPFatalError",
  "msg": "Net::SMTPFatalError: Email delivery failed. Recipients: [EMAIL:4a0c62b1a1a5a41c]. Error message: 550 5.1.1 mailbox unavailable",
  "backtrace": [
    "app/lib/smtp_client.rb:27:in 'SmtpClient#deliver!'"
  ],
  "account_id": 3,
  "user_id": 12,
  "prog": "Rails"
}`}
      </CodeBlock>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          <code>log_and_reraise_error</code> writes{' '}
          <code>
            &lt;ErrorClass&gt;: Email delivery failed. Recipients: &lt;recipients&gt;. Error
            message: &lt;message&gt;
          </code>
          . The other two handlers write{' '}
          <code>
            &lt;ErrorClass&gt;: Cannot send email to &lt;recipients&gt;. Error message:
            &lt;message&gt;
          </code>
          .
        </li>
        <li>
          The recipients come from the error&apos;s own <code>recipients</code> method
          (Postmark&apos;s errors have one), or else from the mail&apos;s <code>to</code>,{' '}
          <code>cc</code> and <code>bcc</code>, and are scrubbed like any other address.
          They&apos;re <code>unknown</code> when the mailer failed before it built the mail.
        </li>
        <li>
          With <code>deliver_later</code>, <code>ActionMailer::MailDeliveryJob</code> passes an
          error that escapes the mailer to the mailer class. An error the mailer already logged is
          raised again without a second line, so the job fails as <code>deliver_now</code> would
          (and the{' '}
          <Link href="/docs/integrations/active-job" className="underline">
            ActiveJob integration
          </Link>{' '}
          writes the job&apos;s <code>error</code> line). An error raised before the mailer ran,
          such as a record that was deleted before the job ran, is logged by the class with fewer
          fields:
        </li>
      </ul>
      <CodeBlock language="json">
        {`{
  "src": "mailer",
  "evt": "error",
  "lvl": "error",
  "ts": "2026-10-17T03:26:03.084+00:00",
  "mailer": "UserMailer",
  "error_class": "ActiveJob::DeserializationError",
  "msg": "ActiveJob::DeserializationError: Email delivery failed. Error message: Error while trying to deserialize arguments: Couldn't find User with 'id'=12",
  "backtrace": [
    "app/models/user.rb:1"
  ],
  "prog": "Rails"
}`}
      </CodeBlock>

      <HeadingWithAnchor id="fields">Fields</HeadingWithAnchor>
      <FieldTable
        rows={[
          [
            'to',
            <>
              The recipients. With <code>filters.email_addresses</code> on (the default), each is
              written as <code>[EMAIL:&lt;hash&gt;]</code>; an address has one hash however
              it&apos;s capitalized. With it off, the addresses are written as they are.
            </>,
          ],
          ['from', 'The first From address, written the same way.'],
          [
            'subject',
            'The subject, scrubbed like any other string (email addresses in it are hashed too).',
          ],
          [
            'msg_id',
            <>
              The Message-ID (<code>delivered</code> and <code>error</code> lines). It looks like an
              email address, so with <code>filters.email_addresses</code> on it&apos;s written as{' '}
              <code>[EMAIL:&lt;hash&gt;]</code> too.
            </>,
          ],
          ['mailer', "The mailer's class."],
          ['mailer_action', 'The mailer method that built the mail.'],
          ['attachments', 'How many attachments the mail has.'],
          [
            'account_id, user_id',
            <>
              The <code>id</code> of each instance variable named in{' '}
              <code>actionmailer_id_mapping</code> that the mailer set (by default{' '}
              <code>@account</code> and <code>@user</code>).
            </>,
          ],
          ['error_class', "error lines: the error's class."],
          ['msg', 'error lines: the message described above.'],
          ['backtrace', 'error lines: the backtrace, up to max_backtrace_lines (default 20).'],
        ]}
      />

      <HeadingWithAnchor id="error-handlers">Error handlers</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        LogStruct adds <code>rescue_from StandardError, with: :log_and_reraise_error</code> to{' '}
        <code>ActionMailer::Base</code>, so every mailer has it. Rails checks a mailer&apos;s own{' '}
        <code>rescue_from</code> handlers first, so you can name one of the three handlers for
        particular errors:
      </p>
      <RubyCodeExample name="action_mailer_rescue_from" />
      <p className="text-neutral-600 dark:text-neutral-300">
        Each handler writes one <code>error</code> line. What happens next depends on{' '}
        <code>config.error_handling_modes.standard_errors</code> (see{' '}
        <Link href="/docs/configuration#error-handling-configuration" className="underline">
          Error Handling Configuration
        </Link>
        ). &quot;Reported&quot; means passed once to your error tracker or{' '}
        <code>error_reporting_handler</code>; &quot;raised&quot; means <code>deliver_now</code>{' '}
        raises the error, and a <code>deliver_later</code> job fails. &quot;Local&quot; is the
        environments in <code>local_environments</code> (development and test by default).
      </p>
      <div className="relative overflow-x-auto">
        <table className="w-full text-sm text-left text-neutral-600 dark:text-neutral-300">
          <thead className="text-neutral-700 dark:text-neutral-300 border-b border-neutral-200 dark:border-neutral-700">
            <tr>
              <th scope="col" className="px-4 py-2 font-medium">
                standard_errors
              </th>
              <th scope="col" className="px-4 py-2 font-medium font-mono text-xs">
                log_and_ignore_error
              </th>
              <th scope="col" className="px-4 py-2 font-medium font-mono text-xs">
                log_and_report_error
              </th>
              <th scope="col" className="px-4 py-2 font-medium font-mono text-xs">
                log_and_reraise_error
              </th>
            </tr>
          </thead>
          <tbody>
            {MODE_ROWS.map(([mode, ignore, report, reraise]) => (
              <tr key={mode} className="border-b border-neutral-200 dark:border-neutral-700">
                <td className="px-4 py-2 font-mono text-xs align-top whitespace-nowrap">{mode}</td>
                <td className="px-4 py-2 align-top">{ignore}</td>
                <td className="px-4 py-2 align-top">{report}</td>
                <td className="px-4 py-2 align-top">{reraise}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <Callout type="warning">
        In <code>Raise</code> mode, the default for standard errors,{' '}
        <code>log_and_report_error</code> raises the error instead of reporting it, and{' '}
        <code>log_and_reraise_error</code> raises it without reporting it. LogStruct reports mail
        errors only in the <code>Report</code> modes; an error tracker that catches raised errors
        may still report them.
      </Callout>

      <HeadingWithAnchor id="logstruct-off" level={3} className="text-xl font-semibold mt-6 mb-3">
        Where LogStruct is off
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        In development, the console and Rake tasks (LogStruct is off there by default), or with{' '}
        <code>enable_actionmailer</code> off, LogStruct doesn&apos;t add the default handler, but
        mailers still have the three methods, so a <code>rescue_from</code> that names one
        doesn&apos;t raise <code>NameError</code>. Each writes{' '}
        <code>&lt;ErrorClass&gt;: &lt;message&gt;</code> to the mailer&apos;s logger, then:
      </p>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          <code>log_and_ignore_error</code> ignores the error.
        </li>
        <li>
          <code>log_and_report_error</code> reports it to <code>Rails.error</code> (as handled, with
          the source <code>logstruct.action_mailer</code>) and doesn&apos;t raise it.
        </li>
        <li>
          <code>log_and_reraise_error</code> raises it, without reporting it.
        </li>
      </ul>

      <HeadingWithAnchor id="mailer-logger" level={3} className="text-xl font-semibold mt-6 mb-3">
        Your own logger calls
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        Mailers keep their logger. A <code>logger.info</code> call inside a mailer is written as an
        ordinary line, with <code>src</code> <code>app</code>.
      </p>

      <HeadingWithAnchor id="settings">Settings</HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          <code>config.integrations.enable_actionmailer</code> (default <code>true</code>).
        </li>
        <li>
          <code>config.integrations.actionmailer_id_mapping</code> (default{' '}
          <code>&#123;account: :account_id, user: :user_id&#125;</code>).
        </li>
        <li>
          <code>config.filters.email_addresses</code> (default <code>true</code>).
        </li>
        <li>
          <code>config.error_handling_modes.standard_errors</code> (default <code>Raise</code>).
        </li>
      </ul>
      <p className="text-neutral-600 dark:text-neutral-300">
        See{' '}
        <Link href="/docs/configuration" className="underline">
          Configuration
        </Link>{' '}
        for the other settings.
      </p>
      <RubyCodeExample name="action_mailer_configuration" />

      <HeadingWithAnchor id="not-logged">Not logged</HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          The mail&apos;s body, headers other than those above, and attachments&apos; contents.
        </li>
        <li>
          Rails&apos; own mail lines (&quot;Delivered mail ...&quot; and the whole mail at debug
          level).
        </li>
        <li>
          A <code>delivered</code> line for a failed delivery, even when the handler ignored the
          error.
        </li>
        <li>
          A <code>deliver_later</code> mail&apos;s arguments: its job lines have only the mailer,
          the mail and the delivery method (see{' '}
          <Link href="/docs/integrations/active-job#arguments" className="underline">
            ActiveJob arguments
          </Link>
          ).
        </li>
      </ul>

      <EditPageLink />
    </div>
  );
}
