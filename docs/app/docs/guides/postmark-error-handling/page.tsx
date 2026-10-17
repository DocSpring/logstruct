import Link from 'next/link';
import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { RubyCodeExample } from '@/components/ruby-code-example';
import { Callout } from '@/components/ui/callout';

// What each handler does with an error, for each standard_errors mode (LogStruct on)
const MODE_ROWS: [string, string, string, string][] = [
  ['Raise (default)', 'Logged', 'Logged, raised', 'Logged, raised'],
  ['Report', 'Logged', 'Logged, reported', 'Logged, reported, raised'],
  [
    'ReportProduction',
    'Logged',
    'Production: logged, reported. Local: logged, raised',
    'Production: logged, reported, raised. Local: logged, raised',
  ],
  ['Log', 'Logged', 'Logged', 'Logged, raised'],
  ['LogProduction', 'Logged', 'Production: logged. Local: logged, raised', 'Logged, raised'],
  ['Ignore', 'Logged', 'Logged', 'Logged, raised'],
];

// The fields of LogStruct::Log::ActionMailer::Error, as a subscriber reads them and as the line has them
const FIELD_ROWS: [string, string, string][] = [
  ['error_class', 'error_class', 'The exception class (a Class; its name in the line)'],
  ['mailer_class', 'mailer', "The mailer class's name"],
  ['mailer_action', 'mailer_action', 'The mailer method'],
  ['message', 'msg', 'The error message, with the recipients'],
  ['to, from, subject', 'to, from, subject', "The mail's addresses and subject"],
  ['message_id', 'msg_id', "The mail's Message-ID"],
  ['attachment_count', 'attachments', 'How many attachments the mail has'],
  ['backtrace', 'backtrace', "The error's backtrace"],
  ['additional_data', '(top level)', 'IDs from actionmailer_id_mapping, such as account_id'],
];

export default function PostmarkErrorHandlingPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="postmark-error-handling" level={1}>
        Handling Postmark Errors
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-300">
        Postmark refuses some mails for good: mail to an inactive recipient (after a hard bounce, a
        spam complaint or a manual suppression) and requests it can&apos;t accept, such as an
        invalid address. Sending them again won&apos;t help. This guide shows how to log those
        errors without failing the delivery, and how to post an alert to Slack without the
        recipients&apos; addresses.
      </p>

      <HeadingWithAnchor id="default-handler">What Mailers Do by Default</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        Where LogStruct is on, it adds{' '}
        <code>rescue_from StandardError, with: :log_and_reraise_error</code> to{' '}
        <code>ActionMailer::Base</code>, so every mailer already has it. A failed delivery is logged
        as one <code>error</code> line and raised again: <code>deliver_now</code> raises, and a{' '}
        <code>deliver_later</code> job fails. Whether the job runs again is up to your job backend
        and your <code>retry_on</code> settings. Where LogStruct is off, mailers have no default
        handler (see{' '}
        <a href="#logstruct-off" className="underline">
          below
        </a>
        ).
      </p>

      <HeadingWithAnchor id="error-handling-methods">The Three Handlers</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        A mailer can name one of these in its own <code>rescue_from</code>. Each writes one{' '}
        <code>error</code> line, and then does what{' '}
        <code>config.error_handling_modes.standard_errors</code> says (see{' '}
        <Link href="/docs/configuration#error-handling-configuration" className="underline">
          Error Handling Configuration
        </Link>
        ). &quot;Reported&quot; means passed once to your error tracker or{' '}
        <code>error_reporting_handler</code>; &quot;raised&quot; means <code>deliver_now</code>{' '}
        raises the error and a <code>deliver_later</code> job fails. &quot;Local&quot; is the
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
        With the default, <code>Raise</code>, <code>log_and_report_error</code> logs the error and
        then raises it; it doesn&apos;t report it. Neither does <code>log_and_reraise_error</code>.
        LogStruct reports mail errors only in the <code>Report</code> modes, though an error tracker
        that catches raised errors may report them itself.
      </Callout>

      <HeadingWithAnchor id="logstruct-off" level={3}>
        Where LogStruct is off
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        Where LogStruct is off (by default in development, consoles, Rake tasks and job runners it
        doesn&apos;t recognize), or with <code>enable_actionmailer</code> off, mailers still have
        the three methods, so a <code>rescue_from</code> that names one works. Each writes{' '}
        <code>&lt;ErrorClass&gt;: &lt;message&gt;</code> to the mailer&apos;s logger, and then:
      </p>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          <code>log_and_ignore_error</code> ignores the error.
        </li>
        <li>
          <code>log_and_report_error</code> reports it to <code>Rails.error</code> (as handled) and
          doesn&apos;t raise it.
        </li>
        <li>
          <code>log_and_reraise_error</code> raises it, without reporting it.
        </li>
      </ul>
      <p className="text-neutral-600 dark:text-neutral-300">
        In a process where LogStruct is off, nothing scrubs that line, and Postmark&apos;s messages
        include the recipient&apos;s address.
      </p>

      <HeadingWithAnchor id="example-postmark-bounces">
        Ignoring Postmark&apos;s Refusals
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        Name <code>log_and_ignore_error</code> for Postmark&apos;s two errors in your{' '}
        <code>ApplicationMailer</code>. Rails checks a class&apos;s own handlers before the ones it
        inherits, so these come before LogStruct&apos;s default handler on{' '}
        <code>ActionMailer::Base</code>:
      </p>
      <RubyCodeExample name="postmark_rescue_from" />
      <p className="text-neutral-600 dark:text-neutral-300">
        Both are subclasses of <code>Postmark::ApiInputError</code>, which the postmark gem raises
        when its API answers 422. With LogStruct on, a refused mail writes its <code>delivery</code>{' '}
        line, then this <code>error</code> line and no <code>delivered</code> line, in any mode, and
        a <code>deliver_later</code> job succeeds:
      </p>
      <CodeBlock language="json">
        {`{
  "src": "mailer",
  "evt": "error",
  "lvl": "error",
  "ts": "2026-10-17T05:18:13.415+00:00",
  "to": [
    "[EMAIL:0d68e00d48aadbd7]"
  ],
  "from": "[EMAIL:5e42c76e1a39d521]",
  "subject": "Your invoice is ready",
  "msg_id": "[EMAIL:0ee4c371a7685a72]",
  "mailer": "InvoiceMailer",
  "mailer_action": "invoice_ready",
  "attachments": 0,
  "error_class": "Postmark::InactiveRecipientError",
  "msg": "Postmark::InactiveRecipientError: Cannot send email to [EMAIL:0d68e00d48aadbd7]. Error message: You tried to send to recipient(s) that have been marked as inactive. Found inactive addresses: [EMAIL:0d68e00d48aadbd7]. Inactive recipients are ones that have generated a hard bounce, a spam complaint, or a manual suppression.",
  "prog": "Rails"
}`}
      </CodeBlock>
      <p className="text-neutral-600 dark:text-neutral-300">
        The line also has the error&apos;s <code>backtrace</code> (its first 20 lines by default,{' '}
        <code>config.limits.max_backtrace_lines</code>), left out here. The recipients in the
        message come from the error&apos;s own <code>recipients</code> (an{' '}
        <code>InactiveRecipientError</code> has them) or else from the mail&apos;s <code>to</code>,{' '}
        <code>cc</code> and <code>bcc</code>, and are scrubbed like any address. See{' '}
        <Link href="/docs/integrations/action-mailer#error" className="underline">
          ActionMailer
        </Link>{' '}
        for the other mail lines.
      </p>

      <HeadingWithAnchor id="custom-notifications">Slack Alerts</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        LogStruct doesn&apos;t send notifications, but it publishes each of its log entries (the{' '}
        <code>LogStruct::Log</code> structs) as a <code>log.logstruct</code> notification when it
        logs it, with the entry in <code>payload[:log]</code> and the level in{' '}
        <code>payload[:level]</code>. To post Postmark&apos;s errors to Slack, subscribe in an
        initializer and enqueue a job of your own:
      </p>
      <RubyCodeExample name="postmark_slack_alerts" />
      <Callout type="warning">
        The notification carries the entry before LogStruct filters it. Its <code>message</code>,{' '}
        <code>to</code> and <code>subject</code> can hold the recipients&apos; addresses as they
        are, so send only fields like <code>mailer_class</code> and <code>error_class</code>.
      </Callout>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          The subscriber runs inside the logger call, after the line is queued to be written. If it
          raises, the line is still written and the error is handled like your app&apos;s other
          errors (the <code>standard_errors</code> mode, which raises it from the logger call by
          default), so keep it to enqueueing a job.
        </li>
        <li>
          It runs only where LogStruct handles mail errors: in processes where LogStruct is on, with{' '}
          <code>enable_actionmailer</code> on (the default). For <code>deliver_later</code>,
          that&apos;s the job process.
        </li>
        <li>
          A refused mail publishes one <code>LogStruct::Log::ActionMailer::Error</code>, so it sends
          one alert.
        </li>
      </ul>

      <HeadingWithAnchor id="error-log-structure">The Error Entry</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        A subscriber gets a <code>LogStruct::Log::ActionMailer::Error</code>. Its attributes, and
        their keys in the line:
      </p>
      <div className="relative overflow-x-auto">
        <table className="w-full text-sm text-left text-neutral-600 dark:text-neutral-300">
          <thead className="text-neutral-700 dark:text-neutral-300 border-b border-neutral-200 dark:border-neutral-700">
            <tr>
              <th scope="col" className="px-4 py-2 font-medium">
                Attribute
              </th>
              <th scope="col" className="px-4 py-2 font-medium">
                Key in the line
              </th>
              <th scope="col" className="px-4 py-2 font-medium">
                Value
              </th>
            </tr>
          </thead>
          <tbody>
            {FIELD_ROWS.map(([attribute, key, value]) => (
              <tr key={attribute} className="border-b border-neutral-200 dark:border-neutral-700">
                <td className="px-4 py-2 font-mono text-xs align-top whitespace-nowrap">
                  {attribute}
                </td>
                <td className="px-4 py-2 font-mono text-xs align-top whitespace-nowrap">{key}</td>
                <td className="px-4 py-2 align-top">{value}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="text-neutral-600 dark:text-neutral-300">
        An error raised before the mailer ran, such as a <code>deliver_later</code> job whose record
        was deleted before the job ran, is logged by the mailer class, with only{' '}
        <code>mailer_class</code>, <code>error_class</code>, <code>message</code> and{' '}
        <code>backtrace</code>.
      </p>

      <EditPageLink />
    </div>
  );
}
