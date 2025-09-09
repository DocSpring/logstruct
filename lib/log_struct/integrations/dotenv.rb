# typed: strict
# frozen_string_literal: true

# rubocop:disable Sorbet/ConstantsFromStrings
require_relative "../boot_buffer"
require "pathname"

begin
  require "dotenv-rails"
rescue LoadError
  # Dotenv-rails gem is not available, integration will be skipped
end

module LogStruct
  module Integrations
    # Dotenv integration: emits structured logs for load/update/save/restore events
    module Dotenv
      extend T::Sig
      extend IntegrationInterface
      @original_logger_setter = T.let(nil, T.nilable(UnboundMethod))

      # Internal state holder to avoid duplicate subscriptions in a Sorbet-friendly way
      State = ::Struct.new(:subscribed)
      STATE = T.let(State.new(false), State)

      sig { override.params(config: LogStruct::Configuration).returns(T.nilable(T::Boolean)) }
      def self.setup(config)
        # Only set up if dotenv-rails is available
        return nil unless Object.const_defined?(:Dotenv)

        # Detachment is handled in Railtie after replay to preserve boot messages

        subscribe!
        true
      end

      class << self
        extend T::Sig

        sig { void }
        def subscribe!
          # Guard against double subscription
          return if STATE.subscribed

          instrumenter = defined?(::ActiveSupport::Notifications) ? ::ActiveSupport::Notifications : nil
          return unless instrumenter

          instrumenter.subscribe("load.dotenv") do |*args|
            # Allow tests to stub Log::Dotenv.new to force an error path
            LogStruct::Log::Dotenv.new
            event = ::ActiveSupport::Notifications::Event.new(*args)
            env = event.payload[:env]
            abs = env.filename
            file = begin
              if defined?(::Rails) && ::Rails.respond_to?(:root) && ::Rails.root
                Pathname.new(abs).relative_path_from(Pathname.new(::Rails.root.to_s)).to_s
              else
                abs
              end
            rescue
              abs
            end

            ts = event.time ? Time.at(event.time) : Time.now
            LogStruct.info(Log::Dotenv::Load.new(file: file, timestamp: ts))
          rescue => e
            if defined?(::Rails) && ::Rails.respond_to?(:env) && ::Rails.env == "test"
              raise
            else
              LogStruct.handle_exception(e, source: LogStruct::Source::Dotenv)
            end
          end

          instrumenter.subscribe("update.dotenv") do |*args|
            LogStruct::Log::Dotenv.new
            event = ::ActiveSupport::Notifications::Event.new(*args)
            diff = event.payload[:diff]
            vars = diff.env.keys.map(&:to_s)

            ts = event.time ? Time.at(event.time) : Time.now
            LogStruct.debug(Log::Dotenv::Update.new(vars: vars, timestamp: ts))
          rescue => e
            if defined?(::Rails) && ::Rails.respond_to?(:env) && ::Rails.env == "test"
              raise
            else
              LogStruct.handle_exception(e, source: LogStruct::Source::Dotenv)
            end
          end

          instrumenter.subscribe("save.dotenv") do |*args|
            LogStruct::Log::Dotenv.new
            event = ::ActiveSupport::Notifications::Event.new(*args)
            ts = event.time ? Time.at(event.time) : Time.now
            LogStruct.info(Log::Dotenv::Save.new(snapshot: true, timestamp: ts))
          rescue => e
            if defined?(::Rails) && ::Rails.respond_to?(:env) && ::Rails.env == "test"
              raise
            else
              LogStruct.handle_exception(e, source: LogStruct::Source::Dotenv)
            end
          end

          instrumenter.subscribe("restore.dotenv") do |*args|
            LogStruct::Log::Dotenv.new
            event = ::ActiveSupport::Notifications::Event.new(*args)
            diff = event.payload[:diff]
            vars = diff.env.keys.map(&:to_s)

            ts = event.time ? Time.at(event.time) : Time.now
            LogStruct.info(Log::Dotenv::Restore.new(vars: vars, timestamp: ts))
          rescue => e
            if defined?(::Rails) && ::Rails.respond_to?(:env) && ::Rails.env == "test"
              raise
            else
              LogStruct.handle_exception(e, source: LogStruct::Source::Dotenv)
            end
          end

          STATE.subscribed = true
        end
      end

      # Early boot subscription to buffer structured logs until logger is ready
      @@boot_subscribed = T.let(false, T::Boolean)
      sig { void }
      def self.setup_boot
        return if @@boot_subscribed
        return unless defined?(::ActiveSupport::Notifications)

        instrumenter = if Object.const_defined?(:Dotenv)
          dm = T.unsafe(Object.const_get(:Dotenv))
          dm.respond_to?(:instrumenter) ? T.unsafe(dm).instrumenter : ::ActiveSupport::Notifications
        else
          ::ActiveSupport::Notifications
        end

        instrumenter.subscribe("load.dotenv") do |*args|
          event = ::ActiveSupport::Notifications::Event.new(*args)
          env = event.payload[:env]
          abs = env.filename
          file = begin
            if defined?(::Rails) && ::Rails.respond_to?(:root) && ::Rails.root
              Pathname.new(abs).relative_path_from(Pathname.new(::Rails.root.to_s)).to_s
            else
              abs
            end
          rescue
            abs
          end
          ts = event.time ? Time.at(event.time) : Time.now
          LogStruct::BootBuffer.add(Log::Dotenv::Load.new(file: file, timestamp: ts))
        rescue => e
          LogStruct.handle_exception(e, source: LogStruct::Source::Dotenv)
        end

        instrumenter.subscribe("update.dotenv") do |*args|
          event = ::ActiveSupport::Notifications::Event.new(*args)
          diff = event.payload[:diff]
          vars = diff.env.keys.map(&:to_s)
          ts = event.time ? Time.at(event.time) : Time.now
          LogStruct::BootBuffer.add(Log::Dotenv::Update.new(vars: vars, timestamp: ts))
        rescue => e
          LogStruct.handle_exception(e, source: LogStruct::Source::Dotenv)
        end

        instrumenter.subscribe("save.dotenv") do |*args|
          event = ::ActiveSupport::Notifications::Event.new(*args)
          ts = event.time ? Time.at(event.time) : Time.now
          LogStruct::BootBuffer.add(Log::Dotenv::Save.new(snapshot: true, timestamp: ts))
        rescue => e
          LogStruct.handle_exception(e, source: LogStruct::Source::Dotenv)
        end

        instrumenter.subscribe("restore.dotenv") do |*args|
          event = ::ActiveSupport::Notifications::Event.new(*args)
          diff = event.payload[:diff]
          vars = diff.env.keys.map(&:to_s)
          ts = event.time ? Time.at(event.time) : Time.now
          LogStruct::BootBuffer.add(Log::Dotenv::Restore.new(vars: vars, timestamp: ts))
        rescue => e
          LogStruct.handle_exception(e, source: LogStruct::Source::Dotenv)
        end

        @@boot_subscribed = true
      end

      # Intercept Dotenv::Rails#logger= to defer replay until we resolve policy
      sig { void }
      def self.intercept_logger_setter!
        return unless Object.const_defined?(:Dotenv)
        dotenv_mod = T.unsafe(Object.const_get(:Dotenv))
        return unless dotenv_mod.const_defined?(:Rails)
        klass = T.unsafe(dotenv_mod.const_get(:Rails))
        return if klass.instance_variable_defined?(:@_logstruct_replay_patched)

        original = klass.instance_method(:logger=)
        @original_logger_setter = original

        mod = Module.new do
          define_method :logger= do |new_logger|
            # Defer replay: store desired logger, keep ReplayLogger as current
            instance_variable_set(:@logstruct_pending_dotenv_logger, new_logger)
            new_logger
          end

          define_method :logstruct_pending_dotenv_logger do
            instance_variable_get(:@logstruct_pending_dotenv_logger)
          end
        end

        klass.prepend(mod)
        klass.instance_variable_set(:@_logstruct_replay_patched, true)
      end

      # Decide which boot logs to emit after user initializers
      sig { void }
      def self.resolve_boot_logs!
        dotenv_mod = Object.const_defined?(:Dotenv) ? T.unsafe(Object.const_get(:Dotenv)) : nil
        klass = dotenv_mod&.const_defined?(:Rails) ? T.unsafe(dotenv_mod.const_get(:Rails)) : nil

        pending_logger = nil
        railtie_instance = nil
        if klass&.respond_to?(:instance)
          railtie_instance = klass.instance
          if railtie_instance.respond_to?(:logstruct_pending_dotenv_logger)
            pending_logger = T.unsafe(railtie_instance).logstruct_pending_dotenv_logger
          end
        end

        if LogStruct.enabled? && LogStruct.config.integrations.enable_dotenv
          # Structured path
          if pending_logger && railtie_instance
            # Clear any buffered original logs
            current_logger = railtie_instance.logger if railtie_instance.respond_to?(:logger)
            if current_logger && current_logger.class.name.end_with?("ReplayLogger")
              begin
                logs = current_logger.instance_variable_get(:@logs)
                logs.clear if logs.respond_to?(:clear)
              rescue
                # best effort
              end
            end
            railtie_instance.config.dotenv.logger = pending_logger
          end

          # Detach original subscriber and subscribe runtime structured
          if dotenv_mod&.const_defined?(:LogSubscriber)
            T.unsafe(dotenv_mod.const_get(:LogSubscriber)).detach_from(:dotenv)
          end
          LogStruct::Integrations::Dotenv.subscribe!

          require_relative "../boot_buffer"
          LogStruct::BootBuffer.flush
        else
          # Original path: replay dotenv lines, drop structured buffer
          if railtie_instance && @original_logger_setter
            setter = @original_logger_setter
            new_logger = pending_logger
            if new_logger.nil? && ENV["RAILS_LOG_TO_STDOUT"].to_s.strip != ""
              require "logger"
              require "active_support/tagged_logging"
              new_logger = ActiveSupport::TaggedLogging.new(::Logger.new($stdout)).tagged("dotenv")
            end
            setter.bind_call(railtie_instance, new_logger) if new_logger
          end
          require_relative "../boot_buffer"
          LogStruct::BootBuffer.clear
        end
      end
    end
  end
end

# Subscribe immediately to capture earliest dotenv events into BootBuffer
LogStruct::Integrations::Dotenv.setup_boot

# rubocop:enable Sorbet/ConstantsFromStrings
