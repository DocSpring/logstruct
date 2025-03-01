# typed: strong

# This file defines type signatures for the Rollbar gem
module Rollbar
  sig { params(exception: Exception, context: T::Hash[T.untyped, T.untyped]).void }
  def self.error(exception, context = {}); end
end
