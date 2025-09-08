/**
 * Descriptions for each LogStruct log structure
 * These are used in the documentation to explain what each log structure is for
 */
export const LOG_STRUCTURE_DESCRIPTIONS: Record<string, string> = {
  Plain: 'For general purpose logging',
  Request: 'For HTTP request details',
  Error: 'For exception details with stack traces',
  ActionMailer: 'For email delivery events',
  ActiveJob: 'For background job execution',
  ActiveStorage: 'For file storage operations',
  Shrine: 'For Shrine file upload events',
  CarrierWave: 'For CarrierWave upload events',
  Sidekiq: 'For Sidekiq job processing',
  Security: 'For security-related events',
  GoodJob: 'For GoodJob background job lifecycle events',
  SQL: 'For ActiveRecord SQL query events and performance metrics',
  ActiveModelSerializers:
    'For render events produced by ActiveModelSerializers (serializer, adapter, resource, duration)',
  Ahoy: 'For analytics tracking events emitted by Ahoy (event name and properties)',
  Dotenv:
    'For dotenv-rails configuration events during boot (load/update/save/restore of env files and variables)',
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
    throw new Error(`No description found for log structure: ${structName}`);
  }
  return description;
}
