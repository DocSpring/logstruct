// Descriptions of the gems in logstruct.gemspec, for the supported versions page
const GEM_DESCRIPTIONS: { [gemName: string]: string } = {
  actionpack: "Rails' request handling (controllers, middleware)",
  activesupport: "Rails' core extensions and notifications",
  globalid: 'Global IDs for records, used to log job arguments',
  lograge: "Taming Rails' default request logging",
  railties: 'Rails core: application boot and Railtie hooks',
  'sorbet-runtime': "Sorbet's runtime type checking component",
  bugsnag: 'Error monitoring and reporting service',
  carrierwave: 'File upload solution for Rails',
  honeybadger: 'Exception, uptime, and performance monitoring',
  rollbar: 'Error tracking and debugging tool',
  'sentry-ruby': 'Error tracking that helps developers monitor and fix crashes',
  shrine: 'File attachment toolkit for Ruby applications',
  sidekiq: 'Simple, efficient background processing for Ruby',
  sorbet: 'A type checker for Ruby',
  semantic_logger: 'A flexible logging framework for Ruby',
  'dotenv-rails': 'Loads environment variables from `.env` files',
  active_model_serializers: 'A library for serializing Ruby objects to JSON',
  ahoy_matey: 'Analytics for Rails',
};

export function getGemDescription(gemName: string): string {
  const description = GEM_DESCRIPTIONS[gemName];
  if (!description) {
    throw new Error(
      `No description found for gem: ${gemName}. Add it to docs/lib/gem-descriptions.ts`,
    );
  }
  return description;
}
