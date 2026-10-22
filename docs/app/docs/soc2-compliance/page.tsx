import type { Metadata } from 'next';
import Link from 'next/link';
import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { RubyCodeExample } from '@/components/ruby-code-example';
import { Callout } from '@/components/ui/callout';

export const metadata: Metadata = {
  title: 'SOC 2 and Your Logs | LogStruct',
  description:
    'What LogStruct does for the logs a SOC 2 audit looks at, where it stops, and what your app still has to do.',
};

export default function SOC2CompliancePage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="soc2-compliance" level={1}>
        SOC 2 and Your Logs
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-300">
        SOC 2 auditors look at how you record what happens in your systems and how you protect the
        data in those records. LogStruct can help with part of that: it writes consistent JSON
        lines, and it filters common secrets and personal data out of them. It doesn&apos;t make an
        app compliant, and this page isn&apos;t audit advice. It says what LogStruct does, where it
        stops, and what your app still has to do.
      </p>

      <HeadingWithAnchor id="what-logstruct-does">What LogStruct Does</HeadingWithAnchor>

      <HeadingWithAnchor id="consistent-lines" level={3}>
        Consistent lines
      </HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          In production, every line LogStruct writes is one JSON object with the same keys for the
          same things: <code>src</code> and <code>evt</code> say what happened, <code>lvl</code> and{' '}
          <code>ts</code> its level and time, and <code>req_id</code> ties a request&apos;s lines
          together (see{' '}
          <Link href="/docs/log-fields" className="underline">
            Log Fields
          </Link>
          ). You can search and alert on them in your log platform without parsing text.
        </li>
        <li>
          LogStruct&apos;s own lines (requests, jobs, mail, security events, errors) are built from
          Sorbet-typed structs. A field with the wrong type raises an error in development and test,
          so a test that runs that code fails. In production the type error is logged and reported
          (the <code>type_checking_errors</code> mode, <code>ReportProduction</code> by default),
          and the line is still written with the value it was given. Hashes and strings you log, the
          message of a <code>Log::Plain</code> and <code>additional_data</code> aren&apos;t
          type-checked.
        </li>
        <li>
          Security events have their own lines (<code>src</code> <code>security</code>): requests to
          hosts Rails blocks, invalid CSRF tokens and IP spoofing errors (see{' '}
          <Link href="/docs/integrations/security" className="underline">
            Security
          </Link>
          ).
        </li>
        <li>
          Request lines don&apos;t say which user made a request unless you add it, for example a{' '}
          <code>user_id</code> with{' '}
          <Link href="/docs/configuration#custom-lograge-options" className="underline">
            custom Lograge options
          </Link>
          .
        </li>
      </ul>

      <HeadingWithAnchor id="filtering" level={3}>
        Filtering and scrubbing
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        LogStruct filters each line before it writes it, by key and by pattern (details in{' '}
        <Link href="/docs/filtering-sensitive-data" className="underline">
          Filtering Sensitive Data
        </Link>
        ):
      </p>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          <strong>Keys.</strong> A value under a sensitive key name (passwords, tokens, secrets, API
          keys, cookies, sessions, authorization headers, card numbers, social security numbers and
          the like), or a key in Rails&apos; <code>filter_parameters</code> or your{' '}
          <code>filter_keys</code>, is replaced by a summary: its class, plus a Hash&apos;s key
          count or an Array&apos;s item count. <code>email</code> and <code>email_address</code>{' '}
          values get a hash of the address too.
        </li>
        <li>
          <strong>Strings.</strong> In every string, LogStruct replaces email addresses with{' '}
          <code>[EMAIL:&lt;hash&gt;]</code>, and scrubs passwords in URLs, sensitive URL query
          params (<code>?token=</code>, OAuth&apos;s <code>?code=</code>), the credentials after{' '}
          <code>Bearer</code> and <code>Basic</code>, card numbers that pass the Luhn check, US
          phone numbers and social security numbers written like <code>123-45-6789</code> or{' '}
          <code>123 45 6789</code>. IP and MAC addresses are scrubbed only if you turn that on.
        </li>
      </ul>
      <p className="text-neutral-600 dark:text-neutral-300">For example, this line:</p>
      <RubyCodeExample name="soc2_filtered_line" />
      <p className="text-neutral-600 dark:text-neutral-300">is written as:</p>
      <CodeBlock language="json">
        {`{
  "msg": "Password reset requested",
  "email": {
    "_filtered": {
      "_class": "String",
      "_hash": "0d68e00d48aadbd7"
    }
  },
  "note": "Reset link sent to [EMAIL:0d68e00d48aadbd7]",
  "credentials": {
    "_filtered": {
      "_class": "Hash",
      "_keys_count": 2
    }
  },
  "reset_url": "https://app.example.com/reset?token=[FILTERED]&step=2",
  "card": "[CREDIT_CARD]",
  "name": "Jo Smith",
  "src": "app",
  "evt": "log",
  "ts": "2026-10-17T05:20:38.341+00:00",
  "lvl": "info",
  "prog": "Rails"
}`}
      </CodeBlock>
      <p className="text-neutral-600 dark:text-neutral-300">
        The name is logged as it is: nothing matches it.
      </p>

      <HeadingWithAnchor id="email-hashes" level={3}>
        Email hashes
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        The hash is an HMAC-SHA256, keyed with <code>config.filters.hash_salt</code> or, by default,
        with a key derived from your app&apos;s <code>secret_key_base</code>. An address gets the
        same hash however it&apos;s capitalized, under a key or inside a string, so you can follow
        one person&apos;s lines without logging their address. The hashes change when the key
        changes. Anyone with the key and a list of addresses can match them to the hashes, so a
        hashed address is still personal data (a pseudonym), and the key must stay secret.
      </p>

      <HeadingWithAnchor id="where-it-stops">Where It Stops</HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          <strong>Only where LogStruct is on.</strong> By default it&apos;s on in production only in
          the web servers and job runners it recognizes, and never in a console. Rake tasks,{' '}
          <code>rails runner</code> and job runners it doesn&apos;t recognize (Solid Queue&apos;s{' '}
          <code>bin/jobs</code>, for example) use Rails&apos; own logger, with no filtering, unless
          you set <code>LOGSTRUCT_ENABLED=true</code> for them (see{' '}
          <Link href="/docs/when-logstruct-runs" className="underline">
            When LogStruct Runs
          </Link>
          ).
        </li>
        <li>
          <strong>Only the lines LogStruct writes.</strong> Filtering happens in LogStruct&apos;s
          formatter. An appender you add to SemanticLogger with another formatter gets the values
          unfiltered, and so does a subscriber to LogStruct&apos;s <code>log.logstruct</code>{' '}
          notifications. Output that doesn&apos;t go through Rails&apos; logger (<code>puts</code>,
          a gem with its own logger) isn&apos;t filtered either.
        </li>
        <li>
          <strong>Only what its keys and patterns match.</strong> Everything else is logged in full:
          names, postal addresses, dates of birth, free text, phone numbers outside the US formats,
          secrets in formats it doesn&apos;t know (an API key in a sentence), and numbers. A card
          number logged as an Integer isn&apos;t scrubbed. A <code>_filtered</code> summary shows
          that one value was filtered, not that nothing else got through.
        </li>
        <li>
          <strong>Error reports.</strong> When LogStruct reports an error, it filters the context it
          adds, but the exception goes to Sentry, Bugsnag, Rollbar, Honeybadger or your handler as
          it is, message and backtrace included. Errors your error tracker catches itself don&apos;t
          go through LogStruct at all.
        </li>
        <li>
          <strong>Storage and alerts.</strong> LogStruct writes lines to STDOUT in production. It
          doesn&apos;t store, ship, rotate, sign or delete them. Apart from the errors it reports to
          your error tracker, it doesn&apos;t alert anyone.
        </li>
      </ul>

      <HeadingWithAnchor id="what-your-app-does">What Your App Still Has to Do</HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          Ship the lines from STDOUT to a log platform, and set its retention, access control and
          protection against changes or deletion there (see{' '}
          <Link href="/docs/logging" className="underline">
            Logging to STDOUT
          </Link>
          ).
        </li>
        <li>
          Set up alerts in that platform, for example on <code>src</code> <code>security</code> or{' '}
          <code>lvl</code> <code>error</code> lines.
        </li>
        <li>
          Turn LogStruct on in every kind of process you run in production, including Rake tasks and
          job runners it doesn&apos;t recognize.
        </li>
        <li>
          Read the lines your app writes for its main flows, with LogStruct on, and add what the
          defaults miss: your own keys to <code>filter_keys</code>, a{' '}
          <code>string_scrubbing_handler</code> for your own formats, and the IP address scrubber if
          you mustn&apos;t keep IP addresses (see{' '}
          <Link href="/docs/configuration#filtering-sensitive-data" className="underline">
            Configuration
          </Link>
          ).
        </li>
        <li>Configure your error tracker&apos;s own data scrubbing for exception messages.</li>
        <li>
          Keep <code>secret_key_base</code> (or <code>hash_salt</code>) secret, and treat hashed
          addresses as personal data in your retention and deletion policies.
        </li>
      </ul>

      <Callout type="info">
        Questions about LogStruct and compliance are welcome on{' '}
        <a
          href="https://github.com/DocSpring/logstruct/issues"
          className="text-blue-600 dark:text-blue-400 hover:underline"
        >
          GitHub
        </a>
        .
      </Callout>

      <EditPageLink />
    </div>
  );
}
