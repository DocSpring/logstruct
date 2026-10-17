import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { RubyCodeExample } from '@/components/ruby-code-example';
import { Callout } from '@/components/ui/callout';

export default function GettingStartedPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="getting-started" level={1}>
        Getting Started with LogStruct
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-300">
        LogStruct needs Ruby 3.3 or newer and Rails 7.1 or newer.
      </p>

      <HeadingWithAnchor id="installation" level={2}>
        Installation
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        {`Add this line to your application's Gemfile:`}
      </p>
      <CodeBlock language="ruby">{`gem "logstruct"`}</CodeBlock>

      <p className="text-neutral-600 dark:text-neutral-300 mt-6 mb-4">And then run:</p>
      <CodeBlock language="bash">bundle install</CodeBlock>

      <p className="text-neutral-600 dark:text-neutral-300 mt-6">
        That&apos;s all you need. In production, LogStruct is now on for your web server and job
        processes (Puma, Unicorn, Thin, Falcon, <code>rails server</code>, Sidekiq and{' '}
        <code>good_job start</code>), and in test for every process except the console. Consoles,
        production Rake tasks and other processes keep Rails&apos; usual logger. See{' '}
        <a href="/docs/when-logstruct-runs">When LogStruct runs</a> for the details and how to turn
        it on for other processes.
      </p>

      <HeadingWithAnchor id="try-it-in-development" level={2}>
        Try It in Development
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct is off in development, so <code>rails server</code> looks the same as before. To
        see the lines your app will write in production, start the server with{' '}
        <code>LOGSTRUCT_ENABLED=true</code>:
      </p>
      <CodeBlock language="bash">LOGSTRUCT_ENABLED=true bin/rails server</CodeBlock>
      <p className="text-neutral-600 dark:text-neutral-300 mt-4 mb-4">
        Each request then writes a line like this:
      </p>
      <CodeBlock language="json">
        {`{"src":"rails","evt":"request","lvl":"info","ts":"2026-10-17T03:09:30.839+00:00","path":"/orders","method":"GET","source_ip":"203.0.113.7","user_agent":"Mozilla/5.0","referer":"https://app.example.com/","format":"html","controller":"OrdersController","action":"index","status":200,"duration_ms":42.1,"view":30.2,"db":8.4,"params":{"page":"2"},"host":"app.example.com","accept":"text/html","prog":"Rails","req_id":"6f1c2b7e-0d4a-4c1e-9a55-3b8e2f7d9c10"}`}
      </CodeBlock>

      <HeadingWithAnchor id="basic-configuration" level={2}>
        Basic Configuration
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct works without any configuration. To change its defaults, create{' '}
        <code className="px-1 py-0.5 bg-neutral-100 dark:bg-neutral-800 rounded">
          config/initializers/logstruct.rb
        </code>
        , for example:
      </p>

      <RubyCodeExample name="basic_configuration" title="config/initializers/logstruct.rb" />

      <p className="text-neutral-600 dark:text-neutral-300 mt-4">
        The <a href="/docs/configuration">configuration page</a> lists every setting.
      </p>

      <HeadingWithAnchor id="basic-usage" level={2}>
        Basic Usage
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        Keep using the Rails logger. Log a message, or a Hash of fields:
      </p>

      <RubyCodeExample name="getting_started_basic_logging" />

      <p className="text-neutral-600 dark:text-neutral-300 mt-6 mb-4">These lines are written:</p>
      <CodeBlock language="json">
        {`{"src":"app","evt":"log","lvl":"info","ts":"2026-10-17T03:14:21.865+00:00","msg":"User signed in","prog":"Rails"}
{"evt":"user_login","user_id":123,"email":{"_filtered":{"_class":"String","_hash":"18a290e45734f1a2"}},"src":"app","ts":"2026-10-17T03:14:21.865+00:00","lvl":"info","prog":"Rails"}
{"src":"app","evt":"log","lvl":"info","ts":"2026-10-17T03:14:21.865+00:00","msg":"Checking the password","prog":"Rails","tags":["Authentication"]}`}
      </CodeBlock>

      <Callout className="mt-4">
        <p>
          A Hash&apos;s keys become the line&apos;s fields. <code>evt</code> names the event
          (default <code>log</code>), and <code>src</code> says where the line came from (default{' '}
          <code>app</code>). Leave <code>src</code> as <code>app</code>, or use a name of your own:
          LogStruct&apos;s integrations use names like <code>rails</code> and <code>job</code>.
        </p>
        <p className="mt-2">
          The <code>email</code> value was filtered: LogStruct logs a hash of it, so you can find
          every line about the same address without logging the address. See{' '}
          <a href="/docs/filtering-sensitive-data">Filtering Sensitive Data</a>.
        </p>
      </Callout>

      <HeadingWithAnchor id="next-steps" level={2}>
        Next Steps
      </HeadingWithAnchor>
      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          <a href="/docs/configuration">Configuration</a>: every setting and its default
        </li>
        <li>
          <a href="/docs/integrations">Integrations</a>: the lines each integration writes
        </li>
        <li>
          <a href="/docs/log-fields">Log Fields</a>: what each field in a line means
        </li>
        <li>
          <a href="/docs/sorbet-types">Sorbet Types</a>: typed log lines of your own
        </li>
        <li>
          <a href="/docs/upgrading">Upgrading to 0.2.0</a>: if you used an earlier version
        </li>
      </ul>

      <EditPageLink />
    </div>
  );
}
