import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { EditPageLink } from '@/components/edit-page-link';
import { parseGemspec } from '@/lib/gemspec-parser';
import { Card } from '@/components/ui/card';
import { Callout } from '@/components/ui/callout';

// Make this a server component
export default async function SupportedVersionsPage() {
  const dependencies = parseGemspec();
  const requiredDeps = dependencies.filter((dep) => dep.type === 'required');
  const optionalDeps = dependencies.filter((dep) => dep.type === 'optional');

  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="supported-versions" level={1}>
        Supported Versions
      </HeadingWithAnchor>

      <HeadingWithAnchor id="ruby-versions" level={2}>
        Ruby Version
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-400">
        LogStruct requires Ruby <span className="text-gray-200">3.2.0</span> or
        higher.
      </p>

      <HeadingWithAnchor id="required-dependencies" level={2}>
        Required Dependencies
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        These gems are required for LogStruct to function properly.
      </p>

      <Card className="p-6">
        <div className="relative overflow-x-auto">
          <table className="w-full text-sm text-left">
            <thead className="text-neutral-700 dark:text-neutral-300 border-b border-neutral-200 dark:border-neutral-700">
              <tr>
                <th scope="col" className="px-4 py-3 font-medium">
                  Gem
                </th>
                <th scope="col" className="px-4 py-3 font-medium">
                  Version
                </th>
                <th scope="col" className="px-4 py-3 font-medium">
                  Description
                </th>
              </tr>
            </thead>
            <tbody>
              {requiredDeps.map((dep) => (
                <tr
                  key={dep.name}
                  className="border-b border-neutral-200 dark:border-neutral-700"
                >
                  <td className="px-4 py-4 font-medium">
                    <a
                      href={`https://rubygems.org/gems/${dep.name}`}
                      target="_blank"
                      rel="noopener noreferrer"
                    >
                      {dep.name}
                    </a>
                  </td>
                  <td className="px-4 py-4 font-mono text-xs">{dep.version}</td>
                  <td className="px-4 py-4">{getGemDescription(dep.name)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      <HeadingWithAnchor id="optional-integrations" level={2}>
        Optional Integrations
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct provides seamless integration with these gems, but they are
        not required for its core functionality.
      </p>

      <Card className="p-6">
        <div className="relative overflow-x-auto">
          <table className="w-full text-sm text-left">
            <thead className="text-neutral-700 dark:text-neutral-300 border-b border-neutral-200 dark:border-neutral-700">
              <tr>
                <th scope="col" className="px-4 py-3 font-medium">
                  Gem
                </th>
                <th scope="col" className="px-4 py-3 font-medium">
                  Version
                </th>
                <th scope="col" className="px-4 py-3 font-medium">
                  Description
                </th>
              </tr>
            </thead>
            <tbody>
              {optionalDeps.map((dep) => (
                <tr
                  key={dep.name}
                  className="border-b border-neutral-200 dark:border-neutral-700"
                >
                  <td className="px-4 py-4 font-medium">
                    <a
                      href={`https://rubygems.org/gems/${dep.name}`}
                      target="_blank"
                      rel="noopener noreferrer"
                    >
                      {dep.name}
                    </a>
                  </td>
                  <td className="px-4 py-4 font-mono text-xs">{dep.version}</td>
                  <td className="px-4 py-4">{getGemDescription(dep.name)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      <Callout type="info">
        <p>
          Please open a PR if you would like to add support for other gems or
          older versions.
        </p>
      </Callout>

      <HeadingWithAnchor id="how-to-use" level={2}>
        How to Use Integrations
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-400">
        To use LogStruct with any of the optional integrations, simply add the
        desired gem to your Gemfile and LogStruct will automatically detect and
        configure it. See the <a href="/docs/integrations">Integrations</a> page
        for more details and log examples.
      </p>

      <EditPageLink />
    </div>
  );
}

// Helper function to provide descriptions for each gem
function getGemDescription(gemName: string): string {
  const descriptions: { [key: string]: string } = {
    rails: 'Web application framework',
    lograge: "Taming Rails' default request logging",
    'sorbet-runtime': "Sorbet's runtime type checking component",
    bugsnag: 'Error monitoring and reporting service',
    carrierwave: 'File upload solution for Rails',
    honeybadger: 'Exception, uptime, and performance monitoring',
    rollbar: 'Error tracking and debugging tool',
    'sentry-ruby':
      'Error tracking that helps developers monitor and fix crashes',
    shrine: 'File attachment toolkit for Ruby applications',
    sidekiq: 'Simple, efficient background processing for Ruby',
    sorbet: 'A type checker for Ruby',
    semantic_logger: 'A flexible logging framework for Ruby',
    'dotenv-rails': 'Loads environment variables from `.env` files',
    active_model_serializers: 'A library for serializing Ruby objects to JSON',
    ahoy_matey: 'Analytics for Rails',
  };

  const description = descriptions[gemName];
  if (!description) {
    throw new Error(
      `No description found for gem: ${gemName}. Add it to docs/app/docs/supported-versions/page.tsx`,
    );
  }

  return descriptions[gemName];
}
