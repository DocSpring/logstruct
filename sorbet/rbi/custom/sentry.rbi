# typed: strong

# This file defines type signatures for the Sentry gem
module Sentry
  sig { params(exception: Exception, options: T::Hash[Symbol, T.untyped]).void }
  def self.capture_exception(exception, options = {}); end
end
