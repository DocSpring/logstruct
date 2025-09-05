# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  class HashUtilsTest < ActiveSupport::TestCase
    test "hash_value returns deterministic truncated SHA256" do
      # Configure a known salt/length for deterministic output
      LogStruct.configure do |c|
        c.filters.hash_salt = "salt:"
        c.filters.hash_length = 8
      end

      h1 = HashUtils.hash_value("secret")
      h2 = HashUtils.hash_value("secret")

      refute_empty h1
      assert_equal 8, h1.length
      assert_equal h1, h2, "hashing must be deterministic for same input"

      # Different input -> different hash
      h3 = HashUtils.hash_value("different")

      refute_equal h1, h3
    end
  end
end
