/* eslint-disable @typescript-eslint/no-explicit-any */
import { RandomDataGenerator } from './random-data-generator';
import { SampleData } from './sample-data';
import {
  generateRequest,
  generateActiveJob,
  generatePlain,
  generateError,
  generateSecurity,
  generateShrine,
  generateSidekiq,
  generateActiveStorage,
  generateActionMailer,
  generateCarrierWave,
  generateGoodJob,
  generateSQL,
  generateAMS,
  generateAhoy,
  generateDotenv,
  generateJobSequence as genJobSequence,
} from './generators';
import {
  LogType,
  Log,
  Level,
  Source,
  Event,
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
  // Import the event type arrays for each log type
  SecurityEvents,
  ActiveJobEvents,
  ShrineEvents,
  ActiveStorageEvents,
  ActionMailerEvents,
  CarrierWaveEvents,
  LogField,
  PropToLogField,
} from './generated/log-types';
import logFields from './generated/log-fields.json';

/**
 * Utility for generating structured log data
 */
export class LogGenerator extends RandomDataGenerator {
  constructor(seed?: number) {
    super(seed);
  }

  /**
   * Transform log properties to JSON keys using the logKeysMap
   * For example: timestamp -> ts, source -> src, etc.
   */
  transformLog(log: Partial<Log>): Record<string, any> {
    const transformedLog: Record<string, any> = {};
    let additionalData: Record<string, any> | undefined;

    // Precompute compact keys set for quick checks
    const compactKeys = new Set<string>(Object.values(LogField));

    // Helper to convert a prop name to PascalCase LogField name
    const toPascal = (name: string): string =>
      name
        .split(/[_\-\s]+/)
        .filter(Boolean)
        .map((s) => s.charAt(0).toUpperCase() + s.slice(1))
        .join('');

    // Process each field in the log
    Object.entries(log).forEach(([propertyName, value]) => {
      if (propertyName === 'additional_data' && value) {
        // Save additional_data to merge later
        additionalData = value as Record<string, any>;
        return;
      }
      // If it's already a compact key (e.g., ts, lvl), keep it
      if (compactKeys.has(propertyName)) {
        transformedLog[propertyName] = value;
        return;
      }

      // Use the generated property -> LogField name mapping to find compact key
      const lfValue = (PropToLogField as Record<string, string | undefined>)[
        propertyName
      ];
      const jsonKey = lfValue as string | undefined;
      transformedLog[jsonKey ?? propertyName] = value;
    });

    // Merge additional_data into the root object if it exists
    if (additionalData) {
      Object.entries(additionalData).forEach(([key, value]) => {
        transformedLog[key] = value;
      });
    }

    return transformedLog;
  }

  /**
   * Select a valid event for a given log type
   */
  private getRandomEventForLogType(logType: LogType): Event {
    // Use the auto-generated event arrays from our TypeScript definitions
    switch (logType) {
      case LogType.REQUEST:
        return Event.REQUEST;
      case LogType.ACTIVEJOB:
        return this.sample(ActiveJobEvents);
      case LogType.PLAIN:
        return Event.LOG;
      case LogType.ERROR:
        return Event.ERROR;
      case LogType.SECURITY:
        return this.sample(SecurityEvents);
      case LogType.SHRINE:
        return this.sample(ShrineEvents);
      case LogType.SIDEKIQ:
        return Event.LOG;
      case LogType.ACTIVESTORAGE:
        return this.sample(ActiveStorageEvents);
      case LogType.ACTIONMAILER:
        return this.sample(ActionMailerEvents);
      case LogType.CARRIERWAVE:
        return this.sample(CarrierWaveEvents);
      case LogType.GOODJOB:
        return Event.LOG; // GoodJob uses generic log events
      case LogType.SQL:
        return Event.DATABASE;
      case LogType.ACTIVEMODELSERIALIZERS:
        return Event.LOG;
      case LogType.AHOY:
        return Event.LOG;
      case LogType.DOTENV:
        return this.sample([
          Event.LOAD,
          Event.UPDATE,
          Event.SAVE,
          Event.RESTORE,
        ]);
      default:
        // Ensure we have an exhaustive switch statement
        logType satisfies never;
        throw new Error(`Unhandled log type: ${logType}`);
    }
  }

  /**
   * Get the source for a specific log type
   */
  private getSourceForLogType(logType: LogType): Source {
    switch (logType) {
      case LogType.REQUEST:
        return Source.RAILS;
      case LogType.ACTIVEJOB:
        return Source.JOB;
      case LogType.SECURITY:
        return Source.SECURITY;
      case LogType.SHRINE:
        return Source.SHRINE;
      case LogType.SIDEKIQ:
        return Source.SIDEKIQ;
      case LogType.ACTIVESTORAGE:
        return Source.STORAGE;
      case LogType.ACTIONMAILER:
        return Source.MAILER;
      case LogType.CARRIERWAVE:
        return Source.CARRIERWAVE;
      case LogType.GOODJOB:
        return Source.JOB;
      case LogType.SQL:
        return Source.APP;
      case LogType.ACTIVEMODELSERIALIZERS:
        return Source.RAILS;
      case LogType.AHOY:
        return Source.APP;
      case LogType.DOTENV:
        return Source.DOTENV;
      case LogType.PLAIN:
      case LogType.ERROR:
        // These can have any source
        return this.randomEnum(Source);
      default:
        // Ensure we have an exhaustive switch statement
        logType satisfies never;
        throw new Error(`Unhandled log type: ${logType}`);
    }
  }

  /**
   * Generate a typed log based on log type
   */
  generateTypedLog(logType: LogType, preferredEvent?: Event): Partial<Log> {
    // Determine appropriate log level based on log type
    let level = Level.INFO; // Default to INFO for most logs
    if (logType === LogType.ERROR) {
      level = Level.ERROR;
    } else if (logType === LogType.SECURITY) {
      // Security logs are often warnings or errors
      level = Math.random() > 0.3 ? Level.WARN : Level.ERROR;
    }

    // Get valid source and event based on log type
    const source = this.getSourceForLogType(logType);
    const event = preferredEvent ?? this.getRandomEventForLogType(logType);

    // Create a base log with timestamp and level
    const log = {
      timestamp: new Date().toISOString(),
      level,
      source,
      event,
    };

    // Add type-specific fields
    switch (logType) {
      case LogType.REQUEST:
        return generateRequest(this, log as Partial<RequestLog>);
      case LogType.ACTIVEJOB:
        return generateActiveJob(this, log as Partial<ActiveJobLog>);
      case LogType.PLAIN:
        return generatePlain(this, log as Partial<PlainLog>);
      case LogType.ERROR:
        return generateError(this, log as Partial<ErrorLog>);
      case LogType.SECURITY:
        return generateSecurity(this, log as Partial<SecurityLog>);
      case LogType.SHRINE:
        return generateShrine(this, log as Partial<ShrineLog>);
      case LogType.SIDEKIQ:
        return generateSidekiq(this, log as Partial<SidekiqLog>);
      case LogType.ACTIVESTORAGE:
        return generateActiveStorage(this, log as Partial<ActiveStorageLog>);
      case LogType.ACTIONMAILER:
        return generateActionMailer(this, log as Partial<ActionMailerLog>);
      case LogType.CARRIERWAVE:
        return generateCarrierWave(this, log as Partial<CarrierWaveLog>);
      case LogType.GOODJOB:
        return generateGoodJob(this, log as Partial<GoodJobLog>);
      case LogType.SQL:
        return generateSQL(this, log as Partial<SQLLog>);
      case LogType.ACTIVEMODELSERIALIZERS:
        return generateAMS(this, log as Partial<ActiveModelSerializersLog>);
      case LogType.AHOY:
        return generateAhoy(this, log as Partial<AhoyLog>);
      case LogType.DOTENV:
        return generateDotenv(this, log as Partial<DotenvLog>);
      default:
        // Ensure we have an exhaustive switch statement
        logType satisfies never;
        throw new Error(`Unhandled log type: ${logType}`);
    }
  }

  /**
   * Generate a random log of a given type
   * Returns a log with field names mapped to JSON keys
   */
  generateLog(logType: LogType): Record<string, any> {
    return this.generateLogWithOptions(logType);
  }

  /**
   * Generate a random log with optional preferences (e.g., a preferred event)
   */
  generateLogWithOptions(
    logType: LogType,
    opts?: { preferredEvent?: Event },
  ): Record<string, any> {
    // Generate a typed log then transform it
    const typedLog = this.generateTypedLog(logType, opts?.preferredEvent);

    // Transform property names to JSON keys
    return this.transformLog(typedLog);
  }

  // Individual generator implementations moved to ./generators

  // ...

  private generatePlainLog(log: Partial<PlainLog>): Partial<PlainLog> {
    log.message = `Log message ${this.randomHex(8)}`;
    return log;
  }

  private generateErrorLog(log: Partial<ErrorLog>): Partial<ErrorLog> {
    log.err_class = this.sample(SampleData.ERROR_TYPES);
    log.message = this.sample(SampleData.ERROR_MESSAGES);

    // Generate 2-4 random backtrace lines
    const numLines = this.randomInt(2, 4);
    log.backtrace = Array.from({ length: numLines }, () =>
      this.sample(SampleData.BACKTRACE_LINES),
    );

    log.additional_data = {
      context: `Error context ${this.randomHex(4)}`,
    };

    return log;
  }

  private generateSecurityLog(log: Partial<SecurityLog>): Partial<SecurityLog> {
    log.message = 'Security violation detected';
    log.blocked_host = 'malicious-site.com';
    log.blocked_hosts = ['malicious-site.com', 'evil-domain.net'];
    log.client_ip = this.randomIP(false);
    log.x_forwarded_for = this.randomIP(false);
    log.path = this.randomPath();
    log.http_method = this.sample(SampleData.HTTP_METHODS);
    log.source_ip = this.randomIP(false);
    log.user_agent = 'Mozilla/5.0';
    log.referer = 'https://example.com';
    log.request_id = this.randomHex(16);
    log.additional_data = {
      attempted_action: 'suspicious_activity',
    };

    return log;
  }

  private generateShrineLog(log: Partial<ShrineLog>): Partial<ShrineLog> {
    log.storage = this.sample(SampleData.STORAGE_SERVICES);
    log.location = `uploads/${this.randomHex(12)}`;
    log.upload_options = { public: true };
    log.download_options = {};
    log.options = { metadata: true };
    log.uploader = 'ImageUploader';
    log.duration_ms = this.randomDuration();
    log.additional_data = {
      content_type: this.sample(SampleData.FILE_TYPES),
      filename: this.sample(SampleData.FILE_NAMES),
    };

    return log;
  }

  private generateSidekiqLog(log: Partial<SidekiqLog>): Partial<SidekiqLog> {
    // Ensure we have the right source and event for SidekiqLog
    const sidekiqLog: Partial<SidekiqLog> = {
      ...log,
      source: Source.SIDEKIQ,
      event: Event.LOG,
      process_id: this.randomInt(1000, 9999),
      thread_id: this.randomHex(8),
      message: 'Job processing',
      context: {
        queue: 'default',
        job_id: this.randomHex(12),
      },
    };

    return sidekiqLog;
  }

  private generateActiveStorageLog(
    log: Partial<ActiveStorageLog>,
  ): Partial<ActiveStorageLog> {
    // Determine the event first if not provided
    const event =
      log.event ||
      this.sample([
        Event.UPLOAD,
        Event.DOWNLOAD,
        Event.DELETE,
        Event.EXIST,
        Event.METADATA,
        Event.STREAM,
        Event.URL,
      ]);

    // Ensure we have the right source and one of the valid events
    const storageLog: Partial<ActiveStorageLog> = {
      ...log,
      source: Source.STORAGE,
      event,
      storage: this.sample(SampleData.STORAGE_SERVICES),
      file_id: this.randomHex(10),
      filename: this.sample(SampleData.FILE_NAMES),
      mime_type: this.sample(SampleData.FILE_TYPES),
      size: this.randomInt(1000, 1000000),
      metadata: { width: 800, height: 600 },
      duration_ms: this.randomDuration(),
      checksum: this.randomHex(32),
      exist: true,
      url: `https://storage.example.com/${this.randomHex(8)}`,
      prefix: 'uploads',
      range: 'bytes=0-1000',
    };

    return storageLog;
  }

  private generateActionMailerLog(
    log: Partial<ActionMailerLog>,
  ): Partial<ActionMailerLog> {
    // Determine the event first if not provided
    const event = log.event || this.sample([Event.DELIVERY, Event.DELIVERED]);

    // Ensure we have the right source and one of the valid events
    const mailerLog: Partial<ActionMailerLog> = {
      ...log,
      source: Source.MAILER,
      event,
      to: [this.randomEmail()],
      from: 'notifications@example.com',
      subject: 'Important notification',
      additional_data: {
        mailer: this.sample(SampleData.MAILER_CLASSES),
        action: this.sample(SampleData.MAILER_ACTIONS),
      },
    };

    return mailerLog;
  }

  private generateCarrierWaveLog(
    log: Partial<CarrierWaveLog>,
  ): Partial<CarrierWaveLog> {
    log.storage = this.sample(SampleData.STORAGE_SERVICES);
    log.file_id = this.randomHex(10);
    log.filename = this.sample(SampleData.FILE_NAMES);
    log.mime_type = this.sample(SampleData.FILE_TYPES);
    log.size = this.randomInt(1000, 1000000);
    log.metadata = { width: 800, height: 600 };
    log.duration_ms = this.randomDuration();
    log.uploader = 'AvatarUploader';
    log.model = 'User';
    log.mount_point = 'avatar';
    log.additional_data = {
      versions: ['thumb', 'medium', 'large'],
    };

    return log;
  }

  private generateGoodJobLog(log: Partial<GoodJobLog>): Partial<GoodJobLog> {
    log.job_id = this.randomHex(8);
    log.job_class = this.sample(SampleData.JOB_CLASSES);
    log.queue_name = this.sample(['default', 'critical', 'low']);
    log.priority = this.randomInt(0, 100);
    log.arguments = [{ id: this.randomInt(1, 1000) }];
    log.executions = this.randomInt(0, 3);
    log.exception_executions = 0;
    log.scheduled_at = new Date().toISOString();
    log.thread_id = `thread-${this.randomHex(4)}`;
    log.process_id = this.randomInt(1000, 99999);

    return log;
  }

  private generateSQLLog(log: Partial<SQLLog>): Partial<SQLLog> {
    const operations = ['SELECT', 'INSERT', 'UPDATE', 'DELETE'];
    const tables = ['users', 'posts', 'comments', 'orders', 'products'];
    const operation = this.sample(operations);
    const table = this.sample(tables);

    log.sql = `${operation} * FROM ${table} WHERE id = ?`;
    log.name = `${table.charAt(0).toUpperCase() + table.slice(1).slice(0, -1)} Load`;
    log.duration_ms = this.randomFloat(0.1, 100.0);
    log.row_count = operation === 'SELECT' ? this.randomInt(0, 100) : 1;
    log.adapter = 'PostgreSQLAdapter';
    log.bind_params = [this.randomInt(1, 1000)];
    log.database_name = 'production';
    log.connection_pool_size = 5;
    log.active_connections = this.randomInt(1, 5);
    log.operation_type = operation;
    log.table_names = [table];

    return log;
  }

  private generateActiveModelSerializersLog(
    log: Partial<ActiveModelSerializersLog>,
  ): Partial<ActiveModelSerializersLog> {
    log.message = 'ams.render';
    log.serializer = this.sample([
      'UserSerializer',
      'ProjectSerializer',
      'OrderSerializer',
    ]);
    log.adapter = this.sample(['json', 'json_api']);
    log.resource_class = this.sample(['User', 'Project', 'Order']);
    log.duration_ms = this.randomFloat(0.2, 30.0);
    return log;
  }

  private generateAhoyLog(log: Partial<AhoyLog>): Partial<AhoyLog> {
    log.message = 'ahoy.track';
    log.ahoy_event = this.sample(['signup', 'purchase', 'visited_page']);
    log.properties = {
      plan: this.sample(['free', 'pro', 'enterprise']),
      referrer: this.sample(['homepage', 'ad', 'email']),
    };
    log.additional_data = {};
    return log;
  }

  private generateDotenvLog(log: Partial<DotenvLog>): Partial<DotenvLog> {
    // Choose event if not pre-selected
    // Narrow the event type specifically for dotenv
    const allowed: Array<DotenvLog['event']> = [
      Event.LOAD,
      Event.UPDATE,
      Event.SAVE,
      Event.RESTORE,
    ];
    const event: DotenvLog['event'] =
      (log.event as DotenvLog['event']) ?? this.sample(allowed);
    const level = Level.INFO;

    // Typically dotenv logs either vars or file depending on event
    const possibleVars = [
      'REGION',
      'BOOT_FLAG',
      'API_KEY',
      'SECRET_TOKEN',
      'LOG_LEVEL',
    ];
    const vars = this.sampleSize(possibleVars, this.randomInt(2, 3));
    const file = this.sample(['.env.development', '.env.test', '.env']);

    const dotenvLog: Partial<DotenvLog> = {
      ...log,
      source: Source.DOTENV,
      event,
      level,
      file,
      vars,
    };

    return dotenvLog;
  }

  /**
   * Generate a sequence of logs that tell a story
   * For example: job enqueue -> start -> finish
   */
  generateJobSequence(): Partial<ActiveJobLog>[] {
    return genJobSequence(this);
  }
}
