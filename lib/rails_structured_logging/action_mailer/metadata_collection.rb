# typed: true
# frozen_string_literal: true

require_relative "../sorbet"

module RailsStructuredLogging
  module ActionMailer
    # Handles collection of metadata for email logging
    module MetadataCollection
      include RailsStructuredLogging::TypedSig
      extend T::Sig

      # Add message-specific metadata to log data
      sig { params(mailer: T.untyped, log_data: T::Hash[Symbol, T.untyped]).void }
      def self.add_message_metadata(mailer, log_data)
        message = mailer.respond_to?(:message) ? mailer.message : nil

        # Add recipient count if message is available
        if message
          # Don't log actual email addresses
          log_data[:recipient_count] = [message.to, message.cc, message.bcc].flatten.compact.count

          # Handle case when attachments might be nil
          log_data[:has_attachments] = message.attachments&.any? || false
          log_data[:attachment_count] = message.attachments&.count || 0
        else
          log_data[:recipient_count] = 0
          log_data[:has_attachments] = false
          log_data[:attachment_count] = 0
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
        # Extract account ID if available
        if mailer.instance_variable_defined?(:@account)
          account = mailer.instance_variable_get(:@account)
          log_data[:account_id] = account.id if account.respond_to?(:id)
        end

        # Extract user ID if available
        return unless mailer.instance_variable_defined?(:@user)

        user = mailer.instance_variable_get(:@user)
        log_data[:user_id] = user.id if user.respond_to?(:id)
      end

      sig { params(log_data: T::Hash[Symbol, T.untyped]).void }
      def self.add_current_tags_to_log_data(log_data)
        # Get current tags from ActiveSupport::TaggedLogging if available
        if ::ActiveSupport::TaggedLogging.respond_to?(:current_tags)
          tags = T.unsafe(::ActiveSupport::TaggedLogging).current_tags
          log_data[:tags] = tags if tags.present?
        end

        # Get request_id from ActionDispatch if available
        if ::ActionDispatch::Request.respond_to?(:current_request_id) &&
            T.unsafe(::ActionDispatch::Request).current_request_id.present?
          log_data[:request_id] = T.unsafe(::ActionDispatch::Request).current_request_id
        end

        # Get job_id from ActiveJob if available
        if defined?(::ActiveJob::Logging) && ::ActiveJob::Logging.respond_to?(:job_id) &&
            T.unsafe(::ActiveJob::Logging).job_id.present?
          log_data[:job_id] = T.unsafe(::ActiveJob::Logging).job_id
        end
      end
    end
  end
end
