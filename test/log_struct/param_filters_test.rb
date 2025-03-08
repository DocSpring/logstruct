# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  class ParamFiltersTest < Minitest::Test
    def setup
      # Save original configuration to restore after tests
      @original_filter_keys = LogStruct.config.filters.filter_keys.dup
      @original_filter_keys_with_hashes = LogStruct.config.filters.filter_keys_with_hashes.dup

      # Configure filter keys for testing
      LogStruct.config.filters.filter_keys = [:password, :secret, :token]
      LogStruct.config.filters.filter_keys_with_hashes = [:email]
    end

    def teardown
      # Restore original configuration
      LogStruct.config.filters.filter_keys = @original_filter_keys
      LogStruct.config.filters.filter_keys_with_hashes = @original_filter_keys_with_hashes
    end

    def test_should_filter_key
      assert ParamFilters.should_filter_key?(:password)
      assert ParamFilters.should_filter_key?("PASSWORD")
      assert ParamFilters.should_filter_key?("secret")
      assert ParamFilters.should_filter_key?(:token)

      refute ParamFilters.should_filter_key?(:username)
      refute ParamFilters.should_filter_key?("email")
    end

    def test_should_include_string_hash
      assert ParamFilters.should_include_string_hash?(:email)
      assert ParamFilters.should_include_string_hash?("EMAIL")

      refute ParamFilters.should_include_string_hash?(:password)
      refute ParamFilters.should_include_string_hash?("username")
    end

    def test_summarize_string
      string = "test-string"

      # Without hash
      result = ParamFilters.summarize_string(string, false)

      assert_equal String, result[:_class]
      assert_equal string.bytesize, result[:_bytes]
      refute result.key?(:_hash)

      # With hash
      result = ParamFilters.summarize_string(string, true)

      assert_equal String, result[:_class]
      refute result.key?(:_bytes)
      assert result.key?(:_hash)
      assert_instance_of String, result[:_hash]
    end

    def test_summarize_hash_without_sensitive_keys
      hash = {name: "John", age: 30}

      result = ParamFilters.summarize_hash(hash)

      assert_equal Hash, result[:_class]
      assert_equal 2, result[:_keys_count]
      assert_equal [:name, :age], result[:_keys]
      assert result.key?(:_bytes)
    end

    def test_summarize_hash_with_sensitive_keys
      hash = {name: "John", password: "secret123"}

      result = ParamFilters.summarize_hash(hash)

      assert_equal Hash, result[:_class]
      assert_equal 2, result[:_keys_count]
      assert_equal [:name, :password], result[:_keys]

      # Should not include byte size for hashes with sensitive keys
      refute result.key?(:_bytes)
    end

    def test_summarize_hash_with_uppercase_sensitive_keys
      hash = {name: "John", PASSWORD: "secret123"}

      result = ParamFilters.summarize_hash(hash)

      assert_equal Hash, result[:_class]
      assert_equal 2, result[:_keys_count]
      assert_equal [:name, :PASSWORD], result[:_keys]

      # Should not include byte size regardless of case
      refute result.key?(:_bytes)
    end

    def test_summarize_hash_empty
      result = ParamFilters.summarize_hash({})

      assert_equal "Hash", result[:_class]
      assert result[:_empty]
    end

    def test_summarize_array
      array = [1, 2, 3]

      result = ParamFilters.summarize_array(array)

      assert_equal Array, result[:_class]
      assert_equal 3, result[:_count]
      assert result.key?(:_bytes)
    end

    def test_summarize_array_empty
      result = ParamFilters.summarize_array([])

      assert_equal "Array", result[:_class]
      assert result[:_empty]
    end

    def test_summarize_json_attribute_with_string
      result = ParamFilters.summarize_json_attribute("username", "john")

      assert_equal String, result[:_class]
      assert_equal "john".bytesize, result[:_bytes]
      refute result.key?(:_hash)

      result = ParamFilters.summarize_json_attribute("email", "john@example.com")

      assert_equal String, result[:_class]
      refute result.key?(:_bytes)
      assert result.key?(:_hash)
    end

    def test_summarize_json_attribute_with_hash
      hash = {name: "John", age: 30}
      result = ParamFilters.summarize_json_attribute("user", hash)

      assert_equal Hash, result[:_class]
      assert_equal 2, result[:_keys_count]
      assert result.key?(:_bytes)

      hash_with_sensitive = {name: "John", password: "secret"}
      result = ParamFilters.summarize_json_attribute("user", hash_with_sensitive)

      assert_equal Hash, result[:_class]
      assert_equal 2, result[:_keys_count]
      refute result.key?(:_bytes)
    end

    def test_summarize_json_attribute_with_array
      array = [1, 2, 3]
      result = ParamFilters.summarize_json_attribute("numbers", array)

      assert_equal Array, result[:_class]
      assert_equal 3, result[:_count]
      assert result.key?(:_bytes)
    end

    def test_summarize_json_attribute_with_other_types
      result = ParamFilters.summarize_json_attribute("age", 30)

      assert_equal Integer, result[:_class]

      result = ParamFilters.summarize_json_attribute("active", true)

      assert_equal TrueClass, result[:_class]
    end
  end
end
