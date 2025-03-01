# typed: strong

# This file defines type signatures for the Bugsnag gem
module Bugsnag
  sig { params(exception: Exception, block: T.nilable(T.proc.params(report: T.untyped).void)).void }
  def self.notify(exception, &block); end
end
