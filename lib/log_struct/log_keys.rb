# typed: strict
# frozen_string_literal: true

module LogStruct
  # Define a mapping of property names to JSON keys
  LOG_KEYS = T.let({
    # Ruby struct property name => JSON key name

    # Shared fields
    source: :src,
    event: :evt,
    timestamp: :ts,
    level: :lvl,

    # Common fields
    message: :msg,
    data: :data,

    # Request-related fields
    path: :path,
    http_method: :method, # Use `http_method` because `method` is a reserved word
    source_ip: :source_ip,
    user_agent: :user_agent,
    referer: :referer,
    request_id: :request_id,

    # HTTP-specific fields
    format: :format,
    controller: :controller,
    action: :action,
    status: :status,
    duration: :duration,
    view: :view,
    db: :db,
    params: :params,

    # Security-specific fields
    blocked_host: :blocked_host,
    blocked_hosts: :blocked_hosts,
    client_ip: :client_ip,
    x_forwarded_for: :x_forwarded_for,

    # Email-specific fields
    to: :to,
    from: :from,
    subject: :subject,

    # Error fields
    err_class: :err_class,
    backtrace: :backtrace,

    # Job-specific fields
    job_id: :job_id,
    job_class: :job_class,
    queue_name: :queue_name,
    arguments: :arguments,
    retry_count: :retry_count,

    # Sidekiq-specific fields
    process_id: :pid,
    thread_id: :tid,
    context: :ctx,

    # Storage-specific fields (ActiveStorage)
    checksum: :checksum,
    exist: :exist,
    url: :url,
    prefix: :prefix,
    range: :range,

    # Storage-specific fields (Shrine)
    storage: :storage,
    operation: :op,
    file_id: :file_id,
    filename: :filename,
    mime_type: :mime_type,
    size: :size,
    metadata: :metadata,
    location: :location,
    upload_options: :upload_opts,
    download_options: :download_opts,
    options: :opts,
    uploader: :uploader,

    # CarrierWave-specific fields
    model: :model,
    mount_point: :mount_point
  }.freeze,
    T::Hash[Symbol, Symbol])
end
