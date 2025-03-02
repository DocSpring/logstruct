# typed: strict
# frozen_string_literal: true

module LogStruct
  module Enums
    # Define violation types as an enum
    class ViolationType < T::Enum
      enums do
        IpSpoof = new(:ip_spoof_attack)
        Csrf = new(:csrf_token_error)
        BlockedHost = new(:blocked_host)
      end
    end
  end
end
