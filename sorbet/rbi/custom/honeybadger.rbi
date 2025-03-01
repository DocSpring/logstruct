# typed: strong

# This file defines type signatures for the Honeybadger gem
module Honeybadger
  sig { params(exception: Exception, options: T::Hash[Symbol, T.untyped]).void }
  def self.notify(exception, options = {}); end
end
