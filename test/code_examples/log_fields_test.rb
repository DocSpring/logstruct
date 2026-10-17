# typed: true
# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "net/smtp"

module LogStruct
  module CodeExamples
    # The example lines on the docs' log fields page come from this test: LogStruct's formatter writes
    # them, and the page reads them from docs/app/docs/log-fields/example-lines.json. The test fails when
    # the file doesn't match what LogStruct writes, or when a built-in log type has no example.
    # Rewrite the file (and format it with Biome) with:
    #
    #   UPDATE_LOG_FIELD_EXAMPLES=1 ruby scripts/test.rb test/code_examples/log_fields_test.rb
    class LogFieldsTest < ActiveSupport::TestCase
      EXAMPLES_FILE = File.expand_path("../../docs/app/docs/log-fields/example-lines.json", __dir__)

      COMMON_KEYS = %w[src evt lvl ts].freeze

      # A server whose time zone is UTC
      TIME = Time.new(2026, 10, 17, 9, 30, 15.123r, "+00:00")
      REQUEST_ID = "6f1c9a2e-7b4d-4e8a-9c61-2d5b8f0e4a17"
      JOB_ID = "c2b8e0f4-1d3a-4b6c-9e7f-5a1d2c3b4e5f"
      JID = "b4a9c63e5f1d2a7e9c0f3b18"
      PID = 4821
      USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:131.0) Gecko/20100101 Firefox/131.0"
      BACKTRACE = [
        "app/services/invoice_export.rb:42:in 'InvoiceExport#upload'",
        "app/services/invoice_export.rb:18:in 'InvoiceExport#call'",
        "app/jobs/invoice_export_job.rb:9:in 'InvoiceExportJob#perform'"
      ].freeze

      # A record that ActiveJob arguments can refer to by GlobalID
      class Customer
        include GlobalID::Identification

        attr_reader :id

        def self.name
          "Customer"
        end

        def self.find(id)
          new(id)
        end

        def initialize(id)
          @id = id
        end
      end

      setup do
        @io = setup_isolated_logger
        # The defaults: 16 characters, and a key that isn't the test app's
        LogStruct.config.filters.hash_length = 16
        LogStruct.config.filters.hash_salt = "logstruct-docs-example"
        @saved_global_id_app = GlobalID.app
        GlobalID.app = "my-app"
      end

      teardown do
        GlobalID.app = @saved_global_id_app
        teardown_isolated_logger
      end

      def test_example_lines_match_the_docs
        examples = Time.stub(:now, TIME) { example_lines }
        built_in = log_struct_names.reject { |name| name.end_with?("::BaseFields") }

        assert_equal built_in.sort, examples.keys.sort, "every built-in log type needs an example"

        file = {"lines" => examples, "formats" => Time.stub(:now, TIME) { format_examples }}
        if ENV["UPDATE_LOG_FIELD_EXAMPLES"]
          File.write(EXAMPLES_FILE, "#{JSON.pretty_generate(file)}\n")
          # The docs' lint checks the file's formatting
          docs = File.expand_path("../../docs", __dir__)

          assert system("pnpm", "exec", "biome", "format", "--write", EXAMPLES_FILE, chdir: docs), "biome format failed"
        end

        assert_equal file,
          JSON.parse(File.read(EXAMPLES_FILE)),
          "Run UPDATE_LOG_FIELD_EXAMPLES=1 ruby scripts/test.rb test/code_examples/log_fields_test.rb"
      end

      def test_common_fields
        lines = Time.stub(:now, TIME) { example_lines }.values

        lines.each do |line|
          # In this order on the lines of LogStruct's own types
          assert_equal COMMON_KEYS, line.keys & COMMON_KEYS
          assert_match(/\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}(Z|[+-]\d\d:\d\d)\z/, line["ts"])
          assert_includes %w[debug info warn error fatal unknown], line["lvl"]
          assert line.key?("prog")
        end
        request = lines.find { |line| line["evt"] == "request" }

        assert_equal REQUEST_ID, T.must(request)["req_id"]
        assert_equal "[FILTERED]", T.must(request).dig("params", "user", "password")
      end

      def test_a_logged_hash
        Time.stub(:now, TIME) do
          ::SemanticLogger.named_tagged(request_id: REQUEST_ID) do
            # ----------------------------------------------------------
            # BEGIN CODE EXAMPLE: log_fields_hash
            # ----------------------------------------------------------
            Rails.logger.info(msg: "Invoice sent", invoice_id: 812, email: "Linda.Martinez@example.com")
            # ----------------------------------------------------------
            # END CODE EXAMPLE: log_fields_hash
            # ----------------------------------------------------------
          end
        end
        line = last_line

        assert_equal %w[msg invoice_id email src evt ts lvl prog req_id], line.keys
        assert_equal({"_class" => "String", "_hash" => StringScrubber.value_hash("linda.martinez@example.com")}, line.dig("email", "_filtered"))
      end

      def test_tags_and_context
        Time.stub(:now, TIME) do
          ::SemanticLogger.named_tagged(request_id: REQUEST_ID) do
            # ----------------------------------------------------------
            # BEGIN CODE EXAMPLE: log_fields_tags
            # ----------------------------------------------------------
            Rails.logger.tagged("billing") do
              Rails.logger.tagged(account_id: 42) do
                Rails.logger.info("Charged card")
              end
            end
            # ----------------------------------------------------------
            # END CODE EXAMPLE: log_fields_tags
            # ----------------------------------------------------------
          end
        end
        line = last_line

        assert_equal ["billing"], line["tags"]
        assert_equal({"account_id" => 42}, line["ctx"])
        assert_equal REQUEST_ID, line["req_id"]
      end

      def test_additional_data
        Time.stub(:now, TIME) do
          # ----------------------------------------------------------
          # BEGIN CODE EXAMPLE: log_fields_additional_data
          # ----------------------------------------------------------
          Rails.logger.info(
            LogStruct::Log::Plain.new(
              message: "Imported invoices",
              additional_data: {account_id: 42, rows: 120}
            )
          )
          # ----------------------------------------------------------
          # END CODE EXAMPLE: log_fields_additional_data
          # ----------------------------------------------------------
        end
        line = last_line

        assert_equal %w[src evt lvl ts msg account_id rows prog], line.keys

        # Its keys replace the line's own fields, except the reserved ones
        replaced = LogStruct::Log::Plain.new(message: "Imported", additional_data: {msg: "Replaced"}).serialize

        assert_equal "Replaced", replaced[:msg]
        %i[src evt lvl ts].each do |key|
          error = assert_raises(ArgumentError) do
            LogStruct::Log::Plain.new(message: "Imported", additional_data: {key => "x"}).serialize
          end

          assert_equal "additional_data attempted to overwrite reserved key: #{key}", error.message
        end
      end

      def test_filtered_summaries
        Time.stub(:now, TIME) do
          # ----------------------------------------------------------
          # BEGIN CODE EXAMPLE: log_fields_filtered
          # ----------------------------------------------------------
          Rails.logger.info(
            msg: "Account updated",
            email: "linda.martinez@example.com",
            password: "correct horse battery staple",
            api_tokens: ["tok_8c1f2a", "tok_93d0b7"],
            credentials: {client_id: "my-app", client_secret: "abc123"},
            note: "Call Linda on 555-201-7788"
          )
          # ----------------------------------------------------------
          # END CODE EXAMPLE: log_fields_filtered
          # ----------------------------------------------------------
        end
        line = last_line

        assert_equal({"_class" => "String", "_hash" => StringScrubber.value_hash("linda.martinez@example.com")}, line.dig("email", "_filtered"))
        assert_equal({"_class" => "String"}, line.dig("password", "_filtered"))
        assert_equal({"_class" => "Array", "_count" => 2}, line.dig("api_tokens", "_filtered"))
        assert_equal({"_class" => "Hash", "_keys_count" => 2, "_keys" => %w[client_id client_secret]}, line.dig("credentials", "_filtered"))
        assert_equal "Call Linda on [PHONE]", line["note"]
      end

      def test_truncation
        Time.stub(:now, TIME) do
          # ----------------------------------------------------------
          # BEGIN CODE EXAMPLE: log_fields_limits
          # ----------------------------------------------------------
          # Small limits, to show the markers (the defaults are 100 keys, 10 items and 32 KB).
          # A line's own keys count too: this one has 4.
          LogStruct.configure do |config|
            config.limits.max_hash_keys = 4
            config.limits.max_array_items = 3
            config.limits.max_string_bytes = 24
          end

          Rails.logger.info(
            msg: "Import finished",
            columns: {first_name: "First name", last_name: "Last name", city: "City", country: "Country", zip: "Postcode"},
            row_ids: [101, 102, 103, 104, 105, 106, 107, 108],
            summary: "Rows 104 and 107 had no postcode"
          )
          # ----------------------------------------------------------
          # END CODE EXAMPLE: log_fields_limits
          # ----------------------------------------------------------
        end
        line = last_line

        assert_equal({"first_name" => "First name", "last_name" => "Last name", "city" => "City", "country" => "Country", "_more_keys" => 1}, line["columns"])
        assert_equal [101, 102, 103, "... and 5 more items"], line["row_ids"]
        assert_equal "Rows 104 and 107 had no ... (cut from 32 bytes)", line["summary"]
      end

      def test_default_limits
        limits = LogStruct::ConfigStruct::Limits.new

        assert_equal 100, limits.max_hash_keys
        assert_equal 10, limits.max_array_items
        assert_equal 20, limits.max_backtrace_lines
        assert_equal 32_768, limits.max_string_bytes

        backtrace = (1..120).map { |number| "app/models/invoice.rb:#{number}:in 'Invoice#total'" }
        Rails.logger.info(msg: "Trace", trace: backtrace)

        assert_equal "... and 100 more lines", last_line["trace"].last

        # An error line's backtrace has the same limit
        Rails.logger.error(LogStruct::Log::Error.new(source: Source::App, error_class: RuntimeError, message: "Failed", backtrace: backtrace))

        assert_equal 21, last_line["backtrace"].size
      end

      private

      # LogStruct's log types, as the docs' generated list has them
      def log_struct_names
        ObjectSpace.each_object(Class).filter_map do |klass|
          name = klass.name
          name if klass < T::Struct && name&.start_with?("LogStruct::Log::")
        end
      end

      def last_line
        ::SemanticLogger.flush
        JSON.parse(T.must(@io.string.lines.last))
      end

      # The line a block writes
      def written
        clear_log_buffer(@io)
        yield
        ::SemanticLogger.flush
        lines = @io.string.lines

        assert_equal 1, lines.size, "expected one line, got: #{@io.string}"
        JSON.parse(T.must(lines.first))
      end

      def in_request(&block)
        ::SemanticLogger.named_tagged(request_id: REQUEST_ID, &block)
      end

      def in_sidekiq_job(job_class, &block)
        ::SemanticLogger.named_tagged(sidekiq_context: {jid: JID, class: job_class}, &block)
      end

      def rails
        Rails.logger
      end

      def logger(name)
        LogStruct::SemanticLogger::Logger.new(name)
      end

      # Each built-in log type, with the values its integration sets
      def example_lines
        @lines = {}

        mail = {
          to: ["linda.martinez@example.com"],
          from: "billing@example.com",
          subject: "Your October invoice",
          mailer_class: "InvoiceMailer",
          mailer_action: "monthly",
          attachment_count: 1,
          additional_data: {account_id: 42, user_id: 1873}
        }
        example(Log::ActionMailer::Delivery) { in_request { rails.info(Log::ActionMailer::Delivery.new(**mail)) } }
        example(Log::ActionMailer::Delivered) do
          in_request { rails.info(Log::ActionMailer::Delivered.new(**mail, message_id: "6710e3a7c41b2_1f2e3d4c5b6a@web-1.mail")) }
        end
        example(Log::ActionMailer::Error) do
          in_sidekiq_job("ActionMailer::MailDeliveryJob") do
            rails.error(Log::ActionMailer::Error.new(
              **mail,
              error_class: Net::SMTPAuthenticationError,
              message: "Net::SMTPAuthenticationError: Email delivery failed. Recipients: billing@example.com. " \
                "Error message: 535 5.7.8 Authentication failed",
              backtrace: ["app/mailers/invoice_mailer.rb:12:in 'InvoiceMailer#monthly'"]
            ))
          end
        end

        job = {
          job_id: JOB_ID,
          job_class: "InvoiceExportJob",
          queue_name: :default,
          arguments: [Customer.new(1873), {month: "2026-09", email: "linda.martinez@example.com"}],
          provider_job_id: JID
        }
        example(Log::ActiveJob::Enqueue) { in_request { rails.info(Log::ActiveJob::Enqueue.new(**job, executions: 0)) } }
        example(Log::ActiveJob::Schedule) do
          in_request { rails.info(Log::ActiveJob::Schedule.new(**job, executions: 0, scheduled_at: TIME + 3600)) }
        end
        example(Log::ActiveJob::Start) do
          in_sidekiq_job("InvoiceExportJob") { rails.info(Log::ActiveJob::Start.new(**job, executions: 1, started_at: TIME, attempt: 1)) }
        end
        example(Log::ActiveJob::Finish) do
          in_sidekiq_job("InvoiceExportJob") do
            # The line's ts is the time the job finished
            finished_at = TIME + 0.812r
            rails.info(Log::ActiveJob::Finish.new(**job, executions: 1, duration_ms: 812.43, finished_at:, timestamp: finished_at))
          end
        end
        # retry_on caught the exception and enqueued the job again, after its wait (3 seconds by default)
        example(Log::ActiveJob::Retry) do
          in_sidekiq_job("InvoiceExportJob") do
            rails.info(Log::ActiveJob::Retry.new(
              **job,
              executions: 1,
              error_class: Net::ReadTimeout,
              message: "Net::ReadTimeout with #<TCPSocket:(closed)>",
              wait_ms: 3000.0
            ))
          end
        end
        # retry_on caught the exception again after the last of its 5 attempts
        example(Log::ActiveJob::RetryStopped) do
          in_sidekiq_job("InvoiceExportJob") do
            rails.error(Log::ActiveJob::RetryStopped.new(
              **job,
              executions: 5,
              error_class: Net::ReadTimeout,
              message: "Net::ReadTimeout with #<TCPSocket:(closed)>"
            ))
          end
        end
        # discard_on caught the exception and dropped the job
        example(Log::ActiveJob::Discard) do
          in_sidekiq_job("InvoiceExportJob") do
            rails.error(Log::ActiveJob::Discard.new(
              **job,
              executions: 1,
              error_class: ::ActiveJob::DeserializationError,
              message: "Error while trying to deserialize arguments: Couldn't find Customer"
            ))
          end
        end
        example(Log::ActiveJob::Error) do
          in_sidekiq_job("InvoiceExportJob") do
            rails.error(Log::ActiveJob::Error.new(
              **job,
              executions: 1,
              error_class: Net::ReadTimeout,
              message: "Net::ReadTimeout with #<TCPSocket:(closed)>",
              backtrace: BACKTRACE
            ))
          end
        end

        example(Log::ActiveModelSerializers) do
          in_request do
            rails.info(Log::ActiveModelSerializers.new(
              message: "ams.render",
              serializer: "InvoiceSerializer",
              adapter: "ActiveModelSerializers::Adapter::Attributes",
              resource_class: "Invoice",
              duration_ms: 1.241
            ))
          end
        end

        blob = {storage: :S3, file_id: "m3k9x2q7w1c8v4b6n0z5h2j7"}
        example(Log::ActiveStorage::Upload) do
          in_request { rails.info(Log::ActiveStorage::Upload.new(**blob, checksum: "3Ys4l0pZ8wQ1mH7cE2uXrA==", duration_ms: 184.3)) }
        end
        example(Log::ActiveStorage::Download) { in_request { rails.info(Log::ActiveStorage::Download.new(**blob, duration_ms: 96.12)) } }
        example(Log::ActiveStorage::Delete) { rails.info(Log::ActiveStorage::Delete.new(**blob)) }
        example(Log::ActiveStorage::Metadata) { rails.info(Log::ActiveStorage::Metadata.new(**blob)) }
        # Existence checks and URLs are logged at debug level, as Rails logs them
        example(Log::ActiveStorage::Exist) { in_request { rails.debug(Log::ActiveStorage::Exist.new(**blob, exist: true)) } }
        example(Log::ActiveStorage::Url) { in_request { rails.debug(Log::ActiveStorage::Url.new(**blob)) } }

        example(Log::Ahoy) do
          in_request { rails.info(Log::Ahoy.new(message: "ahoy.track", ahoy_event: "Viewed invoice", properties: {invoice_id: 812})) }
        end

        stored_file = {
          storage: :file,
          file_id: "avatar.png",
          uploader: "AvatarUploader",
          model: "User",
          mount_point: "avatar",
          version: "",
          store_path: "uploads/user/avatar/1873/avatar.png",
          extension: "png"
        }
        upload = {**stored_file, filename: "avatar.png", mime_type: "image/png", size: 48_213}
        example(Log::CarrierWave::Upload) { in_request { rails.info(Log::CarrierWave::Upload.new(**upload, duration_ms: 12.7)) } }
        # A remote URL fetched into the cache (remote_avatar_url=)
        example(Log::CarrierWave::Download) { in_request { rails.info(Log::CarrierWave::Download.new(**upload)) } }
        example(Log::CarrierWave::Delete) { in_request { rails.info(Log::CarrierWave::Delete.new(**stored_file)) } }

        example(Log::Dotenv::Load) { rails.info(Log::Dotenv::Load.new(file: ".env")) }
        example(Log::Dotenv::Update) { rails.debug(Log::Dotenv::Update.new(vars: %w[DATABASE_URL REDIS_URL])) }
        example(Log::Dotenv::Save) { rails.info(Log::Dotenv::Save.new(snapshot: true)) }
        example(Log::Dotenv::Restore) { rails.info(Log::Dotenv::Restore.new(vars: %w[DATABASE_URL REDIS_URL])) }

        # Rails.logger.error("Import failed", error)
        example(Log::Error) do
          in_request do
            rails.error(Log::Error.new(
              source: Source::App,
              error_class: JSON::ParserError,
              message: "Import failed",
              error_message: "unexpected end of input",
              backtrace: [
                "app/services/invoice_import.rb:27:in 'InvoiceImport#parse'",
                "app/controllers/imports_controller.rb:11:in 'ImportsController#create'"
              ]
            ))
          end
        end

        good_job = logger("GoodJob")
        example(Log::GoodJob::Log) do
          good_job.info(Log::GoodJob::Log.new(message: "Notifier subscribed with LISTEN", process_id: PID, thread_id: "2ix4"))
        end
        example(Log::GoodJob::Error) do
          good_job.error(Log::GoodJob::Error.new(
            error_class: "ActiveRecord::ConnectionNotEstablished",
            error_message: "connection to server at \"10.0.3.12\", port 5432 failed: Connection refused",
            backtrace: ["good_job/notifier.rb:225:in 'GoodJob::Notifier#with_connection'"],
            process_id: PID,
            thread_id: "2ix4",
            level: Level::Error
          ))
        end

        example(Log::Plain) { in_request { rails.info(Log::Plain.new(message: "Exported 120 invoices")) } }

        example(Log::Puma::Start) do
          rails.info(Log::Puma::Start.new(
            mode: "single",
            puma_version: "6.6.1",
            puma_codename: "Return to Forever",
            ruby_version: "ruby 3.4.5 (2025-07-16 revision 20cda200d3) +PRISM [x86_64-linux]",
            min_threads: 3,
            max_threads: 3,
            environment: "production",
            process_id: 1,
            listening_addresses: ["http://0.0.0.0:3000"]
          ))
        end
        example(Log::Puma::Shutdown) { rails.info(Log::Puma::Shutdown.new(process_id: 1)) }
        # An exception that got past the Rails app
        example(Log::Puma::Error) do
          rails.error(Log::Puma::Error.new(
            error_class: NoMethodError,
            message: "undefined method 'call' for nil",
            backtrace: ["config/initializers/health_check.rb:8:in 'HealthCheck#call'"],
            error_context: "Rack app",
            http_method: "GET",
            path: "/up"
          ))
        end

        # Lograge's line, with the params Rails' filter_parameters have already filtered
        example(Log::Request) do
          in_request do
            rails.info(Log::Request.new(
              http_method: "POST",
              path: "/users/sign_in",
              source_ip: "198.51.100.23",
              host: "app.example.com",
              format: :html,
              controller: "Users::SessionsController",
              action: "create",
              status: 302,
              duration_ms: 48.21,
              view: 0.0,
              database: 3.62,
              params: {authenticity_token: "[FILTERED]", user: {email: "[FILTERED]", password: "[FILTERED]", remember_me: "1"}, commit: "Log in"},
              user_agent: USER_AGENT,
              referer: "https://app.example.com/users/sign_in",
              content_type: "application/x-www-form-urlencoded",
              accept: "text/html,application/xhtml+xml"
            ))
          end
        end

        example(Log::SQL) do
          in_request do
            rails.info(Log::SQL.new(
              message: "Invoice Load executed",
              sql: "SELECT \"invoices\".* FROM \"invoices\" WHERE \"invoices\".\"account_id\" = $1",
              name: "Invoice Load",
              duration_ms: 142.37,
              row_count: 120,
              adapter: "PostgreSQLAdapter",
              database_name: "app_production",
              connection_pool_size: 5,
              active_connections: 2,
              operation_type: "SELECT",
              table_names: ["invoices"]
            ))
          end
        end

        # HostAuthorization runs before the request ID middleware
        example(Log::Security::BlockedHost) do
          rails.warn(Log::Security::BlockedHost.new(
            message: "Blocked host detected: admin.example.net",
            blocked_host: "admin.example.net",
            path: "/",
            http_method: "GET",
            source_ip: "203.0.113.7",
            user_agent: "curl/8.7.1",
            blocked_hosts: ["admin.example.net"]
          ))
        end
        example(Log::Security::CSRFViolation) do
          in_request do
            rails.error(Log::Security::CSRFViolation.new(
              path: "/invoices/812",
              http_method: "PATCH",
              source_ip: "198.51.100.23",
              user_agent: USER_AGENT,
              referer: "https://app.example.com/invoices/812/edit",
              message: "Can't verify CSRF token authenticity."
            ))
          end
        end
        example(Log::Security::IPSpoof) do
          in_request do
            rails.warn(Log::Security::IPSpoof.new(
              path: "/login",
              http_method: "GET",
              user_agent: USER_AGENT,
              message: "IP spoofing attack?! HTTP_CLIENT_IP=\"203.0.113.9\" HTTP_X_FORWARDED_FOR=\"198.51.100.4\"",
              source_ip: "10.0.1.15",
              client_ip: "203.0.113.9",
              x_forwarded_for: "198.51.100.4"
            ))
          end
        end

        stored = {storage: :store, location: "invoice/812/original-3f9a1c.pdf"}
        example(Log::Shrine::Upload) do
          in_request do
            rails.info(Log::Shrine::Upload.new(**stored, uploader: "DocumentUploader", upload_options: {}, options: {}, duration_ms: 143.8))
          end
        end
        example(Log::Shrine::Download) { in_request { rails.info(Log::Shrine::Download.new(**stored, download_options: {})) } }
        example(Log::Shrine::Delete) { rails.info(Log::Shrine::Delete.new(**stored)) }
        example(Log::Shrine::Metadata) { in_request { rails.info(Log::Shrine::Metadata.new(storage: :cache)) } }
        example(Log::Shrine::Exist) { rails.info(Log::Shrine::Exist.new(**stored)) }

        example(Log::Sidekiq::Log) do
          in_sidekiq_job("InvoiceSyncWorker") do
            logger("Sidekiq-Server").info(Log::Sidekiq::Log.new(
              message: "start",
              process_id: PID,
              thread_id: "1v8b",
              context: {class: "InvoiceSyncWorker", jid: JID}
            ))
          end
        end
        example(Log::Sidekiq::Error) do
          in_sidekiq_job("InvoiceSyncWorker") do
            rails.warn(Log::Sidekiq::Error.new(
              error_class: Timeout::Error,
              message: "execution expired",
              backtrace: ["app/workers/invoice_sync_worker.rb:15:in 'InvoiceSyncWorker#perform'"],
              error_context: "Job raised exception",
              queue_name: "default",
              retry_count: 2
            ))
          end
        end

        @lines
      end

      def example(log_class, &block)
        @lines[log_class.name] = written(&block)
      end

      # The lines from the code examples above
      def format_examples
        {
          "hash" => written {
            in_request { Rails.logger.info(msg: "Invoice sent", invoice_id: 812, email: "Linda.Martinez@example.com") }
          },
          "tags" => written {
            in_request do
              Rails.logger.tagged("billing") { Rails.logger.tagged(account_id: 42) { Rails.logger.info("Charged card") } }
            end
          },
          "additional_data" => written {
            Rails.logger.info(LogStruct::Log::Plain.new(message: "Imported invoices", additional_data: {account_id: 42, rows: 120}))
          },
          "filtered" => written {
            Rails.logger.info(
              msg: "Account updated",
              email: "linda.martinez@example.com",
              password: "correct horse battery staple",
              api_tokens: ["tok_8c1f2a", "tok_93d0b7"],
              credentials: {client_id: "my-app", client_secret: "abc123"},
              note: "Call Linda on 555-201-7788"
            )
          },
          "limits" => limited_line
        }
      end

      # The line from the limits example (the test's configuration is put back after each test)
      def limited_line
        limits = LogStruct.config.limits
        limits.max_hash_keys = 4
        limits.max_array_items = 3
        limits.max_string_bytes = 24
        written do
          Rails.logger.info(
            msg: "Import finished",
            columns: {first_name: "First name", last_name: "Last name", city: "City", country: "Country", zip: "Postcode"},
            row_ids: [101, 102, 103, 104, 105, 106, 107, 108],
            summary: "Rows 104 and 107 had no postcode"
          )
        end
      end
    end
  end
end
