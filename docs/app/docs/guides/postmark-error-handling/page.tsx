import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';

export default function PostmarkErrorHandlingPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="postmark-error-handling" level={1}>
        Handling Postmark Errors
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-300">
        A guide to handling Postmark bounce errors and sending custom notifications using LogStruct.
      </p>

      <HeadingWithAnchor id="error-handling-methods" level={2}>
        Error Handling Methods
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct provides three error handling methods you can use in <code>rescue_from</code>{' '}
        handlers:
      </p>
      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-300 mb-4">
        <li>
          <code>log_and_ignore_error(error)</code> - Logs the error but doesn't report to Sentry or
          reraise
        </li>
        <li>
          <code>log_and_report_error(error)</code> - Logs the error, reports to Sentry, but doesn't
          reraise
        </li>
        <li>
          <code>log_and_reraise_error(error)</code> - Logs the error, reports to Sentry, and
          reraises (for retry)
        </li>
      </ul>

      <HeadingWithAnchor id="example-postmark-bounces" level={2}>
        Example: Handling Postmark Bounce Errors
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        When using Postmark, you may want to handle bounce errors (inactive recipients, invalid
        emails) differently than other errors:
      </p>
      <CodeBlock language="ruby">{`# config/initializers/action_mailer_postmark_errors.rb
Rails.application.config.after_initialize do
  ActiveSupport.on_load(:action_mailer) do
    if defined?(Postmark)
      # Postmark bounce errors - log but don't reraise (can't be retried)
      rescue_from Postmark::InactiveRecipientError, with: :log_and_ignore_error
      rescue_from Postmark::InvalidEmailRequestError, with: :log_and_ignore_error
    end
  end
end`}</CodeBlock>

      <HeadingWithAnchor id="custom-notifications" level={2}>
        Custom Notifications (e.g., Slack)
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct logs structured error data but doesn't send notifications directly. To send custom
        notifications (like Slack alerts), subscribe to LogStruct logs:
      </p>
      <CodeBlock language="ruby">{`# config/initializers/mailer_notifications.rb
Rails.application.config.after_initialize do
  # Subscribe to LogStruct logs
  ActiveSupport::Notifications.subscribe('log.logstruct') do |_name, _start, _finish, _id, payload|
    log = payload[:log]

    # Send Slack notification for Postmark errors
    if log.is_a?(LogStruct::Log::ActionMailer::Error) &&
       [Postmark::InactiveRecipientError, Postmark::InvalidEmailRequestError].include?(log.error_class)

      InternalSlackNotificationJob.perform_async(
        channel: '#alerts',
        text: "Email delivery error: #{log.message}"
      )
    end
  end
end`}</CodeBlock>

      <HeadingWithAnchor id="error-log-structure" level={2}>
        Error Log Structure
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        When a mailer error occurs, LogStruct creates a{' '}
        <code>LogStruct::Log::ActionMailer::Error</code> with:
      </p>
      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-300 mb-4">
        <li>
          <code>error_class</code> - The exception class (e.g.,{' '}
          <code>Postmark::InactiveRecipientError</code>)
        </li>
        <li>
          <code>message</code> - Formatted message including context and the actual exception
          message
        </li>
        <li>
          <code>backtrace</code> - Stack trace
        </li>
        <li>
          <code>mailer_class</code> - The mailer class name
        </li>
        <li>
          <code>mailer_action</code> - The mailer action/method name
        </li>
        <li>
          <code>to</code>, <code>from</code>, <code>subject</code> - Email metadata
        </li>
        <li>
          <code>attachment_count</code> - Number of attachments
        </li>
        <li>
          <code>additional_data</code> - Custom context (account_id, user_id, etc.)
        </li>
      </ul>

      <HeadingWithAnchor id="error-handling-flow" level={2}>
        Error Handling Flow
      </HeadingWithAnchor>
      <ol className="list-decimal list-inside space-y-2 text-neutral-600 dark:text-neutral-300 mb-4">
        <li>Email delivery fails with an exception</li>
        <li>
          Rails <code>rescue_from</code> catches the exception
        </li>
        <li>
          LogStruct method is called (e.g., <code>log_and_ignore_error</code>)
        </li>
        <li>LogStruct creates structured error log</li>
        <li>Your notification subscriber receives the log</li>
        <li>You send custom notifications based on error type</li>
      </ol>

      <EditPageLink path="docs/app/docs/guides/postmark-error-handling/page.tsx" />
    </div>
  );
}
