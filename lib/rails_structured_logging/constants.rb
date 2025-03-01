# frozen_string_literal: true

module RailsStructuredLogging
  # Constants used throughout the gem
  module Constants
    # Default source keys for different components
    SRC_RAILS = :rails
    SRC_SIDEKIQ = :sidekiq
    SRC_SHRINE = :shrine
    SRC_ACTIONMAILER = :actionmailer
    SRC_ACTIVEJOB = :activejob

    # Default event keys for different types of events
    EVT_SECURITY_VIOLATION = :security_violation
    EVT_REQUEST_ERROR = :request_error
    EVT_EMAIL_DELIVERY = :email_delivery
    EVT_JOB_EXECUTION = :job_execution
    EVT_FILE_OPERATION = :file_operation

    # Security violation types
    VIOLATION_TYPE_IP_SPOOF = :ip_spoof_attack
    VIOLATION_TYPE_CSRF = :csrf_token_error
    VIOLATION_TYPE_BLOCKED_HOST = :blocked_host
  end
end
