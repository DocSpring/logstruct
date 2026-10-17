import Link from 'next/link';
import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { RubyCodeExample } from '@/components/ruby-code-example';
import { Callout } from '@/components/ui/callout';

export default function WhenLogStructRunsPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="when-logstruct-runs" level={1}>
        When LogStruct Runs
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-300">
        LogStruct decides in each process whether to replace Rails&apos; logger. Where it&apos;s
        off, the process logs exactly as it would without LogStruct: Rails&apos; text lines, no
        filtering and no integrations.
      </p>

      <HeadingWithAnchor id="the-rule">The rule</HeadingWithAnchor>
      <ol className="list-decimal list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          When the <code>LOGSTRUCT_ENABLED</code> environment variable is set, it decides:{' '}
          <code>true</code>, <code>t</code>, <code>yes</code>, <code>y</code> or <code>1</code> (in
          any case) turns LogStruct on, and any other value turns it off. This applies to consoles
          too.
        </li>
        <li>
          Otherwise LogStruct is on when all of these are true:
          <ul className="list-disc list-outside ml-6 mt-2 space-y-1">
            <li>
              The Rails environment is in <code>config.enabled_environments</code> (default{' '}
              <code>[:test, :production]</code>).
            </li>
            <li>
              The process isn&apos;t a console (<code>rails console</code> or <code>rails c</code>).
            </li>
            <li>
              It&apos;s a server or job process LogStruct recognizes (below), or the environment is{' '}
              <code>test</code>.
            </li>
          </ul>
        </li>
      </ol>
      <p className="text-neutral-600 dark:text-neutral-300">
        So with the defaults, LogStruct is off in development, on for every test process except a
        console, and in production on only in the processes below.
      </p>

      <HeadingWithAnchor id="recognized-processes">Recognized processes</HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          <strong>Puma</strong>, when the program&apos;s name or one of its arguments contains{' '}
          <code>puma</code> (<code>bundle exec puma</code>, or <code>puma</code> started by a
          wrapper script).
        </li>
        <li>
          <strong>
            <code>rails server</code>
          </strong>
          , with any server.
        </li>
        <li>
          <strong>Unicorn, Thin and Falcon</strong>, when their server class (
          <code>Unicorn::HttpServer</code>, <code>Thin::Server</code>, <code>Falcon::Server</code>)
          is defined as LogStruct loads.
        </li>
        <li>
          <strong>Sidekiq</strong>, in the <code>sidekiq</code> process (
          <code>Sidekiq.server?</code>).
        </li>
        <li>
          <strong>GoodJob</strong>, in <code>good_job start</code>. GoodJob&apos;s async mode runs
          inside your web server, which is already recognized.
        </li>
      </ul>
      <p className="text-neutral-600 dark:text-neutral-300">
        Everything else keeps Rails&apos; logger in production. That includes Rake tasks (
        <code>db:migrate</code> too), <code>rails runner</code>, Solid Queue&apos;s{' '}
        <code>bin/jobs</code> (Rails 8&apos;s default job runner), Resque, Delayed Job, Passenger
        and Pitchfork.
      </p>
      <Callout className="mt-2">
        <p>
          Unicorn, Thin and Falcon are recognized by their class names. If your app loads one of
          these gems in every process (it&apos;s in the Gemfile without <code>require: false</code>
          ), Rake tasks and other processes may count as servers too.
        </p>
      </Callout>

      <HeadingWithAnchor id="other-processes">Turning it on for other processes</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        Set <code>LOGSTRUCT_ENABLED=true</code> in the environment of each process that should write
        LogStruct lines, for example in a Procfile:
      </p>
      <CodeBlock language="bash">
        {`web: bundle exec puma -C config/puma.rb
jobs: LOGSTRUCT_ENABLED=true bin/jobs
release: bin/rails db:migrate`}
      </CodeBlock>
      <p className="text-neutral-600 dark:text-neutral-300 mt-4">
        If you set <code>LOGSTRUCT_ENABLED=true</code> for a whole container image, every process in
        it gets LogStruct, consoles included. Set <code>LOGSTRUCT_ENABLED=false</code> to turn it
        off in a process LogStruct would otherwise recognize.
      </p>

      <HeadingWithAnchor id="from-an-initializer">From an initializer</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        LogStruct first decides when the gem is loaded (by <code>Bundler.require</code>), and checks
        again after <code>config/initializers</code> run. An initializer can set{' '}
        <code>config.enabled</code>, or change <code>config.enabled_environments</code> to apply the
        rule above to other environments. <code>LOGSTRUCT_ENABLED</code> wins over both, and{' '}
        <code>config.enabled</code> wins over <code>enabled_environments</code>.
      </p>
      <RubyCodeExample name="enable_in_development" title="config/initializers/logstruct.rb" />
      <p className="text-neutral-600 dark:text-neutral-300 mt-4">
        A few things are set up as the gem loads, before initializers run: Puma&apos;s boot lines in{' '}
        <code>rails server</code> and the logger that early boot lines go to. Use{' '}
        <code>LOGSTRUCT_ENABLED</code> to turn LogStruct on or off for all of the boot.
      </p>

      <HeadingWithAnchor id="development">In development</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        Start the server with <code>LOGSTRUCT_ENABLED=true bin/rails server</code> to see the lines
        your app writes in production. They&apos;re JSON by default; set{' '}
        <code>prefer_json_in_development = false</code> and <code>enable_color_output = true</code>{' '}
        for colored text instead (see{' '}
        <Link href="/docs/configuration#development-preview" className="underline">
          Logger Settings
        </Link>
        ).
      </p>

      <HeadingWithAnchor id="where-lines-go">Where lines go</HeadingWithAnchor>
      <div className="relative overflow-x-auto">
        <table className="w-full text-sm text-left text-neutral-600 dark:text-neutral-300">
          <thead className="text-neutral-700 dark:text-neutral-300 border-b border-neutral-200 dark:border-neutral-700">
            <tr>
              <th scope="col" className="px-4 py-2 font-medium">
                Environment
              </th>
              <th scope="col" className="px-4 py-2 font-medium">
                Output
              </th>
            </tr>
          </thead>
          <tbody>
            <tr className="border-b border-neutral-200 dark:border-neutral-700">
              <td className="px-4 py-2 font-mono text-xs">production (and others)</td>
              <td className="px-4 py-2">STDOUT only, unbuffered. No log file.</td>
            </tr>
            <tr className="border-b border-neutral-200 dark:border-neutral-700">
              <td className="px-4 py-2 font-mono text-xs">development</td>
              <td className="px-4 py-2">
                STDOUT and <code>log/development.log</code>
              </td>
            </tr>
            <tr className="border-b border-neutral-200 dark:border-neutral-700">
              <td className="px-4 py-2 font-mono text-xs">test</td>
              <td className="px-4 py-2">
                <code>log/test.log</code> only, so test output stays clean
              </td>
            </tr>
            <tr className="border-b border-neutral-200 dark:border-neutral-700">
              <td className="px-4 py-2 font-mono text-xs">RAILS_LOG_TO_STDOUT set</td>
              <td className="px-4 py-2">STDOUT only, in any environment</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p className="text-neutral-600 dark:text-neutral-300 mt-4">
        The environments that also write the log file are <code>config.local_environments</code>{' '}
        (default <code>[:development, :test]</code>). LogStruct honors <code>config.log_level</code>
        . A <code>config.logger</code> you set yourself applies only where LogStruct is off.
        Appenders your app adds to SemanticLogger in an initializer are kept. They write with the
        formatter you give them, so give them <code>LogStruct::SemanticLogger::Formatter.new</code>{' '}
        for filtered lines (see{' '}
        <Link href="/docs/filtering-sensitive-data#where-filtering-applies" className="underline">
          Where filtering applies
        </Link>
        ).
      </p>

      <HeadingWithAnchor id="forking-servers">Forking servers</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        LogStruct writes lines through SemanticLogger, which writes them from a background thread. A
        forked child doesn&apos;t inherit its parent&apos;s threads, so LogStruct hooks{' '}
        <code>Process._fork</code>, which Ruby calls for every fork, and starts a new writer thread
        in each child. This covers Puma&apos;s cluster mode, Unicorn, Passenger, Pitchfork, Resque
        and anything else that forks, with no <code>on_worker_boot</code> code of your own.
      </p>

      <HeadingWithAnchor id="when-its-off">When it&apos;s off</HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          Rails&apos; logger, Lograge&apos;s settings and Sidekiq&apos;s logger are left alone.
        </li>
        <li>
          Nothing is filtered or scrubbed: LogStruct&apos;s filters apply only to the lines it
          writes.
        </li>
        <li>
          Mailers still have <code>log_and_ignore_error</code>, <code>log_and_report_error</code>{' '}
          and <code>log_and_reraise_error</code>, so a <code>rescue_from</code> that names one of
          them works everywhere. They log a plain text line to the mailer&apos;s logger (see{' '}
          <Link href="/docs/integrations/action-mailer" className="underline">
            ActionMailer
          </Link>
          ).
        </li>
        <li>
          <code>LogStruct.info</code> and the other logging methods still work, through Rails&apos;
          logger.
        </li>
      </ul>

      <EditPageLink />
    </div>
  );
}
