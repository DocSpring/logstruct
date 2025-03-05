# typed: strict
# frozen_string_literal: true

# Note: We use T::Struct for our Log classes so Sorbet is a hard requirement,
# not an optional dependency.
require "sorbet-runtime"
require "log_struct/sorbet/serialize_symbol_keys"

# Don't extend T::Sig to all modules! We're just a library, not a private Rails application
# See: https://sorbet.org/docs/sigs
# class Module
#   include T::Sig
# end
