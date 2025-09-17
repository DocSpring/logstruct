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

    sig { returns(T::Boolean) }
    def self.patch!
      begin
        require "rails/command"
        require "rails/commands/server/server_command"
      rescue LoadError
        # Best-effort – if Rails isn't available yet we'll try again later
        return false
      end

      server_command = T.let(nil, T.untyped)
      # rubocop:disable Sorbet/ConstantsFromStrings
      begin
        server_command = ::Object.const_get("Rails::Command::ServerCommand")
      rescue NameError
        server_command = nil
      end
      # rubocop:enable Sorbet/ConstantsFromStrings
      return false unless server_command

      patch_server_command(server_command)
      true
    end

    sig { params(server_command: T.untyped).void }
    def self.patch_server_command(server_command)
      return if server_command <= ServerCommandSilencer

      server_command.prepend(ServerCommandSilencer)
    end

    module ServerCommandSilencer
      extend T::Sig

      sig { params(args: T.untyped, block: T.nilable(T.proc.returns(T.untyped))).returns(T.untyped) }
      def perform(*args, &block)
        mark_server_mode!
        super
      end

      sig { params(server: T.untyped, url: T.nilable(String)).void }
      def print_boot_information(server, url)
        mark_server_mode!
        consume_boot_banner(server, url)
      end

      private

      sig { void }
      def mark_server_mode!
        ::LogStruct.instance_variable_set(:@server_mode, true)
      rescue
        # Ignore – server mode is best-effort
      end

      sig { params(server: T.untyped, url: T.nilable(String)).void }
      def consume_boot_banner(server, url)
        return unless defined?(::LogStruct::Integrations::Puma)

        begin
          ::LogStruct::Integrations::Puma.emit_boot_if_needed!
        rescue => e
          ::LogStruct::Integrations::Puma.handle_integration_error(e)
        end

        begin
          model = ::ActiveSupport::Inflector.demodulize(server)
        rescue
          model = "Puma"
        end

        lines = [
          "=> Booting #{model}",
          build_rails_banner_line(url),
          "=> Run `#{lookup_executable} --help` for more startup options"
        ]

        lines.each do |line|
          ::LogStruct::Integrations::Puma.process_line(line)
        rescue => e
          ::LogStruct::Integrations::Puma.handle_integration_error(e)
        end
      end

      sig { params(url: T.nilable(String)).returns(String) }
      def build_rails_banner_line(url)
        suffix = url ? " #{url}" : ""
        "=> Rails #{::Rails.version} application starting in #{::Rails.env}#{suffix}"
      rescue
        "=> Rails application starting"
      end

      sig { returns(String) }
      def lookup_executable
        return "rails" unless T.unsafe(self).respond_to?(:executable, true)

        T.cast(T.unsafe(self).send(:executable), String)
      rescue
        "rails"
      end
    end
  end
end
