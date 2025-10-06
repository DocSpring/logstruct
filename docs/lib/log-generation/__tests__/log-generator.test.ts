import { Event, Level, LogType, Source } from '@/generated/logstruct';
import { LogGenerator } from '../log-generator';

describe('LogGenerator', () => {
  let generator: LogGenerator;

  beforeEach(() => {
    // Use a fixed seed for deterministic tests
    generator = new LogGenerator(12345);
  });

  test('should transform property names to JSON keys', () => {
    const log = generator.generateLog(LogType.PLAIN);

    // Check common fields use the mapped JSON keys
    expect(log).toHaveProperty('ts'); // instead of timestamp
    expect(log).toHaveProperty('lvl'); // instead of level
    expect(log).toHaveProperty('src'); // instead of source
    expect(log).toHaveProperty('evt'); // instead of event
    expect(log).toHaveProperty('msg'); // instead of message

    // Verify the original property names are not present
    expect(log).not.toHaveProperty('timestamp');
    expect(log).not.toHaveProperty('level');
    expect(log).not.toHaveProperty('source');
    expect(log).not.toHaveProperty('event');
  });

  test('should generate logs of specific types', () => {
    const requestLog = generator.generateLog(LogType.REQUEST);
    expect(requestLog).toHaveProperty('method');
    expect(requestLog).toHaveProperty('path');
    expect(requestLog).toHaveProperty('status');

    const errorLog = generator.generateLog(LogType.ERROR);
    expect(errorLog).toHaveProperty('err_class');
    expect(errorLog).toHaveProperty('msg');
    expect(errorLog).toHaveProperty('backtrace');

    const plainLog = generator.generateLog(LogType.PLAIN);
    expect(plainLog).toHaveProperty('msg');
  });

  test('should use appropriate log levels based on log type', () => {
    // Regular logs should be INFO level
    const plainLog = generator.generateLog(LogType.PLAIN);
    expect(plainLog.lvl).toBe('info');

    const requestLog = generator.generateLog(LogType.REQUEST);
    expect(requestLog.lvl).toBe('info');

    // Error logs should be ERROR level
    const errorLog = generator.generateLog(LogType.ERROR);
    expect(errorLog.lvl).toBe('error');

    // Security logs should be WARN or ERROR level
    const securityLog = generator.generateLog(LogType.SECURITY);
    expect(['warn', 'error']).toContain(securityLog.lvl);
  });

  test('should generate job sequences', () => {
    const sequence = generator.generateJobSequence();

    // Should have 3 logs: enqueue, start, finish
    expect(sequence).toHaveLength(3);

    // All should have the same job_id
    const jobId = sequence[0].job_id;
    expect(sequence[1].job_id).toBe(jobId);
    expect(sequence[2].job_id).toBe(jobId);

    // Should have the right event types
    expect(sequence[0].event).toBe(Event.Enqueue);
    expect(sequence[1].event).toBe(Event.Start);
    expect(sequence[2].event).toBe(Event.Finish);

    // All should have the correct source
    expect(sequence[0].source).toBe(Source.Job);
    expect(sequence[1].source).toBe(Source.Job);
    expect(sequence[2].source).toBe(Source.Job);

    // All should have the info log level
    expect(sequence[0].level).toBe(Level.Info);
    expect(sequence[1].level).toBe(Level.Info);
    expect(sequence[2].level).toBe(Level.Info);

    // Only the finish event should have a duration (ms)
    expect(sequence[0]).not.toHaveProperty('duration_ms');
    expect(sequence[1]).not.toHaveProperty('duration_ms');
    expect(sequence[2]).toHaveProperty('duration_ms');

    // Timestamps should be in chronological order
    const time1 = new Date(sequence[0].timestamp as string).getTime();
    const time2 = new Date(sequence[1].timestamp as string).getTime();
    const time3 = new Date(sequence[2].timestamp as string).getTime();

    expect(time1).toBeLessThan(time2);
    expect(time2).toBeLessThan(time3);
  });
});
