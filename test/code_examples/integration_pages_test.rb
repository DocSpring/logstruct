# typed: true
# frozen_string_literal: true

require "test_helper"
require "net/smtp"
require "action_controller"
require "action_controller/metal/request_forgery_protection"
require "active_job"
require "action_mailer"

module LogStruct
  module CodeExamples
    # The settings and code shown on the integration pages (docs/app/docs/integrations/*)
    class IntegrationPagesTest < ActiveSupport::TestCase
      # Raises the error a test sets, like an SMTP server that rejects a mail
      class RejectingDelivery
        class << self
          attr_accessor :error
        end

        def initialize(_settings)
        end

        def deliver!(_mail)
          raise T.must(self.class.error)
        end
      end
      ::ActionMailer::Base.add_delivery_method :logstruct_rejecting, RejectingDelivery

      class ApplicationMailer < ::ActionMailer::Base
        default from: "notifications@example.com"
        self.delivery_method = :logstruct_rejecting
      end

      # ----------------------------------------------------------
      # BEGIN CODE EXAMPLE: action_mailer_rescue_from
      # ----------------------------------------------------------
      class NotificationMailer < ApplicationMailer
        # Log the error, then carry on as if the mail had been sent
        rescue_from Net::SMTPFatalError, with: :log_and_ignore_error

        # Log the error and report it, then carry on as if the mail had been sent
        rescue_from Net::SMTPServerBusy, with: :log_and_report_error

        # Other StandardErrors reach LogStruct's default handler, log_and_reraise_error, which logs and raises
        # them (reporting them too where error_handling_modes.standard_errors reports errors)

        def invoice_ready(user)
          mail(to: user.email, subject: "Your invoice is ready", body: "Your invoice is ready.")
        end
      end
      # ----------------------------------------------------------
      # END CODE EXAMPLE: action_mailer_rescue_from
      # ----------------------------------------------------------

      class WelcomeMailer < ::ActionMailer::Base
        default from: "notifications@example.com"
        self.delivery_method = :test

        def welcome(user, team)
          @user = user
          @team = team
          mail(to: user.email, subject: "Welcome", body: "Welcome!")
        end
      end

      # ----------------------------------------------------------
      # BEGIN CODE EXAMPLE: active_job_log_arguments
      # ----------------------------------------------------------
      class ImportJob < ActiveJob::Base
        # Leave this job's arguments out of its job lines
        self.log_arguments = false

        def perform(file_url, api_token)
        end
      end
      # ----------------------------------------------------------
      # END CODE EXAMPLE: active_job_log_arguments
      # ----------------------------------------------------------

      class InvoiceJob < ::ActiveJob::Base
        def perform(invoice_id)
        end
      end

      User = Struct.new(:id, :email)
      Team = Struct.new(:id)

      setup do
        @io = setup_isolated_logger
        @saved_job_logger = ::ActiveJob::Base.logger
        ::ActiveJob::Base.logger = LogStruct::SemanticLogger::Logger.new("Rails")
        @reported = []
        reported = @reported
        LogStruct.config.error_reporting_handler = ->(error, _context, source) { reported << [error.class, source] }
      end

      teardown do
        ::ActiveJob::Base.logger = @saved_job_logger
        teardown_isolated_logger
      end

      def test_sidekiq_configuration
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: sidekiq_configuration
        # ----------------------------------------------------------
        LogStruct.configure do |config|
          # On by default. false keeps Sidekiq's own logger and error handler.
          config.integrations.enable_sidekiq = false
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: sidekiq_configuration
        # ----------------------------------------------------------

        assert LogStruct::Configuration.new.integrations.enable_sidekiq
        assert_nil LogStruct::Integrations::Sidekiq.setup(LogStruct.config)
      end

      def test_good_job_configuration
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: good_job_configuration
        # ----------------------------------------------------------
        LogStruct.configure do |config|
          # On by default. false keeps GoodJob's own logger and error lines.
          config.integrations.enable_goodjob = false
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: good_job_configuration
        # ----------------------------------------------------------

        assert LogStruct::Configuration.new.integrations.enable_goodjob
        refute LogStruct.config.integrations.enable_goodjob
        assert_nil LogStruct::Integrations::GoodJob.setup(LogStruct.config)
      end

      def test_active_job_configuration
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: active_job_configuration
        # ----------------------------------------------------------
        LogStruct.configure do |config|
          # On by default. false keeps Rails' own ActiveJob log lines.
          config.integrations.enable_activejob = false
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: active_job_configuration
        # ----------------------------------------------------------

        assert LogStruct::Configuration.new.integrations.enable_activejob
        assert_nil LogStruct::Integrations::ActiveJob.setup(LogStruct.config)
      end

      def test_active_job_log_arguments
        ImportJob.perform_now("https://files.example.com/import.csv", "tok_live_123456")
        InvoiceJob.perform_now(42)

        lines = logged_lines.select { |line| line["src"] == "job" }
        import_lines = lines.select { |line| line["job_class"] == ImportJob.name }
        invoice_lines = lines.select { |line| line["job_class"] == InvoiceJob.name }

        assert_equal %w[start finish], import_lines.map { |line| line["evt"] }
        import_lines.each { |line| refute line.key?("arguments"), line.inspect }
        assert_equal [[42], [42]], invoice_lines.map { |line| line["arguments"] }
        refute_includes @io.string, "tok_live_123456"
      end

      def test_action_mailer_configuration
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: action_mailer_configuration
        # ----------------------------------------------------------
        LogStruct.configure do |config|
          # On by default
          config.integrations.enable_actionmailer = true

          # Instance variables whose IDs are added to each mail line
          # (default: {account: :account_id, user: :user_id})
          config.integrations.actionmailer_id_mapping = {account: :account_id, user: :user_id, team: :team_id}

          # Write email addresses as [EMAIL:<hash>] (default: true)
          config.filters.email_addresses = true
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: action_mailer_configuration
        # ----------------------------------------------------------

        # Mailer actions are class methods through ActionMailer's method_missing, which Sorbet can't see
        T.unsafe(WelcomeMailer).welcome(User.new(12, "user@example.com"), Team.new(7)).deliver_now

        delivery, delivered = logged_lines.select { |line| line["src"] == "mailer" }

        assert_equal %w[delivery delivered], [T.must(delivery)["evt"], T.must(delivered)["evt"]]
        assert_equal [12, 7], T.must(delivered).values_at("user_id", "team_id")
        assert_match(/\A\[EMAIL:[0-9a-f]+\]\z/, T.must(delivered)["to"].first)
        refute_includes @io.string, "user@example.com"
      end

      def test_action_mailer_rescue_from
        user = User.new(12, "user@example.com")

        # log_and_ignore_error: one error line, no delivered line, nothing raised or reported
        RejectingDelivery.error = Net::SMTPFatalError.new("550 5.1.1 mailbox unavailable")
        invoice_ready(user).deliver_now

        assert_equal %w[delivery error], mailer_events
        assert_empty @reported

        # log_and_report_error: one error line, reported, nothing raised, in any mode
        RejectingDelivery.error = Net::SMTPServerBusy.new("451 4.3.0 try again later")
        invoice_ready(user).deliver_now

        assert_equal %w[delivery error], mailer_events
        assert_equal [[Net::SMTPServerBusy, LogStruct::Source::Mailer]], @reported

        # Other errors: LogStruct's default handler logs and raises them, in Raise mode (the default for
        # standard errors) without reporting them ...
        @reported.clear
        RejectingDelivery.error = Errno::ECONNREFUSED.new("connect(2) for smtp.example.com port 587")
        assert_raises(Errno::ECONNREFUSED) { invoice_ready(user).deliver_now }
        assert_equal %w[delivery error], mailer_events
        assert_empty @reported

        # ... and in Report mode reporting them too
        LogStruct.config.error_handling_modes.standard_errors = LogStruct::ErrorHandlingMode::Report
        assert_raises(Errno::ECONNREFUSED) { invoice_ready(user).deliver_now }
        assert_equal %w[delivery error], mailer_events
        assert_equal [[Errno::ECONNREFUSED, LogStruct::Source::Mailer]], @reported
      end

      def test_sql_configuration
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: sql_configuration
        # ----------------------------------------------------------
        LogStruct.configure do |config|
          # Off by default
          config.integrations.enable_sql_logging = true

          # Log queries that take at least this many milliseconds, as a Float
          # (default: 100.0; 0 or nil logs every query)
          config.integrations.sql_slow_query_threshold = 250.0

          # Log bind values (default: true unless Rails.env is "production")
          config.integrations.sql_log_bind_params = false
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: sql_configuration
        # ----------------------------------------------------------

        payload = {sql: "SELECT \"users\".* FROM \"users\" WHERE \"users\".\"id\" = ?", name: "User Load", binds: [], type_casted_binds: [42]}
        LogStruct::Integrations::ActiveRecord.handle_sql_event("sql.active_record", 0.0, 0.1, "1", payload)
        LogStruct::Integrations::ActiveRecord.handle_sql_event("sql.active_record", 0.0, 0.3, "2", payload)

        lines = logged_lines.select { |line| line["evt"] == "database" }

        assert_equal 1, lines.size
        assert_equal ["User Load", 300.0, "SELECT", ["users"]], T.must(lines.first).values_at("name", "duration_ms", "op_type", "table_names")
        refute T.must(lines.first).key?("bind_params")
      end

      def test_security_configuration
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: security_configuration
        # ----------------------------------------------------------
        LogStruct.configure do |config|
          # Blocked host lines (on by default)
          config.integrations.enable_host_authorization = true

          # CSRF and IP spoofing lines (on by default)
          config.integrations.enable_rack_error_handler = true

          # Log CSRF and IP spoofing errors and report them to your error tracker (the default).
          # Log writes the line without reporting the error.
          config.error_handling_modes.security_errors = LogStruct::ErrorHandlingMode::Report
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: security_configuration
        # ----------------------------------------------------------

        request = ::ActionDispatch::Request.new(Rack::MockRequest.env_for("/comments", method: "POST"))
        error_lines = LogStruct::Integrations::RackErrorHandler::ErrorLines
        error_lines.intercept(request, ::ActionController::InvalidAuthenticityToken.new("Can't verify CSRF token authenticity."))

        LogStruct.config.error_handling_modes.security_errors = LogStruct::ErrorHandlingMode::Log
        error_lines.intercept(request, ::ActionController::InvalidAuthenticityToken.new("Can't verify CSRF token authenticity."))

        lines = logged_lines.select { |line| line["src"] == "security" }

        assert_equal [%w[csrf_violation error /comments POST]] * 2, lines.map { |line| line.values_at("evt", "lvl", "path", "method") }
        assert_equal [[::ActionController::InvalidAuthenticityToken, LogStruct::Source::Security]], @reported
      end

      private

      def logged_lines
        ::SemanticLogger.flush
        @io.string.lines.filter_map do |line|
          JSON.parse(line)
        rescue JSON::ParserError
          nil
        end
      end

      # Mailer actions are class methods through ActionMailer's method_missing, which Sorbet can't see
      def invoice_ready(user)
        T.unsafe(NotificationMailer).invoice_ready(user)
      end

      # The mailer lines logged since the last call
      def mailer_events
        events = logged_lines.select { |line| line["src"] == "mailer" }.map { |line| line["evt"] }
        clear_log_buffer(@io)
        events
      end
    end
  end
end
