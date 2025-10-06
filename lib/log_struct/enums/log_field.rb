# typed: strict
# frozen_string_literal: true

# NOTE:
# - This enum defines human‑readable field names (constants) that map to compact
#   JSON key symbols via `serialize` (e.g., Database => :db).
# - The enum constant names are code‑generated into
#   `schemas/meta/log-fields.json` by `scripts/generate_structs.rb` and
#   referenced from `schemas/meta/log-source-schema.json` to strictly validate
#   field keys in `schemas/log_sources/*`.
# - When adding or renaming fields here, run the generator so schema validation
#   stays in sync.
#
# Use human-readable field names as the enum values and short field names for the JSON properties

module LogStruct
  class LogField < T::Enum
    enums do
      # Shared fields
      Source = new(:src)
      Event = new(:evt)
      Timestamp = new(:ts)
      Level = new(:lvl)

      # Common fields
      Message = new(:msg)
      Data = new(:data)

      # Request-related fields
      Path = new(:path)
      HttpMethod = new(:method) # property name was http_method
      SourceIp = new(:source_ip)
      UserAgent = new(:user_agent)
      Referer = new(:referer)
      RequestId = new(:request_id)

      # HTTP-specific fields
      Format = new(:format)
      Controller = new(:controller)
      Action = new(:action)
      Status = new(:status)
      # DurationMs already defined below for general metrics
      View = new(:view)
      Database = new(:db)
      Params = new(:params)

      # Security-specific fields
      BlockedHost = new(:blocked_host)
      BlockedHosts = new(:blocked_hosts)
      ClientIp = new(:client_ip)
      XForwardedFor = new(:x_forwarded_for)

      # Email-specific fields
      To = new(:to)
      From = new(:from)
      Subject = new(:subject)
      MessageId = new(:msg_id)
      MailerClass = new(:mailer)
      MailerAction = new(:mailer_action)
      AttachmentCount = new(:attachments)

      # Error fields
      ErrClass = new(:err_class)
      Backtrace = new(:backtrace)

      # Job-specific fields
      JobId = new(:job_id)
      JobClass = new(:job_class)
      QueueName = new(:queue_name)
      Arguments = new(:arguments)
      RetryCount = new(:retry_count)
      Retries = new(:retries)
      Attempt = new(:attempt)
      Executions = new(:executions)
      ExceptionExecutions = new(:exception_executions)
      ProviderJobId = new(:provider_job_id)
      ScheduledAt = new(:scheduled_at)
      StartedAt = new(:started_at)
      FinishedAt = new(:finished_at)
      DurationMs = new(:duration_ms)
      WaitMs = new(:wait_ms)
      # Deprecated: ExecutionTime/WaitTime/RunTime
      ExecutionTime = new(:execution_time)
      WaitTime = new(:wait_time)
      RunTime = new(:run_time)
      Priority = new(:priority)
      CronKey = new(:cron_key)
      ErrorMessage = new(:error_message)
      Result = new(:result)
      EnqueueCaller = new(:enqueue_caller)

      # Dotenv fields
      File = new(:file)
      Vars = new(:vars)
      Snapshot = new(:snapshot)

      # Sidekiq-specific fields
      ProcessId = new(:pid)
      ThreadId = new(:tid)
      Context = new(:ctx)

      # Storage-specific fields (ActiveStorage)
      Checksum = new(:checksum)
      Exist = new(:exist)
      Url = new(:url)
      Prefix = new(:prefix)
      Range = new(:range)

      # Storage-specific fields (Shrine)
      Storage = new(:storage)
      Operation = new(:op)
      FileId = new(:file_id)
      Filename = new(:filename)
      MimeType = new(:mime_type)
      Size = new(:size)
      Metadata = new(:metadata)
      Location = new(:location)
      UploadOptions = new(:upload_opts)
      DownloadOptions = new(:download_opts)
      Options = new(:opts)
      Uploader = new(:uploader)

      # CarrierWave-specific fields
      Model = new(:model)
      MountPoint = new(:mount_point)
      Version = new(:version)
      StorePath = new(:store_path)
      Extension = new(:ext)

      # SQL-specific fields
      Sql = new(:sql)
      Name = new(:name)
      RowCount = new(:row_count)
      # Use Adapter for both AMS and SQL adapter name
      BindParams = new(:bind_params)
      DatabaseName = new(:db_name)
      ConnectionPoolSize = new(:pool_size)
      ActiveConnections = new(:active_count)
      OperationType = new(:op_type)
      TableNames = new(:table_names)

      # ActiveModelSerializers fields
      Serializer = new(:serializer)
      Adapter = new(:adapter)
      ResourceClass = new(:resource_class)

      # Ahoy-specific fields
      AhoyEvent = new(:ahoy_event)
      Properties = new(:properties)

      # Puma / server lifecycle fields
      Mode = new(:mode)
      PumaVersion = new(:puma_version)
      PumaCodename = new(:puma_codename)
      RubyVersion = new(:ruby_version)
      MinThreads = new(:min_threads)
      MaxThreads = new(:max_threads)
      Environment = new(:environment)
      ListeningAddresses = new(:listening_addresses)
      Address = new(:addr)
    end
  end
end
