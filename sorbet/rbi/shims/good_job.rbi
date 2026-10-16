# typed: true

# GoodJob isn't installed for development (it needs PostgreSQL), so Tapioca has no RBI for it.
# These are the settings the GoodJob integration changes.
module GoodJob
  class << self
    sig { returns(T.untyped) }
    def logger; end

    sig { params(logger: T.untyped).void }
    def logger=(logger); end

    sig { returns(T.nilable(T.proc.params(exception: StandardError).void)) }
    def on_thread_error; end

    sig { params(handler: T.nilable(T.proc.params(exception: StandardError).void)).void }
    def on_thread_error=(handler); end
  end

  # Logs GoodJob's notifications as text
  class LogSubscriber; end

  class CLI
    class << self
      sig { returns(T.nilable(T::Boolean)) }
      def within_exe?; end

      sig { params(value: T.nilable(T::Boolean)).void }
      def log_to_stdout=(value); end
    end
  end
end
