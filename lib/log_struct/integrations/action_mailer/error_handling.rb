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

        # ActionMailer::MailDeliveryJob passes errors to the mailer class (`handle_exception`), which
        # looks the rescue_from handlers up on the class, so the handlers are defined there too.
        # (ActiveSupport::Concern extends the class with ClassMethods when it's included or prepended.)
        module ClassMethods
          extend T::Sig

          # Logs the error, and doesn't report or raise it
          sig { params(ex: StandardError).void }
          def log_and_ignore_error(ex)
            ErrorHandling.handle_mailer_class_error(self, ex, report: false, reraise: false)
          end

          # Logs and reports the error, and doesn't raise it
          sig { params(ex: StandardError).void }
          def log_and_report_error(ex)
            ErrorHandling.handle_mailer_class_error(self, ex, report: true, reraise: false)
          end

          # Logs the error and raises it again, reporting it too in the Report modes
          sig { params(ex: StandardError).void }
          def log_and_reraise_error(ex)
            ErrorHandling.handle_mailer_class_error(self, ex, report: ErrorHandling.report_before_reraise?, reraise: true)
          end
        end

        # log_and_reraise_error reports the error where standard_errors' mode reports the app's errors
        # (Report, and ReportProduction in production). Elsewhere whatever rescues the raised error decides.
        sig { returns(T::Boolean) }
        def self.report_before_reraise?
          mode = LogStruct.error_handling_mode_for(Source::Mailer)
          mode == ErrorHandlingMode::Report || (mode == ErrorHandlingMode::ReportProduction && LogStruct.is_production?)
        end

        # An error that reaches the class handler from the delivery itself was logged (and reported)
        # by the mailer's handler, which raised it again (log_and_reraise_error). It's raised again,
        # without logging it twice, so the job fails as deliver_now would.
        sig { params(mailer_class: T.untyped, error: StandardError, report: T::Boolean, reraise: T::Boolean).void }
        def self.handle_mailer_class_error(mailer_class, error, report:, reraise:)
          Kernel.raise error if LogStruct::LoggedErrors.logged?(error)

          message = if reraise
            "#{error.class}: Email delivery failed. Error message: #{error.message}"
          else
            "#{error.class}: Cannot send email. Error message: #{error.message}"
          end
          LogStruct.error(Log::ActionMailer::Error.new(
            mailer_class: mailer_class.to_s,
            error_class: error.class,
            message: message,
            backtrace: error.backtrace,
            level: Level::Error
          ))
          LogStruct.report_error(error, source: Source::Mailer, context: {mailer_class: mailer_class.to_s}) if report

          Kernel.raise error if reraise
        end

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

        # Logs the error, and doesn't report or raise it
        sig { params(ex: StandardError).void }
        def log_and_ignore_error(ex)
          self.logstruct_mail_failed = true
          log_email_delivery_error(ex, notify: false, report: false, reraise: false)
        end

        # Logs and reports the error, and doesn't raise it
        sig { params(ex: StandardError).void }
        def log_and_report_error(ex)
          log_email_delivery_error(ex, notify: false, report: true, reraise: false)
        end

        # Logs the error and raises it again, reporting it too in the Report modes (report_before_reraise?)
        sig { params(ex: StandardError).void }
        def log_and_reraise_error(ex)
          log_email_delivery_error(ex, notify: false, report: ErrorHandling.report_before_reraise?, reraise: true)
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
            timestamp: Time.now,
            level: Level::Error
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
          # The mailer class handler gets the error if it's raised from here (re-raised, or raised by
          # LogStruct.handle_exception in Raise mode), and mustn't log or report it again
          LogStruct::LoggedErrors.mark(error)

          # Handle notifications, reporting and raising
          handle_error_notifications(error, notify, report, reraise)
        end

        # Generate appropriate error message based on error handling strategy
        sig { params(error: StandardError, reraise: T::Boolean).returns(String) }
        def error_message_for(error, reraise)
          if reraise
            "#{error.class}: Email delivery failed. Recipients: #{recipients(error)}. Error message: #{error.message}"
          else
            "#{error.class}: Cannot send email to #{recipients(error)}. Error message: #{error.message}"
          end
        end

        # Handle error notifications, reporting, and reraising
        sig { params(error: StandardError, notify: T::Boolean, report: T::Boolean, reraise: T::Boolean).void }
        def handle_error_notifications(error, notify, report, reraise)
          # Log a notification event if requested
          log_notification_event(error) if notify

          # Report to error reporting service if requested. The structured error line is already logged.
          if report
            context = {
              mailer_class: self.class.to_s,
              mailer_action: respond_to?(:action_name) ? action_name : nil,
              recipients: recipients(error)
            }
            LogStruct.report_error(error, source: Source::Mailer, context: context)
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

        # The formatter scrubs the addresses in the line
        sig { params(error: StandardError).returns(String) }
        def recipients(error)
          # Some delivery errors (Postmark's, for example) have the recipients that failed
          if error.respond_to?(:recipients) && T.unsafe(error).recipients.present?
            return T.unsafe(error).recipients.join(", ")
          end

          # Otherwise the mail's own: to, cc and bcc (unknown when the mailer failed before it built the mail)
          mail = respond_to?(:message) ? message : nil
          destinations = mail.respond_to?(:destinations) ? Array(mail.destinations).compact : []
          destinations.empty? ? "unknown" : destinations.join(", ")
        end
      end
    end
  end
end
