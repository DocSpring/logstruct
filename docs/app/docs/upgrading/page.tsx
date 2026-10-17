import Link from 'next/link';
import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { Callout } from '@/components/ui/callout';

export default function UpgradingPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="upgrading" level={1}>
        Upgrading to 0.2.0
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-300">
        0.2.0 changes the shape of some lines, filters more, and fixes integrations that logged
        nothing or logged twice. This page lists what you may need to change. The{' '}
        <a
          href="https://github.com/DocSpring/logstruct/blob/main/CHANGELOG.md"
          className="underline"
        >
          changelog
        </a>{' '}
        has every change.
      </p>

      <HeadingWithAnchor id="requirements">Requirements</HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>Ruby 3.3 or newer, and Rails 7.1 or newer.</li>
        <li>
          LogStruct depends on <code>railties</code>, <code>actionpack</code>,{' '}
          <code>activesupport</code>, <code>globalid</code> and <code>lograge</code> instead of{' '}
          <code>rails</code>, so it no longer installs every Rails framework.
        </li>
        <li>
          Pin <code>gem &quot;logstruct&quot;, &quot;~&gt; 0.2.0&quot;</code>. Below 1.0, a minor
          version can change lines.
        </li>
      </ul>

      <HeadingWithAnchor id="lines">Lines that look different</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        Update the log queries, dashboards and alerts that read these fields.
      </p>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          <strong>A logged Hash&apos;s keys are at the top level</strong>, not under{' '}
          <code>payload</code>. A Hash can set its own <code>evt</code> and <code>src</code>:
        </li>
      </ul>
      <CodeBlock language="ruby">{`Rails.logger.info({evt: "signup", user_id: 1, plan: "pro"})`}</CodeBlock>
      <CodeBlock language="json">
        {`{"evt":"signup","user_id":1,"plan":"pro","src":"app","ts":"2026-10-17T03:14:21.865Z","lvl":"info","prog":"Rails"}`}
      </CodeBlock>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          <strong>Email hashes changed.</strong> A hash is now an HMAC-SHA256, 16 characters long,
          keyed with <code>filters.hash_salt</code> or, without it, a key derived from your
          app&apos;s <code>secret_key_base</code>. Every hash differs from 0.1&apos;s, and they
          change again if <code>secret_key_base</code> does: set <code>hash_salt</code> to keep
          them. An address has one hash however it&apos;s capitalized.
        </li>
        <li>
          <strong>Filtered values have no length.</strong> A filtered String is{' '}
          <code>{'{"_filtered":{"_class":"String"}}'}</code>, without <code>_bytes</code>. Keys in{' '}
          <code>filter_keys_with_hashes</code> (<code>email</code>, <code>email_address</code>) are
          filtered too, with a <code>_hash</code>:
        </li>
      </ul>
      <CodeBlock language="json">
        {`{"msg":"Invited","email":{"_filtered":{"_class":"String","_hash":"537d1000c07039b3"}},"invite_token":{"_filtered":{"_class":"String"}},"src":"app","evt":"log","ts":"2026-10-17T03:14:21.865Z","lvl":"info","prog":"Rails"}`}
      </CodeBlock>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          <strong>More keys are filtered.</strong> Sensitive keys are matched by their words in any
          case or separator style, so <code>apiKey</code>, <code>X-Api-Key</code>,{' '}
          <code>Set-Cookie</code>, <code>passwords</code>, <code>session</code>,{' '}
          <code>passcode</code> and <code>card_number</code> are filtered by default. Rails&apos;{' '}
          <code>filter_parameters</code> match as Rails matches them: <code>:secret</code> filters{' '}
          <code>clientSecret</code>. See{' '}
          <Link href="/docs/filtering-sensitive-data" className="underline">
            Filtering Sensitive Data
          </Link>
          .
        </li>
        <li>
          <strong>Request lines</strong> have <code>source_ip</code> and <code>host</code>. If your{' '}
          <code>lograge_custom_options</code> added them, remove them there.
        </li>
        <li>
          <strong>Tags are written</strong>: <code>logger.tagged</code> and{' '}
          <code>config.log_tags</code> give a <code>tags</code> array, and named tags go in{' '}
          <code>ctx</code>.
        </li>
        <li>
          <strong>Times have milliseconds</strong> in every field (<code>scheduled_at</code>,{' '}
          <code>started_at</code>, <code>finished_at</code>, ...), like <code>ts</code>. A finish
          line&apos;s <code>ts</code> is when the job finished.
        </li>
        <li>
          <strong>Size limits.</strong> Hashes write their first 100 keys, backtraces 20 lines (an
          error line&apos;s backtrace had 5), other Arrays 10 items, and strings are cut at 32 KB.
          See{' '}
          <Link href="/docs/configuration#limits" className="underline">
            Limits
          </Link>
          .
        </li>
        <li>
          <strong>Error lines</strong> from Sidekiq, Puma and ActiveJob have typed fields instead of
          fields in <code>additional_data</code>, and the request&apos;s <code>path</code>,{' '}
          <code>method</code>, <code>source_ip</code>, <code>user_agent</code> and{' '}
          <code>referer</code>. A message logged with an exception (
          <code>logger.error(&quot;Import failed&quot;, e)</code>) has the message in{' '}
          <code>msg</code> and the exception&apos;s in <code>error_message</code>.
        </li>
        <li>
          <strong>Mail error lines</strong> say <code>Email delivery failed</code>, not{' '}
          <code>Email delivery error, will retry</code>. Update alerts that match the old text.
        </li>
        <li>
          <strong>Removed fields</strong> that were never written: ActiveStorage&apos;s{' '}
          <code>url</code> (a signed URL anyone could use), ActiveJob&apos;s <code>retries</code>,
          the blocked host line&apos;s <code>allowed_hosts</code> and <code>allow_ip_hosts</code>{' '}
          (it has <code>blocked_hosts</code> instead), and Shrine&apos;s <code>metadata</code> and{' '}
          <code>exist</code>.
        </li>
      </ul>

      <HeadingWithAnchor id="behavior">Behavior changes</HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          <strong>Production writes to STDOUT only.</strong> LogStruct no longer adds a{' '}
          <code>log/production.log</code> that nothing rotated. Development writes STDOUT and its
          log file, and test its log file. See{' '}
          <Link href="/docs/when-logstruct-runs#where-lines-go" className="underline">
            Where lines go
          </Link>
          .
        </li>
        <li>
          <strong>Sorbet type errors raise in development and test.</strong>{' '}
          <code>error_handling_modes.type_checking_errors</code> defaults to{' '}
          <code>ReportProduction</code>: raised in <code>local_environments</code>, logged and
          reported in production. They were only logged, so a test suite can find type errors it
          missed before. Set it to <code>Log</code> to only log them while you fix them.
        </li>
        <li>
          <strong>Integrations are set up after your initializers</strong>, so the settings in{' '}
          <code>config/initializers/logstruct.rb</code> apply. LogStruct&apos;s Lograge settings and
          Sidekiq logger replace ones another initializer set: configure them through LogStruct (
          <code>lograge_custom_options</code>, for example).
        </li>
        <li>
          <strong>IP spoofing</strong> isn&apos;t checked on every request any more. Rails raises{' '}
          <code>IpSpoofAttackError</code> where your app reads <code>remote_ip</code> and responds
          as it would without LogStruct, and LogStruct logs it there.
        </li>
        <li>
          <strong>Blocked hosts</strong> get your app&apos;s own{' '}
          <code>config.host_authorization[:response_app]</code> if you set one.
        </li>
        <li>
          <strong>Mail delivery jobs log only the mailer, the mail and the delivery method</strong>{' '}
          as their <code>arguments</code>, because mailers are often passed tokens (Devise&apos;s
          reset password token) as plain Strings.
        </li>
        <li>
          <strong>A failed Sidekiq job</strong> is one structured <code>warn</code> line without its
          arguments, instead of Sidekiq&apos;s three text lines.
        </li>
        <li>
          <strong>Mailers keep their logger</strong>, so <code>logger.info</code> in a mailer is
          written.
        </li>
      </ul>

      <HeadingWithAnchor id="code">Code that may need changing</HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          <code>LogStruct::Log::Sidekiq</code> is now <code>LogStruct::Log::Sidekiq::Log</code>.
        </li>
        <li>
          <code>LogStruct::Log::Error</code>&apos;s <code>error_class</code> takes any{' '}
          <code>Exception</code> class.
        </li>
        <li>
          <code>LogStruct.handle_exception</code> takes <code>log:</code>. If your tests stub it
          with a lambda, accept <code>log:</code> too.
        </li>
        <li>
          Removed: <code>LogStruct::Integrations::GoodJob::LogSubscriber</code> and{' '}
          <code>Log::GoodJob::Enqueue</code>, <code>Start</code>, <code>Finish</code> and{' '}
          <code>Schedule</code> (GoodJob&apos;s jobs are logged by the ActiveJob integration),{' '}
          <code>LogStruct::Integrations::Rack</code>, <code>Log::ActiveStorage::Stream</code> and{' '}
          <code>Event::Stream</code>.
        </li>
        <li>
          <code>config.integrations.enable_semantic_logger</code> does nothing. It&apos;s kept so
          existing configs load; you can remove it.
        </li>
      </ul>

      <HeadingWithAnchor id="new">New in 0.2.0</HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          <Link href="/docs/configuration#limits" className="underline">
            <code>config.limits</code>
          </Link>
          , <code>filters.url_query_params</code>, <code>filters.path_matchers</code> and{' '}
          <code>filters.authorization_credentials</code>.
        </li>
        <li>
          ActiveJob <code>retry</code>, <code>retry_stopped</code> and <code>discard</code> lines,
          and lines for <code>perform_all_later</code>.
        </li>
        <li>CarrierWave download and delete lines, and ActiveStorage deletes by prefix.</li>
        <li>
          Every line logged during a Sidekiq job has the job&apos;s <code>jid</code> and class in{' '}
          <code>ctx</code>.
        </li>
        <li>
          Forked children (Puma and Unicorn workers, Passenger, Pitchfork, Resque) write their lines
          with no setup.
        </li>
      </ul>

      <Callout className="mt-4">
        <p>
          If you use the{' '}
          <Link href="/docs/terraform" className="underline">
            Terraform provider
          </Link>
          , upgrade it with the gem: its catalog of sources and events is built in, and 0.2.0
          removes GoodJob&apos;s <code>enqueue</code>, <code>start</code>, <code>finish</code> and{' '}
          <code>schedule</code> events and ActiveStorage&apos;s <code>stream</code> event.
        </p>
      </Callout>

      <EditPageLink />
    </div>
  );
}
