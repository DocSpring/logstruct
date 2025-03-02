# typed: strict
# frozen_string_literal: true

require_relative "log_source"
require_relative "log_event"
require_relative "log_entries/log_entry_interface"
require_relative "log_entries/error"
require_relative "log_entries/email"
require_relative "log_entries/request"
require_relative "log_entries/job"
require_relative "log_entries/file"
require_relative "log_entries/notification"

module RailsStructuredLogging
  # Module for all structured log entry types
  module LogEntries
  end
end
