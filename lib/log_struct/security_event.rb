# typed: strict
# frozen_string_literal: true

module LogStruct
  # Define log source types as an enum
  class SecurityEvent < T::Enum
    enums do
      IpSpoof = new(:ip_spoof_attack)
      Csrf = new(:csrf_token_error)
      BlockedHost = new(:blocked_host)
    end
  end
end
