# typed: strict
# frozen_string_literal: true

# RBI file for Logger constants
class Logger
  # Severity constants that are accessible directly on the Logger class
  DEBUG = T.let(0, Integer)
  INFO = T.let(1, Integer)
  WARN = T.let(2, Integer)
  ERROR = T.let(3, Integer)
  FATAL = T.let(4, Integer)
  UNKNOWN = T.let(5, Integer)
end