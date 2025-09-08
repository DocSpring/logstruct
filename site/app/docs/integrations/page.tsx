import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';
import { RubyCodeExample } from '@/components/ruby-code-example';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { LogGenerator } from '@/lib/log-generation';
import { AllLogTypes, Event } from '@/lib/log-generation/log-types';
import { getCodeExample } from '@/lib/codeExamples';
import {
  getEventsForLogType,
  getLogTypeInfo,
  getTitleId,
} from '@/lib/integration-helpers';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';

// Helper to format logs as JSON strings for display
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function formatLog(log: Record<string, any>): string {
  return JSON.stringify(log, null, 2);
}

// Create a single log generator with a fixed seed for consistent examples
const logGenerator = new LogGenerator(12345);

export default function IntegrationsPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="integrations" level={1}>
        Integrations
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-400">
        LogStruct integrates with many popular gems and Rails components to
        provide comprehensive structured logging throughout your application.
        These integrations automatically hook into important events and capture
        relevant context for better observability.
      </p>

      {/* Dynamically generate sections for each log type */}
      {AllLogTypes.map((logType) => {
        const logTypeInfo = getLogTypeInfo(logType);
        if (!logTypeInfo) return null; // Skip plain logs, etc.

        const { title, description, configuration_code, preferredEvent } =
          logTypeInfo;

        return (
          <div key={logType} className="mt-10">
            <HeadingWithAnchor id={getTitleId(title)}>
              {title}
            </HeadingWithAnchor>
            <p className="text-neutral-600 dark:text-neutral-400 mb-4">
              {description}
            </p>

            {/* Show Ruby code example if one is specified */}
            {configuration_code && (
              <>
                <HeadingWithAnchor
                  id={`${getTitleId(title)}-configuration`}
                  level={2}
                  className="text-xl font-semibold mt-6 mb-3"
                >
                  Configuration
                </HeadingWithAnchor>
                <div className="mb-4">
                  <RubyCodeExample name={configuration_code} />
                </div>
              </>
            )}

            {/* Generate a log example for this type */}
            <HeadingWithAnchor
              id={`${getTitleId(title)}-examples`}
              level={2}
              className="text-xl font-semibold mt-6 mb-3"
            >
              Example Logs
            </HeadingWithAnchor>
            {(() => {
              const events = getEventsForLogType(logType);
              if (events.length <= 1) {
                const only = events[0];
                return (
                  <CodeBlock language="json">
                    {formatLog(
                      logGenerator.generateLogWithOptions(logType, {
                        preferredEvent: preferredEvent ?? only,
                      }),
                    )}
                  </CodeBlock>
                );
              }
              return (
                <Tabs defaultValue={String(events[0])}>
                  <TabsList className="cursor-pointer w-fit flex flex-wrap gap-2">
                    {events.map((evt) => (
                      <TabsTrigger
                        key={String(evt)}
                        value={String(evt)}
                        className="cursor-pointer"
                      >
                        {String(evt)}
                      </TabsTrigger>
                    ))}
                  </TabsList>
                  {events.map((evt) => (
                    <TabsContent
                      key={String(evt)}
                      value={String(evt)}
                      className="mt-0.5"
                    >
                      <CodeBlock language="json">
                        {formatLog(
                          logGenerator.generateLogWithOptions(logType, {
                            preferredEvent: evt as Event,
                          }),
                        )}
                      </CodeBlock>
                    </TabsContent>
                  ))}
                </Tabs>
              );
            })()}
          </div>
        );
      })}

      {/* Special case for Sorbet that doesn't fit the standard pattern */}
      <div className="mt-10">
        <HeadingWithAnchor id="sorbet-integration">
          Sorbet Integration
        </HeadingWithAnchor>
        <p className="text-neutral-600 dark:text-neutral-400 mb-4">
          LogStruct integrates with Sorbet to handle type checking errors
          appropriately based on the environment. We raise any logging-related
          errors in test/development and log or report them in production to
          avoid crashing your application.
        </p>

        <HeadingWithAnchor
          id="sorbet-configuration"
          level={2}
          className="text-xl font-semibold mt-6 mb-3"
        >
          Configuration
        </HeadingWithAnchor>
        <div className="rounded-lg bg-neutral-100 p-4 dark:bg-neutral-900">
          <CodeBlock language="ruby" unwrapped={true}>
            {getCodeExample('sorbet_error_handlers_configuration').code}
          </CodeBlock>
        </div>
      </div>

      <EditPageLink />
    </div>
  );
}
