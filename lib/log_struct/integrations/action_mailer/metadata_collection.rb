# typed: strict
# frozen_string_literal: true

module LogStruct
  module Integrations
    module ActionMailer
      # Handles collection of metadata for email logging
      module MetadataCollection
        extend T::Sig
        # Add message-specific metadata to log data
        sig { params(mailer: T.untyped, log_data: T::Hash[Symbol, T.untyped]).void }
        def self.add_message_metadata(mailer, log_data)
          message = mailer.respond_to?(:message) ? mailer.message : nil

          # Add attachment count if message is available
          log_data[:attachment_count] = if message
            message.attachments&.count || 0
          else
            0
          end
        end

        # Add context metadata to log data
        sig { params(mailer: T.untyped, log_data: T::Hash[Symbol, T.untyped]).void }
        def self.add_context_metadata(mailer, log_data)
          # Add account ID information if available (but not user email)
          extract_ids_to_log_data(mailer, log_data)

          # Add any current tags from ActiveJob or ActionMailer
          add_current_tags_to_log_data(log_data)
        end

        sig { params(mailer: T.untyped, log_data: T::Hash[Symbol, T.untyped]).void }
        def self.extract_ids_to_log_data(mailer, log_data)
          # Use configured ID mapping from LogStruct configuration
          id_mapping = LogStruct.config.integrations.actionmailer_id_mapping

          id_mapping.each do |ivar_name, log_key|
            ivar = :"@#{ivar_name}"
            next unless mailer.instance_variable_defined?(ivar)

            obj = mailer.instance_variable_get(ivar)
            log_data[log_key] = obj.id if obj.respond_to?(:id)
          end
        end

        sig { params(log_data: T::Hash[Symbol, T.untyped]).void }
        def self.add_current_tags_to_log_data(log_data)
          # Get current tags from thread-local storage or ActiveSupport::TaggedLogging
          tags = if ::ActiveSupport::TaggedLogging.respond_to?(:current_tags)
            T.unsafe(::ActiveSupport::TaggedLogging).current_tags
          else
            Thread.current[:activesupport_tagged_logging_tags] || []
          end
          log_data[:tags] = tags if tags.present?

          # Get job_id from ActiveJob if available
          if defined?(::ActiveJob::Logging) && ::ActiveJob::Logging.respond_to?(:job_id) &&
              T.unsafe(::ActiveJob::Logging).job_id.present?
            log_data[:job_id] = T.unsafe(::ActiveJob::Logging).job_id
          end
        end
      end
    end
  end
end
