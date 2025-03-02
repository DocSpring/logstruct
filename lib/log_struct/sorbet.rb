# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

# Extend T::Sig to all modules so we don't have to write `extend T::Sig` everywhere.
# See: https://sorbet.org/docs/sigs
class Module
  include T::Sig
end
