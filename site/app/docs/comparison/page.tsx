import { Check, X, Minus } from 'lucide-react';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { EditPageLink } from '@/components/edit-page-link';

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
          lograge: true,
          railsSemanticLogger: true,
          logstasher: true,
          logcraft: true,
        },
        {
          name: 'Type-safe log structures (Sorbet)',
          logstruct: true,
          lograge: false,
          railsSemanticLogger: false,
          logstasher: false,
          logcraft: false,
        },
        {
          name: 'Zero configuration',
          logstruct: true,
          lograge: false,
          railsSemanticLogger: {
            partial: true,
            tooltip: 'Requires manual configuration for many features',
          },
          logstasher: {
            partial: true,
            tooltip: 'Requires configuration for non-default behaviors',
          },
          logcraft: true,
        },
        {
          name: 'Request log formatting',
          logstruct: true,
          lograge: true,
          railsSemanticLogger: true,
          logstasher: true,
          logcraft: true,
        },
        {
          name: 'Multiple output destinations',
          logstruct: true,
          lograge: false,
          railsSemanticLogger: true,
          logstasher: false,
          logcraft: false,
        },
        {
          name: 'Colorized console output',
          logstruct: true,
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
          name: 'Advanced parameter filtering',
          logstruct: true,
          lograge: {
            partial: true,
            tooltip: 'Uses Rails default filtering',
          },
          railsSemanticLogger: {
            partial: true,
            tooltip: 'Uses Rails default filtering',
          },
          logstasher: {
            partial: true,
            tooltip: 'Uses Rails default filtering',
          },
          logcraft: { partial: true, tooltip: 'Uses Rails default filtering' },
        },
        {
          name: 'Email/SSN scrubbing in strings',
          logstruct: true,
          lograge: false,
          railsSemanticLogger: false,
          logstasher: false,
          logcraft: false,
        },
        {
          name: 'Security event logging',
          logstruct: true,
          lograge: false,
          railsSemanticLogger: false,
          logstasher: false,
          logcraft: false,
        },
        {
          name: 'CSRF/IP spoofing detection logs',
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
          name: 'Sidekiq integration',
          logstruct: true,
          lograge: false,
          railsSemanticLogger: true,
          logstasher: true,
          logcraft: false,
        },
        {
          name: 'ActionMailer integration',
          logstruct: true,
          lograge: false,
          railsSemanticLogger: true,
          logstasher: false,
          logcraft: false,
        },
        {
          name: 'ActiveStorage integration',
          logstruct: true,
          lograge: false,
          railsSemanticLogger: false,
          logstasher: false,
          logcraft: false,
        },
        {
          name: 'CarrierWave/Shrine support',
          logstruct: true,
          lograge: false,
          railsSemanticLogger: false,
          logstasher: false,
          logcraft: false,
        },
        {
          name: 'Error reporter integration',
          logstruct: true,
          lograge: false,
          railsSemanticLogger: {
            partial: true,
            tooltip: 'Limited error context and formatting',
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
          name: 'Tagged logging support',
          logstruct: true,
          lograge: true,
          railsSemanticLogger: true,
          logstasher: true,
          logcraft: true,
        },
        {
          name: 'Performance metrics',
          logstruct: true,
          lograge: true,
          railsSemanticLogger: true,
          logstasher: true,
          logcraft: true,
        },
        {
          name: 'Custom log classes',
          logstruct: true,
          lograge: false,
          railsSemanticLogger: false,
          logstasher: false,
          logcraft: false,
        },
        {
          name: 'Terraform export',
          logstruct: true,
          lograge: false,
          railsSemanticLogger: false,
          logstasher: false,
          logcraft: false,
        },
      ],
    },
  ];

  const renderCell = (
    value: boolean | string | { partial: boolean; tooltip: string },
  ) => {
    if (value === true)
      return (
        <Check className="w-5 h-5 text-green-600 dark:text-green-500 mx-auto" />
      );
    if (value === false)
      return <X className="w-5 h-5 text-red-500 dark:text-red-400 mx-auto" />;
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
      return (
        <Minus className="w-5 h-5 text-yellow-600 dark:text-yellow-500 mx-auto" />
      );
    return <span className="text-xs">{value}</span>;
  };

  return (
    <div>
      <table className="w-full border-collapse">
        <thead>
          <tr className="border-b border-neutral-200 dark:border-neutral-800">
            <th className="text-left py-4 px-3 text-sm font-semibold">
              Feature
            </th>
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
            <th className="text-center py-4 px-2 text-sm font-semibold">
              Lograge
            </th>
            <th className="text-center py-4 px-2 text-sm font-semibold">
              Logstasher
            </th>
            <th className="text-center py-4 px-2 text-sm font-semibold">
              Logcraft
            </th>
          </tr>
        </thead>
        <tbody>
          {features.map((category) => (
            <>
              <tr
                key={category.category}
                className="bg-neutral-50 dark:bg-neutral-900"
              >
                <td
                  colSpan={6}
                  className="py-2 px-3 font-semibold text-xs uppercase tracking-wide text-neutral-600 dark:text-neutral-400"
                >
                  {category.category}
                </td>
              </tr>
              {category.items.map((feature, index) => (
                <tr
                  key={`${category.category}-${index}`}
                  className="border-b border-neutral-100 dark:border-neutral-900"
                >
                  <td className="py-2 px-3 text-sm">{feature.name}</td>
                  <td className="py-2 px-2 text-center bg-purple-50 dark:bg-purple-950/20">
                    {renderCell(feature.logstruct)}
                  </td>
                  <td className="py-2 px-2 text-center">
                    {renderCell(feature.railsSemanticLogger)}
                  </td>
                  <td className="py-2 px-2 text-center">
                    {renderCell(feature.lograge)}
                  </td>
                  <td className="py-2 px-2 text-center">
                    {renderCell(feature.logstasher)}
                  </td>
                  <td className="py-2 px-2 text-center">
                    {renderCell(feature.logcraft)}
                  </td>
                </tr>
              ))}
            </>
          ))}
        </tbody>
      </table>
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
        <p className="text-lg text-neutral-600 dark:text-neutral-400 mt-4">
          How LogStruct compares to other popular Rails logging solutions.
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
      <div className="space-y-4 text-neutral-600 dark:text-neutral-400">
        <p>
          <a
            href="https://github.com/reidmorrison/rails_semantic_logger"
            target="_blank"
            rel="noopener noreferrer"
            className="font-semibold hover:text-purple-600 dark:hover:text-purple-400"
          >
            Rails Semantic Logger
          </a>{' '}
          bridges Semantic Logger with Rails, providing automatic integration
          with Rails components. It replaces various Rails loggers and adds
          request logging similar to Lograge. While it offers good Rails
          integration, it lacks the type safety, advanced filtering, and
          security features that LogStruct provides. The configuration can also
          be complex for teams wanting specific behaviors.
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
        <div className="space-y-4 text-neutral-600 dark:text-neutral-400">
          <p>
            <a
              href="https://github.com/roidrage/lograge"
              target="_blank"
              rel="noopener noreferrer"
              className="font-semibold hover:text-purple-600 dark:hover:text-purple-400"
            >
              Lograge
            </a>{' '}
            is the original Rails request log tamer. It transforms Rails&apos;
            verbose, multi-line request logs into single-line structured logs.
            It&apos;s lightweight, focused, and does one thing exceptionally
            well: cleaning up request logs. LogStruct actually uses Lograge
            under the hood for request log processing, then enhances it with
            type safety and advanced filtering.
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
        <div className="space-y-4 text-neutral-600 dark:text-neutral-400">
          <p>
            <a
              href="https://github.com/shadabahmed/logstasher"
              target="_blank"
              rel="noopener noreferrer"
              className="font-semibold hover:text-purple-600 dark:hover:text-purple-400"
            >
              Logstasher
            </a>{' '}
            is designed specifically for Logstash integration, formatting logs
            in Logstash&apos;s expected JSON format. It includes basic request
            logging and some ActiveSupport notifications. While it works well
            for ELK stack users, it lacks the comprehensive filtering, type
            safety, and broad integration support that LogStruct offers.
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
        <div className="space-y-4 text-neutral-600 dark:text-neutral-400">
          <p>
            <a
              href="https://github.com/zormandi/logcraft"
              target="_blank"
              rel="noopener noreferrer"
              className="font-semibold hover:text-purple-600 dark:hover:text-purple-400"
            >
              Logcraft
            </a>{' '}
            is a newer gem that provides structured logging with good defaults
            for Rails applications. It focuses on simplicity and includes
            request logging and basic integrations. However, it lacks the
            advanced security features, type safety, and comprehensive
            third-party integrations that LogStruct provides.
          </p>
        </div>

        <HeadingWithAnchor id="why-logstruct" level={2}>
          Why Choose LogStruct?
        </HeadingWithAnchor>
        <div className="space-y-4 text-neutral-600 dark:text-neutral-400">
          <p>
            LogStruct combines the best features of all these gems while adding
            unique capabilities:
          </p>
          <ul className="list-disc list-inside space-y-2 ml-4">
            <li>
              <strong>Type Safety:</strong> The only logging gem with full
              Sorbet type checking support
            </li>
            <li>
              <strong>Security First:</strong> Advanced filtering and scrubbing
              that goes beyond basic parameter filtering
            </li>
            <li>
              <strong>True Zero Configuration:</strong> Works perfectly out of
              the box with sensible, production-ready defaults
            </li>
            <li>
              <strong>Comprehensive Integrations:</strong> Supports more
              third-party gems than any other solution
            </li>
            <li>
              <strong>DevOps Friendly:</strong> Terraform export for
              infrastructure-as-code metrics and alarms
            </li>
          </ul>
          <p>
            If you&apos;re starting a new Rails application or looking to
            upgrade your logging infrastructure, LogStruct provides the most
            complete, secure, and developer-friendly solution available.
          </p>
        </div>
      </div>

      <EditPageLink path="app/docs/comparison/page.tsx" />
    </div>
  );
}
