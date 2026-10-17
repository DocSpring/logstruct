// The gems on the supported versions page: LogStruct's dependencies and the gems it integrates with
import { type GemDependency, parseRailsTestAppPumaRequirement } from './gemspec-parser';

// Descriptions of the gems LogStruct depends on (spec.add_dependency in logstruct.gemspec)
const REQUIRED_GEM_DESCRIPTIONS: { [gemName: string]: string } = {
  actionpack: "Rails' request handling (controllers, middleware)",
  activesupport: "Rails' core extensions and notifications",
  globalid: 'Global IDs for records, used to log job arguments',
  lograge: "Rails' request logs as one line per request",
  railties: 'Rails core: application boot and Railtie hooks',
  semantic_logger: 'The logger LogStruct writes its lines with',
  'sorbet-runtime': "Sorbet's runtime type checks, for LogStruct's typed log lines",
};

// Development dependencies in logstruct.gemspec that aren't integrations
export const DEVELOPMENT_TOOLS = ['sorbet'];

export interface Integration {
  name: string;
  description: string;
  // For gems that aren't development dependencies in logstruct.gemspec: what the tests use
  testedWith?: () => string;
  notes?: string;
}

const RAILS_TEST_APP = 'The Rails versions above (Rails test app)';

export const INTEGRATIONS: Integration[] = [
  {
    name: 'actionmailer',
    description: "Rails' mailers: delivery lines and mailer errors",
    testedWith: () => RAILS_TEST_APP,
  },
  {
    name: 'activejob',
    description: "Rails' job framework: a line for each step of a job, and its errors",
    testedWith: () => RAILS_TEST_APP,
  },
  {
    name: 'activerecord',
    description: 'Slow SQL query lines',
    testedWith: () => RAILS_TEST_APP,
    notes: 'Off by default: set enable_sql_logging to turn it on.',
  },
  {
    name: 'activestorage',
    description: "Rails' file storage: uploads, downloads, deletes and other storage calls",
    testedWith: () => RAILS_TEST_APP,
  },
  {
    name: 'active_model_serializers',
    description: 'Serializing Ruby objects to JSON',
  },
  { name: 'ahoy_matey', description: 'Analytics for Rails' },
  { name: 'bugsnag', description: 'Error reporting' },
  { name: 'carrierwave', description: 'File uploads' },
  { name: 'dotenv-rails', description: 'Loads environment variables from .env files' },
  {
    name: 'good_job',
    description: 'A Postgres-based ActiveJob backend',
    testedWith: () => 'Not installed: the tests use stand-ins',
    notes:
      "The ActiveJob integration logs GoodJob's jobs; this one makes GoodJob's own lines JSON and logs its thread errors, which needs GoodJob 3.0 or later.",
  },
  { name: 'honeybadger', description: 'Error reporting' },
  {
    name: 'puma',
    description: 'Web server: boot, shutdown and request error lines',
    testedWith: () => `${parseRailsTestAppPumaRequirement()} (Rails test app)`,
  },
  { name: 'rollbar', description: 'Error reporting' },
  { name: 'sentry-ruby', description: 'Error reporting' },
  { name: 'shrine', description: 'File attachments' },
  {
    name: 'sidekiq',
    description: 'Background jobs',
    notes:
      "Sidekiq 6: LogStruct keeps Sidekiq's own failed-job handler, which logs the job (with its arguments) and the error in three lines. Sidekiq 6 and 8 are untested.",
  },
];

export function getGemDescription(gemName: string): string {
  const description =
    REQUIRED_GEM_DESCRIPTIONS[gemName] ??
    INTEGRATIONS.find((integration) => integration.name === gemName)?.description;
  if (!description) {
    throw new Error(
      `No description found for gem: ${gemName}. Add it to docs/lib/gem-descriptions.ts`,
    );
  }
  return description;
}

export interface IntegrationRow extends Integration {
  testedWithText: string;
}

// The integrations table: development dependencies are tested with the gemspec's requirement
export function getIntegrationRows(dependencies: GemDependency[]): IntegrationRow[] {
  const development = dependencies.filter((dep) => dep.type === 'development');

  for (const dep of development) {
    const known =
      DEVELOPMENT_TOOLS.includes(dep.name) ||
      INTEGRATIONS.some((integration) => integration.name === dep.name);
    if (!known) {
      throw new Error(
        `${dep.name} is a development dependency in logstruct.gemspec but not in docs/lib/gem-descriptions.ts. Add it to INTEGRATIONS or DEVELOPMENT_TOOLS.`,
      );
    }
  }

  return INTEGRATIONS.map((integration) => {
    const dep = development.find((d) => d.name === integration.name);
    if (dep && integration.testedWith) {
      throw new Error(
        `${integration.name} is a development dependency in logstruct.gemspec: remove its testedWith`,
      );
    }
    const testedWithText = dep ? dep.version : integration.testedWith?.();
    if (!testedWithText) {
      throw new Error(
        `${integration.name} isn't a development dependency in logstruct.gemspec: give it a testedWith`,
      );
    }
    return { ...integration, testedWithText };
  });
}
