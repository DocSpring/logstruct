# typed: strict
# frozen_string_literal: true

require_relative "../enums/level"
require_relative "../log"

module LogStruct
  module Concerns
    # Concern for handling errors according to configured modes
    module Logging
      module ClassMethods
        extend T::Sig

        # Type-safe interface for Rails.logger
        sig { params(log: Log::Interfaces::CommonFields).void }
        def log(log)
          level = log.level
          case level
          when Level::Debug
            Rails.logger.debug(log)
          when Level::Info
            Rails.logger.info(log)
          when Level::Warn
            Rails.logger.warn(log)
          when Level::Error
            Rails.logger.error(log)
          when Level::Fatal
            Rails.logger.fatal(log)
          when Level::Unknown
            Rails.logger.error(log) # Log unknown severity as error
          else
            T.absurd(level)
          end
        end
      end
    end
  end
end
