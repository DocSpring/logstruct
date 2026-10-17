/**
 * Descriptions for each LogStruct log structure
 * These are used in the documentation to explain what each log structure is for
 */
export const LOG_STRUCTURE_DESCRIPTIONS: Record<string, string> = {
  Plain: 'For general purpose logging',
  Request: 'For HTTP request details',
  Error: 'For exception details with stack traces',
  ActionMailer: 'For email delivery events',
  Delivered: 'Logged after a mail is delivered (after_deliver), unless the delivery failed',
  Delivery: 'Logged before a mail is sent (before_deliver)',
  ActiveJob: "For ActiveJob's enqueue, start, finish, retry and error events",
  Enqueue: 'ActiveJob enqueued a job to run now (perform_later or perform_all_later)',
  Finish: 'A job finished without raising an exception (ActiveJob)',
  Schedule: 'ActiveJob enqueued a job to run later (perform_later with wait or wait_until)',
  Start: 'Lifecycle start event for jobs or services (ActiveJob or Puma boot)',
  Retry: "retry_on caught a job's exception and enqueued the job again (ActiveJob)",
  RetryStopped: "retry_on caught a job's exception after the job's last attempt (ActiveJob)",
  Discard: "discard_on caught a job's exception and dropped the job (ActiveJob)",
  ActiveStorage: 'For file storage operations',
  Delete: 'A stored file was deleted (ActiveStorage, CarrierWave, or Shrine)',
  Download:
    'A stored file was read (ActiveStorage or Shrine), or CarrierWave fetched a remote URL into its cache',
  Exist: 'Existence check for a stored file (ActiveStorage or Shrine)',
  Metadata: "ActiveStorage updated a stored file's metadata, or Shrine extracted a file's metadata",
  Upload: 'A file was stored (ActiveStorage, CarrierWave, or Shrine)',
  Url: 'ActiveStorage generated a URL for a stored file (the URL itself is not logged)',
  Shrine:
    "For Shrine's file operations: uploads, downloads, deletes, metadata and existence checks",
  CarrierWave: "For CarrierWave's file operations: stores, deletes and remote downloads",
  Sidekiq: "For Sidekiq's own log lines and failed jobs",
  Security: 'For security-related events',
  BlockedHost:
    'Request blocked by ActionDispatch::HostAuthorization (host not on the allowed list)',
  CSRFViolation: 'Request rejected due to a CSRF token violation',
  IPSpoof:
    "Rails raised IpSpoofAttackError where the app read request.remote_ip (the Client-IP header isn't in X-Forwarded-For)",
  GoodJob: "For GoodJob's own log lines and thread errors",
  Log: "A log line: a plain message, or a line from GoodJob's or Sidekiq's own logger",
  SQL: 'For ActiveRecord SQL queries slower than sql_slow_query_threshold (100 ms by default)',
  ActiveModelSerializers:
    'For render events produced by ActiveModelSerializers (serializer, adapter, resource, duration)',
  Ahoy: 'One line for each Ahoy::Tracker#track call, with the event name and its properties',
  Dotenv:
    'For dotenv-rails configuration events during boot (load/update/save/restore of env files and variables)',
  Load: 'dotenv-rails load event when environment variables are read from disk',
  Restore: 'dotenv-rails restore event rolling back to the last saved state',
  Save: 'dotenv-rails save event persisting environment variables',
  Update: 'dotenv-rails update event after manipulating environment values',
  Puma: 'For Puma server lifecycle events and request errors',
  Shutdown: 'Puma server shutdown event',
};

/**
 * Get the description for a log structure
 * @param structName The name of the log structure (e.g., "Plain", "Request")
 * @returns The description of the log structure
 * @throws Error if no description is found for the structure
 */
export function getLogStructureDescription(structName: string): string {
  const description = LOG_STRUCTURE_DESCRIPTIONS[structName];
  if (!description) {
    throw new Error(
      `No description found for log structure: ${structName}. ` +
        'Add it to lib/log-structure-descriptions.ts',
    );
  }
  return description;
}
