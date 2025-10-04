# typed: true

require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "simple test that generates logs" do # rubocop:disable Minitest/NoAssertions
    # This test just needs to run and generate some logs
    Rails.logger.info("Test log message")
  end
end
