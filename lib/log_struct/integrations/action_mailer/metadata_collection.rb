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
      end
    end
  end
end
