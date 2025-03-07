import { EditPageLink } from '@/components/edit-page-link';
import { CodeBlock } from '@/components/code-block';
import { RubyCodeExample } from '@/components/ruby-code-example';

export default function GettingStartedPage() {
  return (
    <div className="space-y-6">
      <h1 className="text-4xl font-bold">Getting Started with LogStruct</h1>
      <p className="text-lg text-neutral-600 dark:text-neutral-400">
        Follow these steps to add LogStruct to your Rails application and start
        enjoying the benefits of structured JSON logging.
      </p>

      <h2 className="text-2xl font-bold mt-10 mb-4">Installation</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        {`Add this line to your application's Gemfile:`}
      </p>
      <CodeBlock language="ruby">{`gem 'logstruct'`}</CodeBlock>

      <p className="text-neutral-600 dark:text-neutral-400 mt-6 mb-4">
        And then execute:
      </p>
      <CodeBlock language="bash">bundle install</CodeBlock>

      <p className="text-neutral-600 dark:text-neutral-400 mt-6">
        {`LogStruct is now installed and will automatically enable JSON structured logging in the test and production environments.`}
      </p>

      <h2 className="text-2xl font-bold mt-10 mb-4">Basic Configuration</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
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

      <h2 className="text-2xl font-bold mt-10 mb-4">Basic Usage</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        You can use LogStruct with the standard Rails logger:
      </p>

      <CodeBlock language="ruby">
        {`# Log a simple message
Rails.logger.info "User signed in"

# Log structured data
Rails.logger.info({
  src: "rails",
  evt: "user_login",
  user_id: user.id,
  ip_address: request.remote_ip
})

# Log with tags
Rails.logger.tagged("Authentication") do
  Rails.logger.info "User signed in"
  Rails.logger.info({ user_id: user.id, ip_address: request.remote_ip })
end`}
      </CodeBlock>

      <p className="text-neutral-600 dark:text-neutral-400 mt-6">
        LogStruct will automatically convert all logs to JSON format with a
        consistent structure, making them easy to parse and search in log
        management systems.
      </p>

      <h2 className="text-2xl font-bold mt-10 mb-4">Next Steps</h2>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        Explore these pages to learn more about LogStruct:
      </p>
      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-400">
        <li>
          <a
            href="/docs/configuration"
            className="text-gray-200 hover:underline"
          >
            Configuration
          </a>{' '}
          - Learn how to customize LogStruct for your needs
        </li>
        <li>
          <a
            href="/docs/integrations"
            className="text-gray-200 hover:underline"
          >
            Integrations
          </a>{' '}
          - Explore built-in integrations with popular gems
        </li>
        <li>
          <a href="/docs/type-safety" className="text-gray-200 hover:underline">
            Type Safety
          </a>{' '}
          - Advanced logging with Sorbet type checking
        </li>
      </ul>

      <EditPageLink />
    </div>
  );
}
