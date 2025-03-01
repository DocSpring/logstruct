# frozen_string_literal: true

module RailsStructuredLogging
  module ActionMailer
    # Handles error handling for ActionMailer
    module ErrorHandling
      extend ActiveSupport::Concern

      included do
        # NOTE: rescue_from handlers are checked in reverse order.
        # The handler that was defined last is checked first, so put
        # more specific handlers at the end.
        # -------------------------------------------------------------
        # Log and report to Sentry by default. These errors are retried.
        rescue_from StandardError, with: :log_and_reraise_error

        if defined?(Postmark)
          rescue_from Postmark::Error, with: :log_and_reraise_error

          # Errors that should be sent as a notification but not an error report (no retry)
          rescue_from Postmark::InactiveRecipientError, with: :log_and_notify_error
          rescue_from Postmark::InvalidEmailRequestError, with: :log_and_notify_error
        end
      end

      protected

      # Error handling methods with different behaviors:
      # - log_and_ignore_error: Just logs the error without reporting or retrying
      # - log_and_notify_error: Logs and sends a Slack notification, but doesn't report to Sentry or reraise
      # - log_and_report_error: Logs and reports to Sentry, but doesn't reraise
      # - log_and_reraise_error: Logs, reports to Sentry, and reraises for retry

      def log_and_ignore_error(ex)
        log_email_delivery_error(ex, notify: false, report: false, reraise: false)
      end

      def log_and_notify_error(ex)
        log_email_delivery_error(ex, notify: true, report: false, reraise: false)
      end

      def log_and_report_error(ex)
        log_email_delivery_error(ex, notify: false, report: true, reraise: false)
      end

      def log_and_reraise_error(ex)
        log_email_delivery_error(ex, notify: false, report: true, reraise: true)
      end

      private

      # Log when email delivery fails
      def log_email_delivery_error(error, notify: false, report: true, reraise: true)
        # Skip logging for AbortDeliveryError as it's an expected case
        # when emails are intentionally not sent
        return if defined?(ApplicationMailer) &&
                 defined?(ApplicationMailer::AbortDeliveryError) &&
                 error.is_a?(ApplicationMailer::AbortDeliveryError)

        # Generate appropriate error message
        message = error_message_for(error, reraise)

        # Use structured error logging
        Logger.log_structured_error(self, error, message)

        # Handle notifications and reporting
        handle_error_notifications(error, notify, report, reraise)
      end

      # Generate appropriate error message based on error handling strategy
      def error_message_for(error, reraise)
        if reraise
          "#{error.class}: Email delivery error, will retry. Recipients: #{recipients(error)}"
        else
          "#{error.class}: Cannot send email to #{recipients(error)}"
        end
      end

      # Handle error notifications, reporting, and reraising
      def handle_error_notifications(error, notify, report, reraise)
        # Send notification to Slack if requested
        if notify && defined?(InternalSlackNotificationJob) && defined?(SlackChannels)
          InternalSlackNotificationJob.perform_async(
            channel: SlackChannels::CUSTOMERS,
            text: "Postmark error: #{error.class}: Cannot send email to #{recipients(error)}! #{error.message}"
          )
        end

        # Report to Sentry if requested
        if report && defined?(Sentry)
          Sentry.capture_exception(error)
        end

        # Re-raise the error if requested
        raise error if reraise
      end

      def recipients(error)
        # Extract recipient info if available
        if error.respond_to?(:recipients) && error.recipients.present?
          error.recipients.join(', ')
        else
          'unknown'
        end
      end
    end
  end
end
