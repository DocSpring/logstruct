# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  class HashUtilsTest < ActiveSupport::TestCase
    teardown do
      HashUtils.reset!
    end

    test "hash_value is an HMAC-SHA256 keyed with the configured salt" do
      LogStruct.configure do |c|
        c.filters.hash_salt = "salt:"
        c.filters.hash_length = 8
      end

      h1 = HashUtils.hash_value("secret")

      assert_equal OpenSSL::HMAC.hexdigest("SHA256", "salt:", "secret")[0...8], h1
      assert_equal h1, HashUtils.hash_value("secret"), "hashing must be deterministic for same input"
      refute_equal h1, HashUtils.hash_value("different")
    end

    test "without a salt, the key is derived from the app's secret_key_base" do
      LogStruct.configure { |c| c.filters.hash_salt = nil }
      HashUtils.reset!

      derived_key = ::Rails.application.key_generator.generate_key("LogStruct hashed values", 32)

      assert_equal derived_key, HashUtils.hash_key
      refute_equal HashUtils::FALLBACK_KEY, HashUtils.hash_key
      assert_equal OpenSSL::HMAC.hexdigest("SHA256", derived_key, "user@example.com")[0...12],
        HashUtils.hash_value("user@example.com")
    end

    test "hashes are 16 characters by default" do
      assert_equal 16, ConfigStruct::Filters.new.hash_length
    end

    test "hashing a long value uses a bounded input" do
      LogStruct.config.filters.hash_salt = "salt:"
      LogStruct.config.limits.max_string_bytes = 8
      value = "x" * 10_000
      expected = OpenSSL::HMAC.hexdigest("SHA256", "salt:", "xxxxxxxx\0#{value.bytesize}")[0...LogStruct.config.filters.hash_length]

      assert_equal expected, HashUtils.hash_value(value)
    end

    test "fallback key is random and private to the process" do
      LogStruct.configure { |c| c.filters.hash_salt = nil }
      HashUtils.reset!

      ::Rails.stub(:application, nil) do
        key = HashUtils.hash_key

        assert_equal 32, key.bytesize
        refute_equal "l0g5t0p", key
        assert_equal key, HashUtils.hash_key
      end
    end
  end
end
