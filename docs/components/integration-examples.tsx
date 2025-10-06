'use client';

import { useId } from 'react';
import { CodeBlock } from '@/components/code-block';
import { useFiltering } from '@/components/filtering-context';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import type { Event, LogType } from '@/generated/logstruct';
import { LogGenerator } from '@/lib/log-generation';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
const formatLog = (log: Record<string, any>) => JSON.stringify(log, null, 2);

export function IntegrationExamples({
  logType,
  events,
  preferredEvent,
}: {
  logType: LogType;
  events: Event[];
  preferredEvent?: Event;
}) {
  const { filtering, setFiltering } = useFiltering();
  const gen = new LogGenerator(12345, filtering);
  const baseFilteringId = useId();

  if (events.length <= 1) {
    const only = events[0];
    const inputId = `${baseFilteringId}-filter`;
    return (
      <div className="relative">
        <CodeBlock language="json">
          {formatLog(
            gen.generateLogWithOptions(logType, {
              preferredEvent: preferredEvent ?? only,
              filtering,
            }),
          )}
        </CodeBlock>
        <div className="absolute bottom-2 right-3 text-xs text-neutral-500 dark:text-neutral-300 flex items-center gap-2 bg-white/60 dark:bg-neutral-900/60 px-2 py-1 rounded">
          <label className="cursor-pointer select-none" htmlFor={inputId}>
            Apply filtering
          </label>
          <input
            aria-label="Apply filtering"
            type="checkbox"
            className="cursor-pointer"
            id={inputId}
            checked={filtering}
            onChange={(e) => setFiltering(e.target.checked)}
          />
        </div>
      </div>
    );
  }

  return (
    <div>
      <Tabs defaultValue={String(events[0])}>
        <TabsList className="cursor-pointer w-fit flex flex-wrap gap-2">
          {events.map((evt) => (
            <TabsTrigger key={String(evt)} value={String(evt)} className="cursor-pointer">
              {String(evt)}
            </TabsTrigger>
          ))}
        </TabsList>
        {events.map((evt) => {
          const inputId = `${baseFilteringId}-${String(evt)}`;
          return (
            <TabsContent key={String(evt)} value={String(evt)} className="mt-0.5">
              <div className="relative">
                <CodeBlock language="json">
                  {formatLog(
                    gen.generateLogWithOptions(logType, {
                      preferredEvent: evt,
                      filtering,
                    }),
                  )}
                </CodeBlock>
                <div className="absolute bottom-2 right-3 text-xs text-neutral-500 dark:text-neutral-300 flex items-center gap-2 bg-white/60 dark:bg-neutral-900/60 px-2 py-1 rounded">
                  <label className="cursor-pointer select-none" htmlFor={inputId}>
                    Apply filtering
                  </label>
                  <input
                    aria-label="Apply filtering"
                    type="checkbox"
                    className="cursor-pointer"
                    id={inputId}
                    checked={filtering}
                    onChange={(e) => setFiltering(e.target.checked)}
                  />
                </div>
              </div>
            </TabsContent>
          );
        })}
      </Tabs>
    </div>
  );
}
