import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { Callout } from '@/components/ui/callout';
import { getCodeExample } from '@/lib/codeExamples';

export default function DocsPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="introduction" level={1}>
        Introduction
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-400">
        LogStruct adds JSON structured logging to any Rails app. Simply add the
        gem to your Gemfile and add an initializer to configure it. Now your
        Rails app prints beautiful JSON logs to STDOUT.
      </p>

      <HeadingWithAnchor id="features" level={2}>
        Features
      </HeadingWithAnchor>
      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-400">
        <li>
          JSON logging enabled by default in production and test environments.
        </li>
        <li>
          Sets up <a href="https://github.com/roidrage/lograge">Lograge</a> for
          structured request logging.
        </li>
        <li>
          Uses{' '}
          <a href="https://github.com/reidmorrison/semantic_logger">
            Semantic Logger
          </a>{' '}
          as the logging framework.
        </li>
        <li>
          Automatic integration with many Rails components and third-party gems.
        </li>
        <li>
          Customizable error handling and reporting with sensible,
          production-ready defaults.
        </li>
        <li>
          Sensitive data scrubbing and param filtering for security and privacy.
        </li>
        <li>
          Host authorization response app for logging &quot;blocked host&quot;
          security violations.
        </li>
        <li>
          Rack middleware for logging errors, IP Spoofing, CSRF violations, etc.
        </li>
        <li>Type checking with Sorbet.</li>
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
            <CodeBlock language="ruby">
              {getCodeExample('basic_logging').code}
            </CodeBlock>
            <Callout className="mt-4">
              This approach is ideal for most applications. No knowledge of
              Sorbet is required and you don&apos;t need to worry about
              type-checking.
            </Callout>
          </TabsContent>
          <TabsContent value="typed" className="mt-0.5">
            <CodeBlock language="ruby">
              {getCodeExample('typed_logging').code}
            </CodeBlock>
            <Callout className="mt-4" type="success">
              This approach provides several benefits: IDE autocompletion, type
              checking (in all environments), and guaranteed log structure with
              valid data.
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
          View on GitHub
        </a>
      </div>

      <EditPageLink />
    </div>
  );
}
