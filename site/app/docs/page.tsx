import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { atomDark } from 'react-syntax-highlighter/dist/esm/styles/prism';
import { EditPageLink } from '@/components/edit-page-link';

export default function DocsPage() {
  return (
    <div className="space-y-6">
      <h1 className="text-4xl font-bold">LogStruct Documentation</h1>
      <p className="text-lg text-neutral-600 dark:text-neutral-400">
        LogStruct adds JSON structured logging to any Rails app. Simply add the
        gem to your Gemfile and add an initializer to configure it. Now your
        Rails app prints beautiful JSON logs to STDOUT.
      </p>

      <div className="my-8">
        <Tabs defaultValue="ruby">
          <TabsList>
            <TabsTrigger value="ruby">Plain Ruby</TabsTrigger>
            <TabsTrigger value="typed">Sorbet Types</TabsTrigger>
          </TabsList>
          <TabsContent value="ruby" className="mt-4">
            <div className="rounded-lg bg-neutral-100 p-4 dark:bg-neutral-900">
              <SyntaxHighlighter
                language="ruby"
                style={atomDark}
                customStyle={{
                  fontSize: '0.875rem',
                  fontFamily:
                    'ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace',
                  backgroundColor: 'transparent',
                  padding: '0',
                  borderRadius: '0px',
                }}
              >
                {`# Log a simple string
Rails.logger.info "User signed in"

# Log a hash with custom fields
Rails.logger.info({
  event: "user_login",
  user_id: 123,
  ip_address: "192.168.1.1",
  custom_field: "any value you want"
})`}
              </SyntaxHighlighter>
            </div>
            <p className="mt-4 text-neutral-600 dark:text-neutral-400">
              {`This approach is ideal for most applications and follows Ruby's philosophy of flexibility and developer convenience.`}
            </p>
          </TabsContent>
          <TabsContent value="typed" className="mt-4">
            <div className="rounded-lg bg-neutral-100 p-4 dark:bg-neutral-900">
              <SyntaxHighlighter
                language="ruby"
                style={atomDark}
                customStyle={{
                  fontSize: '0.875rem',
                  fontFamily:
                    'ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace',
                  backgroundColor: 'transparent',
                  padding: '0',
                  borderRadius: '0px',
                }}
              >
                {`# Create a typed request log entry
request_log = LogStruct::Log::Request.new(
  source: LogStruct::Source::Rails,
  method: "GET",
  path: "/users",
  status: 200,
  duration_ms: 45.2,
)

# Log the typed struct
Rails.logger.info(request_log)`}
              </SyntaxHighlighter>
            </div>
            <p className="mt-4 text-neutral-600 dark:text-neutral-400">
              This approach provides several benefits: type checking at
              development time, consistent log structure, IDE autocompletion,
              and better documentation.
            </p>
          </TabsContent>
        </Tabs>
      </div>

      <h2 className="text-2xl font-bold mt-10 mb-4">Features</h2>
      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-400">
        <li>
          JSON logging enabled by default in production and test environments
        </li>
        <li>ActionMailer integration for email delivery logging</li>
        <li>ActiveJob integration for job execution logging</li>
        <li>Sidekiq integration for background job logging</li>
        <li>Shrine and CarrierWave integration for file upload logging</li>
        <li>ActiveStorage integration for cloud storage operations</li>
        <li>Error handling and reporting</li>
        <li>Metadata collection for rich context</li>
        <li>Lograge integration for structured request logging</li>
        <li>Sensitive data scrubbing for security and privacy</li>
        <li>Host authorization logging for security violations</li>
        <li>Rack middleware for enhanced error logging</li>
        <li>Type checking with Sorbet and RBS annotations</li>
      </ul>

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
