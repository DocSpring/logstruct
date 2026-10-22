# typed: true
# frozen_string_literal: true

# cspell:ignore jdoe iban IBANs Ghpcy Bpcy

require "test_helper"
require "minitest/mock"

module LogStruct
  module CodeExamples
    # The examples on the docs' Filtering Sensitive Data page. The page's example lines, its lists of key
    # names and its table of scrubbed strings are read from the page and checked against what LogStruct
    # writes: docs/app/docs/filtering-sensitive-data/page.tsx
    class FilteringTest < ActiveSupport::TestCase
      include DocsPage

      PAGE = File.expand_path("../../docs/app/docs/filtering-sensitive-data/page.tsx", __dir__)

      # A server whose time zone is UTC
      TIME = Time.new(2026, 10, 17, 9, 30, 15.123r, "+00:00")

      Bind = Struct.new(:name)

      # The list in a new Rails 8 app's config/initializers/filter_parameter_logging.rb
      RAILS_8_FILTER_PARAMETERS = %i[passw email secret token _key crypt salt certificate otp ssn cvv cvc].freeze

      setup do
        @io = setup_isolated_logger
        # LogStruct's defaults, without the test app's filter_parameters
        filters = LogStruct.config.filters
        defaults = ConfigStruct::Filters.new
        filters.filter_keys = defaults.filter_keys
        filters.filter_keys_with_hashes = defaults.filter_keys_with_hashes
        filters.filter_matchers = defaults.filter_matchers
        filters.path_matchers = defaults.path_matchers
        # The default length, and a key that isn't the test app's
        filters.hash_length = 16
        filters.hash_salt = "logstruct-docs-example"
      end

      teardown do
        teardown_isolated_logger
      end

      def test_filtered_values
        Time.stub(:now, TIME) do
          # ----------------------------------------------------------
          # BEGIN CODE EXAMPLE: filtering_filtered_values
          # ----------------------------------------------------------
          Rails.logger.info(
            msg: "Password changed",
            user_id: 1873,
            email: "Linda.Martinez@example.com",
            password: "correct horse battery staple",
            otp: 482113,
            api_tokens: ["tok_8c1f2a", "tok_93d0b7"],
            credentials: {client_id: "my-app", client_secret: "abc123"}
          )
          # ----------------------------------------------------------
          # END CODE EXAMPLE: filtering_filtered_values
          # ----------------------------------------------------------
        end

        assert_equal page_json("FILTERED_VALUES_LINE"), last_line
      end

      def test_other_summaries
        formatter = Formatter.new

        assert_equal({_filtered: {_class: "Hash", _empty: true}}, formatter.process_values({credentials: {}})[:credentials])
        assert_equal({_filtered: {_class: "Array", _empty: true}}, formatter.process_values({tokens: []})[:tokens])
        assert_equal({_filtered: {_class: NilClass}}, formatter.process_values({password: nil})[:password])
        summary = formatter.process_values({credentials: (1..12).to_h { |i| [:"key#{i}", i] }})

        assert_equal 12, summary.dig(:credentials, :_filtered, :_keys_count)
        email_key = formatter.process_values({credentials: {"linda@example.com" => 1}})

        assert_equal({_class: Hash, _keys_count: 1}, email_key.dig(:credentials, :_filtered))
        # A value Rails' parameter filter has already replaced stays as it is, with no hash
        assert_equal({email: "[FILTERED]", password: "[FILTERED]"}, formatter.process_values({email: "[FILTERED]", password: "[FILTERED]"}))
        # At any depth, and in Arrays
        nested = formatter.process_values({user: {profile: {password: "x"}}, items: [{token: "y"}]})

        assert_equal({_filtered: {_class: String}}, nested.dig(:user, :profile, :password))
        assert_equal({_filtered: {_class: String}}, T.must(nested[:items]).first[:token])
      end

      def test_default_filter_keys
        defaults = ConfigStruct::Filters.new

        assert_equal page_strings("DEFAULT_FILTER_KEYS").map(&:to_sym), defaults.filter_keys
        assert_equal page_strings("DEFAULT_HASHED_KEYS").map(&:to_sym), defaults.filter_keys_with_hashes
        # filter_keys entries match a key's name or its words, not part of a key
        %w[credit_card creditCard Credit-Card CREDIT_CARD pw PW].each do |key|
          assert ParamFilters.should_filter_key?(key), "#{key} should be filtered"
        end
        LogStruct.config.filters.filter_matchers = []

        refute ParamFilters.should_filter_key?("credit_card_number")
        LogStruct.config.filters.filter_keys += [:_key]

        refute ParamFilters.should_filter_key?("cron_key")
      end

      def test_default_key_pattern
        (page_strings("PATTERN_FILTERED_KEYS") + page_strings("PATTERN_OVERMATCHED_KEYS")).each do |key|
          assert ParamFilters.should_filter_key?(key), "#{key} should be filtered by default"
        end
        (page_strings("PATTERN_UNFILTERED_KEYS") + page_strings("RAILS_FILTERED_KEYS")).each do |key|
          refute ParamFilters.should_filter_key?(key), "#{key} shouldn't be filtered by default"
        end
      end

      def test_rails_filter_parameters
        saved = ::Rails.application.config.filter_parameters
        ::Rails.application.config.filter_parameters = RAILS_8_FILTER_PARAMETERS.dup
        LogStruct.merge_rails_filter_parameters!

        assert_equal page_strings("RAILS_8_FILTER_PARAMETERS").map(&:to_sym), RAILS_8_FILTER_PARAMETERS
        page_strings("RAILS_FILTERED_KEYS").each do |key|
          assert ParamFilters.should_filter_key?(key), "#{key} should be filtered with Rails 8's filter_parameters"
        end
        # Partial matches skip LogStruct's own fields at the top of a line
        line = Formatter.new.process_values({cron_key: "nightly", arguments: [{cron_key: "nightly"}]})

        assert_equal "nightly", line[:cron_key]
        assert_equal({_filtered: {_class: String}}, T.must(line[:arguments]).first[:cron_key])
        # A key Rails' :email filters, but that isn't in filter_keys_with_hashes, gets no hash
        assert_equal({_filtered: {_class: String}}, Formatter.new.process_values({user_email: "linda@example.com"})[:user_email])
      ensure
        ::Rails.application.config.filter_parameters = saved
      end

      def test_hashed_values
        Time.stub(:now, TIME) do
          # ----------------------------------------------------------
          # BEGIN CODE EXAMPLE: filtering_hashed_values
          # ----------------------------------------------------------
          Rails.logger.info(
            msg: "Sent a password reset link to Linda.Martinez@example.com",
            email: "linda.martinez@example.com",
            reply_to: "support@example.com"
          )
          # ----------------------------------------------------------
          # END CODE EXAMPLE: filtering_hashed_values
          # ----------------------------------------------------------
        end
        line = last_line

        assert_equal page_json("HASHED_VALUES_LINE"), line
        # One hash per address, however it's capitalized, in a string and under a filtered key
        assert_equal "Sent a password reset link to [EMAIL:#{line.dig("email", "_filtered", "_hash")}]", line["msg"]
        # Other values are hashed as they are
        refute_equal StringScrubber.value_hash("JDoe"), StringScrubber.value_hash("jdoe")
      end

      def test_hash_key
        ClimateControl.modify(LOGSTRUCT_HASH_KEY: "a-long-random-secret") do
          # ----------------------------------------------------------
          # BEGIN CODE EXAMPLE: filtering_hash_salt
          # ----------------------------------------------------------
          LogStruct.configure do |config|
            # The key for the hashes. Without it, LogStruct derives one from secret_key_base.
            config.filters.hash_salt = ENV.fetch("LOGSTRUCT_HASH_KEY")
          end
          # ----------------------------------------------------------
          # END CODE EXAMPLE: filtering_hash_salt
          # ----------------------------------------------------------
        end
        with_salt = StringScrubber.value_hash("linda@example.com")

        assert_equal OpenSSL::HMAC.hexdigest("SHA256", "a-long-random-secret", "linda@example.com")[0...16], with_salt

        # Without hash_salt, a key derived from the app's secret_key_base
        LogStruct.config.filters.hash_salt = nil
        HashUtils.reset!
        derived = ::Rails.application.key_generator.generate_key("LogStruct hashed values", 32)

        assert_equal OpenSSL::HMAC.hexdigest("SHA256", derived, "linda@example.com")[0...16], StringScrubber.value_hash("linda@example.com")
      ensure
        HashUtils.reset!
      end

      def test_adding_keys
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: filtering_adding_keys
        # ----------------------------------------------------------
        LogStruct.configure do |config|
          # Filter these keys too. Keys match by their words, so :date_of_birth also filters
          # dateOfBirth and Date-Of-Birth, but not date_of_birth_verified.
          config.filters.filter_keys += [:date_of_birth, :pin]

          # Filter these keys and log a hash of their String values, as for email
          config.filters.filter_keys_with_hashes += [:phone]

          # A rule for key names: it gets each key as a String, and its value
          config.filters.filter_matchers << LogStruct::ConfigStruct::FilterMatcher.new(
            callable: ->(key, _value) { key.end_with?("_iban") },
            label: "IBANs"
          )
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: filtering_adding_keys
        # ----------------------------------------------------------

        assert ParamFilters.should_filter_key?("dateOfBirth")
        assert ParamFilters.should_filter_key?("Date-Of-Birth")
        refute ParamFilters.should_filter_key?("date_of_birth_verified")
        assert ParamFilters.should_filter_key?("pin")
        assert ParamFilters.should_filter_key?("payout_iban")
        # The defaults are still there
        assert ParamFilters.should_filter_key?("password")
        assert ParamFilters.should_filter_key?("access_token")
        line = Formatter.new.process_values({phone: "555-123-4567"})

        assert_equal({_filtered: {_class: String, _hash: StringScrubber.value_hash("555-123-4567")}}, line[:phone])
      end

      def test_scrubbers
        defaults = ConfigStruct::Filters.new
        scrubbers = page_scrubbers

        assert_equal %w[authorization_credentials url_query_params url_passwords email_addresses credit_card_numbers
          phone_numbers ssns ip_addresses mac_addresses],
          scrubbers.map { |scrubber| scrubber[:setting] }
        scrubbers.each do |scrubber|
          setting = scrubber[:setting]

          assert_equal defaults.public_send(setting), scrubber[:default], "the default for #{setting}"
          # Each row runs with that scrubber on, and the others at their defaults
          LogStruct.config.filters.public_send(:"#{setting}=", true)

          scrubber[:examples].each do |logged, written|
            assert_equal written, StringScrubber.scrub(logged), "#{setting}: #{logged}"
          end
          LogStruct.config.filters.public_send(:"#{setting}=", defaults.public_send(setting))
          # Off, the scrubber leaves the strings it would change
          LogStruct.config.filters.public_send(:"#{setting}=", false)
          scrubber[:examples].each do |logged, written|
            next if logged == written

            refute_equal written, StringScrubber.scrub(logged), "#{setting} off: #{logged}"
          end
          LogStruct.config.filters.public_send(:"#{setting}=", defaults.public_send(setting))
        end
      end

      def test_what_scrubbing_leaves
        formatter = Formatter.new
        line = formatter.process_values({card: 4111111111111111, note: "4111111111111111", status: :"linda@example.com"})
        keys = formatter.process_values({"linda@example.com" => 1})

        # Numbers aren't scrubbed
        assert_equal 4111111111111111, line[:card]
        assert_equal "[CREDIT_CARD]", line[:note]
        # Symbols and Hash keys are
        assert_equal "[EMAIL:#{StringScrubber.value_hash("linda@example.com")}]", line[:status]
        assert_equal ["[EMAIL:#{StringScrubber.value_hash("linda@example.com")}]"], keys.keys
        # Secrets with no known format, in plain text
        assert_equal "Signed in with password=hunter2", StringScrubber.scrub("Signed in with password=hunter2")
        assert_equal "Key sk_live_51H8abcdefghijklmnop", StringScrubber.scrub("Key sk_live_51H8abcdefghijklmnop")
        # A URL's user name and host look like an email address
        assert_equal "https://[EMAIL:#{StringScrubber.value_hash("user@example.com")}]/path", StringScrubber.scrub("https://user@example.com/path")
      end

      def test_sql_bind_values
        sql = Integrations::ActiveRecord
        # Rails passes each bind's column as an object with a name
        email = Bind.new("email")
        name = Bind.new("name")

        # By column name, with no summary or hash
        assert_equal "[FILTERED]", sql.filter_bind(email, "linda@example.com")
        assert_equal "Linda", sql.filter_bind(name, "Linda")
        # String values that look like secrets
        ["a" * 51, "d41d8cd98f00b204e9800998ecf8427e", "dGhpcyBpcyBhIHNlY3JldCB2YWx1ZQ==",
          "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.abc", "Bearer abc"].each do |value|
          assert_equal "[FILTERED]", sql.filter_bind_parameter(value), value
        end
        # Text, even long text or text that mentions a secret, isn't
        ["Linda", "monkey", "Forgot password", "#{"a " * 26}long text"].each do |value|
          assert_equal value, sql.filter_bind_parameter(value), value
        end
        assert_equal 42, sql.filter_bind_parameter(42)
      end

      def test_where_filtering_applies
        other_io = StringIO.new
        other = ::Logger.new(other_io)
        other.formatter = proc { |_severity, _time, _progname, message| "#{message}\n" }
        logger = T.cast(Rails.logger, LogStruct::SemanticLogger::Logger)
        logger.broadcast_to(other)
        begin
          logger.info("Signed in linda@example.com")
          logger.info(msg: "A Hash", password: "hunter2")
        ensure
          logger.stop_broadcasting_to(other)
        end

        # Loggers added with broadcast_to get String messages, scrubbed, and no Hashes
        assert_equal "Signed in [EMAIL:#{StringScrubber.value_hash("linda@example.com")}]\n", other_io.string

        # The exception goes to the error reporter as it is, and the context is filtered
        reported = []
        LogStruct.config.error_reporting_handler = ->(error, context, _source) { reported << [error, context] }
        error = RuntimeError.new("Charge failed for linda@example.com")
        LogStruct.report_error(error, source: Source::App, context: {password: "hunter2"})

        assert_same error, reported.dig(0, 0)
        assert_equal "Charge failed for linda@example.com", reported.dig(0, 0).message
        assert_equal({password: {_filtered: {_class: String}}}, reported.dig(0, 1))

        # log.logstruct subscribers get the entry as it was logged
        received = T.let(nil, T.untyped)
        subscriber = ActiveSupport::Notifications.subscribe("log.logstruct") { |_name, _start, _finish, _id, payload| received = payload[:log] }
        begin
          Rails.logger.info(Log::Plain.new(message: "Imported", additional_data: {password: "hunter2"}))
        ensure
          ActiveSupport::Notifications.unsubscribe(subscriber)
        end

        assert_equal({password: "hunter2"}, received.additional_data)
      end

      def test_limits
        formatter = Formatter.new
        circular = {name: "a"}
        circular[:self] = circular

        # Values that can't be filtered are summarized
        assert_equal({_filtered: {_class: "Hash", _keys_count: 2}}, formatter.process_values({value: circular}).dig(:value, :self))
        # Long strings are scrubbed before they're cut
        LogStruct.config.limits.max_string_bytes = 20
        cut = formatter.process_values({note: "#{"x" * 10} linda@example.com"})[:note]

        assert_match(/\A#{"x" * 10} \[EMAIL:/, cut)
        refute_includes cut, "linda"
      end

      private

      def last_line
        ::SemanticLogger.flush
        JSON.parse(T.must(@io.string.lines.last))
      end

      def page = docs_page(PAGE)

      def page_json(name) = docs_page_json(PAGE, name)

      # A list of single-quoted strings on the page: const NAME = ['...', ...];
      def page_strings(name)
        source = page[/const #{name}(?::[^=]*)? = \[(.*?)\];/m, 1]

        assert source, "#{name} not found in #{PAGE}"
        strings = T.must(source).scan(/'([^']*)'/).flatten

        refute_empty strings, "no strings in #{name}"
        strings
      end

      # The page's SCRUBBERS: each scrubber's setting, its default and its [logged, written, note] examples
      def page_scrubbers
        source = page[/const SCRUBBERS(?::[^=]*)? = \[(.*?)\n\];/m, 1]

        assert source, "SCRUBBERS not found in #{PAGE}"
        T.must(source).split(/(?=\bsetting: ')/).drop(1).map do |part|
          scrubber = {
            setting: part[/\Asetting: '(\w+)'/, 1],
            default: part[/\bdefaultOn: (true|false)/, 1] == "true",
            examples: part.scan(/\[\s*'([^']*)',\s*'([^']*)'(?:,\s*'[^']*')?,?\s*\]/)
          }

          refute_empty scrubber[:examples], "no examples for #{scrubber[:setting]}"
          scrubber
        end
      end
    end
  end
end
