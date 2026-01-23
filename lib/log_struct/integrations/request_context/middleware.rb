# typed: strict
# frozen_string_literal: true

module LogStruct
  module Integrations
    module RequestContext
      # Middleware that captures request_id and stores it in SemanticLogger's
      # named_tags so all logs during the request include the request_id.
      class Middleware
        extend T::Sig

        sig { params(app: T.untyped).void }
        def initialize(app)
          @app = app
        end

        sig { params(env: T.untyped).returns(T.untyped) }
        def call(env)
          request = ::ActionDispatch::Request.new(env)
          ::SemanticLogger.push_named_tags(request_id: request.request_id)
          @app.call(env)
        ensure
          ::SemanticLogger.pop_named_tags
        end
      end
    end
  end
end
