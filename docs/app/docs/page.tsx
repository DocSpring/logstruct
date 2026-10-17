import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { Callout } from '@/components/ui/callout';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { getCodeExample } from '@/lib/codeExamples';

export default function DocsPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="introduction" level={1}>
        Introduction
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-300">
        LogStruct adds JSON structured logging to Rails apps. Add the gem to your Gemfile, and in
        production your app writes one JSON line to STDOUT for each request, job, email, error and
        log call. An initializer is only needed to change the defaults.
      </p>

      <HeadingWithAnchor id="features" level={2}>
        Features
      </HeadingWithAnchor>
      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          On in production for the server and job processes it recognizes (Puma, Unicorn, Thin,
          Falcon, <code>rails server</code>, Sidekiq and <code>good_job start</code>), and in test
          for every process except the console. Off in development, consoles and production Rake
          tasks unless you set <code>LOGSTRUCT_ENABLED=true</code>. See{' '}
          <a href="/docs/when-logstruct-runs">When LogStruct runs</a>.
        </li>
        <li>
          Sets up <a href="https://github.com/roidrage/lograge">Lograge</a> for request lines, and
          uses <a href="https://github.com/reidmorrison/semantic_logger">Semantic Logger</a> to
          write every line.
        </li>
        <li>
          <a href="/docs/integrations">Integrations</a> for ActiveJob, ActionMailer, Sidekiq,
          GoodJob, Puma, ActiveStorage, Shrine, CarrierWave, Ahoy, ActiveModelSerializers, Dotenv
          and SQL queries (opt-in).
        </li>
        <li>
          <a href="/docs/filtering-sensitive-data">Filtering</a> of sensitive keys and scrubbing of
          emails, card numbers and other sensitive values in strings.
        </li>
        <li>
          Security lines for blocked hosts, CSRF errors and IP spoofing errors, with Rails&apos; own
          responses left as they are.
        </li>
        <li>
          Error handling modes that decide whether each kind of error is raised, logged or reported,
          with reports going to Sentry, Bugsnag, Rollbar, Honeybadger or your own reporter.
        </li>
        <li>
          Typed log lines with <a href="/docs/sorbet-types">Sorbet</a>, for the built-in lines and
          your own.
        </li>
      </ul>

      <HeadingWithAnchor id="logging-with-logstruct" level={2}>
        Logging with LogStruct
      </HeadingWithAnchor>

      <div className="mt-4">
        <Tabs defaultValue="ruby">
          <TabsList className="cursor-pointer w-fit">
            <TabsTrigger value="ruby" className="cursor-pointer">
              Plain Ruby
            </TabsTrigger>
            <TabsTrigger value="typed" className="cursor-pointer">
              Sorbet Types
            </TabsTrigger>
          </TabsList>
          <TabsContent value="ruby" className="mt-0.5">
            <CodeBlock language="ruby">{getCodeExample('basic_logging').code}</CodeBlock>
            <p className="mt-4 text-neutral-600 dark:text-neutral-300">These lines are written:</p>
            <CodeBlock language="json">
              {`{"src":"app","evt":"log","lvl":"info","ts":"2026-10-17T03:14:21.865+00:00","msg":"User signed in","prog":"Rails"}
{"evt":"user_login","user_id":123,"plan":"pro","src":"app","ts":"2026-10-17T03:14:21.865+00:00","lvl":"info","prog":"Rails"}
{"msg":"Charged the card","amount_cents":1999,"currency":"usd","src":"app","evt":"log","ts":"2026-10-17T03:14:21.865+00:00","lvl":"info","prog":"Rails"}`}
            </CodeBlock>
            <Callout className="mt-4">
              Most apps only need this. No knowledge of Sorbet is required.
            </Callout>
          </TabsContent>
          <TabsContent value="typed" className="mt-0.5">
            <CodeBlock language="ruby">{getCodeExample('typed_logging').code}</CodeBlock>
            <p className="mt-4 text-neutral-600 dark:text-neutral-300">This line is written:</p>
            <CodeBlock language="json">
              {`{"src":"app","evt":"log","lvl":"info","ts":"2026-10-17T03:14:21.865+00:00","msg":"User signed in","user_id":123,"plan":"pro","prog":"Rails"}`}
            </CodeBlock>
            <Callout className="mt-4" type="success">
              Typed lines give you IDE autocompletion, and their fields are type-checked when the
              line is built: a wrong type raises in development and test, and is reported in
              production. The <code>additional_data</code> fields are merged into the top level of
              the line.
            </Callout>
          </TabsContent>
        </Tabs>
      </div>

      <div className="mt-10 flex gap-4">
        <a
          href="/docs/getting-started"
          className="rounded-md bg-neutral-900 px-4 py-2 font-medium text-white transition-colors hover:bg-neutral-700 dark:bg-neutral-100 dark:text-neutral-900 dark:hover:bg-neutral-200"
        >
          Get Started →
        </a>
        <a
          href="https://github.com/DocSpring/logstruct"
          target="_blank"
          rel="noopener noreferrer"
          className="rounded-md border border-neutral-200 px-4 py-2 font-medium text-neutral-900 transition-colors hover:bg-neutral-100 dark:border-neutral-800 dark:text-neutral-100 dark:hover:bg-neutral-800"
        >
          GitHub
        </a>
      </div>

      <EditPageLink />
    </div>
  );
}
