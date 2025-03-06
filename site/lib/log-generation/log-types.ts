/* eslint-disable @typescript-eslint/no-explicit-any */
// Auto-generated TypeScript definitions for LogStruct
// Generated on 2025-03-06 15:05:27

// Enum types
export enum LogLevel {
  DEBUG = "debug",
  INFO = "info",
  WARN = "warn",
  ERROR = "error",
  FATAL = "fatal",
  UNKNOWN = "unknown",
}

export enum Source {
  TYPE_CHECKING = "type_checking",
  LOGSTRUCT = "logstruct",
  SECURITY = "security",
  REQUEST = "request",
  JOB = "job",
  STORAGE = "storage",
  MAILER = "mailer",
  APP = "app",
  SHRINE = "shrine",
  CARRIERWAVE = "carrierwave",
  SIDEKIQ = "sidekiq",
}

export enum LogEvent {
  LOG = "log",
  REQUEST = "request",
  ENQUEUE = "enqueue",
  SCHEDULE = "schedule",
  START = "start",
  FINISH = "finish",
  UPLOAD = "upload",
  DOWNLOAD = "download",
  DELETE = "delete",
  METADATA = "metadata",
  EXIST = "exist",
  STREAM = "stream",
  URL = "url",
  DELIVERY = "delivery",
  DELIVERED = "delivered",
  IP_SPOOF = "ip_spoof",
  CSRF_VIOLATION = "csrf_violation",
  BLOCKED_HOST = "blocked_host",
  ERROR = "error",
  UNKNOWN = "unknown",
}

// Log Types
export enum LogType {
  SIDEKIQ = "Sidekiq",
  SHRINE = "Shrine",
  SECURITY = "Security",
  REQUEST = "Request",
  PLAIN = "Plain",
  ERROR = "Error",
  ACTIVEJOB = "ActiveJob",
  ACTIVESTORAGE = "ActiveStorage",
  ACTIONMAILER = "ActionMailer",
  CARRIERWAVE = "CarrierWave",
}

// Log Interfaces
export interface SidekiqLog {
  source: Source;
  event: LogEvent;
  timestamp: string;
  level: LogLevel;
  process_id: number;
  thread_id: string;
  message: string;
  context: Record<string, any>;
}

export interface ShrineLog {
  source: Source;
  event: LogEvent;
  timestamp: string;
  level: LogLevel;
  msg: string;
  storage: string;
  location: string;
  upload_options: Record<string, any>;
  download_options: Record<string, any>;
  options: Record<string, any>;
  uploader: string;
  duration: number;
  data: Record<string, any>;
}

export interface SecurityLog {
  source: Source;
  event: LogEvent;
  timestamp: string;
  level: LogLevel;
  message: string;
  blocked_host: string;
  blocked_hosts: string[];
  client_ip: string;
  x_forwarded_for: string;
  data: Record<string, any>;
  path: string;
  http_method: string;
  source_ip: string;
  user_agent: string;
  referer: string;
  request_id: string;
}

export interface RequestLog {
  source: Source;
  event: LogEvent;
  timestamp: string;
  level: LogLevel;
  method: string;
  path: string;
  format: string;
  controller: string;
  action: string;
  status: number;
  duration: number;
  view: number;
  db: number;
  params: Record<string, any>;
  source_ip: string;
  user_agent: string;
  referer: string;
  request_id: string;
}

export interface PlainLog {
  source: Source;
  event: LogEvent;
  timestamp: string;
  level: LogLevel;
  message: any[];
}

export interface ErrorLog {
  source: Source;
  event: LogEvent;
  timestamp: string;
  level: LogLevel;
  err_class: any;
  message: string;
  backtrace: string[];
  data: Record<string, any>;
}

export interface ActiveJobLog {
  source: Source;
  event: LogEvent;
  timestamp: string;
  level: LogLevel;
  job_id: string;
  job_class: string;
  queue_name: string;
  arguments: any[];
  duration: number;
  data: Record<string, any>;
}

export interface ActiveStorageLog {
  source: Source;
  event: LogEvent;
  timestamp: string;
  level: LogLevel;
  operation: any;
  storage: string;
  file_id: string;
  filename: string;
  mime_type: string;
  size: number;
  metadata: string;
  duration: number;
  checksum: string;
  exist: boolean;
  url: string;
  prefix: string;
  range: string;
}

export interface ActionMailerLog {
  source: Source;
  event: LogEvent;
  timestamp: string;
  level: LogLevel;
  to: any[];
  from: string;
  subject: string;
  data: Record<string, any>;
}

export interface CarrierWaveLog {
  source: Source;
  event: LogEvent;
  timestamp: string;
  level: LogLevel;
  operation: any;
  storage: string;
  file_id: string;
  filename: string;
  mime_type: string;
  size: number;
  metadata: string;
  duration: number;
  uploader: string;
  model: string;
  mount_point: string;
  data: Record<string, any>;
}

// Union type for all logs
export type Log =
  | SidekiqLog
  | ShrineLog
  | SecurityLog
  | RequestLog
  | PlainLog
  | ErrorLog
  | ActiveJobLog
  | ActiveStorageLog
  | ActionMailerLog
  | CarrierWaveLog
;