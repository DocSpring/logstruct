import { Check, Minus, X } from 'lucide-react';
import React from 'react';
import { EditPageLink } from '@/components/edit-page-link';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';

// cspell:words Logstasher Logcraft Resque Stasher

type FeatureValue = boolean | string | { partial: boolean; tooltip: string };

interface FeatureItem {
  name: string;
  logstruct: FeatureValue;
  lograge: FeatureValue;
  railsSemanticLogger: FeatureValue;
  logstasher: FeatureValue;
  logcraft: FeatureValue;
}

interface FeatureCategory {
  category: string;
  items: FeatureItem[];
}

function ComparisonTable() {
  const features: FeatureCategory[] = [
    {
      category: 'Core Features',
      items: [
        {
          name: 'Structured JSON logging',
          logstruct: true,
          lograge: {
            partial: true,
            tooltip:
              'Request lines only, with its Json or Logstash formatter. The default format is key=value.',
          },
          railsSemanticLogger: true,
          logstasher: {
            partial: true,
            tooltip:
              'JSON for the Rails events it subscribes to and for LogStasher.info calls, in its own file. Rails.logger lines stay text.',
          },
          logcraft: true,
        },
        {
          name: 'Typed log lines (Sorbet structs), including your own',
          logstruct: true,
          lograge: false,
          railsSemanticLogger: false,
          logstasher: false,
          logcraft: false,
        },
        {
          name: 'Works without configuration',
          logstruct: {
            partial: true,
            tooltip:
              'On in tests, and in production for servers and workers (Puma, Sidekiq, GoodJob, ...) but not Rake tasks. Off in the console. Development is opt-in (LOGSTRUCT_ENABLED=true). SQL lines are off by default.',
          },
          lograge: false,
          railsSemanticLogger: {
            partial: true,
            tooltip:
              'Works with no configuration, but writes text to log/<env>.log. JSON needs an appender with formatter: :json.',
          },
          logstasher: false,
          logcraft: {
            partial: true,
            tooltip:
              'No initializer, but its README asks you to remove the logging settings Rails generates in production.rb.',
          },
        },
        {
          name: 'Single-line request logs',
          logstruct: true,
          lograge: true,
          railsSemanticLogger: true,
          logstasher: true,
          logcraft: true,
        },
        {
          name: 'Multiple output destinations',
          logstruct: {
            partial: true,
            tooltip:
              "STDOUT in production, STDOUT and Rails' log file in development, the log file in test. Semantic Logger appenders your app adds in an initializer are kept, but LogStruct has no setting of its own for more outputs.",
          },
          lograge: false,
          railsSemanticLogger: true,
          logstasher: false,
          logcraft: false,
        },
        {
          name: 'Colorized console output',
          logstruct: {
            partial: true,
            tooltip:
              'Development only, and opt-in: set prefer_json_in_development = false. LogStruct is off in the Rails console.',
          },
          lograge: false,
          railsSemanticLogger: true,
          logstasher: false,
          logcraft: false,
        },
      ],
    },
    {
      category: 'Security & Privacy',
      items: [
        {
          name: 'Filtering sensitive keys in every line',
          logstruct: true,
          lograge: {
            partial: true,
            tooltip:
              "Logs no params and drops the query string. Params you add with custom_options are already filtered by Rails' filter_parameters.",
          },
          railsSemanticLogger: {
            partial: true,
            tooltip:
              "Request params and SQL binds use Rails' filter_parameters. Other values are written as given.",
          },
          logstasher: {
            partial: true,
            tooltip:
              "Request params (opt-in) are filtered by Rails' filter_parameters. The path keeps its query string.",
          },
          logcraft: {
            partial: true,
            tooltip:
              "Request params and path are filtered by Rails' filter_parameters, and you can log only listed params. SQL binds aren't filtered.",
          },
        },
        {
          name: 'Scrubbing emails, card numbers and tokens inside strings',
          logstruct: true,
          lograge: false,
          railsSemanticLogger: false,
          logstasher: false,
          logcraft: false,
        },
        {
          name: 'Security lines (CSRF failures, IP spoofing, blocked hosts)',
          logstruct: true,
          lograge: false,
          railsSemanticLogger: false,
          logstasher: false,
          logcraft: false,
        },
      ],
    },
    {
      category: 'Integrations',
      items: [
        {
          name: 'ActiveJob',
          logstruct: true,
          lograge: false,
          railsSemanticLogger: true,
          logstasher: true,
          logcraft: false,
        },
        {
          name: 'Sidekiq',
          logstruct: true,
          lograge: false,
          railsSemanticLogger: true,
          logstasher: false,
          logcraft: {
            partial: true,
            tooltip: 'Through the separate logcraft-sidekiq gem.',
          },
        },
        {
          name: 'GoodJob',
          logstruct: true,
          lograge: false,
          railsSemanticLogger: false,
          logstasher: false,
          logcraft: false,
        },
        {
          name: 'ActionMailer',
          logstruct: true,
          lograge: false,
          railsSemanticLogger: true,
          logstasher: true,
          logcraft: false,
        },
        {
          name: 'ActiveStorage',
          logstruct: true,
          lograge: false,
          railsSemanticLogger: false,
          logstasher: false,
          logcraft: false,
        },
        {
          name: 'CarrierWave and Shrine',
          logstruct: true,
          lograge: false,
          railsSemanticLogger: false,
          logstasher: false,
          logcraft: false,
        },
        {
          name: 'ActiveRecord SQL lines',
          logstruct: true,
          lograge: false,
          railsSemanticLogger: true,
          logstasher: true,
          logcraft: true,
        },
        {
          name: 'Error reporting (Sentry, Bugsnag, Rollbar, Honeybadger)',
          logstruct: true,
          lograge: false,
          railsSemanticLogger: {
            partial: true,
            tooltip:
              "Semantic Logger's Sentry, Bugsnag and Honeybadger appenders send error lines to those services, once you add them.",
          },
          logstasher: false,
          logcraft: false,
        },
      ],
    },
    {
      category: 'Developer Experience',
      items: [
        {
          name: 'Tags (logger.tagged, config.log_tags)',
          logstruct: true,
          lograge: false,
          railsSemanticLogger: true,
          logstasher: {
            partial: true,
            tooltip:
              "Its own events have a tags array (LogStasher.info(msg, tags: [...])). Tags from logger.tagged and config.log_tags aren't in them.",
          },
          logcraft: {
            partial: true,
            tooltip:
              'No tags. within_log_context adds key-value fields to every line logged in a block.',
          },
        },
        {
          name: 'Terraform provider for CloudWatch metric filters (checks src/evt pairs)',
          logstruct: true,
          lograge: false,
          railsSemanticLogger: false,
          logstasher: false,
          logcraft: false,
        },
      ],
    },
  ];

  const renderCell = (value: boolean | string | { partial: boolean; tooltip: string }) => {
    if (value === true)
      return <Check className="w-5 h-5 text-green-600 dark:text-green-500 mx-auto" />;
    if (value === false) return <X className="w-5 h-5 text-red-500 dark:text-red-400 mx-auto" />;
    if (typeof value === 'object' && value.partial)
      return (
        <div className="relative group flex justify-center">
          <Minus className="w-5 h-5 text-yellow-600 dark:text-yellow-500 cursor-help" />
          <div className="absolute bottom-full mb-2 hidden group-hover:block z-10 w-48 p-2 text-xs bg-neutral-900 dark:bg-neutral-800 text-white rounded shadow-lg pointer-events-none">
            {value.tooltip}
          </div>
        </div>
      );
    if (value === 'partial')
      return <Minus className="w-5 h-5 text-yellow-600 dark:text-yellow-500 mx-auto" />;
    return <span className="text-xs">{String(value)}</span>;
  };

  return (
    <div>
      {/* Seven columns don't fit a phone: the table scrolls sideways instead of the page */}
      <div className="overflow-x-auto">
        <table className="w-full border-collapse">
          <thead>
            <tr className="border-b border-neutral-200 dark:border-neutral-800">
              <th className="text-left py-4 px-3 text-sm font-semibold">Feature</th>
              <th className="text-center py-4 px-2 text-sm font-semibold bg-purple-50 dark:bg-purple-950/20">
                LogStruct
              </th>
              <th className="text-center py-4 px-2 text-sm font-semibold">
                Rails
                <br />
                Semantic
                <br />
                Logger
              </th>
              <th className="text-center py-4 px-2 text-sm font-semibold">Lograge</th>
              <th className="text-center py-4 px-2 text-sm font-semibold">Logstasher</th>
              <th className="text-center py-4 px-2 text-sm font-semibold">Logcraft</th>
            </tr>
          </thead>
          <tbody>
            {features.map((category) => (
              <React.Fragment key={category.category}>
                <tr className="bg-neutral-50 dark:bg-neutral-900">
                  <td
                    colSpan={6}
                    className="py-2 px-3 font-semibold text-xs uppercase tracking-wide text-neutral-600 dark:text-neutral-300"
                  >
                    {category.category}
                  </td>
                </tr>
                {category.items.map((feature) => (
                  <tr
                    key={`${category.category}-${feature.name}`}
                    className="border-b border-neutral-100 dark:border-neutral-900"
                  >
                    <td className="py-2 px-3 text-sm">{feature.name}</td>
                    <td className="py-2 px-2 text-center bg-purple-50 dark:bg-purple-950/20">
                      {renderCell(feature.logstruct)}
                    </td>
                    <td className="py-2 px-2 text-center">
                      {renderCell(feature.railsSemanticLogger)}
                    </td>
                    <td className="py-2 px-2 text-center">{renderCell(feature.lograge)}</td>
                    <td className="py-2 px-2 text-center">{renderCell(feature.logstasher)}</td>
                    <td className="py-2 px-2 text-center">{renderCell(feature.logcraft)}</td>
                  </tr>
                ))}
              </React.Fragment>
            ))}
          </tbody>
        </table>
      </div>
      <p className="text-sm text-neutral-500 dark:text-neutral-400 mt-4">
        A check means the gem documents or implements the feature, a dash that it partly does (hover
        over the dash for what&apos;s there), and a cross that it doesn&apos;t. Checked in October
        2026 against each gem&apos;s latest release: Rails Semantic Logger 5.2.0 (with Semantic
        Logger 5.1.0), Lograge 0.15.1, Logstasher 3.0.0 and Logcraft 2.3.
      </p>
    </div>
  );
}

export default function ComparisonPage() {
  return (
    <div className="space-y-8">
      <div>
        <HeadingWithAnchor id="comparison" level={1}>
          Comparison with Other Logging Gems
        </HeadingWithAnchor>
        <p className="text-lg text-neutral-600 dark:text-neutral-300 mt-4">
          How LogStruct compares with four other Rails logging gems.
        </p>
      </div>

      <ComparisonTable />

      <HeadingWithAnchor id="rails-semantic-logger" level={2}>
        <a
          href="https://github.com/reidmorrison/rails_semantic_logger"
          target="_blank"
          rel="noopener noreferrer"
          className="hover:text-purple-600 dark:hover:text-purple-400"
        >
          Rails Semantic Logger
        </a>
      </HeadingWithAnchor>
      <div className="space-y-4 text-neutral-600 dark:text-neutral-300">
        <p>
          <a
            href="https://github.com/reidmorrison/rails_semantic_logger"
            target="_blank"
            rel="noopener noreferrer"
            className="font-semibold hover:text-purple-600 dark:hover:text-purple-400"
          >
            Rails Semantic Logger
          </a>{' '}
          replaces Rails&apos; logger with Semantic Logger, so Rails, the app and gems such as
          Sidekiq, SolidQueue, Resque, Delayed Job and Mongoid log through it. It turns Rails&apos;
          request logs into one &quot;Completed&quot; line and has its own log subscribers for
          ActiveRecord, ActionMailer, ActiveJob and ActionView. Semantic Logger writes on a
          background thread to any number of appenders (files, STDOUT, Elasticsearch, Splunk,
          CloudWatch Logs, Sentry, Bugsnag and others), as text, color or JSON. With no
          configuration it writes text to <code>log/&lt;env&gt;.log</code>, and to STDOUT under{' '}
          <code>rails server</code>. It supports tags and named tags, and has test helpers for
          Minitest and RSpec. Request params and SQL binds go through Rails&apos;{' '}
          <code>filter_parameters</code>; other values are written as given.
        </p>
        <p>
          LogStruct writes its lines through Semantic Logger too (the <code>semantic_logger</code>{' '}
          gem, not <code>rails_semantic_logger</code>), with its own JSON formatter. Both replace
          Rails&apos; logger, so an app uses one or the other. LogStruct writes to STDOUT in
          production and development, plus Rails&apos; log file in development and test, and adds
          typed lines, filtering and scrubbing of every line, security lines and error handling
          modes.
        </p>
      </div>

      <div className="space-y-8 mt-12">
        <HeadingWithAnchor id="lograge" level={2}>
          <a
            href="https://github.com/roidrage/lograge"
            target="_blank"
            rel="noopener noreferrer"
            className="hover:text-purple-600 dark:hover:text-purple-400"
          >
            Lograge
          </a>
        </HeadingWithAnchor>
        <div className="space-y-4 text-neutral-600 dark:text-neutral-300">
          <p>
            <a
              href="https://github.com/roidrage/lograge"
              target="_blank"
              rel="noopener noreferrer"
              className="font-semibold hover:text-purple-600 dark:hover:text-purple-400"
            >
              Lograge
            </a>{' '}
            replaces Rails&apos; multi-line request and view logs with one line per request (and one
            per Action Cable event). The default format is <code>key=value</code>; JSON, Logstash,
            Graylog2, LTSV and other formatters are options. Other log lines are left as they are.
            It logs no params unless you add them with <code>custom_options</code>, and it&apos;s
            off until you set <code>config.lograge.enabled = true</code>.
          </p>
          <p>
            LogStruct depends on Lograge and uses it to build its request lines, which are then
            filtered and scrubbed like every other line. The Hash a{' '}
            <code>lograge_custom_options</code> proc returns is merged into the request line.
          </p>
        </div>

        <HeadingWithAnchor id="logstasher" level={2}>
          <a
            href="https://github.com/shadabahmed/logstasher"
            target="_blank"
            rel="noopener noreferrer"
            className="hover:text-purple-600 dark:hover:text-purple-400"
          >
            Logstasher
          </a>
        </HeadingWithAnchor>
        <div className="space-y-4 text-neutral-600 dark:text-neutral-300">
          <p>
            <a
              href="https://github.com/shadabahmed/logstasher"
              target="_blank"
              rel="noopener noreferrer"
              className="font-semibold hover:text-purple-600 dark:hover:text-purple-400"
            >
              Logstasher
            </a>{' '}
            writes Logstash JSON events for requests, mailer deliveries, ActiveJob jobs and view
            renders (and SQL queries, if you turn them on) to its own file,{' '}
            <code>log/logstash_&lt;env&gt;.log</code> by default, or to another logger. The
            app&apos;s own <code>Rails.logger</code> lines stay in Rails&apos; text log.{' '}
            <code>LogStasher.info</code> and the other level methods log the app&apos;s own events
            with tags (its logger&apos;s level is WARN unless you set{' '}
            <code>config.logstasher.log_level</code>), and <code>LogStasher.watch</code> adds data
            from any ActiveSupport notification to the request&apos;s event. It&apos;s off until you
            set <code>config.logstasher.enabled = true</code>.
          </p>
          <p>
            LogStruct writes every line, the app&apos;s own included, as JSON (to STDOUT in
            production), and has Sidekiq, GoodJob, ActiveStorage, CarrierWave and Shrine
            integrations.
          </p>
        </div>

        <HeadingWithAnchor id="logcraft" level={2}>
          <a
            href="https://github.com/zormandi/logcraft"
            target="_blank"
            rel="noopener noreferrer"
            className="hover:text-purple-600 dark:hover:text-purple-400"
          >
            Logcraft
          </a>
        </HeadingWithAnchor>
        <div className="space-y-4 text-neutral-600 dark:text-neutral-300">
          <p>
            <a
              href="https://github.com/zormandi/logcraft"
              target="_blank"
              rel="noopener noreferrer"
              className="font-semibold hover:text-purple-600 dark:hover:text-purple-400"
            >
              Logcraft
            </a>{' '}
            sets <code>Rails.logger</code>, and every logger made with <code>Logcraft.logger</code>,
            to write JSON to STDOUT, without an initializer. It replaces Rails&apos; request logs
            with one access log line per request, logs unhandled errors on one line, and writes SQL
            queries as JSON at debug level. <code>within_log_context</code> adds fields to every
            line logged in a block, and <code>global_context</code> to every line. It includes RSpec
            matchers for log output. Sidekiq support is a separate gem,{' '}
            <code>logcraft-sidekiq</code>. The README on its main branch describes Logcraft 3, which
            isn&apos;t released yet.
          </p>
          <p>
            LogStruct also writes JSON to STDOUT in production. It adds typed lines, filtering of
            every line (not only request params), scrubbing, security lines and integrations for
            jobs, mailers and file uploads.
          </p>
        </div>

        <HeadingWithAnchor id="what-logstruct-adds" level={2}>
          What LogStruct Adds
        </HeadingWithAnchor>
        <div className="space-y-4 text-neutral-600 dark:text-neutral-300">
          <p>LogStruct builds on Semantic Logger and Lograge, and adds:</p>
          <ul className="list-disc list-inside space-y-2 ml-4">
            <li>
              <strong>Typed lines:</strong> each integration&apos;s lines are Sorbet structs with
              typed fields, and you can define your own.
            </li>
            <li>
              <strong>Filtering:</strong> sensitive keys are filtered in every line, not only in
              request params, using LogStruct&apos;s key list and Rails&apos;{' '}
              <code>filter_parameters</code>. Values of <code>email</code> and{' '}
              <code>email_address</code> keys are replaced with a hash.
            </li>
            <li>
              <strong>Scrubbing:</strong> inside strings, emails are replaced with a hash, and card
              numbers, phone numbers, SSNs, URL passwords, sensitive URL query params and{' '}
              <code>Bearer</code> and <code>Basic</code> credentials are masked. IP and MAC address
              scrubbing is opt-in.
            </li>
            <li>
              <strong>Security lines:</strong> CSRF failures, IP spoofing errors and blocked hosts.
            </li>
            <li>
              <strong>Error handling modes:</strong> for each kind of error (Sorbet type errors,
              security errors, LogStruct&apos;s own errors and the rest), you choose whether to log
              it, report it to your error reporter or raise it, or to raise it only in development
              and test.
            </li>
            <li>
              <strong>Integrations:</strong> ActiveJob, Sidekiq, GoodJob, ActionMailer,
              ActiveStorage, CarrierWave, Shrine, SQL queries (opt-in), Puma, Ahoy,
              ActiveModelSerializers, dotenv-rails, host authorization and Sorbet&apos;s error
              handlers.
            </li>
            <li>
              <strong>Terraform provider:</strong> it checks <code>src</code>/<code>evt</code> pairs
              at plan time and builds the CloudWatch filter patterns for metric filters.
            </li>
          </ul>
          <p>
            What it doesn&apos;t do: it has no setting for other log destinations (it writes to
            STDOUT in production and development, plus Rails&apos; log file in development and
            test), it&apos;s off in development unless you set <code>LOGSTRUCT_ENABLED=true</code>,
            and it&apos;s off in the Rails console.
          </p>
        </div>
      </div>

      <EditPageLink />
    </div>
  );
}
