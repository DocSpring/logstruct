import Link from 'next/link';
import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { RubyCodeExample } from '@/components/ruby-code-example';

export default function TroubleshootingPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="troubleshooting" level={1}>
        Troubleshooting
      </HeadingWithAnchor>

      <HeadingWithAnchor id="still-text">Production logs are still text</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        LogStruct is on only in the processes it recognizes as servers or job workers (Puma,{' '}
        <code>rails server</code>, Unicorn, Thin, Falcon, Sidekiq and <code>good_job start</code>
        ). Rake tasks, <code>rails runner</code>, Solid Queue&apos;s <code>bin/jobs</code> and other
        job runners keep Rails&apos; logger. Set <code>LOGSTRUCT_ENABLED=true</code> in those
        processes&apos; environment. See{' '}
        <Link href="/docs/when-logstruct-runs" className="underline">
          When LogStruct Runs
        </Link>
        .
      </p>

      <HeadingWithAnchor id="nothing-in-development">
        Nothing changes in development
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        LogStruct is off in development by default. Start the server with{' '}
        <code>LOGSTRUCT_ENABLED=true bin/rails server</code>, or turn it on in an initializer (
        <Link href="/docs/when-logstruct-runs#from-an-initializer" className="underline">
          example
        </Link>
        ).
      </p>

      <HeadingWithAnchor id="some-lines-text">Some lines are still text</HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          Lines a gem or your code writes with its own <code>Logger.new($stdout)</code>,{' '}
          <code>puts</code> or <code>warn</code> don&apos;t go through Rails&apos; logger, so
          LogStruct never sees them. Point those loggers at <code>Rails.logger</code>.
        </li>
        <li>
          Text logged through <code>Rails.logger</code> is a JSON line with the text in{' '}
          <code>msg</code>. That includes the lines of Rails components and gems LogStruct has no
          integration for. Log a Hash to get fields of your own.
        </li>
        <li>Output from before the app loads LogStruct (Bundler, or a boot script) is text.</li>
      </ul>

      <HeadingWithAnchor id="filtered-value">A value I need is filtered</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        A key is filtered when one of its words is a sensitive word (<code>session_id</code>,{' '}
        <code>auth_provider</code> and <code>cookie_consent</code> are), when it&apos;s in{' '}
        <code>filters.filter_keys</code>, or when Rails&apos; <code>filter_parameters</code> match
        it. Rails matches its Symbols and Strings anywhere in a key, so a new app&apos;s{' '}
        <code>:token</code> filters <code>token_count</code> and its <code>:_key</code> filters{' '}
        <code>cache_key</code>. Rename the key, change <code>filter_parameters</code>, or filter
        only the keys you list:
      </p>
      <RubyCodeExample name="filter_listed_keys_only" title="config/initializers/logstruct.rb" />
      <p className="text-neutral-600 dark:text-neutral-300 mt-4">
        A String that looks like an email, a card number, a phone number or an SSN is scrubbed
        wherever it appears. Turn off the scrubbers you don&apos;t want in{' '}
        <Link href="/docs/configuration#filtering-sensitive-data" className="underline">
          Filtering Sensitive Data
        </Link>
        .
      </p>

      <HeadingWithAnchor id="unhandled-errors">Errors and 404s at fatal level</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        An error your app didn&apos;t handle is an error line with <code>src</code>{' '}
        <code>rails</code> and the response&apos;s <code>status</code>, written where Rails would
        log its block of text, at Rails&apos; level for these errors: <code>fatal</code> unless you
        change it. Routing errors (404) and the other errors Rails turns into a response of their
        own are logged too, as Rails logs them. Rails&apos; settings change both:
      </p>
      <CodeBlock language="ruby">
        {`# config/environments/production.rb
config.action_dispatch.debug_exception_log_level = :error
# Leave out the errors Rails turns into a 404, 422 and so on
config.action_dispatch.log_rescued_responses = false`}
      </CodeBlock>

      <HeadingWithAnchor id="type-errors">
        Type errors raise in tests after upgrading
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        Since 0.2.0, <code>error_handling_modes.type_checking_errors</code> is{' '}
        <code>ReportProduction</code>: a Sorbet type error raises in development and test, and is
        logged and reported in production. The errors were there before; LogStruct only logged them.
        Fix them, or set the mode to <code>Log</code> while you do (see{' '}
        <Link href="/docs/configuration#error-handling-configuration" className="underline">
          Error Handling
        </Link>
        ).
      </p>

      <HeadingWithAnchor id="settings-ignored">
        My Lograge or Sidekiq settings are ignored
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        LogStruct sets up Lograge and Sidekiq&apos;s logger after <code>config/initializers</code>{' '}
        run, so it replaces what another initializer set. Add request fields with{' '}
        <Link href="/docs/configuration#custom-lograge-options" className="underline">
          <code>lograge_custom_options</code>
        </Link>
        , or turn the integration off (<code>enable_lograge</code>, <code>enable_sidekiq</code>) to
        keep your own setup.
      </p>

      <HeadingWithAnchor id="missing-lines">Lines are missing at exit</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        SemanticLogger writes lines from a background thread, and writes the ones still queued when
        the process exits. A process killed with <code>SIGKILL</code> (or out of memory) loses its
        queued lines. In a script that must not lose any, call <code>SemanticLogger.flush</code>{' '}
        after the lines that matter.
      </p>

      <HeadingWithAnchor id="hashes-differ">Email hashes differ between apps</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        Hashes are keyed with <code>filters.hash_salt</code>, or a key derived from each app&apos;s{' '}
        <code>secret_key_base</code>. Set the same <code>hash_salt</code> (from your credentials) in
        every app whose lines you compare, and keep it when <code>secret_key_base</code> changes.
      </p>

      <HeadingWithAnchor id="logstruct-errors">
        Lines with <code>src</code> <code>logstruct</code>
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        These are errors inside LogStruct (an integration that couldn&apos;t build its line, for
        example), or, with no error tracker set up, errors LogStruct was asked to report. In
        development and test LogStruct&apos;s own errors raise instead (
        <code>error_handling_modes.logstruct_errors</code>), so that they&apos;re found early.
        Please{' '}
        <a href="https://github.com/DocSpring/logstruct/issues" className="underline">
          open an issue
        </a>{' '}
        for one that isn&apos;t a report.
      </p>

      <HeadingWithAnchor id="cut-values">
        Values end with &quot;more items&quot; or <code>_more_keys</code>
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        Lines have size limits: 100 keys per Hash, 10 items per Array, 20 lines per backtrace and 32
        KB per string. Change them with{' '}
        <Link href="/docs/configuration#limits" className="underline">
          <code>config.limits</code>
        </Link>
        .
      </p>

      <EditPageLink />
    </div>
  );
}
