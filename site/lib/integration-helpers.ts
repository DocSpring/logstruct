import { LogType } from '@/lib/log-generation/log-types';

// Generate information for each log type (extracted from integrations/page.tsx)
export function getLogTypeInfo(logType: LogType): {
  title: string;
  description: string;
  configuration_code?: string;
} | null {
  switch (logType) {
    case LogType.ACTIONMAILER:
      return {
        title: 'ActionMailer Integration',
        description:
          'The ActionMailer integration automatically logs email delivery events and handles errors during email delivery.',
      };

    case LogType.ACTIVEJOB:
      return {
        title: 'ActiveJob Integration',
        description:
          'The ActiveJob integration logs job enqueuing, execution, and completion events with detailed information about the job.',
      };

    case LogType.ACTIVESTORAGE:
      return {
        title: 'ActiveStorage Integration',
        description:
          'The ActiveStorage integration logs uploads, downloads, deletes, and other file operations with detailed information about the file and storage service.',
      };

    case LogType.CARRIERWAVE:
      return {
        title: 'CarrierWave Integration',
        description:
          'The CarrierWave integration adds structured logging for file upload operations, including file metadata and operation duration.',
      };

    case LogType.REQUEST:
      return {
        title: 'Request Logs (via Lograge)',
        description:
          'LogStruct configures Lograge to output request logs in a structured JSON format compatible with the rest of your logs.',
        configuration_code: 'lograge_custom_options',
      };

    case LogType.SECURITY:
      return {
        title: 'Security Logging',
        description:
          'LogStruct includes security-focused logging for Rails applications.',
      };

    case LogType.SHRINE:
      return {
        title: 'Shrine Integration',
        description:
          'The Shrine integration adds structured logging for file uploads and other Shrine operations, including file metadata and operation duration.',
      };

    case LogType.SIDEKIQ:
      return {
        title: 'Sidekiq Integration',
        description:
          'The Sidekiq integration configures structured JSON logging for Sidekiq worker and client logs, maintaining consistent format with other logs.',
      };

    case LogType.ERROR:
      return {
        title: 'Error Handling',
        description:
          'LogStruct provides structured error logging across your application, capturing error class, message, backtrace, and contextual data for better debugging.',
      };

    case LogType.PLAIN:
      // Plain logs are not an integration
      return null;

    default:
      return null;
  }
}

export function getTitleId(title: string): string {
  return title
    .toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/[^a-z0-9-]/g, '');
}
