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
    CAUSE_MESSAGE_LEFT_OUT = "(left out: it quotes the request's input)"

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

    # For text that writes an error's whole chain (its causes too): each message in it that quotes a params parser's
    # input, with what to write instead. Longest first, since an error's message can contain its cause's. An error
    # raised without a message (Rack's and Rails' depth limits) has its class name as its message, which quotes
    # nothing and is also the text's label for its class, so it stays.
    sig { params(error: Exception).returns(T::Array[[String, String]]) }
    def self.replacements(error)
      pairs = T.let([], T::Array[[String, String]])
      seen = T.let({}.compare_by_identity, T::Hash[Exception, TrueClass])
      current = T.let(error, T.nilable(Exception))
      while current && !seen.key?(current)
        seen[current] = true
        message, cause_message = messages(current)
        pairs << [current.message, message] if message != current.message && !default_message?(current)
        cause = current.cause
        pairs << [cause.message, CAUSE_MESSAGE_LEFT_OUT] if cause && cause_message.nil? && !default_message?(cause)
        current = cause
      end
      pairs.reject { |quoted, _| quoted.empty? }.uniq.sort_by { |quoted, _| -quoted.length }
    end

    sig { params(error: Exception).returns(T::Boolean) }
    def self.default_message?(error)
      error.message == error.class.name
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
