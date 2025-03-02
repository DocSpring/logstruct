# typed: true
# frozen_string_literal: true

module LogStruct
  module Integrations
    module ActionMailer
      # Handles error handling for ActionMailer
      module ErrorHandling
        extend ActiveSupport::Concern

        # NOTE: rescue_from handlers are checked in reverse order.
        # If you add any custom handlers to your own ApplicationMailer,
        # they will be checked first. (Put the most specific error classes at the end.)

        included do
          # Log and reraise by default. These errors are retried.
          rescue_from StandardError, with: :log_and_reraise_exception
        end

        protected

        # Just log the error without reporting or retrying
        sig { params(ex: StandardError).void }
        def log_and_ignore_exception(ex)
          log_email_delivery_error(ex, notify: false, report: false, reraise: false)
        end

        # Log and report to error service, but doesn't reraise.
        sig { params(ex: StandardError).void }
        def log_and_report_exception(ex)
          log_email_delivery_error(ex, notify: false, report: true, reraise: false)
        end

        # Log, report to error service, and reraise for retry
        sig { params(ex: StandardError).void }
        def log_and_reraise_exception(ex)
          log_email_delivery_error(ex, notify: false, report: true, reraise: true)
        end

        private

        # Log when email delivery fails
        sig { params(error: StandardError, notify: T::Boolean, report: T::Boolean, reraise: T::Boolean).void }
        def log_email_delivery_error(error, notify: false, report: true, reraise: true)
          # Generate appropriate error message
          message = error_message_for(error, reraise)

          # Use structured error logging
          Logger.log_structured_error(self, error, message)

          # Handle notifications and reporting
          handle_error_notifications(error, notify, report, reraise)
        end

        # Generate appropriate error message based on error handling strategy
        sig { params(error: StandardError, reraise: T::Boolean).returns(String) }
        def error_message_for(error, reraise)
          if reraise
            "#{error.class}: Email delivery error, will retry. Recipients: #{recipients(error)}"
          else
            "#{error.class}: Cannot send email to #{recipients(error)}"
          end
        end

        # Handle error notifications, reporting, and reraising
        sig { params(error: StandardError, notify: T::Boolean, report: T::Boolean, reraise: T::Boolean).void }
        def handle_error_notifications(error, notify, report, reraise)
          # Log a notification event if requested
          log_notification_event(error) if notify

          # Report to error reporting service if requested
          if report
            context = {
              mailer_class: self.class.to_s,
              mailer_action: respond_to?(:action_name) ? action_name : nil,
              recipients: recipients(error)
            }

            # Create an exception log for structured logging
            exception_data = Log::Exception.from_exception(
              LogSource::Mailer,
              LogEvent::Error,
              error,
              context
            )

            # Log the exception with structured data
            Rails.logger.error(exception_data)

            # Call the report_exception proc
            LogStruct.config.exception_reporting_handler.call(error, context)
          end

          # Re-raise the error if requested
          Kernel.raise error if reraise
        end

        # Log a notification event that can be picked up by external systems
        sig { params(error: StandardError).void }
        def log_notification_event(error)
          # Create an error log data object
          exception_data = Log::Exception.from_exception(
            LogSource::Mailer,
            LogEvent::Error,
            error,
            {
              mailer: self.class,
              action: action_name,
              recipients: recipients(error)
            }
          )

          # Log the error at info level since it's not a critical error
          Rails.logger.info(exception_data)
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
