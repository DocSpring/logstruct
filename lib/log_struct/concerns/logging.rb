# typed: strict
# frozen_string_literal: true

require_relative "../log_level"
require_relative "../log"

module LogStruct
  module Concerns
    # Concern for handling errors according to configured modes
    module Logging
      extend T::Sig

      sig { params(level: LogLevel, log: Log).void }
      def log(level, log)
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
        else
          T.absurd(level)
        end
      end
    end
  end
end
