# typed: strict
# frozen_string_literal: true

begin
  require "carrierwave"
rescue LoadError
  # CarrierWave gem is not available, integration will be skipped
end
require_relative "../hash_utils"

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

      # Logs the operations that store, delete or fetch a file: store! (an upload, when there's a
      # cached file to store), remove! (a delete) and download! (a remote URL fetched into the cache).
      # retrieve_from_store! isn't logged: it only points the uploader at a stored file, and runs
      # each time a record's mounted file is read.
      module LoggingMethods
        extend T::Sig
        extend T::Helpers
        requires_ancestor { ::CarrierWave::Uploader::Base }

        sig { params(args: T.untyped).returns(T.untyped) }
        def store!(*args)
          # CarrierWave only stores a cached file; a record's save calls store! on every uploader
          storing = !cache_only && (cached? || !args.first.nil?)
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result = super
          return result unless storing && !cached?

          duration_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000.0
          log_file_operation do
            # file_fields is a Hash Sorbet can't check against the struct's keyword arguments
            Log::CarrierWave::Upload.new(
              **T.unsafe(file_fields),
              mime_type: file&.content_type,
              size: file&.size,
              duration_ms: duration_ms
            )
          end
          result
        end

        sig { returns(T.untyped) }
        def remove!
          fields = file ? file_fields : nil
          result = super
          log_file_operation { Log::CarrierWave::Delete.new(**T.unsafe(fields)) } if fields
          result
        end

        sig { params(uri: T.untyped, remote_headers: T.untyped).returns(T.untyped) }
        def download!(uri, remote_headers = {})
          result = super
          log_file_operation do
            Log::CarrierWave::Download.new(
              **T.unsafe(file_fields),
              mime_type: file&.content_type,
              size: file&.size
            )
          end
          result
        end

        private

        # The fields every CarrierWave line has
        sig { returns(T::Hash[Symbol, T.untyped]) }
        def file_fields
          {
            storage: storage.class.name.to_s.split("::").last.to_s.downcase.to_sym,
            file_id: HashUtils.hash_value(identifier.to_s),
            uploader: self.class.name,
            model: model&.class&.name,
            mount_point: mounted_as&.to_s,
            version: version_name&.to_s
          }
        end

        # A problem with a log line mustn't stop the file operation that has already happened
        sig { params(block: T.proc.returns(Log::Interfaces::CommonFields)).void }
        def log_file_operation(&block)
          LogStruct.info(yield)
        rescue => e
          LogStruct.handle_exception(e, source: Source::Internal, context: {integration: :carrierwave})
        end
      end
    end
  end
end
