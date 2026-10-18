import { AllLogTypes, Event, Level, LogType, Source } from '@/generated/logstruct';
import { getEventsForLogType } from '@/lib/integration-helpers';
import { LogGenerator } from '../log-generator';
import { valueHash } from '../string-scrubber';

type Line = Record<string, unknown>;

// Lines from many seeds, to cover the random choices (small seeds start with small numbers)
function lines(
  logType: LogType,
  opts: { preferredEvent?: Event; filtering?: boolean } = {},
): Line[] {
  return Array.from({ length: 60 }, (_, seed) =>
    new LogGenerator((seed + 1) * 100_003).generateLogWithOptions(logType, opts),
  );
}

// The sources whose schemas have an error event (schemas/log_sources/*.yml)
const ERROR_EVENT_TYPES = [
  LogType.ACTIONMAILER,
  LogType.ACTIVEJOB,
  LogType.GOODJOB,
  LogType.PUMA,
  LogType.SIDEKIQ,
];

describe('LogGenerator', () => {
  let generator: LogGenerator;

  beforeEach(() => {
    // Use a fixed seed for deterministic tests
    generator = new LogGenerator(12345);
  });

  // The integrations page passes its build time, so the browser renders the lines the server did
  test('a generator given a time writes every line at that time, the same on every render', () => {
    const now = Date.UTC(2026, 0, 1, 12, 30);
    for (const logType of AllLogTypes) {
      for (const preferredEvent of getEventsForLogType(logType)) {
        const render = () =>
          new LogGenerator(12345, true, now).generateLogWithOptions(logType, { preferredEvent });

        expect(render().ts).toBe('2026-01-01T12:30:00.000+00:00');
        expect(render()).toEqual(render());
      }
    }
  });

  test('uses the short JSON keys', () => {
    const log = generator.generateLog(LogType.PLAIN);

    for (const key of ['ts', 'lvl', 'src', 'evt', 'msg']) expect(log).toHaveProperty(key);
    for (const key of ['timestamp', 'level', 'source', 'event'])
      expect(log).not.toHaveProperty(key);
  });

  test('writes src, evt, lvl and ts first, and prog after the fields', () => {
    const log = generator.generateLog(LogType.REQUEST);
    const keys = Object.keys(log);

    expect(keys.slice(0, 4)).toEqual(['src', 'evt', 'lvl', 'ts']);
    expect(log.prog).toBe('Rails');
    expect(keys.indexOf('prog')).toBeGreaterThan(keys.indexOf('params'));
  });

  test('writes ts as LogStruct does on a server in UTC', () => {
    for (const logType of AllLogTypes) {
      expect(generator.generateLog(logType).ts).toMatch(
        /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}\+00:00$/,
      );
    }
  });

  test('generates the main fields of each type', () => {
    const requestLog = generator.generateLog(LogType.REQUEST);
    expect(requestLog).toHaveProperty('method');
    expect(requestLog).toHaveProperty('path');
    expect(requestLog).toHaveProperty('status');
    expect(requestLog).toHaveProperty('req_id');

    const errorLog = generator.generateLog(LogType.ERROR);
    expect(errorLog).toHaveProperty('error_class');
    expect(errorLog).toHaveProperty('msg');
    expect(errorLog).toHaveProperty('backtrace');
  });

  test('uses the levels the integrations log at', () => {
    expect(generator.generateLog(LogType.PLAIN).lvl).toBe('info');
    expect(generator.generateLog(LogType.REQUEST).lvl).toBe('info');
    expect(generator.generateLog(LogType.ERROR).lvl).toBe('error');

    const security = (evt: Event) =>
      generator.generateLogWithOptions(LogType.SECURITY, { preferredEvent: evt }).lvl;
    expect(security(Event.BlockedHost)).toBe(Level.Warn);
    expect(security(Event.CSRFViolation)).toBe(Level.Error);
    expect(security(Event.IPSpoof)).toBe(Level.Warn);

    const dotenvUpdate = generator.generateLogWithOptions(LogType.DOTENV, {
      preferredEvent: Event.Update,
    });
    expect(dotenvUpdate.lvl).toBe(Level.Debug);

    const storage = (evt: Event) =>
      generator.generateLogWithOptions(LogType.ACTIVESTORAGE, { preferredEvent: evt }).lvl;
    expect(storage(Event.Upload)).toBe(Level.Info);
    expect(storage(Event.Exist)).toBe(Level.Debug);
    expect(storage(Event.Url)).toBe(Level.Debug);
  });

  test.each(ERROR_EVENT_TYPES)('writes the error line of %s', (logType) => {
    const log = generator.generateLogWithOptions(logType, { preferredEvent: Event.Error });
    expect(log.evt).toBe(Event.Error);
    expect(log).toHaveProperty('error_class');
  });

  test('writes a line for every event the integrations page shows', () => {
    for (const logType of AllLogTypes) {
      for (const evt of getEventsForLogType(logType)) {
        const log = generator.generateLogWithOptions(logType, { preferredEvent: evt });
        expect(log.evt).toBe(evt);
      }
    }
  });

  test('error lines come from the sources that write them', () => {
    const sources = new Set(lines(LogType.ERROR).map((log) => log.src));
    for (const source of sources) {
      expect([Source.App, Source.Rails, Source.TypeChecking]).toContain(source);
    }
  });

  test('request lines have real HTTP statuses, and the database time as a number', () => {
    const statuses = [200, 201, 204, 301, 302, 304, 400, 401, 403, 404, 422, 500];
    for (const log of lines(LogType.REQUEST)) {
      expect(statuses).toContain(log.status);
      expect(typeof log.db).toBe('number');
    }
  });

  test("request params show the [FILTERED] that Rails' filter_parameters wrote", () => {
    const params = lines(LogType.REQUEST, { filtering: false }).map((log) =>
      JSON.stringify(log.params),
    );

    expect(params.some((p) => p.includes('"password":"[FILTERED]"'))).toBe(true);
    expect(params.some((p) => p.includes('"invite_token":"[FILTERED]"'))).toBe(true);
    for (const p of params) {
      expect(p).not.toMatch(
        /"(email|password|password_confirmation|current_password)":"(?!\[FILTERED\])/,
      );
      expect(p).not.toContain('_filtered');
    }
  });

  test('filters keys that Rails leaves alone, and scrubs strings, in request params', () => {
    const payments = lines(LogType.REQUEST)
      .map((log) => log.params as Line)
      .filter((params) => 'payment_method' in params)
      .map((params) => params.payment_method as Line);

    expect(payments.length).toBeGreaterThan(0);
    for (const payment of payments) {
      expect(payment.credit_card).toEqual({ _filtered: { _class: 'String' } });
      expect(payment.cvc).toBe('[FILTERED]');
      expect(payment.phone).toBe('[PHONE]');
    }
  });

  test('job arguments show a summary of a filtered email, with its hash', () => {
    const [raw, filtered] = [false, true].map((filtering) =>
      new LogGenerator(7).generateLogWithOptions(LogType.ACTIVEJOB, {
        preferredEvent: Event.Enqueue,
        filtering,
      }),
    );
    const email = ((raw.arguments as unknown[])[1] as Line).email as string;

    expect(((filtered.arguments as unknown[])[1] as Line).email).toEqual({
      _filtered: { _class: 'String', _hash: valueHash(email) },
    });
  });

  test('scrubs accented email addresses whole, with one hash per address', () => {
    const raw = lines(LogType.ACTIONMAILER, { preferredEvent: Event.Delivery, filtering: false });
    const filtered = lines(LogType.ACTIONMAILER, { preferredEvent: Event.Delivery });
    const hashes = new Map<string, unknown>();

    raw.forEach((log, index) => {
      const email = (log.to as string[])[0];
      const scrubbed = (filtered[index].to as string[])[0];
      expect(scrubbed).toBe(`[EMAIL:${valueHash(email)}]`);
      if (hashes.has(email)) expect(hashes.get(email)).toBe(scrubbed);
      hashes.set(email, scrubbed);
    });
    expect(raw.some((log) => /[^ -~]/.test((log.to as string[])[0]))).toBe(true);
  });

  test('never writes _bytes in a filtered summary', () => {
    for (const logType of AllLogTypes) {
      for (const log of lines(logType)) {
        expect(JSON.stringify(log)).not.toContain('_bytes');
      }
    }
  });

  test("Sidekiq's lines in a job have the job's ID and class in ctx, and others no context", () => {
    const sidekiqLines = lines(LogType.SIDEKIQ);
    const outsideJobs = sidekiqLines.filter((log) => !('ctx' in log));
    expect(outsideJobs.length).toBeGreaterThan(0);
    for (const log of outsideJobs) expect(log.msg).toBe('Starting processing, hit Ctrl-C to stop');

    for (const log of sidekiqLines.filter((line) => 'ctx' in line)) {
      const ctx = log.ctx as Line;
      expect(ctx.jid).toMatch(/^[0-9a-f]{24}$/);
      expect(typeof ctx.class).toBe('string');
      expect(ctx).not.toHaveProperty('ctx');
    }
  });

  test("CarrierWave lines are its integration's uploads, remote downloads and deletes", () => {
    const events = new Set(lines(LogType.CARRIERWAVE).map((log) => log.evt));
    expect([...events].sort()).toEqual([Event.Delete, Event.Download, Event.Upload].sort());
  });

  test('SQL lines name the database adapter, and are slow queries', () => {
    for (const log of lines(LogType.SQL)) {
      expect(log.adapter).toBe('PostgreSQLAdapter');
      expect(log.duration_ms as number).toBeGreaterThanOrEqual(100);
    }
  });

  test('writes the job error lines ActiveJob has: a failed run, or a job the queue refused', () => {
    const errors = lines(LogType.ACTIVEJOB, { preferredEvent: Event.Error });
    const refused = errors.filter((log) => log.executions === 0);
    const failed = errors.filter((log) => log.executions === 1);

    expect(refused.length).toBeGreaterThan(0);
    expect(failed.length).toBeGreaterThan(0);
    for (const log of refused) {
      expect(log).toHaveProperty('req_id');
      expect(log).not.toHaveProperty('provider_job_id');
      expect(log).not.toHaveProperty('ctx');
    }
    for (const log of failed) expect(log).toHaveProperty('ctx');
  });

  test.each([Event.Retry, Event.RetryStopped, Event.Discard])(
    'writes the %s line of a job, with the exception',
    (evt) => {
      const log = generator.generateLogWithOptions(LogType.ACTIVEJOB, { preferredEvent: evt });
      expect(log.evt).toBe(evt);
      expect(log.lvl).toBe(evt === Event.Retry ? Level.Info : Level.Error);
      expect(log).toHaveProperty('error_class');
      expect(log).toHaveProperty('msg');
    },
  );

  test("writes a job's enqueue, start and finish lines, each ts the time of its event", () => {
    const [enqueue, start, finish] = generator.generateJobSequence();

    expect([enqueue.evt, start.evt, finish.evt]).toEqual([
      Event.Enqueue,
      Event.Start,
      Event.Finish,
    ]);
    for (const line of [enqueue, start, finish]) {
      expect(line.src).toBe(Source.Job);
      expect(line.lvl).toBe(Level.Info);
      expect(line.provider_job_id).toBe(enqueue.provider_job_id);
    }
    expect(start.job_id).toBe(enqueue.job_id);
    expect(finish.job_id).toBe(enqueue.job_id);
    expect(start.started_at).toBe(start.ts);
    expect(finish.finished_at).toBe(finish.ts);
    expect(enqueue).not.toHaveProperty('duration_ms');
    expect(finish).toHaveProperty('duration_ms');
    // Sidekiq ran the job: its job ID is the provider_job_id
    expect((start.ctx as Line).jid).toBe(start.provider_job_id);

    const times = [enqueue, start, finish].map((line) => new Date(line.ts as string).getTime());
    expect(times[0]).toBeLessThan(times[1]);
    expect(times[1]).toBeLessThan(times[2]);
  });

  test('writes every time in a line with milliseconds, like ts', () => {
    const time = /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}\+00:00$/;
    const at = (evt: Event, key: string) =>
      generator.generateLogWithOptions(LogType.ACTIVEJOB, { preferredEvent: evt })[key];
    expect(at(Event.Schedule, 'scheduled_at')).toMatch(time);
    expect(at(Event.Start, 'started_at')).toMatch(time);
    expect(at(Event.Finish, 'finished_at')).toMatch(time);
  });

  test("blocked host lines list the hosts Rails blocked, and not Rails' host settings", () => {
    const log = generator.generateLogWithOptions(LogType.SECURITY, {
      preferredEvent: Event.BlockedHost,
    });
    expect(log.blocked_hosts).toEqual([log.blocked_host]);
    expect(log).not.toHaveProperty('allowed_hosts');
    expect(log).not.toHaveProperty('allow_ip_hosts');
  });
});
