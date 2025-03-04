# typed: strict
# frozen_string_literal: true

require_relative "../enums/log_level"
require_relative "../log"

module LogStruct
  module Concerns
    # Concern for handling errors according to configured modes
    module Logging
      module ClassMethods
        extend T::Sig

        # Type-safe interface for Rails.logger
        sig { params(log: Log::CommonInterface).void }
        def log(log)
          level = log.level
          case level
          when LogLevel::Debug
            Rails.logger.debug(log)
          when LogLevel::Info
            Rails.logger.info(log)
          when LogLevel::Warn
            Rails.logger.warn(log)
          when LogLevel::Error
            Rails.logger.error(log)
          when LogLevel::Fatal
            Rails.logger.fatal(log)
          when LogLevel::Unknown
            Rails.logger.error(log) # Log unknown severity as error
          else
            T.absurd(level)
          end
        end
      end
    end
  end
end
