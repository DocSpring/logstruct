# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  class ParamFiltersTest < ActiveSupport::TestCase
    setup do
      LogStruct.configure do |c|
        c.filters.filter_keys = %i[password token]
        c.filters.filter_keys_with_hashes = %i[email]
        c.filters.hash_salt = "s:"
        c.filters.hash_length = 6
      end
    end

    test "should_filter_key? respects configured sensitive keys" do
      assert ParamFilters.should_filter_key?(:password)
      assert ParamFilters.should_filter_key?("TOKEN")
      refute ParamFilters.should_filter_key?(:username)
    end

    test "should_include_string_hash? respects configured hash keys" do
      assert ParamFilters.should_include_string_hash?(:email)
      refute ParamFilters.should_include_string_hash?(:password)
    end

    test "summarize_string includes hash when requested" do
      s = ParamFilters.summarize_string("abc@ex.com", true)

      assert_equal String, s[:_class]
      assert_match(/[0-9a-f]{6}/, s[:_hash])
      refute s.key?(:_bytes)
    end

    test "summarize_string doesn't say how long the string is" do
      s = ParamFilters.summarize_string("hunter2", false)

      assert_equal({_class: String}, s)
    end

    test "summarize_hash has the keys, not the size" do
      assert_equal({_class: Hash, _keys_count: 2, _keys: [:a, :b]}, ParamFilters.summarize_hash({a: 1, b: 2}))
      assert_equal({_class: Hash, _keys_count: 1, _keys: [:value]}, ParamFilters.summarize_hash({value: "secret"}))
    end

    test "summarize_hash handles non symbol keys" do
      summary = ParamFilters.summarize_hash({1 => "value"})

      assert_equal Hash, summary[:_class]
      assert_equal 1, summary[:_keys_count]
      assert_equal ["1"], summary[:_keys]
    end

    test "summarize_array reports the count, not the size, and handles empty" do
      s = ParamFilters.summarize_array(["token-1234567890"])

      assert_equal({_class: Array, _count: 1}, s)

      empty = ParamFilters.summarize_array([])

      assert_equal "Array", empty[:_class]
      assert empty[:_empty]
    end

    test "summarize_json_attribute dispatches by type and honors hash keys setting" do
      # String + key with hash
      s1 = ParamFilters.summarize_json_attribute(:email, "test@x.com")

      assert s1.key?(:_hash)

      # String + normal key -> class only
      s2 = ParamFilters.summarize_json_attribute(:message, "hello")

      assert_equal({_class: String}, s2)

      # Hash
      s3 = ParamFilters.summarize_json_attribute(:payload, {a: 1})

      assert_equal Hash, s3[:_class]

      # Array
      s4 = ParamFilters.summarize_json_attribute(:list, [1, 2])

      assert_equal Array, s4[:_class]

      # Other
      s5 = ParamFilters.summarize_json_attribute(:id, 123)

      assert_equal Integer, s5[:_class]
    end

    test "default regex filter matcher catches common sensitive key patterns" do
      # Reset config to use fresh defaults (with default filter_matchers)
      LogStruct.configuration = LogStruct::Configuration.new

      # Should filter keys containing sensitive patterns with word boundaries
      assert ParamFilters.should_filter_key?(:access_token)
      assert ParamFilters.should_filter_key?(:refresh_token)
      assert ParamFilters.should_filter_key?(:api_key)
      assert ParamFilters.should_filter_key?(:private_key)
      assert ParamFilters.should_filter_key?(:secret_key)
      assert ParamFilters.should_filter_key?(:access_key)
      assert ParamFilters.should_filter_key?(:encryption_key)
      assert ParamFilters.should_filter_key?(:client_secret)
      assert ParamFilters.should_filter_key?(:auth_header)
      assert ParamFilters.should_filter_key?(:auth_token)
      assert ParamFilters.should_filter_key?(:credentials)
      assert ParamFilters.should_filter_key?(:password_hash)

      # Case insensitive
      assert ParamFilters.should_filter_key?(:ACCESS_TOKEN)
      assert ParamFilters.should_filter_key?(:Api_Key)
    end

    test "default pattern matches keys by their words, whatever their case or separators" do
      LogStruct.configuration = LogStruct::Configuration.new

      %w[
        apiKey X-Api-Key accessToken clientSecret privateKey HTTP_AUTHORIZATION Proxy-Authorization
        cookie Set-Cookie session jwt passwords tokens newPassword X-Amz-Signature otp_code
      ].each do |key|
        assert ParamFilters.should_filter_key?(key), "#{key} should be filtered"
      end
      %w[signature_field_id author authority keyboard cron_key primaryKey].each do |key|
        refute ParamFilters.should_filter_key?(key), "#{key} should not be filtered"
      end
    end

    test "filter_keys match keys by their words too" do
      LogStruct.config.filters.filter_keys = [:account_number]

      assert ParamFilters.should_filter_key?("accountNumber")
      assert ParamFilters.should_filter_key?("Account-Number")
      refute ParamFilters.should_filter_key?("account")
    end

    test "default regex filter matcher does not match false positives" do
      # Reset config to use fresh defaults (with default filter_matchers)
      LogStruct.configuration = LogStruct::Configuration.new

      # Word boundaries should prevent these false positives
      refute ParamFilters.should_filter_key?(:keyboard)
      refute ParamFilters.should_filter_key?(:turkey)
      refute ParamFilters.should_filter_key?(:monkey)
      refute ParamFilters.should_filter_key?(:hockey)
      refute ParamFilters.should_filter_key?(:credenza)

      # "key" alone is too broad - these should NOT be filtered
      refute ParamFilters.should_filter_key?(:cron_key)
      refute ParamFilters.should_filter_key?(:primary_key)
      refute ParamFilters.should_filter_key?(:foreign_key)
      refute ParamFilters.should_filter_key?(:unique_key)

      # Normal fields should not be filtered
      refute ParamFilters.should_filter_key?(:username)
      refute ParamFilters.should_filter_key?(:first_name)
      refute ParamFilters.should_filter_key?(:card_id)
      refute ParamFilters.should_filter_key?(:pin_count)
    end

    test "the default pattern filters API keys, passcodes, card numbers and SSNs" do
      LogStruct.configuration = LogStruct::Configuration.new

      %i[apikey apiKeys passcode credit_card_number creditCard card_number cardNumber social_security_number].each do |key|
        assert ParamFilters.should_filter_key?(key), "#{key} wasn't filtered"
      end
    end

    test "keys in filter_keys_with_hashes are filtered, with a hash of the value" do
      LogStruct.configuration = LogStruct::Configuration.new
      LogStruct.config.filters.filter_keys_with_hashes += [:username]

      assert ParamFilters.should_filter_key?(:username)
      assert ParamFilters.should_filter_key?(:userName)
      assert ParamFilters.should_filter_key?(:email_address)
      assert ParamFilters.should_include_string_hash?(:userName)
    end
  end
end
