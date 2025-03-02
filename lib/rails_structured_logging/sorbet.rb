# typed: strict
# frozen_string_literal: true

# Enable type checking for the entire codebase
module RailsStructuredLogging
  # Extend T::Sig to all classes and modules
  module TypedSig
    extend T::Sig

    sig { params(base: Module).void }
    def self.included(base)
      base.extend(T::Sig)
    end
  end
end
