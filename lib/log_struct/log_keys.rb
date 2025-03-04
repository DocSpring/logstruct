# typed: strict
# frozen_string_literal: true

module LogStruct
  module LogKeys
    # Shared fields
    SRC = :src
    EVT = :evt
    TS = :ts
    LVL = :lvl

    # Common fields
    MSG = :msg
    DATA = :data

    # Request-related fields
    PATH = :path
    METHOD = :method  # Note: we use `http_method` in code but `method` in JSON
    SOURCE_IP = :source_ip
    USER_AGENT = :user_agent
    REFERER = :referer
    REQUEST_ID = :request_id

    # HTTP-specific fields
    FORMAT = :format
    CONTROLLER = :controller
    ACTION = :action
    STATUS = :status
    DURATION = :duration
    VIEW = :view
    DB = :db
    PARAMS = :params

    # Security-specific fields
    BLOCKED_HOST = :blocked_host
    BLOCKED_HOSTS = :blocked_hosts
    CLIENT_IP = :client_ip
    X_FORWARDED_FOR = :x_forwarded_for

    # Email-specific fields
    TO = :to
    FROM = :from
    SUBJECT = :subject

    # Error and Exception fields
    ERR_CLASS = :err_class
    BACKTRACE = :backtrace

    # Job-specific fields
    JOB_ID = :job_id
    JOB_CLASS = :job_class
    QUEUE_NAME = :queue_name
    ARGUMENTS = :arguments
    RETRY_COUNT = :retry_count

    # Sidekiq-specific fields
    PID = :pid # Process ID
    TID = :tid # Thread ID
    CTX = :ctx # Context

    # Storage-specific fields (ActiveStorage)
    CHECKSUM = :checksum
    EXIST = :exist
    URL = :url
    PREFIX = :prefix
    RANGE = :range

    # Storage-specific fields (Shrine)
    STORAGE = :storage
    OP = :op # Operation
    FILE_ID = :file_id
    FILENAME = :filename
    MIME_TYPE = :mime_type
    SIZE = :size
    METADATA = :metadata
    LOCATION = :location
    UPLOAD_OPTS = :upload_opts
    DOWNLOAD_OPTS = :download_opts
    OPTS = :opts
    UPLOADER = :uploader

    # CarrierWave-specific fields
    MODEL = :model
    MOUNT_POINT = :mount_point
  end
end
