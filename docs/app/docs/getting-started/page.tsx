import { EditPageLink } from '@/components/edit-page-link';
import { CodeBlock } from '@/components/code-block';
import { RubyCodeExample } from '@/components/ruby-code-example';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { getCodeExample } from '@/lib/codeExamples';

export default function GettingStartedPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="getting-started" level={1}>
        Getting Started with LogStruct
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-300">
        Follow these steps to add LogStruct to your Rails application and start
        enjoying the benefits of structured JSON logging.
      </p>

      <HeadingWithAnchor id="installation" level={2}>
        Installation
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        {`Add this line to your application's Gemfile:`}
      </p>
      <CodeBlock language="ruby">{`gem 'logstruct'`}</CodeBlock>

      <p className="text-neutral-600 dark:text-neutral-300 mt-6 mb-4">
        And then execute:
      </p>
      <CodeBlock language="bash">bundle install</CodeBlock>

      <p className="text-neutral-600 dark:text-neutral-300 mt-6">
        {`LogStruct is now installed and will automatically enable JSON structured logging for test runs and server processes in production environments. Console and other Rake tasks will use human-readable logs by default.`}
      </p>

      <HeadingWithAnchor id="basic-configuration" level={2}>
        Basic Configuration
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        While LogStruct works out of the box with zero configuration, you might
        want to customize it to better suit your application. Create a new file
        at{' '}
        <code className="px-1 py-0.5 bg-neutral-100 dark:bg-neutral-800 rounded">
          config/initializers/logstruct.rb
        </code>{' '}
        with the following content:
      </p>

      <RubyCodeExample
        name="basic_configuration"
        title="config/initializers/logstruct.rb"
      />

      <HeadingWithAnchor id="basic-usage" level={2}>
        Basic Usage
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        You can use LogStruct with the standard Rails logger:
      </p>

      <CodeBlock language="ruby">
        {getCodeExample('getting_started_basic_logging').code}
      </CodeBlock>

      <p className="text-neutral-600 dark:text-neutral-300 mt-6">
        LogStruct will automatically convert all logs to JSON format with a
        consistent structure, making them easy to parse and search in log
        management systems.
      </p>

      <HeadingWithAnchor id="next-steps" level={2}>
        Next Steps
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        Explore these pages to learn more about LogStruct:
      </p>
      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          <a href="/docs/configuration">Configuration</a> - Learn how to
          customize LogStruct for your application
        </li>
        <li>
          <a href="/docs/integrations">Integrations</a> - Explore built-in
          integrations with popular gems
        </li>
        <li>
          <a href="/docs/sorbet-types">Type Safety</a> - Advanced logging with
          Sorbet type checking
        </li>
      </ul>

      <EditPageLink />
    </div>
  );
}
