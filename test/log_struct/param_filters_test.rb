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

    test "summarize_string includes bytes when not hashing" do
      s = ParamFilters.summarize_string("hello", false)

      assert_equal String, s[:_class]
      assert_equal 5, s[:_bytes]
      refute s.key?(:_hash)
    end

    test "summarize_hash includes keys and optional bytes when no sensitive keys" do
      summary = ParamFilters.summarize_hash({a: 1, b: 2})

      assert_equal Hash, summary[:_class]
      assert_equal 2, summary[:_keys_count]
      assert_equal [:a, :b], summary[:_keys]
      assert_kind_of Integer, summary[:_bytes]

      # Presence of sensitive key removes _bytes
      summary2 = ParamFilters.summarize_hash({password: "x", a: 1})

      assert_equal Hash, summary2[:_class]
      refute summary2.key?(:_bytes)
    end

    test "summarize_array reports count/bytes and handles empty" do
      s = ParamFilters.summarize_array([1, 2, 3])

      assert_equal Array, s[:_class]
      assert_equal 3, s[:_count]
      assert_operator s[:_bytes], :>, 0

      empty = ParamFilters.summarize_array([])

      assert_equal "Array", empty[:_class]
      assert empty[:_empty]
    end

    test "summarize_json_attribute dispatches by type and honors hash keys setting" do
      # String + key with hash
      s1 = ParamFilters.summarize_json_attribute(:email, "test@x.com")

      assert s1.key?(:_hash)

      # String + normal key -> bytes
      s2 = ParamFilters.summarize_json_attribute(:message, "hello")

      assert s2.key?(:_bytes)

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
  end
end
