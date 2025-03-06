/* eslint-disable @typescript-eslint/no-explicit-any */
import { RandomDataGenerator } from "./random-data-generator";
import { SampleData } from "./sample-data";
import { 
  LogType, Log, LogLevel, Source, LogEvent,
  RequestLog, ActiveJobLog, PlainLog, ErrorLog,
  SecurityLog, ShrineLog, SidekiqLog, ActiveStorageLog,
  ActionMailerLog, CarrierWaveLog
} from "./log-types";

/**
 * Utility for generating structured log data
 */
export class LogGenerator extends RandomDataGenerator {
  constructor(seed?: number) {
    super(seed);
  }

  /**
   * Generate a random log of a given type
   */
  generateLog(logType: LogType): Partial<Log> {
    // Create a log with common fields
    const log: Partial<Log> = {
      timestamp: new Date().toISOString(),
      level: this.randomEnum(LogLevel),
      source: this.randomEnum(Source),
      event: this.randomEnum(LogEvent),
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
        return log;
    }
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
    log.format = "json";
    log.params = {
      id: this.randomInt(1, 1000),
      action: log.action,
      controller: log.controller
    };
    log.source_ip = this.randomIP(false);
    log.user_agent = "Mozilla/5.0";
    log.referer = "https://example.com";
    log.request_id = this.randomHex(16);
    
    return log;
  }
  
  private generateActiveJobLog(log: Partial<ActiveJobLog>): Partial<ActiveJobLog> {
    log.job_id = this.randomHex(8);
    log.job_class = this.sample(SampleData.JOB_CLASSES);
    log.queue_name = ["default", "critical", "low", "mailers"][this.randomInt(0, 3)];
    log.arguments = [
      this.randomInt(1, 100),
      { action: this.sample(["create", "update", "process"]) }
    ];
    log.duration = this.randomDuration();
    log.data = {
      retries: this.randomInt(0, 3),
      scheduled_at: this.randomTimestamp()
    };
    
    return log;
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
    log.backtrace = Array.from({length: numLines}, () => this.sample(SampleData.BACKTRACE_LINES));
    
    log.data = {
      context: `Error context ${this.randomHex(4)}`
    };
    
    return log;
  }
  
  private generateSecurityLog(log: Partial<SecurityLog>): Partial<SecurityLog> {
    log.message = "Security violation detected";
    log.blocked_host = "malicious-site.com";
    log.blocked_hosts = ["malicious-site.com", "evil-domain.net"];
    log.client_ip = this.randomIP(false);
    log.x_forwarded_for = this.randomIP(false);
    log.path = this.randomPath();
    log.http_method = this.sample(SampleData.HTTP_METHODS);
    log.source_ip = this.randomIP(false);
    log.user_agent = "Mozilla/5.0";
    log.referer = "https://example.com";
    log.request_id = this.randomHex(16);
    log.data = {
      attempted_action: "suspicious_activity"
    };
    
    return log;
  }
  
  private generateShrineLog(log: Partial<ShrineLog>): Partial<ShrineLog> {
    log.msg = "File uploaded";
    log.storage = this.sample(SampleData.STORAGE_SERVICES);
    log.location = `uploads/${this.randomHex(12)}`;
    log.upload_options = { public: true };
    log.download_options = { };
    log.options = { metadata: true };
    log.uploader = "ImageUploader";
    log.duration = this.randomDuration();
    log.data = {
      content_type: this.sample(SampleData.FILE_TYPES),
      filename: this.sample(SampleData.FILE_NAMES)
    };
    
    return log;
  }
  
  private generateSidekiqLog(log: Partial<SidekiqLog>): Partial<SidekiqLog> {
    log.process_id = this.randomInt(1000, 9999);
    log.thread_id = this.randomHex(8);
    log.message = "Job processing";
    log.context = {
      queue: "default",
      job_id: this.randomHex(12)
    };
    
    return log;
  }
  
  private generateActiveStorageLog(log: Partial<ActiveStorageLog>): Partial<ActiveStorageLog> {
    log.operation = "upload";
    log.storage = this.sample(SampleData.STORAGE_SERVICES);
    log.file_id = this.randomHex(10);
    log.filename = this.sample(SampleData.FILE_NAMES);
    log.mime_type = this.sample(SampleData.FILE_TYPES);
    log.size = this.randomInt(1000, 1000000);
    log.metadata = JSON.stringify({ width: 800, height: 600 });
    log.duration = this.randomDuration();
    log.checksum = this.randomHex(32);
    log.exist = true;
    log.url = `https://storage.example.com/${this.randomHex(8)}`;
    log.prefix = "uploads";
    log.range = "bytes=0-1000";
    
    return log;
  }
  
  private generateActionMailerLog(log: Partial<ActionMailerLog>): Partial<ActionMailerLog> {
    log.to = [this.randomEmail()];
    log.from = "notifications@example.com";
    log.subject = "Important notification";
    log.data = {
      mailer: this.sample(SampleData.MAILER_CLASSES),
      action: this.sample(SampleData.MAILER_ACTIONS)
    };
    
    return log;
  }
  
  private generateCarrierWaveLog(log: Partial<CarrierWaveLog>): Partial<CarrierWaveLog> {
    log.operation = "upload";
    log.storage = this.sample(SampleData.STORAGE_SERVICES);
    log.file_id = this.randomHex(10);
    log.filename = this.sample(SampleData.FILE_NAMES);
    log.mime_type = this.sample(SampleData.FILE_TYPES);
    log.size = this.randomInt(1000, 1000000);
    log.metadata = JSON.stringify({ width: 800, height: 600 });
    log.duration = this.randomDuration();
    log.uploader = "AvatarUploader";
    log.model = "User";
    log.mount_point = "avatar";
    log.data = {
      versions: ["thumb", "medium", "large"]
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
    const queueName = ["default", "critical", "low", "mailers"][
      this.randomInt(0, 3)
    ];
    const args = [
      this.randomInt(1, 100),
      { action: this.sample(["create", "update", "process"]) },
    ];

    // Enqueue event
    const enqueueLog: Partial<ActiveJobLog> = {
      timestamp: new Date().toISOString(),
      level: LogLevel.INFO,
      source: Source.JOB,
      event: LogEvent.ENQUEUE,
      job_id: jobId,
      job_class: jobClass,
      queue_name: queueName,
      arguments: args,
    };

    // Start event (happens a little later)
    const startTime = new Date(
      new Date(enqueueLog.timestamp as string).getTime() + this.randomInt(100, 5000)
    );
    const startLog: Partial<ActiveJobLog> = {
      timestamp: startTime.toISOString(),
      level: LogLevel.INFO,
      source: Source.JOB,
      event: LogEvent.START,
      job_id: jobId,
      job_class: jobClass,
      queue_name: queueName,
      arguments: args,
    };

    // Finish event (with duration)
    const duration = this.randomFloat(50, 2000);
    const finishTime = new Date(startTime.getTime() + duration);
    const finishLog: Partial<ActiveJobLog> = {
      timestamp: finishTime.toISOString(),
      level: LogLevel.INFO,
      source: Source.JOB,
      event: LogEvent.FINISH,
      job_id: jobId,
      job_class: jobClass,
      queue_name: queueName,
      arguments: args,
      duration: duration,
    };

    return [enqueueLog, startLog, finishLog];
  }
}
