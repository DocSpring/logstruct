/**
 * Descriptions for each LogStruct enum class
 * These are used in the documentation to explain what each enum is for
 */
export const ENUM_DESCRIPTIONS: Record<string, string> = {
  'LogStruct::Level': 'Log severity levels for different types of log messages',
  'LogStruct::Source':
    'Sources of log messages to identify which part of the system generated them',
  'LogStruct::Event': 'Event types for different kinds of operations and activities',
  'LogStruct::ErrorHandlingMode': 'Error handling strategies for different types of errors',
};

/**
 * Get the description for an enum class
 * @param enumName The full name of the enum class (e.g., "LogStruct::Level")
 * @returns The description of the enum
 * @throws Error if no description is found for the enum
 */
export function getEnumDescription(enumName: string): string {
  const description = ENUM_DESCRIPTIONS[enumName];
  if (!description) {
    throw new Error(
      `No description found for enum: ${enumName}. Add it to lib/enum-descriptions.ts`,
    );
  }
  return description;
}

/**
 * Value descriptions for specific enum values
 * These provide context for what each enum value means
 */
export const ENUM_VALUE_DESCRIPTIONS: Record<string, Record<string, string>> = {
  'LogStruct::Level': {
    Debug: 'Detailed debugging information',
    Info: 'General informational messages',
    Warn: 'Warning conditions that should be noted',
    Error: 'Error conditions that affect operation',
    Fatal: 'Severe error conditions that cause the application to terminate',
    Unknown: 'Used when a log level cannot be determined',
  },
  'LogStruct::Source': {
    Rails: 'Core Rails framework components',
    App: 'Application-specific code',
    Job: 'Background job processing',
    Mailer: 'Email delivery and processing',
    Security: 'Security-related events and checks',
    TypeChecking: 'Type checking errors (Sorbet)',
    Internal: 'Errors from LogStruct itself',
    Storage: 'ActiveStorage logs and errors',
    Shrine: 'Shrine file operations (uploads, downloads, deletes, metadata, existence checks)',
    CarrierWave: 'CarrierWave file operations (stores, deletes, remote downloads)',
    Sidekiq: 'Sidekiq background job logs and errors',
    Dotenv: 'Dotenv-rails configuration events (env file load/update/save/restore)',
    Puma: 'Puma server lifecycle events and request errors',
  },
  'LogStruct::ErrorHandlingMode': {
    Ignore: 'Completely ignore errors',
    Log: "Log errors but don't report them",
    LogProduction:
      'Raise in local_environments (development and test by default), log everywhere else',
    Report: 'Log and report errors to error service',
    ReportProduction:
      'Raise in local_environments (development and test by default), log and report everywhere else',
    Raise: 'Raise the error, without logging or reporting it',
  },
  'LogStruct::Event': {
    Shutdown: 'Server shutting down',
    Log: 'Standard log message',
    Request: 'HTTP request',
    Database: 'Database query event and metrics',
    Generate: 'Serialization/render event (ActiveModelSerializers)',
    Enqueue: 'Job added to queue',
    Schedule: 'Job scheduled for future processing',
    Start: 'Job processing started, or server started',
    Finish: 'Job processing completed',
    Retry: 'Job enqueued again by retry_on after an exception',
    RetryStopped: 'retry_on stopped retrying a job after its last attempt',
    Discard: 'Job dropped by discard_on after an exception',
    Load: 'Configuration load operation (e.g., dotenv file loaded)',
    Update: 'Configuration update operation (e.g., env var set)',
    Save: 'Configuration state saved (e.g., snapshot)',
    Restore: 'Configuration state restored (e.g., snapshot restored)',
    Upload: 'File upload operation',
    Download: 'File download operation',
    Delete: 'File deletion operation',
    Metadata: 'File metadata operation',
    Exist: 'File existence check operation',
    Url: 'File URL generation operation',
    Delivery: 'Email about to be sent (before_deliver)',
    Delivered: 'Email delivered (after_deliver)',
    IPSpoof: 'Rails raised IpSpoofAttackError when the app read request.remote_ip',
    CSRFViolation: 'Cross-Site Request Forgery violation',
    BlockedHost: 'Request blocked by ActionDispatch::HostAuthorization',
    Error: 'Error occurrence',
    Unknown: 'Unclassified event type',
  },
};

/**
 * Get the description for a specific enum value
 * @param enumName The full name of the enum class (e.g., "LogStruct::Level")
 * @param valueName The name of the enum value (e.g., "Debug")
 * @returns The description of the enum value
 * @throws Error if no description is found for the enum value
 */
export function getEnumValueDescription(enumName: string, valueName: string): string {
  const enumValues = ENUM_VALUE_DESCRIPTIONS[enumName];
  if (!enumValues) {
    throw new Error(`No values found for enum: ${enumName}`);
  }

  const description = enumValues[valueName];
  if (!description) {
    throw new Error(
      `No description found for enum value: ${enumName}::${valueName}. ` +
        'Add it to lib/enum-descriptions.ts',
    );
  }

  return description;
}
