import { LogType } from '@/lib/log-generation/log-types';

// Generate information for each log type (extracted from integrations/page.tsx)
export function getLogTypeInfo(logType: LogType): {
  title: string;
  description: string;
  configuration_code?: string;
} | null {
  switch (logType) {
    case LogType.AHOY:
      return {
        title: 'Ahoy',
        description:
          'Emits structured logs for analytics events tracked via Ahoy::Tracker#track (message: "ahoy.track").',
      };

    case LogType.ACTIVEMODELSERIALIZERS:
      return {
        title: 'ActiveModelSerializers',
        description:
          'Subscribes to *.active_model_serializers notifications and logs serializer, adapter, resource class, and duration (message: "ams.render").',
      };
    case LogType.ACTIONMAILER:
      return {
        title: 'ActionMailer',
        description:
          'The ActionMailer integration automatically logs email delivery events and handles errors during email delivery.',
      };

    case LogType.ACTIVEJOB:
      return {
        title: 'ActiveJob',
        description:
          'The ActiveJob integration logs job enqueuing, execution, and completion events with detailed information about the job.',
      };

    case LogType.ACTIVESTORAGE:
      return {
        title: 'ActiveStorage',
        description:
          'The ActiveStorage integration logs uploads, downloads, deletes, and other file operations with detailed information about the file and storage service.',
      };

    case LogType.CARRIERWAVE:
      return {
        title: 'CarrierWave',
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
        title: 'Shrine',
        description:
          'The Shrine integration adds structured logging for file uploads and other Shrine operations, including file metadata and operation duration.',
      };

    case LogType.SIDEKIQ:
      return {
        title: 'Sidekiq',
        description:
          'The Sidekiq integration configures structured JSON logging for Sidekiq worker and client logs, maintaining consistent format with other logs.',
      };

    case LogType.GOODJOB:
      return {
        title: 'GoodJob',
        description:
          'The GoodJob integration logs job lifecycle events (enqueue, start, finish, error) with execution context and performance metrics.',
      };

    case LogType.SQL:
      return {
        title: 'SQL (ActiveRecord) Logging',
        description:
          'Captures ActiveRecord SQL queries with duration, operation type, table names, and optional bind parameters, with smart filtering of noisy queries.',
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

// Additional integrations not represented as LogType entries but supported by the gem.
// Centralize their titles/descriptions here to keep docs consistent.
export type ExtraIntegration = {
  id: string; // stable anchor/id
  title: string;
  description: string;
  configuration_code?: string;
};

export const AdditionalIntegrations: ExtraIntegration[] = [
  {
    id: 'ahoy',
    title: 'Ahoy',
    description:
      'When ahoy_matey is present, LogStruct emits lightweight structured logs for analytics events tracked via Ahoy::Tracker#track. Toggle with config.integrations.enable_ahoy.',
    configuration_code: 'integrations_configuration',
  },
  {
    id: 'active-model-serializers',
    title: 'ActiveModelSerializers',
    description:
      'If ActiveModelSerializers is present, LogStruct subscribes to *.active_model_serializers notifications and logs serializer name, adapter, resource class, and render duration. Toggle with config.integrations.enable_active_model_serializers.',
    configuration_code: 'integrations_configuration',
  },
];
