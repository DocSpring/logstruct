# typed: false
# frozen_string_literal: true

# Mock Rails for testing
module Rails
  class << self
    def logger
      @logger ||= Logger.new($stdout).tap do |logger|
        logger.level = Logger::FATAL # Suppress output during tests
      end
    end

    def env
      "test"
    end

    def root
      Pathname.new(Dir.pwd)
    end

    def application
      OpenStruct.new(
        config: OpenStruct.new(
          logstruct: OpenStruct.new(
            enabled: true,
            filter_parameters: [:password, :token, :secret, :key, :access, :auth, :credentials],
            active_job_integration_enabled: true,
            active_storage_integration_enabled: true,
            action_mailer_integration_enabled: true
          )
        )
      )
    end
  end
end

# Mock ActionMailer for testing
module ActionMailer
  class Base
    def self.rescue_from(*args)
    end

    def self.rescue_handlers
      []
    end
  end

  class MessageDelivery
    def handle_exceptions
    end
  end
end

# Mock ActiveJob for testing
module ActiveJob
  class Base
    def self.logger
      Rails.logger
    end
  end

  class LogSubscriber
    def logger
      Rails.logger
    end
  end
end

# Mock ActiveStorage for testing
module ActiveStorage
  class Service
  end
end
