# typed: strict
# frozen_string_literal: true

module LogStruct
  module Integrations
    module Puma
      extend T::Sig
      extend T::Helpers

      STATE = T.let(
        {
          installed: false,
          boot_emitted: false,
          shutdown_emitted: false,
          handler_pending_started: false,
          start_info: {
            mode: nil,
            puma_version: nil,
            puma_codename: nil,
            ruby_version: nil,
            min_threads: nil,
            max_threads: nil,
            environment: nil,
            pid: nil,
            listening: []
          }
        },
        T::Hash[Symbol, T.untyped]
      )

      class << self
        extend T::Sig

        sig { params(config: LogStruct::Configuration).returns(T.nilable(T::Boolean)) }
        def setup(config)
          return nil unless config.integrations.enable_puma

          # No stdout wrapping here.

          # Ensure Puma is loaded so we can patch its classes
          begin
            require "puma"
          rescue LoadError
            # If Puma isn't available, skip setup
            return nil
          end

          install_patches!

          if ARGV.include?("server")
            # Emit deterministic boot/started events based on CLI args
            begin
              port = T.let(nil, T.nilable(String))
              ARGV.each_with_index do |arg, idx|
                if arg == "-p" || arg == "--port"
                  port = ARGV[idx + 1]
                  break
                elsif arg.start_with?("--port=")
                  port = arg.split("=", 2)[1]
                  break
                end
              end
              si = T.cast(STATE[:start_info], T::Hash[Symbol, T.untyped])
              si[:pid] ||= Process.pid
              si[:environment] ||= ((defined?(::Rails) && ::Rails.respond_to?(:env)) ? ::Rails.env : nil)
              si[:mode] ||= "single"
              if port && !T.cast(si[:listening], T::Array[T.untyped]).any? { |a| a.to_s.include?(":" + port.to_s) }
                si[:listening] = ["tcp://127.0.0.1:#{port}"]
              end
              emit_boot_if_needed!
              unless STATE[:started_emitted]
                emit_started!
                STATE[:started_emitted] = true
              end
            rescue => e
              handle_integration_error(e)
            end
            begin
              %w[TERM INT].each do |sig|
                Signal.trap(sig) { emit_shutdown!(sig) }
              end
            rescue => e
              handle_integration_error(e)
            end
            at_exit do
              emit_shutdown!("Exiting")
            rescue => e
              handle_integration_error(e)
            end

            # Connection-based readiness: emit started once port is accepting connections
            # No background threads or sockets; rely solely on parsing Puma output
          end
          true
        end

        sig { void }
        def install_patches!
          return if STATE[:installed]
          STATE[:installed] = true

          state_reset!

          begin
            begin
              require "puma"
            rescue => e
              handle_integration_error(e)
            end
            puma_mod = ::Object.const_defined?(:Puma) ? T.unsafe(::Object.const_get(:Puma)) : nil # rubocop:disable Sorbet/ConstantsFromStrings
            # rubocop:disable Sorbet/ConstantsFromStrings
            if puma_mod&.const_defined?(:LogWriter)
              T.unsafe(::Object.const_get("Puma::LogWriter")).prepend(LogWriterPatch)
            end
            if puma_mod&.const_defined?(:Events)
              ev = T.unsafe(::Object.const_get("Puma::Events"))
              ev.prepend(EventsPatch)
            end
            # Patch Rack::Handler::Puma.run to emit lifecycle logs using options
            if ::Object.const_defined?(:Rack)
              rack_mod = T.unsafe(::Object.const_get(:Rack))
              if rack_mod.const_defined?(:Handler)
                handler_mod = T.unsafe(rack_mod.const_get(:Handler))
                if handler_mod.const_defined?(:Puma)
                  handler = T.unsafe(handler_mod.const_get(:Puma))
                  handler.singleton_class.prepend(RackHandlerPatch)
                end
              end
            end
            # Avoid patching CLI/Server; rely on log parsing
            # Avoid patching CLI to minimize version-specific risks
            # rubocop:enable Sorbet/ConstantsFromStrings
          rescue => e
            handle_integration_error(e)
          end

          # Rely on Puma patches to observe lines
        end

        sig { params(e: StandardError).void }
        def handle_integration_error(e)
          server_mode = false
          begin
            server_mode = ::LogStruct.instance_variable_defined?(:@server_mode) && ::LogStruct.instance_variable_get(:@server_mode)
          rescue
            server_mode = false
          end
          if defined?(::Rails) && ::Rails.respond_to?(:env) && ::Rails.env.test? && !server_mode
            raise e
          else
            LogStruct.handle_exception(e, source: Source::Puma)
          end
        end

        # No stdout interception

        sig { void }
        def state_reset!
          STATE[:boot_emitted] = false
          STATE[:shutdown_emitted] = false
          STATE[:started_emitted] = false
          STATE[:handler_pending_started] = false
          STATE[:start_info] = {
            mode: nil,
            puma_version: nil,
            puma_codename: nil,
            ruby_version: nil,
            min_threads: nil,
            max_threads: nil,
            environment: nil,
            pid: nil,
            listening: []
          }
        end

        sig { params(line: String).returns(T::Boolean) }
        def process_line(line)
          l = line.to_s.strip
          return false if l.empty?

          # Suppress non-JSON rails banners
          return true if l.start_with?("=> ")

          # Ignore boot line
          return true if l.start_with?("=> Booting Puma")

          if l.start_with?("Puma starting in ")
            # Example: Puma starting in single mode...
            T.cast(STATE[:start_info], T::Hash[Symbol, T.untyped])[:mode] = l.sub("Puma starting in ", "").sub(" mode...", "")
            return true
          end

          if (m = l.match(/^(?:\*\s*)?Puma version: (\S+)(?:.*"([^\"]+)")?/))
            T.cast(STATE[:start_info], T::Hash[Symbol, T.untyped])[:puma_version] = m[1]
            if m[2]
              T.cast(STATE[:start_info], T::Hash[Symbol, T.untyped])[:puma_codename] = m[2]
            end
            return true
          end

          if (m = l.match(/^\* Ruby version: (.+)$/))
            T.cast(STATE[:start_info], T::Hash[Symbol, T.untyped])[:ruby_version] = m[1]
            return true
          end

          if (m = l.match(/^(?:\*\s*)?Min threads: (\d+)/))
            T.cast(STATE[:start_info], T::Hash[Symbol, T.untyped])[:min_threads] = m[1].to_i
            return true
          end

          if (m = l.match(/^(?:\*\s*)?Max threads: (\d+)/))
            T.cast(STATE[:start_info], T::Hash[Symbol, T.untyped])[:max_threads] = m[1].to_i
            return true
          end

          if (m = l.match(/^(?:\*\s*)?Environment: (\S+)/))
            T.cast(STATE[:start_info], T::Hash[Symbol, T.untyped])[:environment] = m[1]
            return true
          end

          if (m = l.match(/^(?:\*\s*)?PID:\s+(\d+)/))
            T.cast(STATE[:start_info], T::Hash[Symbol, T.untyped])[:pid] = m[1].to_i
            return true
          end

          if (m = l.match(/^\*?\s*Listening on (.+)$/))
            si = T.cast(STATE[:start_info], T::Hash[Symbol, T.untyped])
            list = T.cast(si[:listening], T::Array[T.untyped])
            address = T.must(m[1])
            list << address unless list.include?(address)
            # Emit started when we see the first listening address
            if !STATE[:started_emitted]
              emit_started!
              STATE[:started_emitted] = true
            end
            return true
          end

          if l == "Use Ctrl-C to stop"
            si = T.cast(STATE[:start_info], T::Hash[Symbol, T.untyped])
            # Fallback: if no listening address captured yet, infer from ARGV
            if T.cast(si[:listening], T::Array[T.untyped]).empty?
              begin
                port = T.let(nil, T.untyped)
                ARGV.each_with_index do |arg, idx|
                  if arg == "-p" || arg == "--port"
                    port = ARGV[idx + 1]
                    break
                  elsif arg.start_with?("--port=")
                    port = arg.split("=", 2)[1]
                    break
                  end
                end
                if port
                  si[:listening] << "tcp://127.0.0.1:#{port}"
                end
              rescue => e
                handle_integration_error(e)
              end
            end
            if !STATE[:started_emitted]
              emit_started!
              STATE[:started_emitted] = true
            end
            return false
          end

          if l.start_with?("- Gracefully stopping")
            emit_shutdown!(l)
            return true
          end

          if l.start_with?("=== puma shutdown:")
            emit_shutdown!(l)
            return true
          end

          if l == "- Goodbye!"
            # Swallow
            return true
          end

          if l == "Exiting"
            emit_shutdown!(l)
            return true
          end

          false
        end

        sig { void }
        def emit_boot_if_needed!
          # Intentionally no-op: we no longer emit a boot log
          STATE[:boot_emitted] = true
        end

        # No server hooks; rely on parsing only

        sig { void }
        def emit_started!
          si = T.cast(STATE[:start_info], T::Hash[Symbol, T.untyped])
          log = Log::Puma::Started.new(
            mode: T.cast(si[:mode], T.nilable(String)),
            puma_version: T.cast(si[:puma_version], T.nilable(String)),
            puma_codename: T.cast(si[:puma_codename], T.nilable(String)),
            ruby_version: T.cast(si[:ruby_version], T.nilable(String)),
            min_threads: T.cast(si[:min_threads], T.nilable(Integer)),
            max_threads: T.cast(si[:max_threads], T.nilable(Integer)),
            environment: T.cast(si[:environment], T.nilable(String)),
            process_id: T.cast(STATE[:start_info], T::Hash[Symbol, T.untyped])[:pid] || Process.pid,
            listening_addresses: T.cast(T.cast(STATE[:start_info], T::Hash[Symbol, T.untyped])[:listening], T::Array[String]),
            level: Level::Info,
            timestamp: Time.now
          )
          LogStruct.info(log)
          STATE[:handler_pending_started] = false
          # Only use LogStruct; SemanticLogger routes to STDOUT in test
        end

        sig { params(_message: String).void }
        def emit_shutdown!(_message)
          return if STATE[:shutdown_emitted]
          STATE[:shutdown_emitted] = true
          log = Log::Puma::Shutdown.new(
            process_id: T.cast(STATE[:start_info], T::Hash[Symbol, T.untyped])[:pid] || Process.pid,
            level: Level::Info,
            timestamp: Time.now
          )
          LogStruct.info(log)
          # Only use LogStruct; SemanticLogger routes to STDOUT in test
          # Let SemanticLogger appender write to STDOUT
        end
      end

      # STDOUT interception is handled globally via StdoutFilter; keep Puma patches minimal

      # Patch Puma::LogWriter to intercept log writes
      module LogWriterPatch
        extend T::Sig

        sig { params(msg: String).returns(T.untyped) }
        def log(msg)
          consumed = ::LogStruct::Integrations::Puma.process_line(msg)
          super unless consumed
        end

        sig { params(msg: String).returns(T.untyped) }
        def write(msg)
          any_consumed = T.let(false, T::Boolean)
          msg.to_s.each_line do |l|
            any_consumed = true if ::LogStruct::Integrations::Puma.process_line(l)
          end
          super unless any_consumed
        end

        sig { params(msg: String).returns(T.untyped) }
        def <<(msg)
          any_consumed = T.let(false, T::Boolean)
          msg.to_s.each_line do |l|
            any_consumed = true if ::LogStruct::Integrations::Puma.process_line(l)
          end
          super unless any_consumed
        end

        sig { params(msg: String).returns(T.untyped) }
        def puts(msg)
          consumed = ::LogStruct::Integrations::Puma.process_line(msg)
          if consumed
            # attempt to suppress; only forward if not consumed
            return nil
          end
          if ::Kernel.instance_variables.include?(:@stdout)
            io = T.unsafe(::Kernel.instance_variable_get(:@stdout))
            return io.puts(msg)
          end
          super
        end

        sig { params(msg: String).returns(T.untyped) }
        def info(msg)
          consumed = ::LogStruct::Integrations::Puma.process_line(msg)
          super unless consumed
        end
      end

      # Patch Puma::Events as a fallback for some versions where Events handles output
      module EventsPatch
        extend T::Sig

        sig { params(str: String).returns(T.untyped) }
        def log(str)
          consumed = ::LogStruct::Integrations::Puma.process_line(str)
          super unless consumed
        end
      end

      # Hook Rack::Handler::Puma.run to emit structured started/shutdown
      module RackHandlerPatch
        extend T::Sig

        sig do
          params(
            app: T.untyped,
            args: T.untyped,
            block: T.nilable(T.proc.returns(T.untyped))
          ).returns(T.untyped)
        end
        def run(app, *args, &block)
          rest = args
          options = T.let({}, T::Hash[T.untyped, T.untyped])
          rest.each do |value|
            next unless value.is_a?(Hash)
            options.merge!(value)
          end

          begin
            si = T.cast(::LogStruct::Integrations::Puma::STATE[:start_info], T::Hash[Symbol, T.untyped])
            si[:mode] ||= "single"
            si[:environment] ||= ((defined?(::Rails) && ::Rails.respond_to?(:env)) ? ::Rails.env : nil)
            si[:pid] ||= Process.pid
            si[:listening] ||= []
            port = T.let(nil, T.untyped)
            host = T.let(nil, T.untyped)
            if options.respond_to?(:[])
              port = options[:Port] || options["Port"] || options[:port] || options["port"]
              host = options[:Host] || options["Host"] || options[:host] || options["host"]
            end
            if port
              list = T.cast(si[:listening], T::Array[T.untyped])
              list.clear
              h = (host && host != "0.0.0.0") ? host : "127.0.0.1"
              list << "tcp://#{h}:#{port}"
            end
            state = ::LogStruct::Integrations::Puma::STATE
            state[:handler_pending_started] = true unless state[:started_emitted]
          rescue => e
            ::LogStruct::Integrations::Puma.handle_integration_error(e)
          end

          begin
            Kernel.at_exit do
              unless ::LogStruct::Integrations::Puma::STATE[:shutdown_emitted]
                ::LogStruct::Integrations::Puma.emit_shutdown!("Exiting")
                ::LogStruct::Integrations::Puma::STATE[:shutdown_emitted] = true
              end
            rescue => e
              ::LogStruct::Integrations::Puma.handle_integration_error(e)
            end
          rescue => e
            ::LogStruct::Integrations::Puma.handle_integration_error(e)
          end

          begin
            result = super(app, **options, &block)
          ensure
            state = ::LogStruct::Integrations::Puma::STATE
            if state[:handler_pending_started] && !state[:started_emitted]
              begin
                ::LogStruct::Integrations::Puma.emit_started!
                state[:started_emitted] = true
              rescue => e
                ::LogStruct::Integrations::Puma.handle_integration_error(e)
              ensure
                state[:handler_pending_started] = false
              end
            end
          end

          result
        end
      end

      # (No Launcher patch)

      # No Server patch

      # No InterceptorIO

      # Removed EventsInitPatch and CLIPatch to avoid version-specific conflicts
    end
  end
end
