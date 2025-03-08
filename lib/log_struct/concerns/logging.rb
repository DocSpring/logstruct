# typed: strict
# frozen_string_literal: true

require_relative "../log"

module LogStruct
  module Concerns
    # Concern for handling errors according to configured modes
    module Logging
      module ClassMethods
        extend T::Sig

        # Log a log struct at debug level
        sig { params(log: Log::Interfaces::CommonFields).void }
        def debug(log)
          Rails.logger.debug(log)
        end

        # Log a log struct at info level
        sig { params(log: Log::Interfaces::CommonFields).void }
        def info(log)
          Rails.logger.info(log)
        end

        # Log a log struct at warn level
        sig { params(log: Log::Interfaces::CommonFields).void }
        def warn(log)
          Rails.logger.warn(log)
        end

        # Log a log struct at error level
        sig { params(log: Log::Interfaces::CommonFields).void }
        def error(log)
          Rails.logger.error(log)
        end

        # Log a log struct at fatal level
        sig { params(log: Log::Interfaces::CommonFields).void }
        def fatal(log)
          Rails.logger.fatal(log)
        end
      end
    end
  end
end
