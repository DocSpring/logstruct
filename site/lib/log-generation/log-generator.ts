/* eslint-disable @typescript-eslint/no-explicit-any */
import { RandomDataGenerator } from './random-data-generator';
import { SampleData } from './sample-data';
import {
  Event,
  Level,
  LogType,
  Source,
  Request,
  ActiveJob,
  Plain,
  Error as ErrorNs,
  Security,
  Shrine,
  Sidekiq,
  ActiveStorage,
  ActionMailer,
  Carrierwave,
  GoodJob,
  Sql,
  ActiveModelSerializers,
  Ahoy,
  Dotenv,
} from '@/generated/logstruct';

type JsonRecord = Record<string, any>;

export class LogGenerator extends RandomDataGenerator {
  private filterEnabled: boolean;

  constructor(seed?: number, filtering: boolean = true) {
    super(seed);
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
    const result: JsonRecord = (() => {
      switch (logType) {
        case LogType.REQUEST:
          return Request.RequestRequest.random(this, {
            http_method: this.sample(['GET', 'POST', 'PUT', 'DELETE']),
            path: this.sample(SampleData.PATHS),
            status: this.randomInt(200, 599),
            params: this.getRandomRequestParams(),
          }).serialize();

        case LogType.ACTIVEJOB: {
          switch (
            evt ??
            this.sample([
              Event.Enqueue,
              Event.Schedule,
              Event.Start,
              Event.Finish,
            ])
          ) {
            case Event.Enqueue:
              return ActiveJob.ActiveJobEnqueue.random(this).serialize();
            case Event.Schedule:
              return ActiveJob.ActiveJobSchedule.random(this).serialize();
            case Event.Start:
              return ActiveJob.ActiveJobStart.random(this).serialize();
            case Event.Finish:
            default:
              return ActiveJob.ActiveJobFinish.random(this).serialize();
          }
        }

        case LogType.PLAIN:
          return Plain.PlainLog.random(this, {
            message: 'Hello from LogStruct',
          }).serialize();

        case LogType.ERROR:
          return ErrorNs.ErrorError.random(this, {
            level: Level.Error,
            backtrace: [
              'app/models/user.rb:12:in find',
              'app/controllers/users_controller.rb:34:in show',
            ],
          }).serialize();

        case LogType.SECURITY: {
          switch (
            evt ??
            this.sample([Event.BlockedHost, Event.CSRFViolation, Event.IPSpoof])
          ) {
            case Event.CSRFViolation:
              return Security.SecurityCSRFViolation.random(this, {
                level: Level.Warn,
              }).serialize();
            case Event.IPSpoof:
              return Security.SecurityIPSpoof.random(this, {
                level: Level.Warn,
              }).serialize();
            case Event.BlockedHost:
            default:
              return Security.SecurityBlockedHost.random(this, {
                level: Level.Warn,
              }).serialize();
          }
        }

        case LogType.SHRINE: {
          switch (
            evt ??
            this.sample([Event.Upload, Event.Download, Event.Delete])
          ) {
            case Event.Download:
              return Shrine.ShrineDownload.random(this).serialize();
            case Event.Delete:
              return Shrine.ShrineDelete.random(this).serialize();
            case Event.Upload:
            default:
              return Shrine.ShrineUpload.random(this).serialize();
          }
        }

        case LogType.SIDEKIQ:
          return Sidekiq.SidekiqLog.random(this).serialize();

        case LogType.ACTIVESTORAGE: {
          switch (
            evt ??
            this.sample([
              Event.Upload,
              Event.Download,
              Event.Delete,
              Event.Metadata,
              Event.Exist,
              Event.Url,
            ])
          ) {
            case Event.Download:
              return ActiveStorage.ActiveStorageDownload.random(
                this,
              ).serialize();
            case Event.Delete:
              return ActiveStorage.ActiveStorageDelete.random(this).serialize();
            case Event.Metadata:
              return ActiveStorage.ActiveStorageMetadata.random(
                this,
              ).serialize();
            case Event.Exist:
              return ActiveStorage.ActiveStorageExist.random(this).serialize();
            case Event.Url:
              return ActiveStorage.ActiveStorageUrl.random(this).serialize();
            case Event.Upload:
            default:
              return ActiveStorage.ActiveStorageUpload.random(this).serialize();
          }
        }

        case LogType.ACTIONMAILER: {
          switch (evt ?? this.sample([Event.Delivery, Event.Delivered])) {
            case Event.Delivered:
              return ActionMailer.ActionMailerDelivered.random(this, {
                to: [this.randomEmail()],
                from: 'no-reply@example.com',
                subject: 'Welcome!',
              }).serialize();
            case Event.Delivery:
            default:
              return ActionMailer.ActionMailerDelivery.random(this, {
                to: [this.randomEmail()],
                from: 'no-reply@example.com',
                subject: 'Welcome!',
              }).serialize();
          }
        }

        case LogType.CARRIERWAVE: {
          switch (evt ?? this.sample([Event.Upload, Event.Delete])) {
            case Event.Delete:
              return Carrierwave.CarrierWaveDelete.random(this).serialize();
            case Event.Upload:
            default:
              return Carrierwave.CarrierWaveUpload.random(this).serialize();
          }
        }

        case LogType.GOODJOB: {
          switch (
            evt ??
            this.sample([
              Event.Enqueue,
              Event.Start,
              Event.Finish,
              Event.Error,
              Event.Log,
            ])
          ) {
            case Event.Enqueue:
              return GoodJob.GoodJobEnqueue.random(this).serialize();
            case Event.Start:
              return GoodJob.GoodJobStart.random(this).serialize();
            case Event.Finish:
              return GoodJob.GoodJobFinish.random(this).serialize();
            case Event.Error:
              return GoodJob.GoodJobError.random(this).serialize();
            case Event.Log:
            default:
              return GoodJob.GoodJobLog.random(this).serialize();
          }
        }

        case LogType.SQL:
          return Sql.SQLDatabase.random(this).serialize();

        case LogType.ACTIVEMODELSERIALIZERS:
          return ActiveModelSerializers.ActiveModelSerializersGenerate.random(
            this,
          ).serialize();

        case LogType.AHOY:
          return Ahoy.AhoyLog.random(this).serialize();

        case LogType.DOTENV: {
          switch (
            evt ??
            this.sample([Event.Update, Event.Load, Event.Save, Event.Restore])
          ) {
            case Event.Load:
              return Dotenv.DotenvLoad.random(this).serialize();
            case Event.Save:
              return Dotenv.DotenvSave.random(this).serialize();
            case Event.Restore:
              return Dotenv.DotenvRestore.random(this).serialize();
            case Event.Update:
            default:
              return Dotenv.DotenvUpdate.random(this).serialize();
          }
        }

        default:
          return Plain.PlainLog.random(this, {
            message: 'Example',
          }).serialize();
      }
    })();
    return filtering ? this.applyFilters(result) : result;
  }

  private applyFilters(log: JsonRecord): JsonRecord {
    const SENSITIVE_KEYS = new Set<string>([
      'password',
      'password_confirmation',
      'current_password',
      'token',
      'secret',
      'api_key',
      'authorization',
      'credit_card',
      'phone',
      'ssn',
      'tax_id',
      'email',
    ]);
    const emailRe = /^[^\s@]+@[^\s@]+\.[^\s@]+$/i;

    const filterValue = (key: string, value: any): any => {
      const k = key.toLowerCase();
      if (typeof value === 'string') {
        if (SENSITIVE_KEYS.has(k)) {
          if (k.includes('password')) return this.randomPassword(true);
          if (k.includes('credit')) return this.randomCreditCard(true);
          if (k.includes('phone')) return this.randomPhone(true);
          if (k.includes('email')) return this.randomFilteredEmailString();
          return '[FILTERED]';
        }
        if (emailRe.test(value)) return this.randomFilteredEmailString();
        return value;
      }
      if (Array.isArray(value)) {
        if (SENSITIVE_KEYS.has(k)) return this.filteredArray(value.length);
        return value.map((v) => filterValue(key, v));
      }
      if (value && typeof value === 'object') {
        if (['data', 'payload', 'attributes', 'request_body'].includes(k)) {
          return this.filteredHash('json');
        }
        return walk(value as Record<string, any>);
      }
      return value;
    };

    const walk = (obj: Record<string, any>): Record<string, any> => {
      const out: Record<string, any> = Array.isArray(obj) ? ([] as any) : {};
      for (const [k, v] of Object.entries(obj)) {
        (out as any)[k] = filterValue(k, v);
      }
      return out;
    };

    return walk(log);
  }

  // Backwards-compatible helper for tests expecting typed (unserialized) logs
  generateJobSequence(): Array<Record<string, any>> {
    const job_id = this.randomHex(8);
    const base = Date.now();
    const t1 = new Date(base).toISOString();
    const t2 = new Date(base + 500).toISOString();
    const t3 = new Date(base + 1200).toISOString();

    const enqueue = {
      timestamp: t1,
      level: 'info',
      source: Source.Job,
      event: Event.Enqueue,
      job_id,
      job_class: 'HardJob',
    };
    const start = {
      timestamp: t2,
      level: 'info',
      source: Source.Job,
      event: Event.Start,
      job_id,
      job_class: 'HardJob',
    };
    const finish = {
      timestamp: t3,
      level: 'info',
      source: Source.Job,
      event: Event.Finish,
      job_id,
      job_class: 'HardJob',
      duration_ms: this.randomDuration(),
    };
    return [enqueue, start, finish];
  }

  // Build realistic request params with sensitive fields to demonstrate filtering
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  private getRandomRequestParams(): Record<string, any> {
    const scenario = this.sample([
      'login',
      'register',
      'payment',
      'search',
      'profile_update',
    ]);
    switch (scenario) {
      case 'login':
        return {
          email: this.randomEmail(),
          password: this.randomPassword(false),
          remember_me: Math.random() > 0.5,
        };
      case 'register':
        return {
          user: {
            email: this.randomEmail(),
            password: this.randomPassword(false),
            password_confirmation: this.randomPassword(false),
          },
          invite_token: this.randomHex(8),
        };
      case 'payment':
        return {
          credit_card: this.randomCreditCard(false),
          phone: this.randomPhone(false),
          address: {
            line1: '123 Main St',
            city: 'Metropolis',
          },
        };
      case 'profile_update':
        return {
          token: this.randomHex(12),
          attributes: {
            email: this.randomEmail(),
            current_password: this.randomPassword(false),
          },
        };
      case 'search':
      default:
        return {
          q: 'rails filtering demo',
          page: this.randomInt(1, 5),
          tags: ['demo', 'filter'],
        };
    }
  }
}
