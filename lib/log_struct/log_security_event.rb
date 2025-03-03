# typed: strict
# frozen_string_literal: true

module LogStruct
  # Define log source types as an enum
  class LogSecurityEvent < T::Enum
    enums do
      IPSpoof = new(:ip_spoof)
      CSRFError = new(:csrf_error)
      BlockedHost = new(:blocked_host)
    end
  end
end
