/* eslint-disable @typescript-eslint/no-explicit-any */
import { Event, Level, Source, DotenvLog } from '../log-types';
import type { RandomDataGenerator } from '../random-data-generator';

export function generateDotenv(
  gen: RandomDataGenerator,
  log: Partial<DotenvLog>,
): Partial<DotenvLog> {
  const allowed: Array<DotenvLog['event']> = [
    Event.LOAD,
    Event.UPDATE,
    Event.SAVE,
    Event.RESTORE,
  ];
  const event: DotenvLog['event'] =
    (log.event as DotenvLog['event']) ?? gen.sample(allowed);

  const file = gen.sample(['.env.development', '.env.test', '.env']);
  const vars = gen.sampleSize(
    ['REGION', 'BOOT_FLAG', 'API_KEY', 'SECRET_TOKEN', 'LOG_LEVEL'],
    gen.randomInt(1, 3),
  );

  const base: Partial<DotenvLog> = {
    ...log,
    source: Source.DOTENV,
    level: Level.INFO,
    event,
  };

  switch (event) {
    case Event.LOAD:
      return { ...base, file };
    case Event.UPDATE:
      return { ...base, vars };
    case Event.RESTORE:
      return { ...base, vars };
    case Event.SAVE:
    default:
      // Include a hint for snapshot save to keep the example meaningful
      return { ...base, snapshot: true };
  }
}
