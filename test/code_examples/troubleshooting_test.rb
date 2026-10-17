# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  module CodeExamples
    class TroubleshootingTest < ActiveSupport::TestCase
      def test_filter_listed_keys_only
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: filter_listed_keys_only
        # ----------------------------------------------------------
        LogStruct.configure do |config|
          # Filter the keys in filter_keys (and Rails' filter_parameters) only, not every key with a
          # sensitive word in it, such as session_id or cookie_consent
          config.filters.filter_matchers.reject! { |matcher| matcher.label == "default_sensitive_pattern" }
          # So list the other keys you want filtered
          config.filters.filter_keys += [:api_key, :session_token]
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: filter_listed_keys_only
        # ----------------------------------------------------------

        filtered = Formatter.new.process_values({session_id: "s-1", cookie_consent: true, api_key: "k-1", password: "p"})

        assert_equal ["s-1", true], filtered.values_at(:session_id, :cookie_consent)
        assert_equal [{_filtered: {_class: String}}] * 2, filtered.values_at(:api_key, :password)
      end
    end
  end
end
