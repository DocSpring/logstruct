/**
 * Descriptions for each LogStruct log structure
 * These are used in the documentation to explain what each log structure is for
 */
export const LOG_STRUCTURE_DESCRIPTIONS: Record<string, string> = {
  Plain: 'For general purpose logging',
  Request: 'For HTTP request details',
  Error: 'For exception details with stack traces',
  ActionMailer: 'For email delivery events',
  Delivered: 'ActionMailer callback emitted after a message is delivered',
  Delivery: 'ActionMailer event capturing when a mailer sends a message',
  ActiveJob: 'For background job execution',
  Enqueue: 'Background job enqueued event (ActiveJob or GoodJob scheduling a job for execution)',
  Finish: 'Background job completion event indicating success (ActiveJob/GoodJob)',
  Schedule:
    'Deferred background job scheduling event (ActiveJob or GoodJob scheduling with a run_at time)',
  Start: 'Lifecycle start event for jobs or services (ActiveJob, GoodJob, or Puma boot)',
  ActiveStorage: 'For file storage operations',
  Delete: 'Deletion of a persisted attachment (ActiveStorage, CarrierWave, or Shrine)',
  Download: 'File download event (ActiveStorage, CarrierWave, or Shrine)',
  Exist: 'Existence check for a stored file (ActiveStorage or Shrine)',
  Metadata: 'Metadata read or write against a stored file (ActiveStorage or Shrine)',
  Stream: 'Streaming read of stored file contents (ActiveStorage)',
  Upload: 'File upload event (ActiveStorage, CarrierWave, or Shrine)',
  Url: 'URL generation event for a stored file (ActiveStorage)',
  Shrine: 'For Shrine file upload events',
  CarrierWave: 'For CarrierWave upload events',
  Sidekiq: 'For Sidekiq job processing',
  Security: 'For security-related events',
  BlockedHost:
    'Request blocked by ActionDispatch::HostAuthorization (host not on the allowed list)',
  CSRFViolation: 'Request rejected due to a CSRF token violation',
  IPSpoof: 'Request rejected because the IP address spoofing check failed',
  GoodJob: 'For GoodJob background job lifecycle events',
  Log: 'Structured GoodJob log output captured from the worker process',
  SQL: 'For ActiveRecord SQL query events and performance metrics',
  ActiveModelSerializers:
    'For render events produced by ActiveModelSerializers (serializer, adapter, resource, duration)',
  Ahoy: 'For analytics tracking events emitted by Ahoy (event name and properties)',
  Dotenv:
    'For dotenv-rails configuration events during boot (load/update/save/restore of env files and variables)',
  Load: 'dotenv-rails load event when environment variables are read from disk',
  Restore: 'dotenv-rails restore event rolling back to the last saved state',
  Save: 'dotenv-rails save event persisting environment variables',
  Update: 'dotenv-rails update event after manipulating environment values',
  Puma: 'For Puma server lifecycle events',
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
