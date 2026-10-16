# typed: strict
# frozen_string_literal: true

module LogStruct
  # Exceptions LogStruct has already logged as a structured line, so an integration that sees the same
  # exception again doesn't log it twice. GoodJob passes a failed job's exception to on_thread_error after
  # the ActiveJob integration has logged it, for example. Exceptions are held weakly, so a mark doesn't keep
  # one alive.
  module LoggedErrors
    extend T::Sig

    @logged = T.let(ObjectSpace::WeakMap.new, ObjectSpace::WeakMap)
    @mutex = T.let(Mutex.new, Mutex)

    sig { params(error: Exception).void }
    def self.mark(error)
      @mutex.synchronize { @logged[error] = true }
    end

    sig { params(error: Exception).returns(T::Boolean) }
    def self.logged?(error)
      @mutex.synchronize { @logged.key?(error) }
    end
  end
end
