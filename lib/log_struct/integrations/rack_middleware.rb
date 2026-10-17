# typed: strict
# frozen_string_literal: true

module LogStruct
  module Integrations
    # A Rack middleware around the app: subclasses define call, and pass the request on to @app
    class RackMiddleware
      extend T::Sig
      extend T::Helpers

      abstract!

      sig { params(app: T.untyped).void }
      def initialize(app)
        @app = app
      end

      sig { abstract.params(env: T.untyped).returns(T.untyped) }
      def call(env)
      end
    end
  end
end
