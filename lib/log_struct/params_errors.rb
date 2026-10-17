# typed: strict
# frozen_string_literal: true

module LogStruct
  # Errors from parsing a request's params: Rails' ParseError (and its ParamErrors), and Rack's. Their messages, and
  # those of errors raised because of them (Rails' "Invalid request parameters: ..."), quote the request's input: a
  # JSON parser's excerpt of the body, Rack's "invalid %-encoding (<value>)". Nothing can filter a body that didn't
  # parse, so LogStruct's lines leave the input out.
  module ParamsErrors
    extend T::Sig

    # Matched by name, so this works without ActionDispatch or Rack loaded
    NAMES = T.let(
      [
        "ActionDispatch::Http::Parameters::ParseError",
        "Rack::BadRequest",
        "Rack::QueryParser::InvalidParameterError",
        "Rack::QueryParser::ParameterTypeError",
        "Rack::QueryParser::ParamsTooDeepError"
      ].freeze,
      T::Array[String]
    )
    # Rails' message for a ParseError
    PARSE_ERROR_MESSAGE = "Error occurred while parsing request parameters"
    PARAMS_ERROR_MESSAGE = "Invalid request parameters"

    # The message and the cause's message to log for an error, without the input a params parser quoted
    sig { params(error: Exception).returns([String, T.nilable(String)]) }
    def self.messages(error)
      cause = error.cause
      if params_error?(error)
        [parse_error?(error) ? PARSE_ERROR_MESSAGE : PARAMS_ERROR_MESSAGE, nil]
      elsif cause && params_error?(cause)
        message = error.message.sub(cause.message, "").sub(/[\s:]+\z/, "")
        [message.empty? ? PARAMS_ERROR_MESSAGE : message, nil]
      else
        [error.message, cause&.message]
      end
    end

    sig { params(error: Exception).returns(T::Boolean) }
    def self.parse_error?(error)
      !!defined?(::ActionDispatch::Http::Parameters::ParseError) &&
        error.instance_of?(::ActionDispatch::Http::Parameters::ParseError)
    end

    sig { params(error: Exception).returns(T::Boolean) }
    def self.params_error?(error)
      error.class.ancestors.any? { |ancestor| NAMES.include?(ancestor.name) }
    end
  end
end
