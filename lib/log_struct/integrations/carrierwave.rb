# typed: strict
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
      sig { override.params(config: LogStruct::Configuration).returns(T.nilable(T::Boolean)) }
      def self.setup(config)
        return nil unless defined?(::CarrierWave)
        return nil unless config.enabled
        return nil unless config.integrations.enable_carrierwave

        # Patch CarrierWave to add logging
        ::CarrierWave::Uploader::Base.prepend(LoggingMethods)

        true
      end

      # Methods to add logging to CarrierWave operations
      module LoggingMethods
        extend T::Sig
        extend T::Helpers
        requires_ancestor { ::CarrierWave::Uploader::Base }

        # Log file storage operations
        sig { params(args: T.untyped).returns(T.untyped) }
        def store!(*args)
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result = super
          duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

          # Extract file information
          file_size = file.size if file.respond_to?(:size)
          {
            identifier: identifier,
            filename: file.filename,
            content_type: file.content_type,
            size: file_size,
            store_path: store_path,
            extension: file.extension
          }

          # Log the store operation with structured data
          log_data = Log::CarrierWave::Upload.new(
            storage: storage.class.name.split("::").last.downcase.to_sym,
            file_id: identifier,
            filename: file.filename,
            mime_type: file.content_type,
            size: file_size,
            duration_ms: (duration * 1000.0).to_f,
            uploader: self.class.name,
            model: model.class.name,
            mount_point: mounted_as.to_s,
            version: version_name.to_s,
            store_path: store_path,
            extension: file.extension
          )

          ::Rails.logger.info(log_data)
          result
        end

        # Log file retrieve operations
        sig { params(identifier: T.untyped, args: T.untyped).returns(T.untyped) }
        def retrieve_from_store!(identifier, *args)
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result = super
          Process.clock_gettime(Process::CLOCK_MONOTONIC)

          # Extract file information if available
          file_size = file.size if file&.respond_to?(:size)

          # Log the retrieve operation with structured data
          log_data = Log::CarrierWave::Download.new(
            storage: storage.class.name.split("::").last.downcase.to_sym,
            file_id: identifier,
            filename: file&.filename,
            mime_type: file&.content_type,
            size: file_size,
            # No duration field on Download event schema
            uploader: self.class.name,
            model: model.class.name,
            mount_point: mounted_as.to_s,
            version: version_name.to_s,
            store_path: store_path,
            extension: file&.extension
          )

          ::Rails.logger.info(log_data)
          result
        end
      end
    end
  end
end
