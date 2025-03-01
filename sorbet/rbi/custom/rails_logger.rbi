# typed: strong
# frozen_string_literal: true

module Rails
  # Define Rails.logger with methods that accept either String or Hash
  sig { returns(Logger) }
  def self.logger; end

  class Logger
    # Define logging methods that accept either String or Hash
    sig { params(message: T.any(String, T::Hash[T.any(Symbol, String), T.untyped])).void }
    def info(message); end

    sig { params(message: T.any(String, T::Hash[T.any(Symbol, String), T.untyped])).void }
    def error(message); end

    sig { params(message: T.any(String, T::Hash[T.any(Symbol, String), T.untyped])).void }
    def warn(message); end

    sig { params(message: T.any(String, T::Hash[T.any(Symbol, String), T.untyped])).void }
    def debug(message); end

    sig { params(message: T.any(String, T::Hash[T.any(Symbol, String), T.untyped])).void }
    def fatal(message); end

    # Define public_send to support dynamic log level selection
    sig { params(method: Symbol, message: T.any(String, T::Hash[T.any(Symbol, String), T.untyped])).void }
    def public_send(method, message); end
  end
end
