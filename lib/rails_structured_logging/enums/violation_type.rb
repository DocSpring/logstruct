# frozen_string_literal: true
# typed: strict

require 'sorbet-runtime'
require_relative 'enum_helpers'

module RailsStructuredLogging
  module Enums
    # Define violation types as an enum
    class ViolationType < T::Enum
      extend T::Sig
      extend EnumHelpers

      enums do
        IpSpoof = new(:ip_spoof_attack)
        Csrf = new(:csrf_token_error)
        BlockedHost = new(:blocked_host)
      end
    end
  end
end
