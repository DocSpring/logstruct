/* eslint-disable @typescript-eslint/no-explicit-any */
import { RandomDataGenerator } from './random-data-generator';
import { SampleData } from './sample-data';
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
  // Import the event type arrays for each log type
  SecurityEvents,
  ActiveJobEvents,
  ShrineEvents,
  ActiveStorageEvents,
  ActionMailerEvents,
  CarrierWaveEvents,
  // Import the array of all log types
  AllLogTypes,
} from './log-types';
import logKeysMap from './log-keys.json';

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

    // Process each field in the log
    Object.entries(log).forEach(([propertyName, value]) => {
      const jsonKey = (logKeysMap as Record<string, string>)[propertyName];
      if (jsonKey) {
        // Use the mapped JSON key
        transformedLog[jsonKey] = value;
      } else {
        // Keep original name if no mapping exists
        transformedLog[propertyName] = value;
      }
    });

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
      default:
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
      case LogType.PLAIN:
      case LogType.ERROR:
        // These can have any source
        return this.randomEnum(Source);
      default:
        logType satisfies never;
        throw new Error(`Unhandled log type: ${logType}`);
    }
  }

  /**
   * Generate a typed log based on log type
   */
  generateTypedLog(logType: LogType): Partial<Log> {
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
    const event = this.getRandomEventForLogType(logType);

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
        return this.generateRequestLog(log as Partial<RequestLog>);
      case LogType.ACTIVEJOB:
        return this.generateActiveJobLog(log as Partial<ActiveJobLog>);
      case LogType.PLAIN:
        return this.generatePlainLog(log as Partial<PlainLog>);
      case LogType.ERROR:
        return this.generateErrorLog(log as Partial<ErrorLog>);
      case LogType.SECURITY:
        return this.generateSecurityLog(log as Partial<SecurityLog>);
      case LogType.SHRINE:
        return this.generateShrineLog(log as Partial<ShrineLog>);
      case LogType.SIDEKIQ:
        return this.generateSidekiqLog(log as Partial<SidekiqLog>);
      case LogType.ACTIVESTORAGE:
        return this.generateActiveStorageLog(log as Partial<ActiveStorageLog>);
      case LogType.ACTIONMAILER:
        return this.generateActionMailerLog(log as Partial<ActionMailerLog>);
      case LogType.CARRIERWAVE:
        return this.generateCarrierWaveLog(log as Partial<CarrierWaveLog>);
      default:
        logType satisfies never;
        throw new Error(`Unhandled log type: ${logType}`);
    }
  }

  /**
   * Generate a random log of a given type
   * Returns a log with field names mapped to JSON keys
   */
  generateLog(logType: LogType): Record<string, any> {
    // Generate a typed log then transform it
    const typedLog = this.generateTypedLog(logType);

    // Transform property names to JSON keys
    return this.transformLog(typedLog);
  }

  private generateRequestLog(log: Partial<RequestLog>): Partial<RequestLog> {
    log.method = this.sample(SampleData.HTTP_METHODS);
    log.path = this.randomPath();
    log.controller = this.sample(SampleData.CONTROLLERS);
    log.action = this.sample(SampleData.ACTIONS);
    log.status = this.sample(SampleData.STATUS_CODES);
    log.duration = this.randomDuration();
    log.view = this.randomFloat(0, 100);
    log.db = this.randomFloat(0, 50);
    log.format = 'json';
    log.params = {
      id: this.randomInt(1, 1000),
      action: log.action,
      controller: log.controller,
    };
    log.source_ip = this.randomIP(false);
    log.user_agent = 'Mozilla/5.0';
    log.referer = 'https://example.com';
    log.request_id = this.randomHex(16);

    return log;
  }

  private generateActiveJobLog(
    log: Partial<ActiveJobLog>,
  ): Partial<ActiveJobLog> {
    // Create the basic job log without duration
    const baseJobLog: Partial<ActiveJobLog> = {
      ...log,
      job_id: this.randomHex(8),
      job_class: this.sample(SampleData.JOB_CLASSES),
      queue_name: ['default', 'critical', 'low', 'mailers'][
        this.randomInt(0, 3)
      ],
      arguments: [
        this.randomInt(1, 100),
        { action: this.sample(['create', 'update', 'process']) },
      ],
      data: {
        retries: this.randomInt(0, 3),
        scheduled_at: this.randomTimestamp(),
      },
    };

    // Only add duration if it's a FINISH event
    const jobLog: Partial<ActiveJobLog> =
      log.event === Event.FINISH
        ? { ...baseJobLog, duration: this.randomDuration() }
        : baseJobLog;

    return jobLog;
  }

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

    log.data = {
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
    log.data = {
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
    log.duration = this.randomDuration();
    log.data = {
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
        Event.UNKNOWN,
      ]);

    // Set appropriate operation based on event
    let operation = 'upload';
    if (event === Event.DOWNLOAD || event === Event.STREAM) {
      operation = 'download';
    } else if (event === Event.DELETE) {
      operation = 'delete';
    } else if (event === Event.METADATA) {
      operation = 'metadata';
    } else if (event === Event.EXIST) {
      operation = 'exists';
    } else if (event === Event.URL) {
      operation = 'url';
    }

    // Ensure we have the right source and one of the valid events
    const storageLog: Partial<ActiveStorageLog> = {
      ...log,
      source: Source.STORAGE,
      event,
      operation,
      storage: this.sample(SampleData.STORAGE_SERVICES),
      file_id: this.randomHex(10),
      filename: this.sample(SampleData.FILE_NAMES),
      mime_type: this.sample(SampleData.FILE_TYPES),
      size: this.randomInt(1000, 1000000),
      metadata: { width: 800, height: 600 },
      duration: this.randomDuration(),
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
      data: {
        mailer: this.sample(SampleData.MAILER_CLASSES),
        action: this.sample(SampleData.MAILER_ACTIONS),
      },
    };

    return mailerLog;
  }

  private generateCarrierWaveLog(
    log: Partial<CarrierWaveLog>,
  ): Partial<CarrierWaveLog> {
    log.operation = 'upload';
    log.storage = this.sample(SampleData.STORAGE_SERVICES);
    log.file_id = this.randomHex(10);
    log.filename = this.sample(SampleData.FILE_NAMES);
    log.mime_type = this.sample(SampleData.FILE_TYPES);
    log.size = this.randomInt(1000, 1000000);
    log.metadata = { width: 800, height: 600 };
    log.duration = this.randomDuration();
    log.uploader = 'AvatarUploader';
    log.model = 'User';
    log.mount_point = 'avatar';
    log.data = {
      versions: ['thumb', 'medium', 'large'],
    };

    return log;
  }

  /**
   * Generate a sequence of logs that tell a story
   * For example: job enqueue -> start -> finish
   */
  generateJobSequence(): Partial<ActiveJobLog>[] {
    const jobId = this.randomHex(8);
    const jobClass = this.sample(SampleData.JOB_CLASSES);
    const queueName = ['default', 'critical', 'low', 'mailers'][
      this.randomInt(0, 3)
    ];
    const args = [
      this.randomInt(1, 100),
      { action: this.sample(['create', 'update', 'process']) },
    ];
    const data = {
      retries: this.randomInt(0, 3),
      scheduled_at: this.randomTimestamp(),
    };

    // Enqueue event
    const enqueueLog: Partial<ActiveJobLog> = {
      timestamp: new Date().toISOString(),
      level: Level.INFO,
      source: Source.JOB,
      event: Event.ENQUEUE,
      job_id: jobId,
      job_class: jobClass,
      queue_name: queueName,
      arguments: args,
      data,
    };

    // Start event (happens a little later)
    const startTime = new Date(
      new Date(enqueueLog.timestamp as string).getTime() +
        this.randomInt(100, 5000),
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
      data,
    };

    // Finish event (with duration)
    const duration = this.randomFloat(50, 2000);
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
      duration: duration,
      data,
    };

    return [enqueueLog, startLog, finishLog];
  }
}
