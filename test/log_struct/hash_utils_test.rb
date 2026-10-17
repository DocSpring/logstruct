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
  end
end
