/* eslint-disable @typescript-eslint/no-explicit-any */
import {
  Event,
  Level,
  Source,
  RequestLog,
  ActiveJobLog,
  PlainLog,
  ErrorLog,
  SecurityLog,
  ShrineLog,
  SidekiqLog,
  ActiveStorageLog,
  ActionMailerLog,
  CarrierWaveLog,
  GoodJobLog,
  SQLLog,
  ActiveModelSerializersLog,
  AhoyLog,
  DotenvLog,
} from '../generated/log-types';
import { RandomDataGenerator } from '../random-data-generator';
import { SampleData } from '../sample-data';

export function generateRequest(
  gen: RandomDataGenerator,
  log: Partial<RequestLog>,
): Partial<RequestLog> {
  log.method = gen.sample(SampleData.HTTP_METHODS);
  log.path = gen.randomPath();
  log.controller = gen.sample(SampleData.CONTROLLERS);
  log.action = gen.sample(SampleData.ACTIONS);
  log.status = gen.sample(SampleData.STATUS_CODES);
  log.duration_ms = gen.randomDuration();
  log.view = gen.randomFloat(0, 100);
  log.database = gen.randomFloat(0, 50);
  log.format = 'json';
  log.params = {
    id: gen.randomInt(1, 1000),
    action: log.action,
    controller: log.controller,
  };
  log.source_ip = gen.randomIP(false);
  log.user_agent = 'Mozilla/5.0';
  log.referer = 'https://example.com';
  log.request_id = gen.randomHex(16);
  return log;
}

export function generateActiveJob(
  gen: RandomDataGenerator,
  log: Partial<ActiveJobLog>,
): Partial<ActiveJobLog> {
  const base: Partial<ActiveJobLog> = {
    ...log,
    job_id: gen.randomHex(8),
    job_class: gen.sample(SampleData.JOB_CLASSES),
    queue_name: ['default', 'critical', 'low', 'mailers'][gen.randomInt(0, 3)],
    arguments: [
      gen.randomInt(1, 100),
      { action: gen.sample(['create', 'update', 'process']) },
    ],
  };
  switch (log.event) {
    case Event.ENQUEUE:
      return {
        ...base,
        retries: gen.randomInt(0, 3),
        scheduled_at: gen.randomTimestamp(),
      };
    case Event.SCHEDULE:
      return {
        ...base,
        scheduled_at: gen.randomTimestamp(),
      };
    case Event.START:
      return {
        ...base,
        started_at: new Date().toISOString(),
        attempt: gen.randomInt(1, 3),
      };
    case Event.FINISH:
      return {
        ...base,
        duration_ms: gen.randomDuration(),
        finished_at: new Date().toISOString(),
      };
    default:
      return base;
  }
}

export function generatePlain(
  _gen: RandomDataGenerator,
  log: Partial<PlainLog>,
): Partial<PlainLog> {
  log.message = `Log message ${Math.random().toString(16).slice(2, 10)}`;
  return log;
}

export function generateError(
  gen: RandomDataGenerator,
  log: Partial<ErrorLog>,
): Partial<ErrorLog> {
  log.err_class = gen.sample(SampleData.ERROR_TYPES);
  log.message = gen.sample(SampleData.ERROR_MESSAGES);
  const num = gen.randomInt(2, 4);
  log.backtrace = Array.from({ length: num }, () =>
    gen.sample(SampleData.BACKTRACE_LINES),
  );
  log.additional_data = { context: `Error context ${gen.randomHex(4)}` };
  return log;
}

export function generateSecurity(
  gen: RandomDataGenerator,
  log: Partial<SecurityLog>,
): Partial<SecurityLog> {
  log.message = 'Security violation detected';
  log.blocked_host = 'malicious-site.com';
  log.blocked_hosts = ['malicious-site.com', 'evil-domain.net'];
  log.client_ip = gen.randomIP(false);
  log.x_forwarded_for = gen.randomIP(false);
  log.path = gen.randomPath();
  log.http_method = gen.sample(SampleData.HTTP_METHODS);
  log.source_ip = gen.randomIP(false);
  log.user_agent = 'Mozilla/5.0';
  log.referer = 'https://example.com';
  log.request_id = gen.randomHex(16);
  log.additional_data = { attempted_action: 'suspicious_activity' };
  return log;
}

export function generateShrine(
  gen: RandomDataGenerator,
  log: Partial<ShrineLog>,
): Partial<ShrineLog> {
  const ops = ['upload', 'download', 'delete', 'metadata', 'exist', 'url'];
  return {
    ...log,
    storage: gen.sample(SampleData.STORAGE_SERVICES),
    location: `${gen.randomHex(8)}.jpg`,
    upload_options: { acl: 'public-read' },
    download_options: { disposition: 'inline' },
    options: { retries: gen.randomInt(0, 2) },
    uploader: 'ImageUploader',
    duration_ms: gen.randomDuration(),
    additional_data: {},
  };
}

export function generateSidekiq(
  gen: RandomDataGenerator,
  log: Partial<SidekiqLog>,
): Partial<SidekiqLog> {
  log.process_id = gen.randomInt(1000, 99999);
  log.thread_id = `thread-${gen.randomHex(4)}` as any;
  log.message = 'Sidekiq worker processed job';
  log.context = { jid: gen.randomHex(8) };
  return log;
}

export function generateActiveStorage(
  gen: RandomDataGenerator,
  log: Partial<ActiveStorageLog>,
): Partial<ActiveStorageLog> {
  const ops = [
    'upload',
    'download',
    'delete',
    'metadata',
    'exist',
    'stream',
    'url',
  ];
  return {
    ...log,
    event: log.event!,
    storage: gen.sample(SampleData.STORAGE_SERVICES),
    file_id: gen.randomHex(10),
    filename: gen.sample(SampleData.FILE_NAMES),
    mime_type: gen.sample(SampleData.FILE_TYPES),
    size: gen.randomInt(1000, 1000000),
    metadata: { width: 800, height: 600 },
    duration_ms: gen.randomDuration(),
    checksum: gen.randomHex(32),
    exist: true,
    url: `https://storage.example.com/${gen.randomHex(8)}`,
    prefix: 'uploads',
    range: 'bytes=0-1000',
  };
}

export function generateActionMailer(
  gen: RandomDataGenerator,
  log: Partial<ActionMailerLog>,
): Partial<ActionMailerLog> {
  const event = log.event || Event.DELIVERY;
  return {
    ...log,
    event,
    to: [gen.randomEmail()],
    from: 'notifications@example.com',
    subject: 'Important notification',
    additional_data: {
      mailer: gen.sample(SampleData.MAILER_CLASSES),
      action: gen.sample(SampleData.MAILER_ACTIONS),
    },
  };
}

export function generateCarrierWave(
  gen: RandomDataGenerator,
  log: Partial<CarrierWaveLog>,
): Partial<CarrierWaveLog> {
  return {
    ...log,
    storage: gen.sample(SampleData.STORAGE_SERVICES),
    file_id: gen.randomHex(10),
    filename: gen.sample(SampleData.FILE_NAMES),
    mime_type: gen.sample(SampleData.FILE_TYPES),
    size: gen.randomInt(1000, 1000000),
    metadata: { width: 800, height: 600 },
    duration_ms: gen.randomDuration(),
    uploader: 'AvatarUploader',
    model: 'User',
    mount_point: 'avatar',
    additional_data: { versions: ['thumb', 'medium', 'large'] },
  };
}

export function generateGoodJob(
  gen: RandomDataGenerator,
  log: Partial<GoodJobLog>,
): Partial<GoodJobLog> {
  return {
    ...log,
    job_id: gen.randomHex(8),
    job_class: gen.sample(SampleData.JOB_CLASSES),
    queue_name: gen.sample(['default', 'critical', 'low']),
    priority: gen.randomInt(0, 100),
    arguments: [{ id: gen.randomInt(1, 1000) }],
    executions: gen.randomInt(0, 3),
    exception_executions: 0,
    scheduled_at: new Date().toISOString(),
    thread_id: `thread-${gen.randomHex(4)}`,
    process_id: gen.randomInt(1000, 99999),
  };
}

export function generateSQL(
  gen: RandomDataGenerator,
  log: Partial<SQLLog>,
): Partial<SQLLog> {
  const operations = ['SELECT', 'INSERT', 'UPDATE', 'DELETE'];
  const tables = ['users', 'posts', 'comments', 'orders', 'products'];
  const operation = gen.sample(operations);
  const table = gen.sample(tables);
  return {
    ...log,
    sql: `${operation} * FROM ${table} WHERE id = ?`,
    name: `${table.charAt(0).toUpperCase() + table.slice(1).slice(0, -1)} Load`,
    duration_ms: gen.randomFloat(0.1, 100.0),
    row_count: operation === 'SELECT' ? gen.randomInt(0, 100) : 1,
    adapter: 'PostgreSQLAdapter',
    bind_params: [gen.randomInt(1, 1000)],
    database_name: 'production',
    connection_pool_size: 5,
    active_connections: gen.randomInt(1, 5),
    operation_type: operation,
    table_names: [table],
  };
}

export function generateAMS(
  gen: RandomDataGenerator,
  log: Partial<ActiveModelSerializersLog>,
): Partial<ActiveModelSerializersLog> {
  log.message = 'ams.render';
  log.serializer = gen.sample([
    'UserSerializer',
    'ProjectSerializer',
    'OrderSerializer',
  ]);
  log.adapter = gen.sample(['json', 'json_api']);
  log.resource_class = gen.sample(['User', 'Project', 'Order']);
  log.duration_ms = gen.randomFloat(0.2, 30.0);
  return log;
}

export function generateAhoy(
  gen: RandomDataGenerator,
  log: Partial<AhoyLog>,
): Partial<AhoyLog> {
  log.message = 'ahoy.track';
  log.ahoy_event = gen.sample(['signup', 'purchase', 'visited_page']);
  log.properties = {
    plan: gen.sample(['free', 'pro', 'enterprise']),
    referrer: gen.sample(['homepage', 'ad', 'email']),
  };
  log.additional_data = {};
  return log;
}

export { generateDotenv } from './dotenv';

export function generateJobSequence(
  gen: RandomDataGenerator,
): Partial<ActiveJobLog>[] {
  const jobId = gen.randomHex(8);
  const jobClass = gen.sample(SampleData.JOB_CLASSES);
  const queueName = ['default', 'critical', 'low', 'mailers'][
    gen.randomInt(0, 3)
  ];
  const args = [
    gen.randomInt(1, 100),
    { action: gen.sample(['create', 'update', 'process']) },
  ];
  const data = {
    retries: gen.randomInt(0, 3),
    scheduled_at: gen.randomTimestamp(),
  };

  const enqueueLog: Partial<ActiveJobLog> = {
    timestamp: new Date().toISOString(),
    level: Level.INFO,
    source: Source.JOB,
    event: Event.ENQUEUE,
    job_id: jobId,
    job_class: jobClass,
    queue_name: queueName,
    arguments: args,
    retries: data.retries as number,
    scheduled_at: data.scheduled_at as string,
  };

  const startTime = new Date(
    new Date(enqueueLog.timestamp as string).getTime() +
      gen.randomInt(100, 5000),
  );
  const startLog: Partial<ActiveJobLog> = {
    timestamp: startTime.toISOString(),
    level: Level.INFO,
    source: Source.JOB,
    event: Event.START,
    job_id: jobId,
    job_class: jobClass,
    queue_name: queueName,
    arguments: args,
    started_at: startTime.toISOString(),
    attempt: gen.randomInt(1, 3),
  };

  const duration = gen.randomFloat(50, 2000);
  const finishTime = new Date(startTime.getTime() + duration);
  const finishLog: Partial<ActiveJobLog> = {
    timestamp: finishTime.toISOString(),
    level: Level.INFO,
    source: Source.JOB,
    event: Event.FINISH,
    job_id: jobId,
    job_class: jobClass,
    queue_name: queueName,
    arguments: args,
    duration_ms: duration,
    finished_at: finishTime.toISOString(),
  };

  return [enqueueLog, startLog, finishLog];
}
