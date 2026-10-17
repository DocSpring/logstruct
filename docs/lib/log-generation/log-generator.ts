import {
  ActionMailer,
  ActiveJob,
  ActiveModelSerializers,
  ActiveStorage,
  Ahoy,
  Carrierwave,
  Dotenv,
  Error as ErrorNs,
  Event,
  GoodJob,
  Level,
  LogType,
  Plain,
  Puma,
  Request,
  Security,
  Shrine,
  Sidekiq,
  Source,
  Sql,
} from '@/generated/logstruct';
import { processValues } from './formatter';
import { railsFilterParameters } from './param-filters';
import { RandomDataGenerator } from './random-data-generator';
import { isoAt, SampleData, withClock } from './sample-data';

type JsonRecord = Record<string, unknown>;

/** The keys LogStruct adds after a line's own fields (Formatter#add_metadata) */
interface LineContext {
  /** The logger's name (prog) */
  prog?: string;
  /** Logged during a request, so the line has the request's ID (req_id) */
  request?: boolean;
  /** Logged during a Sidekiq job, whose ID and class go in ctx */
  sidekiqJob?: SidekiqJob;
  /** A logged Hash, whose own keys come before src, evt, ts and lvl */
  hash?: boolean;
}

interface SidekiqJob {
  jid: string;
  class: string;
}

interface JobFields {
  job_id: string;
  job_class: string;
  queue_name: string;
  arguments: unknown[];
  provider_job_id: string;
}

const IMPORT_ERRORS: Array<[string, string]> = [
  ['JSON::ParserError', 'unexpected end of input'],
  ['CSV::MalformedCSVError', 'Unclosed quoted field in line 14.'],
  ['Date::Error', 'invalid date'],
];

interface RequestScenario {
  http_method: string;
  path: string;
  format: string;
  controller: string;
  action: string;
  status: number;
  params: Record<string, unknown>;
}

/**
 * Example lines for the docs, shaped like the ones LogStruct writes: the same keys, levels and value
 * types, with LogStruct's default filtering and scrubbing applied (unless filtering is off)
 */
export class LogGenerator extends RandomDataGenerator {
  private filterEnabled: boolean;

  constructor(seed?: number, filtering: boolean = true, now?: number) {
    super(seed, now);
    this.filterEnabled = filtering;
  }

  setFiltering(enabled: boolean) {
    this.filterEnabled = enabled;
  }

  generateLog(logType: LogType): JsonRecord {
    return this.generateLogWithOptions(logType, {});
  }

  generateLogWithOptions(
    logType: LogType,
    opts: { preferredEvent?: Event; filtering?: boolean } = {},
  ): JsonRecord {
    const evt = opts.preferredEvent;
    const filtering = opts.filtering ?? this.filterEnabled;
    // Lines built without a timestamp get this generator's time
    const line = withClock(
      () => this.nowMs(),
      () => this.buildLine(logType, evt),
    );
    return filtering ? (processValues(line) as JsonRecord) : line;
  }

  private buildLine(logType: LogType, evt: Event | undefined): JsonRecord {
    switch (logType) {
      case LogType.REQUEST:
        return this.requestLine();
      case LogType.ACTIVEJOB:
        return this.activeJobLine(
          evt ??
            this.sample([
              Event.Enqueue,
              Event.Schedule,
              Event.Start,
              Event.Finish,
              Event.Retry,
              Event.Error,
            ]),
        );
      case LogType.PLAIN:
        return this.plainLine();
      case LogType.ERROR:
        return this.errorLine();
      case LogType.SECURITY:
        return this.securityLine(
          evt ?? this.sample([Event.BlockedHost, Event.CSRFViolation, Event.IPSpoof]),
        );
      case LogType.SHRINE:
        return this.shrineLine(evt ?? this.sample([Event.Upload, Event.Download, Event.Delete]));
      case LogType.SIDEKIQ:
        return this.sidekiqLine(evt ?? this.sample([Event.Log, Event.Log, Event.Error]));
      case LogType.ACTIVESTORAGE:
        return this.activeStorageLine(
          evt ??
            this.sample([
              Event.Upload,
              Event.Download,
              Event.Delete,
              Event.Metadata,
              Event.Exist,
              Event.Url,
            ]),
        );
      case LogType.ACTIONMAILER:
        return this.actionMailerLine(
          evt ?? this.sample([Event.Delivery, Event.Delivered, Event.Error]),
        );
      case LogType.CARRIERWAVE:
        return this.carrierWaveLine(
          evt ?? this.sample([Event.Upload, Event.Download, Event.Delete]),
        );
      case LogType.GOODJOB:
        return this.goodJobLine(evt ?? this.sample([Event.Log, Event.Error]));
      case LogType.SQL:
        return this.sqlLine();
      // cspell:ignore ACTIVEMODELSERIALIZERS
      case LogType.ACTIVEMODELSERIALIZERS:
        return this.withContext(
          new ActiveModelSerializers.ActiveModelSerializersGenerate({
            message: 'ams.render',
            serializer: this.sample(['InvoiceSerializer', 'UserSerializer', 'ProjectSerializer']),
            adapter: 'ActiveModelSerializers::Adapter::Attributes',
            resource_class: this.sample(['Invoice', 'User', 'Project']),
            duration_ms: this.randomFloat(0.2, 15, 3),
          }).serialize(),
          { request: true },
        );
      case LogType.AHOY:
        return this.withContext(
          new Ahoy.AhoyLog({
            message: 'ahoy.track',
            ahoy_event: this.sample(['Viewed invoice', 'Signed up', 'Clicked upgrade']),
            properties: { invoice_id: this.randomInt(100, 999) },
          }).serialize(),
          { request: true },
        );
      case LogType.DOTENV:
        return this.dotenvLine(
          evt ?? this.sample([Event.Load, Event.Update, Event.Save, Event.Restore]),
        );
      case LogType.PUMA:
        return this.pumaLine(evt ?? this.sample([Event.Start, Event.Shutdown, Event.Error]));
      default:
        logType satisfies never;
        throw new Error(`Unhandled log type: ${String(logType)}`);
    }
  }

  // LogStruct's log types write src, evt, lvl and ts first, and prog, req_id and ctx after the
  // line's own fields. A line's own ctx keeps its keys and gains the job's.
  private withContext(line: JsonRecord, context: LineContext): JsonRecord {
    const { src, evt, lvl, ts, ...fields } = line;
    const result: JsonRecord = context.hash ? { ...line } : { src, evt, lvl, ts, ...fields };
    result.prog = context.prog ?? 'Rails';
    if (context.request) result.req_id = this.randomUuid();
    if (context.sidekiqJob) {
      // A ctx the line already has keeps its place
      result.ctx = { ...context.sidekiqJob, ...((line.ctx ?? {}) as JsonRecord) };
    }
    return result;
  }

  private sidekiqJob(jobClass: string): SidekiqJob {
    return { jid: this.randomHex(24), class: jobClass };
  }

  private requestLine(): JsonRecord {
    const scenario = this.requestScenario();
    const html = scenario.format === 'html';
    const duration = this.randomFloat(8, 400);
    return this.withContext(
      new Request.RequestRequest({
        http_method: scenario.http_method,
        path: scenario.path,
        // The client's IP and the host, as Rails' own request line logs them
        source_ip: this.randomIP(),
        host: 'app.example.com',
        format: scenario.format,
        controller: scenario.controller,
        action: scenario.action,
        status: scenario.status,
        duration_ms: duration,
        view: html && scenario.status === 200 ? this.randomFloat(1, duration * 0.4) : 0,
        // The time spent in the database, in milliseconds
        database: this.randomFloat(0.5, duration * 0.5),
        // Rails' filter_parameters have filtered the params before LogStruct sees them
        params: railsFilterParameters(scenario.params),
        user_agent: this.sample(SampleData.USER_AGENTS),
        content_type:
          scenario.http_method === 'GET' ? undefined : 'application/x-www-form-urlencoded',
        accept: html ? 'text/html,application/xhtml+xml' : 'application/json',
      }).serialize(),
      { request: true },
    );
  }

  // Request params as the browser or API client sent them
  private requestScenario(): RequestScenario {
    const scenario = this.sample(['login', 'register', 'payment', 'profile', 'search', 'api']);
    switch (scenario) {
      case 'login':
        return {
          http_method: 'POST',
          path: '/users/sign_in',
          format: 'html',
          controller: 'Users::SessionsController',
          action: 'create',
          status: this.sample([302, 302, 422]),
          params: {
            authenticity_token: this.randomHex(32),
            user: { email: this.randomEmail(), password: this.randomPassword(), remember_me: '1' },
            commit: 'Log in',
          },
        };
      case 'register':
        return {
          http_method: 'POST',
          path: '/users',
          format: 'html',
          controller: 'Users::RegistrationsController',
          action: 'create',
          status: this.sample([302, 422]),
          params: {
            user: {
              email: this.randomEmail(),
              password: this.randomPassword(),
              password_confirmation: this.randomPassword(),
            },
            invite_token: this.randomHex(8),
          },
        };
      case 'payment':
        return {
          http_method: 'POST',
          path: '/billing/payment_method',
          format: 'json',
          controller: 'Billing::PaymentMethodsController',
          action: 'create',
          status: this.sample([201, 422]),
          params: {
            payment_method: {
              credit_card: this.randomCreditCard(),
              cvc: String(this.randomInt(100, 999)),
              phone: this.randomPhone(),
            },
          },
        };
      case 'profile':
        return {
          http_method: 'PATCH',
          path: '/account',
          format: 'html',
          controller: 'AccountsController',
          action: 'update',
          status: 302,
          params: {
            user: {
              name: `${this.sample(SampleData.FIRST_NAMES)} ${this.sample(SampleData.LAST_NAMES)}`,
              email: this.randomEmail(),
              current_password: this.randomPassword(),
            },
          },
        };
      case 'api': {
        const id = String(this.randomInt(100, 999));
        return {
          http_method: 'GET',
          path: `/api/v1/invoices/${id}`,
          format: 'json',
          controller: 'Api::V1::InvoicesController',
          action: 'show',
          status: this.sample([200, 200, 404]),
          params: { id },
        };
      }
      default:
        return {
          http_method: 'GET',
          path: '/invoices',
          format: 'html',
          controller: 'InvoicesController',
          action: 'index',
          status: 200,
          params: { q: 'october', page: String(this.randomInt(1, 5)) },
        };
    }
  }

  private randomJob(): JobFields {
    return {
      job_id: this.randomUuid(),
      job_class: this.sample(SampleData.JOB_CLASSES),
      queue_name: this.sample(['default', 'mailers', 'low']),
      // A record's GlobalID, and a Hash whose email LogStruct filters
      arguments: [
        `gid://my-app/Customer/${this.randomInt(1000, 9999)}`,
        { month: '2026-09', email: this.randomEmail() },
      ],
      provider_job_id: this.randomHex(24),
    };
  }

  // A job's line at a time (milliseconds since the epoch): a start line's ts is the time the job
  // started, and a finish line's the time it finished
  private activeJobLine(evt: Event, job = this.randomJob(), at = this.nowMs()): JsonRecord {
    const timestamp = isoAt(at);
    // Sidekiq runs the job, with Sidekiq's job ID and the job's class in ctx
    const sidekiqJob = { jid: job.provider_job_id, class: job.job_class };
    switch (evt) {
      case Event.Enqueue:
        return this.withContext(
          new ActiveJob.ActiveJobEnqueue({ ...job, timestamp, executions: 0 }).serialize(),
          { request: true },
        );
      case Event.Schedule:
        return this.withContext(
          new ActiveJob.ActiveJobSchedule({
            ...job,
            timestamp,
            executions: 0,
            scheduled_at: isoAt(at + 3_600_000),
          }).serialize(),
          { request: true },
        );
      case Event.Start:
        return this.withContext(
          new ActiveJob.ActiveJobStart({
            ...job,
            timestamp,
            executions: 1,
            started_at: timestamp,
            attempt: 1,
          }).serialize(),
          { sidekiqJob },
        );
      // retry_on caught the exception and enqueued the job again, after its wait (3 seconds by default)
      case Event.Retry:
        return this.withContext(
          new ActiveJob.ActiveJobRetry({
            ...job,
            timestamp,
            executions: 1,
            error_class: 'Net::ReadTimeout',
            message: 'Net::ReadTimeout with #<TCPSocket:(closed)>',
            wait_ms: 3000,
          }).serialize(),
          { sidekiqJob },
        );
      // retry_on caught the exception again after the last of its 5 attempts
      case Event.RetryStopped:
        return this.withContext(
          new ActiveJob.ActiveJobRetryStopped({
            ...job,
            timestamp,
            level: Level.Error,
            executions: 5,
            error_class: 'Net::ReadTimeout',
            message: 'Net::ReadTimeout with #<TCPSocket:(closed)>',
          }).serialize(),
          { sidekiqJob },
        );
      // discard_on caught the exception and dropped the job
      case Event.Discard:
        return this.withContext(
          new ActiveJob.ActiveJobDiscard({
            ...job,
            timestamp,
            level: Level.Error,
            executions: 1,
            error_class: 'ActiveJob::DeserializationError',
            message: "Error while trying to deserialize arguments: Couldn't find Customer",
          }).serialize(),
          { sidekiqJob },
        );
      case Event.Error:
        if (this.randomInt(0, 2) === 0) {
          // The queue couldn't take the job: logged where perform_later was called
          return this.withContext(
            new ActiveJob.ActiveJobError({
              ...job,
              timestamp,
              level: Level.Error,
              executions: 0,
              provider_job_id: undefined,
              error_class: 'RedisClient::CannotConnectError',
              message: 'Connection refused - connect(2) for 10.0.3.15:6379',
              backtrace: this.backtrace(),
            }).serialize(),
            { request: true },
          );
        }
        return this.withContext(
          new ActiveJob.ActiveJobError({
            ...job,
            timestamp,
            level: Level.Error,
            executions: 1,
            error_class: 'Net::ReadTimeout',
            message: 'Net::ReadTimeout with #<TCPSocket:(closed)>',
            backtrace: this.backtrace(),
          }).serialize(),
          { sidekiqJob },
        );
      default:
        return this.withContext(
          new ActiveJob.ActiveJobFinish({
            ...job,
            timestamp,
            executions: 1,
            duration_ms: this.randomDuration(),
            finished_at: timestamp,
          }).serialize(),
          { sidekiqJob },
        );
    }
  }

  private plainLine(): JsonRecord {
    const variant = this.sample(['message', 'hash', 'additional_data', 'url', 'phone', 'bearer']);
    const plain = (message: string, additional_data?: JsonRecord) =>
      this.withContext(new Plain.PlainLog({ message, additional_data }).serialize(), {
        request: true,
      });
    switch (variant) {
      case 'hash':
        // Rails.logger.info(msg: ..., ...): the Hash's keys come first
        return this.withContext(
          {
            msg: 'Password reset requested',
            user_id: this.randomInt(1000, 9999),
            email: this.randomEmail(),
            src: Source.App,
            evt: Event.Log,
            ts: this.isoNow(),
            lvl: Level.Info,
          },
          { request: true, hash: true },
        );
      case 'additional_data':
        return plain('Imported invoices', {
          account_id: this.randomInt(1, 99),
          rows: this.randomInt(10, 500),
        });
      case 'url':
        return plain(
          `Connecting to postgres://app:${this.randomPassword()}@db.internal:5432/app_production`,
        );
      case 'phone':
        return plain(`Customer called from ${this.randomPhone()} about an invoice`);
      case 'bearer':
        return plain(`Webhook sent with Authorization: Bearer ${this.randomHex(32)}`);
      default:
        return plain(`Exported ${this.randomInt(10, 500)} invoices`);
    }
  }

  // Log::Error lines: logger.error(exception) in the app, an error that got past Rails'
  // ShowExceptions, or a Sorbet type error
  private errorLine(): JsonRecord {
    const source = this.sample([Source.App, Source.App, Source.Rails, Source.TypeChecking]);
    switch (source) {
      case Source.Rails:
        return this.withContext(
          new ErrorNs.ErrorError({
            source,
            level: Level.Error,
            error_class: 'ActionDispatch::Http::Parameters::ParseError',
            message: "unexpected character: 'invoice' at line 1 column 1",
            backtrace: this.backtrace(),
            path: '/api/v1/invoices',
            http_method: 'POST',
            source_ip: this.randomIP(),
            user_agent: 'curl/8.7.1',
          }).serialize(),
          { request: true },
        );
      case Source.TypeChecking:
        return this.withContext(
          new ErrorNs.ErrorError({
            source,
            level: Level.Error,
            error_class: 'TypeError',
            message:
              'Parameter \'user_id\': Expected type Integer, got type String with value "1873"',
            backtrace: this.backtrace(),
          }).serialize(),
          { request: true },
        );
      // Rails.logger.error("Import failed", error)
      default: {
        const [error_class, error_message] = this.sample(IMPORT_ERRORS);
        return this.withContext(
          new ErrorNs.ErrorError({
            source: Source.App,
            level: Level.Error,
            error_class,
            message: 'Import failed',
            error_message,
            backtrace: this.backtrace(),
          }).serialize(),
          { request: true },
        );
      }
    }
  }

  private securityLine(evt: Event): JsonRecord {
    switch (evt) {
      case Event.CSRFViolation:
        return this.withContext(
          new Security.SecurityCSRFViolation({
            level: Level.Error,
            path: `/invoices/${this.randomInt(100, 999)}`,
            http_method: 'PATCH',
            source_ip: this.randomIP(),
            user_agent: this.sample(SampleData.USER_AGENTS),
            referer: 'https://app.example.com/invoices',
            message: "Can't verify CSRF token authenticity.",
          }).serialize(),
          { request: true },
        );
      case Event.IPSpoof:
        return this.withContext(
          new Security.SecurityIPSpoof({
            level: Level.Warn,
            path: '/login',
            http_method: 'GET',
            source_ip: '10.0.1.15',
            user_agent: this.sample(SampleData.USER_AGENTS),
            message:
              'IP spoofing attack?! HTTP_CLIENT_IP="203.0.113.9" HTTP_X_FORWARDED_FOR="198.51.100.4"',
            client_ip: '203.0.113.9',
            x_forwarded_for: '198.51.100.4',
          }).serialize(),
          { request: true },
        );
      default: {
        // Rails checks the host before it sets the request ID
        const host = this.sample(['admin.example.net', 'example.com.evil.test', '203.0.113.50']);
        return this.withContext(
          new Security.SecurityBlockedHost({
            level: Level.Warn,
            path: '/',
            http_method: 'GET',
            source_ip: this.randomIP(),
            user_agent: 'curl/8.7.1',
            message: `Blocked host detected: ${host}`,
            blocked_host: host,
            // The Host header (and X-Forwarded-Host when it's set)
            blocked_hosts: [host],
          }).serialize(),
          {},
        );
      }
    }
  }

  private shrineLine(evt: Event): JsonRecord {
    const location = `invoice/${this.randomInt(100, 999)}/original-${this.randomHex(6)}.pdf`;
    switch (evt) {
      case Event.Download:
        return this.withContext(
          new Shrine.ShrineDownload({
            storage: 'store',
            location,
            download_options: {},
          }).serialize(),
          { request: true },
        );
      case Event.Delete:
        return this.withContext(
          new Shrine.ShrineDelete({ storage: 'store', location }).serialize(),
          {},
        );
      // Shrine's metadata event has no location, nor the metadata it extracted
      case Event.Metadata:
        return this.withContext(
          new Shrine.ShrineMetadata({
            storage: 'cache',
            duration_ms: this.randomFloat(1, 40),
          }).serialize(),
          { request: true },
        );
      // Shrine's exists event doesn't say whether the file exists
      case Event.Exist:
        return this.withContext(
          new Shrine.ShrineExist({ storage: 'store', location }).serialize(),
          {},
        );
      default:
        return this.withContext(
          new Shrine.ShrineUpload({
            storage: 'store',
            location,
            filename: `invoice-${this.randomInt(1000, 9999)}.pdf`,
            mime_type: 'application/pdf',
            size: this.randomInt(20_000, 900_000),
            upload_options: {},
            options: {},
            uploader: 'DocumentUploader',
            duration_ms: this.randomFloat(20, 400),
          }).serialize(),
          { request: true },
        );
    }
  }

  private sidekiqLine(evt: Event): JsonRecord {
    const worker = this.sample(SampleData.SIDEKIQ_WORKERS);
    const job = this.sidekiqJob(worker);
    if (evt === Event.Error) {
      // Logged with Rails.logger, after the job's middleware has finished
      return this.withContext(
        new Sidekiq.SidekiqError({
          level: Level.Warn,
          error_class: 'Timeout::Error',
          message: 'execution expired',
          backtrace: [`app/workers/${this.snakeCase(worker)}.rb:15:in '${worker}#perform'`],
          error_context: 'Job raised exception',
          queue_name: this.sample(['default', 'critical', 'low']),
          retry_count: this.randomInt(0, 5),
        }).serialize(),
        { sidekiqJob: job },
      );
    }
    const process_id = this.randomInt(1000, 99999);
    const thread_id = this.randomInt(46656, 1679615).toString(36);
    const kind = this.sample(['start', 'done', 'boot']);
    if (kind === 'boot') {
      // Logged outside a job, so the line has no context
      return this.withContext(
        new Sidekiq.SidekiqLog({
          message: 'Starting processing, hit Ctrl-C to stop',
          process_id,
          thread_id,
        }).serialize(),
        { prog: 'Sidekiq-Server' },
      );
    }
    // Sidekiq's own "start" and "done" lines, with its context
    const done = kind === 'done';
    return this.withContext(
      new Sidekiq.SidekiqLog({
        message: done ? 'done' : 'start',
        context: done
          ? { class: worker, jid: job.jid, elapsed: this.randomFloat(0.01, 9, 3).toString() }
          : { class: worker, jid: job.jid },
        process_id,
        thread_id,
      }).serialize(),
      { prog: 'Sidekiq-Server', sidekiqJob: job },
    );
  }

  private activeStorageLine(evt: Event): JsonRecord {
    const blob = {
      storage: this.sample(['S3', 'Disk', 'GCS']),
      file_id: this.randomBlobKey(),
    };
    switch (evt) {
      case Event.Download:
        return this.withContext(
          new ActiveStorage.ActiveStorageDownload({
            ...blob,
            duration_ms: this.randomFloat(5, 300),
          }).serialize(),
          { request: true },
        );
      case Event.Delete:
        // Purging an image deletes its variants by prefix (delete_prefixed), without a file_id
        return this.withContext(
          new ActiveStorage.ActiveStorageDelete(
            this.randomInt(0, 2) === 0
              ? { storage: blob.storage, prefix: `variants/${blob.file_id}/` }
              : blob,
          ).serialize(),
          {},
        );
      case Event.Metadata:
        return this.withContext(new ActiveStorage.ActiveStorageMetadata(blob).serialize(), {});
      // Existence checks and URLs are logged at debug level, as Rails logs them
      case Event.Exist:
        return this.withContext(
          new ActiveStorage.ActiveStorageExist({
            ...blob,
            level: Level.Debug,
            exist: true,
          }).serialize(),
          { request: true },
        );
      case Event.Url:
        return this.withContext(
          new ActiveStorage.ActiveStorageUrl({ ...blob, level: Level.Debug }).serialize(),
          { request: true },
        );
      default:
        return this.withContext(
          new ActiveStorage.ActiveStorageUpload({
            ...blob,
            checksum: `${this.randomHex(22)}==`,
            duration_ms: this.randomFloat(20, 600),
          }).serialize(),
          { request: true },
        );
    }
  }

  private actionMailerLine(evt: Event): JsonRecord {
    const mail = {
      to: [this.randomEmail()],
      from: 'billing@example.com',
      subject: 'Your October invoice',
      mailer_class: this.sample(SampleData.MAILER_CLASSES),
      mailer_action: this.sample(SampleData.MAILER_ACTIONS),
      attachment_count: this.randomInt(0, 2),
      additional_data: { account_id: this.randomInt(1, 99), user_id: this.randomInt(1000, 9999) },
    };
    switch (evt) {
      case Event.Delivered:
        return this.withContext(
          new ActionMailer.ActionMailerDelivered({
            ...mail,
            message_id: `${this.randomHex(13)}_${this.randomHex(12)}@web-1.mail`,
          }).serialize(),
          {},
        );
      case Event.Error:
        return this.withContext(
          new ActionMailer.ActionMailerError({
            ...mail,
            level: Level.Error,
            error_class: 'Net::SMTPAuthenticationError',
            message: `Net::SMTPAuthenticationError: Email delivery failed. Recipients: ${mail.to.join(', ')}. Error message: 535 5.7.8 Authentication failed`,
            backtrace: [`app/mailers/${this.snakeCase(mail.mailer_class)}.rb:12:in 'deliver'`],
          }).serialize(),
          { sidekiqJob: this.sidekiqJob('ActionMailer::MailDeliveryJob') },
        );
      // Logged before the mail is sent (before_deliver)
      default:
        return this.withContext(new ActionMailer.ActionMailerDelivery(mail).serialize(), {});
    }
  }

  private carrierWaveLine(evt: Event): JsonRecord {
    const id = this.randomInt(1000, 9999);
    const file = {
      storage: 'file',
      file_id: 'avatar.png',
      uploader: 'AvatarUploader',
      model: 'User',
      mount_point: 'avatar',
      version: '',
      store_path: `uploads/user/avatar/${id}/avatar.png`,
      extension: 'png',
    };
    const details = {
      filename: 'avatar.png',
      mime_type: 'image/png',
      size: this.randomInt(1000, 900000),
    };
    switch (evt) {
      // download!, when a remote URL is fetched into the cache (remote_avatar_url=)
      case Event.Download:
        return this.withContext(
          new Carrierwave.CarrierWaveDownload({ ...file, ...details }).serialize(),
          { request: true },
        );
      // remove!, when a record's file is removed or the record destroyed
      case Event.Delete:
        return this.withContext(new Carrierwave.CarrierWaveDelete(file).serialize(), {
          request: true,
        });
      default:
        return this.withContext(
          new Carrierwave.CarrierWaveUpload({
            ...file,
            ...details,
            duration_ms: this.randomFloat(2, 200),
          }).serialize(),
          { request: true },
        );
    }
  }

  private goodJobLine(evt: Event): JsonRecord {
    const process_id = this.randomInt(1000, 99999);
    const thread_id = this.randomInt(46656, 1679615).toString(36);
    if (evt === Event.Error) {
      return this.withContext(
        new GoodJob.GoodJobError({
          level: Level.Error,
          error_class: 'ActiveRecord::ConnectionNotEstablished',
          error_message:
            'connection to server at "10.0.3.12", port 5432 failed: Connection refused',
          backtrace: ["good_job/notifier.rb:225:in 'GoodJob::Notifier#with_connection'"],
          process_id,
          thread_id,
        }).serialize(),
        { prog: 'GoodJob' },
      );
    }
    return this.withContext(
      new GoodJob.GoodJobLog({
        message: this.sample([
          'Notifier subscribed with LISTEN',
          'GoodJob 4.3.0 started scheduler',
        ]),
        process_id,
        thread_id,
      }).serialize(),
      { prog: 'GoodJob' },
    );
  }

  // SQL logging is off by default, and logs queries slower than 100 ms when it's on
  private sqlLine(): JsonRecord {
    const table = this.sample(['invoices', 'users', 'projects']);
    const model = `${table[0].toUpperCase()}${table.slice(1, -1)}`;
    return this.withContext(
      new Sql.SQLDatabase({
        message: `${model} Load executed`,
        sql: `SELECT "${table}".* FROM "${table}" WHERE "${table}"."account_id" = $1`,
        name: `${model} Load`,
        duration_ms: this.randomFloat(100, 900),
        row_count: this.randomInt(0, 500),
        adapter: 'PostgreSQLAdapter',
        database_name: 'app_production',
        connection_pool_size: 5,
        active_connections: this.randomInt(1, 5),
        operation_type: 'SELECT',
        table_names: [table],
      }).serialize(),
      { request: true },
    );
  }

  private dotenvLine(evt: Event): JsonRecord {
    const vars = this.sampleSize(['DATABASE_URL', 'REDIS_URL', 'SMTP_HOST', 'S3_BUCKET'], 2);
    switch (evt) {
      case Event.Update:
        // Logged at debug level
        return this.withContext(
          new Dotenv.DotenvUpdate({ level: Level.Debug, vars }).serialize(),
          {},
        );
      case Event.Save:
        return this.withContext(new Dotenv.DotenvSave({ snapshot: true }).serialize(), {});
      case Event.Restore:
        return this.withContext(new Dotenv.DotenvRestore({ vars }).serialize(), {});
      default:
        return this.withContext(
          new Dotenv.DotenvLoad({ file: this.sample(['.env', '.env.production']) }).serialize(),
          {},
        );
    }
  }

  private pumaLine(evt: Event): JsonRecord {
    switch (evt) {
      case Event.Shutdown:
        return this.withContext(new Puma.PumaShutdown({ process_id: 1 }).serialize(), {});
      // An exception that got past the Rails app
      case Event.Error:
        return this.withContext(
          new Puma.PumaError({
            level: Level.Error,
            error_class: 'NoMethodError',
            message: "undefined method 'call' for nil",
            backtrace: ["config/initializers/health_check.rb:8:in 'HealthCheck#call'"],
            error_context: 'Rack app',
            http_method: 'GET',
            path: '/up',
          }).serialize(),
          {},
        );
      default: {
        const threads = this.randomInt(3, 5);
        return this.withContext(
          new Puma.PumaStart({
            mode: this.sample(['single', 'cluster']),
            puma_version: '6.6.1',
            puma_codename: 'Return to Forever',
            ruby_version: 'ruby 3.4.5 (2025-07-16 revision 20cda200d3) +PRISM [x86_64-linux]',
            min_threads: threads,
            max_threads: threads,
            environment: 'production',
            process_id: 1,
            listening_addresses: ['http://0.0.0.0:3000'],
          }).serialize(),
          {},
        );
      }
    }
  }

  private backtrace(): string[] {
    return this.sampleSize(SampleData.BACKTRACE_LINES, this.randomInt(2, 5));
  }

  // ActiveStorage blob keys: 28 lowercase letters and digits
  private randomBlobKey(): string {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    let key = '';
    for (let i = 0; i < 28; i++) key += chars[this.randomInt(0, chars.length - 1)];
    return key;
  }

  private snakeCase(name: string): string {
    return name.replace(/([a-z\d])([A-Z])/g, '$1_$2').toLowerCase();
  }

  // Typed job lines (before serialization), for the tests
  /** The enqueue, start and finish lines of one job, half a second and 1.2 seconds apart */
  generateJobSequence(): JsonRecord[] {
    const job = this.randomJob();
    const enqueuedAt = this.nowMs();
    const lines = [
      this.activeJobLine(Event.Enqueue, job, enqueuedAt),
      this.activeJobLine(Event.Start, job, enqueuedAt + 500),
      this.activeJobLine(Event.Finish, job, enqueuedAt + 1200),
    ];
    // The finish line's duration is the time from start to finish
    lines[2].duration_ms = 700;
    return this.filterEnabled ? lines.map((line) => processValues(line) as JsonRecord) : lines;
  }
}
