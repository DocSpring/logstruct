# typed: true

# GoodJob isn't installed for development (it needs PostgreSQL), so Tapioca has no RBI for it.
# These are the settings the GoodJob integration changes.
module GoodJob
  class << self
    sig { returns(T.untyped) }
    def logger; end

    sig { params(logger: T.untyped).void }
    def logger=(logger); end

    sig { returns(T.nilable(T.proc.params(exception: Exception).void)) }
    def on_thread_error; end

    sig { params(handler: T.nilable(T.proc.params(exception: Exception).void)).void }
    def on_thread_error=(handler); end

    # Every GoodJob component passes its thread errors here; it calls on_thread_error
    sig { params(exception: Exception).void }
    def _on_thread_error(exception); end
  end

  # Logs GoodJob's notifications as text
  class LogSubscriber
    sig { params(progname: T.untyped, tags: T::Array[T.untyped], block: T.nilable(T.proc.returns(String))).void }
    def error(progname = nil, tags: [], &block); end
  end

  # The job running on the current thread: `job` in GoodJob 4, `execution` in GoodJob 3
  module CurrentThread
    class << self
      sig { returns(T.untyped) }
      def job; end

      sig { returns(T.untyped) }
      def execution; end
    end
  end

  class Notifier
    CONNECTION_ERRORS = T.let([], T::Array[String])
  end

  class CLI
    class << self
      sig { returns(T.nilable(T::Boolean)) }
      def within_exe?; end

      sig { params(value: T.nilable(T::Boolean)).void }
      def log_to_stdout=(value); end
    end
  end
end
