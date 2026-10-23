# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  class BoundedInputTest < ActiveSupport::TestCase
    test "symbolize_keys converts every key of a Hash within the limit" do
      LogStruct.config.limits.max_hash_keys = 3

      assert_equal({a: 1, b: {"c" => 2}, "3": 3}, BoundedInput.symbolize_keys({"a" => 1, :b => {"c" => 2}, 3 => 3}))
    end

    test "symbolize_keys leaves the last slot to the count of the keys it leaves out" do
      LogStruct.config.limits.max_hash_keys = 3
      symbolized = BoundedInput.symbolize_keys((1..10).to_h { |i| ["k#{i}", i] })

      assert_equal({k1: 1, k2: 2, _more_keys: 8}, symbolized)
      # The formatter writes it as it is, though the test app's filter_parameters have :key (Rails' default
      # list has :_key), which matches _more_keys
      assert_equal symbolized, Formatter.new.process_values(symbolized)
    end

    test "symbolize_keys counts oversized keys in the slots they leave" do
      LogStruct.config.limits.max_hash_keys = 3
      LogStruct.config.limits.max_string_bytes = 8
      long_key = "k" * 9

      within = BoundedInput.symbolize_keys({long_key => "hidden", "short" => 1})
      past = BoundedInput.symbolize_keys({long_key => "hidden", "short" => 1, "next" => 2, "last" => 3})

      assert_equal({short: 1, _oversized_keys: 1}, within)
      assert_equal({short: 1, _more_keys: 2, _oversized_keys: 1}, past)
      [within, past].each do |symbolized|
        assert_equal symbolized, Formatter.new.process_values(symbolized)
      end
    end

    test "symbolize_keys counts the keys of ActionController::Parameters without converting them" do
      LogStruct.config.limits.max_hash_keys = 2
      params = ::ActionController::Parameters.new("visible" => "yes", "nested" => {"token" => "secret"}, "last" => 1)

      symbolized = params.stub(:to_unsafe_h, -> { raise "full conversion" }) do
        BoundedInput.symbolize_keys(params)
      end

      assert_equal({visible: "yes", _more_keys: 2}, symbolized)
    end
  end
end
