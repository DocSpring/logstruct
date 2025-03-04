# typed: strict
# frozen_string_literal: true

module LogStruct
  # Define log levels as an enum
  class LogLevel < T::Enum
    enums do
      # Standard log levels
      Debug = new(:debug)
      Info = new(:info)
      Warn = new(:warn)
      Error = new(:error)
      Fatal = new(:fatal)
      Unknown = new(:unknown)
    end
  end
end
