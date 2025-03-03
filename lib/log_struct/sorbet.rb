# typed: strict
# frozen_string_literal: true

# Note: We use T::Struct for our Log classes so Sorbet is a hard requirement,
# not an optional dependency.
require "sorbet-runtime"
require_relative "multi_error_reporter"

# Configure sorbet-runtime to use our error reporter for type checking failures
# https://sorbet.org/docs/runtime#on_failure-changing-what-happens-on-runtime-errors
T::Configuration.call_validation_error_handler = lambda do |signature, opts|
  error = TypeError.new(opts[:pretty_message])

  # More recent versions of Rails support Rails.env.local? (but we support Rails 7.0)
  if ::Rails.env.test? || ::Rails.env.development?
    # Fail hard in test/dev to catch any type issues early (both our own tests and our users' tests)
    raise error
  else
    # Report/log errors in production but don't crash
    LogStruct::MultiErrorReporter.report_exception(error)
  end
end

# Extend T::Sig to all modules so we don't have to write `extend T::Sig` everywhere.
# See: https://sorbet.org/docs/sigs
class Module
  include T::Sig
end
