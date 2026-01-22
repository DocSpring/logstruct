# typed: strict

module ActiveSupport
  extend T::Sig

  sig { returns(T.untyped) }
  def self.event_reporter; end
end
