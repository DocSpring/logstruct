/**
 * Log examples utility for documentation
 * Contains functions that generate sample logs for each integration
 */

import { LogGenerator } from './log-generator';
import { LogType, LogEvent, Source, LogLevel } from './log-types';

// Create a single instance of the log generator with a fixed seed for consistency
const logGenerator = new LogGenerator(12345);

// Function to get formatted JSON log examples
function formatLog(log: Record<string, any>): string {
  return JSON.stringify(log, null, 2);
}

// Create sample logs for different integration types
export function getActionMailerDeliverLog(): string {
  const log = logGenerator.generateTypedLog(LogType.ACTIONMAILER);
  log.source = Source.MAILER;
  log.event = LogEvent.DELIVERED;
  log.level = LogLevel.INFO;
  
  const transformed = logGenerator.transformLog({
    ...log,
    timestamp: "2023-09-15T12:34:56.789Z",
  });

  return formatLog(transformed);
}

export function getActionMailerErrorLog(): string {
  const log = logGenerator.generateTypedLog(LogType.ACTIONMAILER);
  log.source = Source.MAILER;
  log.event = LogEvent.ERROR;
  log.level = LogLevel.ERROR;
  
  const transformed = logGenerator.transformLog({
    ...log,
    timestamp: "2023-09-15T12:34:56.789Z",
  });
  
  // Add specific error details
  transformed.error = "SMTP connection failed";
  transformed.message = "Failed to connect to SMTP server";
  transformed.backtrace = ["app/mailers/notification_mailer.rb:25:in 'weekly_digest'", "..."];
  
  return formatLog(transformed);
}

export function getActiveJobLog(): string {
  const log = logGenerator.generateTypedLog(LogType.ACTIVEJOB);
  log.source = Source.JOB;
  log.event = LogEvent.FINISH;
  log.level = LogLevel.INFO;
  
  const transformed = logGenerator.transformLog({
    ...log,
    timestamp: "2023-09-15T12:34:56.789Z",
  });
  
  return formatLog(transformed);
}

export function getSidekiqProcessLog(): string {
  const log = logGenerator.generateTypedLog(LogType.SIDEKIQ);
  log.source = Source.SIDEKIQ;
  log.event = LogEvent.FINISH;
  log.level = LogLevel.INFO;
  
  const transformed = logGenerator.transformLog({
    ...log,
    timestamp: "2023-09-15T12:34:56.789Z",
  });
  
  return formatLog(transformed);
}

export function getSidekiqErrorLog(): string {
  const log = logGenerator.generateTypedLog(LogType.SIDEKIQ);
  log.source = Source.SIDEKIQ;
  log.event = LogEvent.ERROR;
  log.level = LogLevel.ERROR;
  
  const transformed = logGenerator.transformLog({
    ...log,
    timestamp: "2023-09-15T12:34:56.789Z",
  });
  
  // Add specific error details
  transformed.error = "NoMethodError";
  transformed.message = "undefined method 'import_data' for nil:NilClass";
  transformed.backtrace = ["app/jobs/import_job.rb:25:in 'perform'", "..."];
  transformed.retry_count = 2;
  transformed.retry = true;
  
  return formatLog(transformed);
}

export function getIPSpoofLog(): string {
  const log = logGenerator.generateTypedLog(LogType.SECURITY);
  log.source = Source.SECURITY;
  log.event = LogEvent.IP_SPOOF;
  log.level = LogLevel.ERROR;
  
  const transformed = logGenerator.transformLog({
    ...log,
    timestamp: "2023-09-15T12:34:56.789Z",
  });
  
  transformed.message = "IP spoofing attack detected";
  transformed.client_ip = "192.168.1.1";
  transformed.x_forwarded_for = "10.0.0.1, 172.16.0.1";
  
  return formatLog(transformed);
}

export function getCSRFViolationLog(): string {
  const log = logGenerator.generateTypedLog(LogType.SECURITY);
  log.source = Source.SECURITY;
  log.event = LogEvent.CSRF_VIOLATION;
  log.level = LogLevel.ERROR;
  
  const transformed = logGenerator.transformLog({
    ...log,
    timestamp: "2023-09-15T12:34:56.789Z",
  });
  
  transformed.message = "CSRF token verification failed";
  transformed.controller = "UsersController";
  transformed.action = "update";
  transformed.path = "/users/123";
  transformed.method = "POST";
  
  return formatLog(transformed);
}

export function getBlockedHostLog(): string {
  const log = logGenerator.generateTypedLog(LogType.SECURITY);
  log.source = Source.SECURITY;
  log.event = LogEvent.BLOCKED_HOST;
  log.level = LogLevel.ERROR;
  
  const transformed = logGenerator.transformLog({
    ...log,
    timestamp: "2023-09-15T12:34:56.789Z",
  });
  
  transformed.message = "Blocked host attempt";
  transformed.blocked_host = "malicious-site.com";
  transformed.allowed_hosts = ["example.com", "api.example.com"];
  
  return formatLog(transformed);
}

export function getGeneralExceptionLog(): string {
  const log = logGenerator.generateTypedLog(LogType.ERROR);
  log.source = Source.REQUEST;
  log.event = LogEvent.ERROR;
  log.level = LogLevel.ERROR;
  
  const transformed = logGenerator.transformLog({
    ...log,
    timestamp: "2023-09-15T12:34:56.789Z",
  });
  
  transformed.message = "Error during request processing";
  transformed.error = "ActiveRecord::RecordNotFound";
  transformed.path = "/api/users/999";
  transformed.method = "GET";
  transformed.controller = "Api::UsersController";
  transformed.action = "show";
  transformed.backtrace = [
    "app/controllers/api/users_controller.rb:25:in `show'",
    "..."
  ];
  
  return formatLog(transformed);
}

export function getHostAuthorizationLog(): string {
  const log = logGenerator.generateTypedLog(LogType.SECURITY);
  log.source = Source.SECURITY;
  log.event = LogEvent.BLOCKED_HOST;
  log.level = LogLevel.ERROR;
  
  const transformed = logGenerator.transformLog({
    ...log,
    timestamp: "2023-09-15T12:34:56.789Z",
  });
  
  transformed.blocked_host = "malicious-site.com";
  transformed.message = "Blocked host: malicious-site.com";
  
  return formatLog(transformed);
}

export function getLogRageLog(): string {
  const log = logGenerator.generateTypedLog(LogType.REQUEST);
  log.source = Source.REQUEST;
  log.event = LogEvent.REQUEST;
  log.level = LogLevel.INFO;
  
  const transformed = logGenerator.transformLog({
    ...log,
    timestamp: "2023-09-15T12:34:56.789Z",
  });
  
  return formatLog(transformed);
}

export function getShrineLog(): string {
  const log = logGenerator.generateTypedLog(LogType.SHRINE);
  log.source = Source.SHRINE;
  log.event = LogEvent.UPLOAD;
  log.level = LogLevel.INFO;
  
  const transformed = logGenerator.transformLog({
    ...log,
    timestamp: "2023-09-15T12:34:56.789Z",
  });
  
  return formatLog(transformed);
}

export function getCarrierWaveLog(): string {
  const log = logGenerator.generateTypedLog(LogType.CARRIERWAVE);
  log.source = Source.CARRIERWAVE;
  log.event = LogEvent.UPLOAD;
  log.level = LogLevel.INFO;
  
  const transformed = logGenerator.transformLog({
    ...log,
    timestamp: "2023-09-15T12:34:56.789Z",
  });
  
  return formatLog(transformed);
}

export function getActiveStorageLog(): string {
  const log = logGenerator.generateTypedLog(LogType.ACTIVESTORAGE);
  log.source = Source.STORAGE;
  log.event = LogEvent.UPLOAD;
  log.level = LogLevel.INFO;
  
  const transformed = logGenerator.transformLog({
    ...log,
    timestamp: "2023-09-15T12:34:56.789Z",
  });
  
  return formatLog(transformed);
}