# typed: true
# frozen_string_literal: true

begin
  require "carrierwave"
rescue LoadError
  # CarrierWave gem is not available, integration will be skipped
end

module LogStruct
  module Integrations
    # CarrierWave integration for structured logging
    module CarrierWave
      class << self
        # Set up CarrierWave structured logging
        sig { void }
        def setup
          return unless defined?(::CarrierWave)
          return unless LogStruct.enabled?
          return unless LogStruct.configuration.carrierwave_integration_enabled

          # Patch CarrierWave to add logging
          ::CarrierWave::Uploader::Base.prepend(LoggingMethods)
        end
      end

      # Methods to add logging to CarrierWave operations
      module LoggingMethods
        def store!(file = nil)
          start_time = Time.now
          result = super
          duration = (Time.now - start_time) * 1000 # Convert to milliseconds

          log_operation("store", file, duration)
          result
        end

        def retrieve_from_store!(identifier)
          start_time = Time.now
          result = super
          duration = (Time.now - start_time) * 1000 # Convert to milliseconds

          log_operation("retrieve", {identifier: identifier}, duration)
          result
        end

        def remove!
          start_time = Time.now
          result = super
          duration = (Time.now - start_time) * 1000 # Convert to milliseconds

          log_operation("remove", {identifier: identifier}, duration)
          result
        end

        private

        def log_operation(operation, file_info, duration)
          return unless LogStruct.enabled?
          return unless LogStruct.configuration.carrierwave_integration_enabled

          # Create structured log data
          log_data = Log::CarrierWave.new(
            src: LogSource::CarrierWave,
            evt: LogEvent::FileOperation,
            operation: operation,
            storage: storage.to_s,
            file_id: identifier,
            filename: file.try(:original_filename) || file.try(:filename),
            mime_type: file.try(:content_type),
            size: file.try(:size),
            duration: duration
          )

          # Log the structured data
          Rails.logger.info(log_data)
        end
      end
    end
  end
end
