# typed: true
# frozen_string_literal: true

# Add your extra requires here (`bin/tapioca require` can be used to bootstrap this list)
require "rspec"
require "rspec/mocks"
# require "rspec/rails" # Uncomment if using Rails integration tests

# Rails components
require "active_model"
require "active_model/error"
require "active_record"
require "active_record/connection_adapters/abstract/schema_statements"
require "active_record/connection_adapters/abstract/database_statements"
require "active_support/concern"
require "action_mailer"
require "action_mailer/base"

# Optional dependencies
require "sidekiq"
require "sidekiq/logger"
require "shrine"
require "sentry-ruby"
require "bugsnag"
require "rollbar"
require "honeybadger"
require "postmark"
