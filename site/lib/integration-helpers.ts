import { Event, LogType } from '@/generated/logstruct';

// Generate information for each log type (extracted from integrations/page.tsx)
export function getLogTypeInfo(logType: LogType): {
  title: string;
  description: string;
  configuration_code?: string;
  preferredEvent?: Event;
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

    case LogType.DOTENV:
      return {
        title: 'Dotenv',
        description:
          'Converts dotenv-rails boot messages (load/update/save/restore) into structured JSON. Early boot events are buffered and emitted once configuration is loaded.',
        preferredEvent: Event.Update,
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
      // Ensure we have an exhaustive switch statement
      logType satisfies never;
      throw new Error(`Unhandled log type: ${logType}`);
  }
}

// Events to showcase for each log type (used for example tabs)
export function getEventsForLogType(logType: LogType): Event[] {
  switch (logType) {
    case LogType.REQUEST:
      return [Event.Request];
    case LogType.ACTIVEJOB:
      return [Event.Enqueue, Event.Schedule, Event.Start, Event.Finish];
    case LogType.PLAIN:
      return [Event.Log];
    case LogType.ERROR:
      return [Event.Error];
    case LogType.SECURITY:
      return [Event.BlockedHost, Event.CSRFViolation, Event.IPSpoof];
    case LogType.SHRINE:
      return [Event.Upload, Event.Download, Event.Delete];
    case LogType.SIDEKIQ:
      return [Event.Log];
    case LogType.ACTIVESTORAGE:
      return [
        Event.Upload,
        Event.Download,
        Event.Delete,
        Event.Metadata,
        Event.Exist,
        Event.Url,
      ];
    case LogType.ACTIONMAILER:
      return [Event.Delivery, Event.Delivered];
    case LogType.CARRIERWAVE:
      return [Event.Upload, Event.Delete];
    case LogType.GOODJOB:
      return [Event.Enqueue, Event.Start, Event.Finish, Event.Error, Event.Log];
    case LogType.SQL:
      return [Event.Database];
    case LogType.ACTIVEMODELSERIALIZERS:
      return [Event.Generate];
    case LogType.AHOY:
      return [Event.Log];
    case LogType.DOTENV:
      return [Event.Update, Event.Load, Event.Save, Event.Restore];
    default:
      logType satisfies never;
      return [Event.Log];
  }
}

export function getTitleId(title: string): string {
  return title
    .toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/[^a-z0-9-]/g, '');
}
