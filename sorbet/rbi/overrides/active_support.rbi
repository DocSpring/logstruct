# typed: strong

module ActiveSupport
  class Logger
    sig { params(tags: T.untyped, blk: T.proc.returns(T.untyped)).returns(T.untyped) }
    def tagged(tags, &blk); end
  end

  class BroadcastLogger
    sig { params(tags: T.untyped, blk: T.proc.returns(T.untyped)).returns(T.untyped) }
    def tagged(tags, &blk); end
  end

  module Notifications
    class Event
      sig { returns(String) }
      attr_reader :name

      sig { returns(T.nilable(Float)) }
      attr_reader :time

      sig { returns(T.nilable(Float)) }
      attr_reader :end

      sig { returns(String) }
      attr_reader :transaction_id

      sig { returns(T::Array[T.untyped]) }
      attr_reader :children

      sig { returns(T::Hash[Symbol, T.untyped]) }
      attr_accessor :payload

      sig do
        params(
          name: String,
          start: T.nilable(Float),
          ending: T.nilable(Float),
          transaction_id: String,
          payload: T::Hash[Symbol, T.untyped]
        ).void
      end
      def initialize(name, start, ending, transaction_id, payload); end
    end
  end
end
