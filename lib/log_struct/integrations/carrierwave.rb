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
      extend T::Sig
      extend IntegrationInterface

      # Set up CarrierWave structured logging
      sig { override.params(config: LogStruct::Configuration).void }
      def self.setup(config)
        return unless defined?(::CarrierWave)
        return unless config.enabled
        return unless config.integrations.enable_carrierwave

        # Patch CarrierWave to add logging
        ::CarrierWave::Uploader::Base.prepend(LoggingMethods)
      end

      # Methods to add logging to CarrierWave operations
      module LoggingMethods
        extend T::Sig

        # Log file storage operations
        sig { params(args: T.untyped).returns(T.untyped) }
        def store!(*args)
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result = super
          duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

          # Extract file information
          file_size = file.size if file.respond_to?(:size)
          file_info = {
            identifier: identifier,
            filename: file.filename,
            content_type: file.content_type,
            size: file_size,
            store_path: store_path,
            extension: file.extension
          }

          # Log the store operation with structured data
          log_data = Log::CarrierWave.new(
            source: Source::CarrierWave,
            event: LogEvent::Upload,
            duration: duration * 1000.0, # Convert to ms
            model: model.class.name,
            uploader: self.class.name,
            mounted_as: mounted_as.to_s,
            storage: storage.class.name,
            version: version_name.to_s,
            processing: processing.to_s,
            file: file_info
          )

          ::Rails.logger.info(log_data)
          result
        end

        # Log file retrieve operations
        sig { params(identifier: T.untyped, args: T.untyped).returns(T.untyped) }
        def retrieve_from_store!(identifier, *args)
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result = super
          duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

          # Extract file information if available
          file_size = file.size if file&.respond_to?(:size)
          file_info = if file
            {
              identifier: identifier,
              filename: file.filename,
              content_type: file.content_type,
              size: file_size,
              extension: file.extension
            }
          else
            {identifier: identifier}
          end

          # Log the retrieve operation with structured data
          log_data = Log::CarrierWave.new(
            source: Source::CarrierWave,
            event: LogEvent::Download,
            duration: duration * 1000.0, # Convert to ms
            uploader: self.class.name,
            mounted_as: mounted_as.to_s,
            storage: storage.class.name,
            version: version_name.to_s,
            file: file_info
          )

          ::Rails.logger.info(log_data)
          result
        end
      end
    end
  end
end
