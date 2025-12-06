# typed: strict
# frozen_string_literal: true

namespace :logging do
  desc "Test log output for rake task logging tests"
  task test_output: :environment do
    Rails.logger.info "Test log message from rake task"
    Rails.logger.tagged("custom_tag") do
      Rails.logger.info "Tagged test log message"
    end
  end
end
