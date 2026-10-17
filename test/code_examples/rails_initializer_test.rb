# typed: true
# frozen_string_literal: true

require "test_helper"

module LogStruct
  module CodeExamples
    class RailsInitializerTest < ActiveSupport::TestCase
      def test_rails_initializer
        # ----------------------------------------------------------
        # BEGIN CODE EXAMPLE: rails_initializer
        # ----------------------------------------------------------
        # config/initializers/logstruct.rb
        LogStruct.configure do |config|
          # Filter these keys too, on top of LogStruct's defaults and Rails' filter_parameters
          config.filters.filter_keys += [:date_of_birth, :account_number]

          # Keep the same email hashes when secret_key_base changes, and in every app that logs the
          # same people. Without it, the key is derived from secret_key_base.
          config.filters.hash_salt = Rails.application.credentials.logstruct_hash_key

          # Add the signed-in user to request lines (see append_info_to_payload below)
          config.integrations.lograge_custom_options = ->(event, _options) {
            {user_id: event.payload[:user_id]}
          }

          # Log SQL queries slower than 250 ms
          config.integrations.enable_sql_logging = true
          config.integrations.sql_slow_query_threshold = 250.0

          # Log the account and organization a mail was sent for
          config.integrations.actionmailer_id_mapping = {account: :account_id, organization: :organization_id}
        end
        # ----------------------------------------------------------
        # END CODE EXAMPLE: rails_initializer
        # ----------------------------------------------------------

        config = LogStruct.config

        assert_includes config.filters.filter_keys, :password
        assert_includes config.filters.filter_keys, :date_of_birth
        assert_nil config.filters.hash_salt # no such credential in the test app
        event = ActiveSupport::Notifications::Event.new("process_action.action_controller", 0.0, 0.0, "id", {user_id: 7})

        assert_equal({user_id: 7}, config.integrations.lograge_custom_options&.call(event, {}))
        assert config.integrations.enable_sql_logging
        assert_in_delta 250.0, T.must(config.integrations.sql_slow_query_threshold)
        assert_equal({account: :account_id, organization: :organization_id}, config.integrations.actionmailer_id_mapping)
      end
    end
  end
end
