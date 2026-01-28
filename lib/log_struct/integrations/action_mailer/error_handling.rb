# typed: strict
# frozen_string_literal: true

module LogStruct
  module Integrations
    module ActionMailer
      # Handles error handling for ActionMailer
      #
      # IMPORTANT LIMITATIONS:
      # 1. This module must be included BEFORE users define rescue_from handlers
      #    to ensure proper handler precedence (user handlers are checked first)
      # 2. Rails rescue_from handlers don't bubble to parent class handlers after reraise
      # 3. Handler order matters: Rails checks rescue_from handlers in reverse declaration order
      module ErrorHandling
        extend T::Sig
        extend ActiveSupport::Concern

        sig { returns(T.nilable(T::Boolean)) }
        attr_accessor :logstruct_mail_failed

        # NOTE: rescue_from handlers are checked in reverse order of declaration.
        # We want LogStruct handlers to be checked AFTER user handlers (lower priority),
        # so we need to add them BEFORE user handlers are declared.

        # This will be called when the module is included/prepended
        sig { params(base: T.untyped).void }
        def self.install_handler(base)
          # Only add the handler once per class
          return if base.instance_variable_get(:@_logstruct_handler_installed)

          # Add our handler FIRST so it has lower priority than user handlers
          base.rescue_from StandardError, with: :log_and_reraise_error

          # Mark as installed to prevent duplicates
          base.instance_variable_set(:@_logstruct_handler_installed, true)
        end

        included do
          LogStruct::Integrations::ActionMailer::ErrorHandling.install_handler(self)
        end

        # Also support prepended (used by tests and manual setup)
        sig { params(base: T.untyped).void }
        def self.prepended(base)
          install_handler(base)
        end

        protected

        # Just log the error without reporting or retrying
        sig { params(ex: StandardError).void }
        def log_and_ignore_error(ex)
          self.logstruct_mail_failed = true
          log_email_delivery_error(ex, notify: false, report: false, reraise: false)
        end

        # Log and report to error service, but doesn't reraise.
        sig { params(ex: StandardError).void }
        def log_and_report_error(ex)
          log_email_delivery_error(ex, notify: false, report: true, reraise: false)
        end

        # Log, report to error service, and reraise for retry
        sig { params(ex: StandardError).void }
        def log_and_reraise_error(ex)
          log_email_delivery_error(ex, notify: false, report: true, reraise: true)
        end

        private

        # Handle an error from a mailer
        sig { params(mailer: T.untyped, error: StandardError, message: String).void }
        def log_structured_error(mailer, error, message)
          # Get message if available
          mailer_message = mailer.respond_to?(:message) ? mailer.message : nil

          # Prepare universal mailer fields
          message_data = {}
          MetadataCollection.add_message_metadata(mailer, message_data)

          # Prepare app-specific context data for additional_data
          context_data = {}
          MetadataCollection.add_context_metadata(mailer, context_data)

          # Extract email fields
          to = mailer_message&.to
          from = mailer_message&.from&.first
          subject = mailer_message&.subject
          message_id = extract_message_id_from_mailer(mailer)

          # Create ActionMailer-specific error struct
          exception_data = Log::ActionMailer::Error.new(
            to: to,
            from: from,
            subject: subject,
            message_id: message_id,
            mailer_class: mailer.class.to_s,
            mailer_action: mailer.respond_to?(:action_name) ? mailer.action_name&.to_s : nil,
            attachment_count: message_data[:attachment_count],
            error_class: error.class,
            message: message,
            backtrace: error.backtrace,
            additional_data: context_data.presence,
            timestamp: Time.now
          )

          # Log the structured error
          LogStruct.error(exception_data)
        end

        # Extract message ID from the mailer
        sig { params(mailer: T.untyped).returns(T.nilable(String)) }
        def extract_message_id_from_mailer(mailer)
          return nil unless mailer.respond_to?(:message)

          mail_message = mailer.message
          return nil unless mail_message.respond_to?(:message_id)

          mail_message.message_id
        end

        # Log when email delivery fails
        sig { params(error: StandardError, notify: T::Boolean, report: T::Boolean, reraise: T::Boolean).void }
        def log_email_delivery_error(error, notify: false, report: true, reraise: true)
          # Generate appropriate error message
          message = error_message_for(error, reraise)

          # Use structured error logging
          log_structured_error(self, error, message)

          # Handle notifications and reporting
          handle_error_notifications(error, notify, report, reraise)
        end

        # Generate appropriate error message based on error handling strategy
        sig { params(error: StandardError, reraise: T::Boolean).returns(String) }
        def error_message_for(error, reraise)
          if reraise
            "#{error.class}: Email delivery error, will retry. Recipients: #{recipients(error)}. Error message: #{error.message}"
          else
            "#{error.class}: Cannot send email to #{recipients(error)}. Error message: #{error.message}"
          end
        end

        # Handle error notifications, reporting, and reraising
        sig { params(error: StandardError, notify: T::Boolean, report: T::Boolean, reraise: T::Boolean).void }
        def handle_error_notifications(error, notify, report, reraise)
          # Log a notification event if requested
          log_notification_event(error) if notify

          # Report to error reporting service if requested
          if report
            context_data = {recipients: recipients(error)}
            exception_data = build_exception_data(error, Level::Error, context_data)

            # Log the exception with structured data
            LogStruct.error(exception_data)

            # Call the error handler with flat context for compatibility
            context = {
              mailer_class: self.class.to_s,
              mailer_action: respond_to?(:action_name) ? action_name : nil,
              recipients: recipients(error)
            }
            LogStruct.handle_exception(error, source: Source::Mailer, context: context)
          end

          # Re-raise the error if requested
          Kernel.raise error if reraise
        end

        # Log a notification event that can be picked up by external systems
        sig { params(error: StandardError).void }
        def log_notification_event(error)
          context_data = {
            mailer: self.class.to_s,
            action: action_name&.to_s,
            recipients: recipients(error)
          }
          exception_data = build_exception_data(error, Level::Info, context_data)

          # Log the error at info level since it's not a critical error
          LogStruct.info(exception_data)
        end

        sig { params(error: StandardError, level: Level, context_data: T::Hash[Symbol, T.untyped]).returns(Log::ActionMailer::Error) }
        def build_exception_data(error, level, context_data)
          mailer_message = respond_to?(:message) ? message : nil

          message_data = {}
          MetadataCollection.add_message_metadata(self, message_data)

          MetadataCollection.add_context_metadata(self, context_data)

          to = mailer_message&.to
          from = mailer_message&.from&.first
          subject = mailer_message&.subject
          message_id = extract_message_id_from_mailer(self)

          Log::ActionMailer::Error.new(
            to: to,
            from: from,
            subject: subject,
            message_id: message_id,
            mailer_class: self.class.to_s,
            mailer_action: respond_to?(:action_name) ? action_name&.to_s : nil,
            attachment_count: message_data[:attachment_count],
            error_class: error.class,
            message: error.message,
            backtrace: error.backtrace,
            additional_data: context_data.presence,
            timestamp: Time.now,
            level: level
          )
        end

        sig { params(error: StandardError).returns(String) }
        def recipients(error)
          # Extract recipient info if available
          if error.respond_to?(:recipients) && T.unsafe(error).recipients.present?
            T.unsafe(error).recipients.join(", ")
          else
            "unknown"
          end
        end
      end
    end
  end
end
