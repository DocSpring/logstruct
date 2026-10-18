import Link from 'next/link';
import { EditPageLink } from '@/components/edit-page-link';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { Card } from '@/components/ui/card';
import { getGemDescription, getIntegrationRows } from '@/lib/gem-descriptions';
import {
  parseCiCombinations,
  parseGemspec,
  parseMinimumRailsVersion,
  parseMinimumRubyVersion,
  parseUnitTestRailsVersion,
  RAILS_DEPENDENCIES,
} from '@/lib/gemspec-parser';

const thClass = 'px-4 py-3 font-medium';
const rowClass = 'border-b border-neutral-200 dark:border-neutral-700';

function GemLink({ name }: { name: string }) {
  return (
    <a href={`https://rubygems.org/gems/${name}`} target="_blank" rel="noopener noreferrer">
      {name}
    </a>
  );
}

export default async function SupportedVersionsPage() {
  const dependencies = parseGemspec();
  const requiredDeps = dependencies.filter((dep) => dep.type === 'required');
  const integrations = getIntegrationRows(dependencies);
  const rubyVersion = parseMinimumRubyVersion();
  const railsVersion = parseMinimumRailsVersion();
  const ciCombinations = parseCiCombinations();
  const unitTestRailsVersion = parseUnitTestRailsVersion();

  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="supported-versions" level={1}>
        Supported Versions
      </HeadingWithAnchor>

      <HeadingWithAnchor id="ruby-versions" level={2}>
        Ruby and Rails
      </HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          Ruby <strong>{rubyVersion}</strong> or newer (the gemspec&apos;s{' '}
          <code>required_ruby_version</code>).
        </li>
        <li>
          Rails <strong>{railsVersion}</strong> or newer. LogStruct depends on{' '}
          {RAILS_DEPENDENCIES.map((name, index) => (
            <span key={name}>
              {index > 0 && (index === RAILS_DEPENDENCIES.length - 1 ? ' and ' : ', ')}
              <code>{name}</code>
            </span>
          ))}
          , not on the whole of Rails, so your app doesn&apos;t need Active Record, Active Job,
          Action Mailer or Active Storage.
        </li>
      </ul>

      <HeadingWithAnchor id="tested-versions" level={2}>
        Versions CI Tests
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        On every pull request and push to main, CI runs LogStruct&apos;s tests, and the integration
        tests of a Rails app generated with the Rails version below, on these combinations. The unit
        tests use Rails {unitTestRailsVersion} in every combination; the Rails version is the
        generated app&apos;s.
      </p>

      <Card className="p-6">
        <div className="relative overflow-x-auto">
          <table className="w-full text-sm text-left">
            <thead className="text-neutral-700 dark:text-neutral-300 border-b border-neutral-200 dark:border-neutral-700">
              <tr>
                <th scope="col" className={thClass}>
                  Ruby
                </th>
                <th scope="col" className={thClass}>
                  Rails
                </th>
              </tr>
            </thead>
            <tbody>
              {ciCombinations.map((combination) => (
                <tr key={`${combination.ruby}-${combination.rails}`} className={rowClass}>
                  <td className="px-4 py-4 font-mono text-xs">{combination.ruby}</td>
                  <td className="px-4 py-4 font-mono text-xs">
                    {combination.rails === 'main' ? "main (Rails' main branch)" : combination.rails}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      <p className="text-neutral-600 dark:text-neutral-300">
        The integration tests also run against Rails&apos; main branch every night. Another job
        boots an app whose bundle has only <code>railties</code> and <code>actionpack</code> and
        checks that it logs a request.
      </p>

      <HeadingWithAnchor id="required-dependencies" level={2}>
        Required Dependencies
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        Installing LogStruct installs these gems.
      </p>

      <Card className="p-6">
        <div className="relative overflow-x-auto">
          <table className="w-full text-sm text-left">
            <thead className="text-neutral-700 dark:text-neutral-300 border-b border-neutral-200 dark:border-neutral-700">
              <tr>
                <th scope="col" className={thClass}>
                  Gem
                </th>
                <th scope="col" className={thClass}>
                  Requirement
                </th>
                <th scope="col" className={thClass}>
                  Description
                </th>
              </tr>
            </thead>
            <tbody>
              {requiredDeps.map((dep) => (
                <tr key={dep.name} className={rowClass}>
                  <td className="px-4 py-4 font-medium">
                    <GemLink name={dep.name} />
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
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct doesn&apos;t install these gems. When your app loads one, LogStruct logs what it
        does (or, for the error reporters, reports errors to it). <strong>Tested with</strong> is
        the version LogStruct&apos;s own test suite installs: the development dependencies in its
        gemspec, or what its Rails test app adds. Other versions may work, but they aren&apos;t
        tested.
      </p>

      <Card className="p-6">
        <div className="relative overflow-x-auto">
          <table className="w-full text-sm text-left">
            <thead className="text-neutral-700 dark:text-neutral-300 border-b border-neutral-200 dark:border-neutral-700">
              <tr>
                <th scope="col" className={thClass}>
                  Gem
                </th>
                <th scope="col" className={thClass}>
                  Tested with
                </th>
                <th scope="col" className={thClass}>
                  Description
                </th>
              </tr>
            </thead>
            <tbody>
              {integrations.map((integration) => (
                <tr key={integration.name} className={rowClass}>
                  <td className="px-4 py-4 font-medium">
                    <GemLink name={integration.name} />
                  </td>
                  <td className="px-4 py-4 font-mono text-xs">{integration.testedWithText}</td>
                  <td className="px-4 py-4">
                    {integration.description}
                    {integration.notes && (
                      <p className="mt-1 text-xs text-neutral-500 dark:text-neutral-400">
                        {integration.notes}
                      </p>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      <HeadingWithAnchor id="how-to-use" level={2}>
        How Integrations Turn On
      </HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          Each integration runs when its gem is loaded, in the processes where LogStruct is on (see{' '}
          <Link href="/docs/configuration#enabling-logstruct">Enabling LogStruct</Link>).
        </li>
        <li>
          Each one except the error reporters has an <code>enable_*</code> setting to turn it off.
          SQL query logging is off by default (<code>enable_sql_logging</code>).
        </li>
        <li>
          Errors are reported to one service: the first of Sentry, Bugsnag, Rollbar and Honeybadger
          that your app loads, unless you set an{' '}
          <Link href="/docs/configuration#custom-error-reporting">error reporting handler</Link>.
        </li>
      </ul>
      <p className="text-neutral-600 dark:text-neutral-300">
        The <Link href="/docs/integrations">Integrations</Link> page shows what each one logs.
        Please open a PR if you&apos;d like support for another gem or version.
      </p>

      <EditPageLink />
    </div>
  );
}
