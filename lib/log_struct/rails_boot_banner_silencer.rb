# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module LogStruct
  module RailsBootBannerSilencer
    extend T::Sig

    @installed = T.let(false, T::Boolean)

    sig { void }
    def self.install!
      return if @installed
      @installed = true

      return unless ARGV.include?("server")
      patch!
    end

    sig { void }
    def self.patch!
      # Do not suppress Rails::Server boot info completely; we rely on
      # some of those lines for Puma readiness parsing.

      # Also silence Thor/ServerCommand banner printing used by Rails CLI
      # Minimal silencer: leave as no-op to avoid Sorbet issues.
      nil
    end
  end
end
