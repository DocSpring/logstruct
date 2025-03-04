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
        extend T::Sig
        # Set up CarrierWave structured logging
        sig { void }
        def setup
          return unless defined?(::CarrierWave)
          return unless LogStruct.enabled?
          return unless LogStruct.config.integrations.enable_carrierwave

          # Patch CarrierWave to add logging
          ::CarrierWave::Uploader::Base.prepend(LoggingMethods)
        end
      end

      # Methods to add logging to CarrierWave operations
      module LoggingMethods
        extend T::Helpers
        requires_ancestor { ::CarrierWave::Uploader::Base }

        sig { params(file: T.untyped).returns(T.untyped) }
        def store!(file = nil)
          start_time = Time.now
          result = super
          duration = (Time.now - start_time) * 1000 # Convert to milliseconds

          log_operation(:upload, file, duration)
          result
        end

        sig { params(identifier: T.untyped).returns(T.untyped) }
        def retrieve_from_store!(identifier)
          start_time = Time.now
          result = super
          duration = (Time.now - start_time) * 1000 # Convert to milliseconds

          log_operation(:download, {identifier: identifier}, duration)
          result
        end

        sig { returns(T.untyped) }
        def remove!
          start_time = Time.now
          result = super
          duration = (Time.now - start_time) * 1000 # Convert to milliseconds

          log_operation(:delete, {identifier: identifier}, duration)
          result
        end

        private

        sig { params(operation: Symbol, file_info: T.untyped, duration: Float).void }
        def log_operation(operation, file_info, duration)
          # Map operation to LogEvent type
          event_type = case operation
          when :upload then LogEvent::Upload
          when :download then LogEvent::Download
          when :delete then LogEvent::Delete
          else LogEvent::Unknown
          end

          # Create structured log data
          log_data = Log::CarrierWave.new(
            source: Source::CarrierWave,
            event: event_type,
            operation: operation.to_s,
            storage: storage.to_s,
            file_id: identifier,
            filename: file_info.try(:original_filename) || file_info.try(:filename),
            mime_type: file_info.try(:content_type),
            size: file_info.try(:size),
            uploader: self.class.name,
            model: model&.class&.name,
            mount_point: mounted_as&.to_s,
            duration: duration
          )

          # Log the structured data
          Rails.logger.info(log_data)
        end
      end
    end
  end
end
