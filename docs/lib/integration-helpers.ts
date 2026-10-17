import { Event, LogType } from '@/generated/logstruct';

// The title, description and details page of each log type's integration, for the integrations page
export function getLogTypeInfo(logType: LogType): {
  title: string;
  description: string;
  configuration_code?: string;
  preferredEvent?: Event;
  docsPath?: string;
} | null {
  switch (logType) {
    case LogType.PUMA:
      return {
        title: 'Puma (Server)',
        description:
          "Replaces Puma's boot and shutdown text with a start line (mode, Puma and Ruby versions, threads, environment and the addresses it listens on) and a shutdown line. An error Puma catches while handling a request (an exception the app didn't rescue, a malformed request, an SSL error) is an error line with the method and path, without the query string.",
        preferredEvent: Event.Start,
      };
    case LogType.AHOY:
      return {
        title: 'Ahoy',
        description:
          'Logs each event Ahoy tracks (Ahoy::Tracker#track) with its name and properties, as an app line whose msg is "ahoy.track".',
      };

    case LogType.ACTIVEMODELSERIALIZERS:
      return {
        title: 'ActiveModelSerializers',
        description:
          'Logs each ActiveModelSerializers render with the serializer, adapter, resource class and duration (msg "ams.render").',
      };
    case LogType.ACTIONMAILER:
      return {
        title: 'ActionMailer',
        description:
          "Logs each mail before it's sent (delivery) and after (delivered), with the mailer, the action and the record IDs you choose with actionmailer_id_mapping. A delivery error is an error line, and what happens next (raise, report, retry) follows error_handling_modes.",
        docsPath: '/docs/integrations/action-mailer',
      };

    case LogType.ACTIVEJOB:
      return {
        title: 'ActiveJob',
        description:
          'Logs a line when a job is enqueued, scheduled, started, finished, retried or discarded, and when it fails, with the job class, ID, queue and its filtered arguments. It works with any queue backend.',
        docsPath: '/docs/integrations/active-job',
      };

    case LogType.ACTIVESTORAGE:
      return {
        title: 'ActiveStorage',
        description:
          "Logs uploads, downloads, deletes and metadata updates with the service and the blob's key (not its filename), in place of Rails' own ActiveStorage lines. Existence checks and URLs are debug lines, as Rails logs them, and URL lines leave out the signed URL.",
      };

    case LogType.CARRIERWAVE:
      return {
        title: 'CarrierWave',
        description:
          'Logs a line when an uploader stores a file (upload), fetches a remote file (download) or removes one (delete), with the uploader, model, mount point, version and file details. Loading a stored file reads no data, and logs nothing.',
      };

    case LogType.REQUEST:
      return {
        title: 'Request Logs (via Lograge)',
        description:
          "Configures Lograge to write one line per request: the method, path, status, duration, controller and action, the filtered params, the client's IP and the host. Add fields of your own with lograge_custom_options.",
        configuration_code: 'lograge_custom_options',
      };

    case LogType.SECURITY:
      return {
        title: 'Security Logging',
        description:
          'Logs requests that HostAuthorization blocked, failed CSRF checks and IP spoofing attempts as security lines, and reports them according to error_handling_modes.security_errors.',
        docsPath: '/docs/integrations/security',
      };

    case LogType.SHRINE:
      return {
        title: 'Shrine',
        description:
          "Loads Shrine's instrumentation plugin and logs its upload, download, delete, metadata and exists operations with the storage, location and duration, and an upload's MIME type and size (not the file's original name), in place of Shrine's own text lines.",
      };

    case LogType.SIDEKIQ:
      return {
        title: 'Sidekiq',
        description:
          "Replaces Sidekiq's logger, so Sidekiq's lines are JSON too. Every line logged while a job runs has the job's jid and class in ctx, and a failed job is one warn line without its arguments.",
        docsPath: '/docs/integrations/sidekiq',
      };

    case LogType.GOODJOB:
      return {
        title: 'GoodJob',
        description:
          "Logs GoodJob's own messages and its thread errors as structured lines (GoodJob 3.0 or later). GoodJob's jobs are logged by the ActiveJob integration.",
        docsPath: '/docs/integrations/good-job',
      };

    case LogType.SQL:
      return {
        title: 'SQL (ActiveRecord) Logging',
        description:
          "Off by default. When on, logs each query that takes at least sql_slow_query_threshold, with the SQL, duration, row count, operation and tables, and the filtered bind values. Schema, cache and migration bookkeeping queries are skipped, and Rails' own SQL lines are turned off.",
        docsPath: '/docs/integrations/sql',
      };

    case LogType.DOTENV:
      return {
        title: 'Dotenv',
        description:
          "Turns dotenv-rails' load, update, save and restore messages into structured lines, with the names of the variables but not their values. Lines from before the logger is ready are kept and written once it is.",
        preferredEvent: Event.Update,
      };

    case LogType.ERROR:
      return {
        title: 'Error Handling',
        description:
          'An exception logged with Rails.logger.error(exception) or LogStruct.error, or handled by LogStruct, is an error line with its class, message and backtrace (up to max_backtrace_lines, default 20), and the request it happened in.',
        docsPath: '/docs/configuration#error-handling-configuration',
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
    case LogType.PUMA:
      return [Event.Start, Event.Shutdown, Event.Error];
    case LogType.REQUEST:
      return [Event.Request];
    case LogType.ACTIVEJOB:
      return [
        Event.Enqueue,
        Event.Schedule,
        Event.Start,
        Event.Finish,
        Event.Retry,
        Event.RetryStopped,
        Event.Discard,
        Event.Error,
      ];
    case LogType.PLAIN:
      return [Event.Log];
    case LogType.ERROR:
      return [Event.Error];
    case LogType.SECURITY:
      return [Event.BlockedHost, Event.CSRFViolation, Event.IPSpoof];
    case LogType.SHRINE:
      return [Event.Upload, Event.Download, Event.Delete, Event.Metadata, Event.Exist];
    case LogType.SIDEKIQ:
      return [Event.Log, Event.Error];
    case LogType.ACTIVESTORAGE:
      return [Event.Upload, Event.Download, Event.Delete, Event.Metadata, Event.Exist, Event.Url];
    case LogType.ACTIONMAILER:
      return [Event.Delivery, Event.Delivered, Event.Error];
    case LogType.CARRIERWAVE:
      return [Event.Upload, Event.Download, Event.Delete];
    case LogType.GOODJOB:
      return [Event.Error, Event.Log];
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
