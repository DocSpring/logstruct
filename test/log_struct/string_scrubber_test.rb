# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  class StringScrubberTest < ActiveSupport::TestCase
    def setup
      # Save original configuration
      @original_config = LogStruct::Configuration.instance

      # Create a new configuration for testing
      test_config = LogStruct::Configuration.new(
        filters: ConfigStruct::Filters.new(
          email_addresses: true,
          url_passwords: true,
          credit_card_numbers: true,
          phone_numbers: true,
          ssns: true,
          ip_addresses: true,
          mac_addresses: true,
          hash_salt: "test_salt",
          hash_length: 8
        ),
        string_scrubbing_handler: nil
      )

      # Replace the configuration
      LogStruct.configuration = test_config
    end

    def teardown
      # Restore original configuration
      LogStruct.configuration = @original_config
    end

    def test_scrub_email_addresses
      # Test with a simple email
      input = "Contact us at user@example.com for more information"
      result = StringScrubber.scrub(input)

      # Verify the email was replaced with a hash
      assert_not_includes result, "user@example.com"
      assert_match(/\[EMAIL:[a-f0-9]+\]/, result)

      # Test with multiple emails
      input = "Emails: user1@example.com and user2@example.org"
      result = StringScrubber.scrub(input)

      assert_not_includes result, "user1@example.com"
      assert_not_includes result, "user2@example.org"
      assert_match(/\[EMAIL:[a-f0-9]+\].*\[EMAIL:[a-f0-9]+\]/, result)
    end

    # cspell:ignore martínez martí exämple
    def test_scrub_email_addresses_in_any_script
      %w[linda.martínez@gmail.com zoë@example.com jose@exämple.com].each do |email|
        result = StringScrubber.scrub("Sent to #{email}.")

        assert_match(/\ASent to \[EMAIL:\h+\]\.\z/, result, email)
      end
    end

    def test_an_email_has_the_same_hash_in_any_case
      assert_equal StringScrubber.scrub("user@example.com"), StringScrubber.scrub("User@Example.COM")
    end

    def test_scrub_strings_with_invalid_utf8
      binary = "From caf\xC3\xA9@example.com \xFF".b

      assert_match(/\AFrom \[EMAIL:\h+\] \uFFFD\z/, StringScrubber.scrub(binary))
    end

    def test_scrub_bearer_tokens_and_basic_credentials
      basic = Base64.strict_encode64("admin:hunter2")

      assert_equal "Authorization: Bearer [FILTERED]",
        StringScrubber.scrub("Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOjF9.sig")
      assert_equal "Retried with basic [FILTERED] after a 401", StringScrubber.scrub("Retried with basic #{basic} after a 401")
      # Short words after them, and base64 without user:password, stay
      assert_equal "Send a Bearer token, or Basic auth on the Basic plan",
        StringScrubber.scrub("Send a Bearer token, or Basic auth on the Basic plan")
      assert_equal "Basic aGVsbG8gd29ybGQ=", StringScrubber.scrub("Basic aGVsbG8gd29ybGQ=")
    end

    def test_scrub_url_passwords
      # Test with a URL containing a password
      # cspell:ignore mydb
      input = "Database URL: postgres://user:password123@localhost:5432/mydb"
      result = StringScrubber.scrub(input)

      # Verify the password was filtered
      assert_not_includes result, "password123"
      assert_includes result, "postgres://user:[PASSWORD]@localhost:5432/mydb"

      # Test with encoded URL
      # cspell:ignore Fuser Asecret
      input = "Encoded URL: https%3A%2F%2Fuser%3Asecret%40example.com"
      result = StringScrubber.scrub(input)

      assert_not_includes result, "secret"
      assert_includes result, "[PASSWORD]"
    end

    def test_scrub_credit_card_numbers
      # Test with a 16-digit card number
      input = "Card: 4111111111111111"
      result = StringScrubber.scrub(input)

      assert_not_includes result, "4111111111111111"
      assert_includes result, "[CREDIT_CARD]"

      # Test with formatted card number
      input = "Card: 4111-1111-1111-1111"
      result = StringScrubber.scrub(input)

      assert_not_includes result, "4111-1111-1111-1111"
      assert_includes result, "[CREDIT_CARD]"
    end

    def test_scrub_url_passwords_with_colons_and_empty_users
      # cspell:ignore hunter Bpassword Bname
      {
        "postgres://user:pass:word@db/app" => "postgres://user:[PASSWORD]@db/app",
        "redis://:hunter2@cache:6379/0" => "redis://:[PASSWORD]@cache:6379/0",
        "https://user:p@ss@example.com/path" => "https://user:[PASSWORD]@example.com/path",
        "https%3a%2f%2fuser%3asecret%40example.com" => "https%3a%2f%2fuser%3a[PASSWORD]%40example.com",
        "https://example.com:8080/path" => "https://example.com:8080/path"
      }.each do |input, expected|
        assert_equal expected, StringScrubber.scrub(input)
      end
    end

    def test_scrub_card_numbers_of_every_length_that_pass_the_luhn_check
      [
        "378282246310005",      # American Express, 15 digits
        "3782 822463 10005",
        "30569309025904",       # Diners Club, 14 digits
        "4222222222222",        # Visa, 13 digits
        "6011111111111117",
        "4111 1111 1111 1111",
        "4000056655665556122",  # 19 digits
        "2223003122003222"      # Mastercard 2-series
      ].each do |number|
        assert_equal "Card: [CREDIT_CARD]", StringScrubber.scrub("Card: #{number}"), number
      end
    end

    def test_leave_other_numbers_alone
      [
        "4111111111111112",     # fails the Luhn check
        "1700000000000000000",  # a timestamp in nanoseconds
        "4111-1111 1111-1111",  # mixed separators
        "id 3.4111111111111111",
        "a4111111111111111b"
      ].each do |input|
        assert_equal input, StringScrubber.scrub(input)
      end
    end

    def test_scrub_sensitive_query_params
      {
        "/reset?token=abc123&page=2" => "/reset?token=[FILTERED]&page=2",
        "https://app.test/callback?code=oauth-code&state=xyz" => "https://app.test/callback?code=[FILTERED]&state=xyz",
        "/login?user%5Bpassword%5D=pw&user%5Bname%5D=ada" => "/login?user%5Bpassword%5D=[FILTERED]&user%5Bname%5D=ada",
        "/api?apiKey=k1&sort=asc#top" => "/api?apiKey=[FILTERED]&sort=asc#top",
        "/search?q=tokens" => "/search?q=tokens",
        "Ready? token=abc" => "Ready? token=abc"
      }.each do |input, expected|
        assert_equal expected, StringScrubber.scrub(input)
      end
    end

    def test_query_params_can_be_left_alone
      LogStruct.config.filters.url_query_params = false

      assert_equal "/reset?token=abc123", StringScrubber.scrub("/reset?token=abc123")
    end

    def test_scrub_name_skips_identifiers
      assert_equal :user_id, StringScrubber.scrub_name(:user_id)
      assert_equal "createdAt", StringScrubber.scrub_name("createdAt")
      assert_equal 1, StringScrubber.scrub_name(1)
      assert_match(/\A\[EMAIL:[a-f0-9]+\]\z/, StringScrubber.scrub_name("ada@example.com"))
      assert_match(/\A\[EMAIL:[a-f0-9]+\]\z/, StringScrubber.scrub_name(:"ada@example.com"))
    end

    def test_without_query
      assert_equal "https://app.test/reset", StringScrubber.without_query("https://app.test/reset?token=abc#x")
      assert_equal "https://app.test/", StringScrubber.without_query("https://app.test/")
      assert_nil StringScrubber.without_query(nil)
    end

    def test_scrub_phone_numbers
      # Test with a formatted phone number
      input = "Call us at 555-123-4567"
      result = StringScrubber.scrub(input)

      assert_not_includes result, "555-123-4567"
      assert_includes result, "[PHONE]"
    end

    def test_scrub_us_phone_numbers_in_their_common_formats
      ["555-123-4567", "555 123 4567", "555.123.4567", "(555) 123-4567", "(555)123-4567", "+1 555-123-4567",
        "+1 (555) 123-4567", "+1-555-123-4567", "1-555-123-4567", "1 (555) 123-4567"].each do |number|
        assert_equal "Call [PHONE] today", StringScrubber.scrub("Call #{number} today"), number
      end
    end

    def test_leave_numbers_other_than_us_phone_numbers
      ["5551234567", "v1.555.123", "+44 20 7946 0958", "order 555-1234"].each do |text|
        assert_equal text, StringScrubber.scrub(text)
      end
    end

    def test_scrub_ssns
      # Test with a formatted SSN
      input = "SSN: 123-45-6789"
      result = StringScrubber.scrub(input)

      assert_not_includes result, "123-45-6789"
      assert_includes result, "[SSN]"
    end

    def test_leave_longer_numbers_that_contain_an_ssn
      ["Part 123-45-6789-0", "Part 9-123-45-6789"].each do |text|
        assert_equal text, StringScrubber.scrub(text)
      end
    end

    def test_scrub_ip_addresses
      # Test with an IP address
      input = "IP: 192.168.1.1"
      result = StringScrubber.scrub(input)

      assert_not_includes result, "192.168.1.1"
      assert_includes result, "[IP]"
    end

    def test_scrub_mac_addresses
      # Test with a MAC address
      input = "MAC: 00:11:22:33:44:55"
      result = StringScrubber.scrub(input)

      assert_not_includes result, "00:11:22:33:44:55"
      assert_includes result, "[MAC]"
    end

    def test_scrub_ipv6_addresses
      {
        "from 2001:db8::1 now" => "from [IP] now",
        "2001:0db8:85a3:0000:0000:8a2e:0370:7334" => "[IP]",
        "[fe80::1ff:fe23:4567:890a]:8080" => "[[IP]]:8080",
        "::1" => "[IP]",
        "::ffff:192.168.1.1" => "[IP]",
        "Connected to 2001:db8::1." => "Connected to [IP].",
        "via fe80::1%en0 now" => "via [IP] now"
      }.each do |input, expected|
        assert_equal expected, StringScrubber.scrub(input), input
      end
    end

    def test_leave_text_with_colons_other_than_ipv6_addresses
      ["at 12:30:45", "ActiveRecord::Base", "Face::Bead", "2026-10-17T12:30:45Z", "a::b::c"].each do |text|
        assert_equal text, StringScrubber.scrub(text)
      end
    end

    def test_scrub_mac_addresses_with_dashes
      assert_equal "MAC: [MAC]", StringScrubber.scrub("MAC: 00-1A-2B-3C-4D-5E")
      assert_equal "00-1A:2B-3C-4D-5E", StringScrubber.scrub("00-1A:2B-3C-4D-5E")
    end

    def test_disabled_filters
      # Create a config with all filters disabled
      test_config = LogStruct::Configuration.new(
        filters: ConfigStruct::Filters.new(
          email_addresses: false,
          url_passwords: false,
          credit_card_numbers: false,
          phone_numbers: false,
          ssns: false,
          ip_addresses: false,
          mac_addresses: false,
          authorization_credentials: false
        )
      )
      LogStruct.configuration = test_config

      # Test with sensitive data
      input = "Email: user@example.com, Card: 4111111111111111, Phone: 555-123-4567, Bearer abcdefghijklmnopqrstuvwxyz"
      result = StringScrubber.scrub(input)

      # Verify nothing was filtered
      assert_equal input, result
    end

    def test_custom_scrubbing_handler
      # Create a config with custom handler
      custom_handler = ->(msg) { msg.gsub("SECRET", "[REDACTED]") }
      test_config = LogStruct::Configuration.new(
        filters: LogStruct.config.filters,
        string_scrubbing_handler: custom_handler
      )
      LogStruct.configuration = test_config

      # Test with custom data
      input = "This contains a SECRET value"
      result = StringScrubber.scrub(input)

      # Verify custom scrubbing was applied
      assert_not_includes result, "SECRET"
      assert_includes result, "[REDACTED]"
    end

    def test_multiple_filters
      # Test with multiple sensitive data types
      input = "Email: user@example.com, Card: 4111111111111111, Phone: 555-123-4567"
      result = StringScrubber.scrub(input)

      # Verify all sensitive data was filtered
      assert_not_includes result, "user@example.com"
      assert_not_includes result, "4111111111111111"
      assert_not_includes result, "555-123-4567"
      assert_match(/\[EMAIL:[a-f0-9]{8,}\]/, result)
      assert_includes result, "[CREDIT_CARD]"
      assert_includes result, "[PHONE]"
    end
  end
end
