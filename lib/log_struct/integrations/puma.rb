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
          rack_handler_patched: false,
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
          LogStruct::Debug.log(:puma, "setup() called")
          return nil unless config.integrations.enable_puma

          # Ensure Puma is loaded so we can patch its classes
          begin
            require "puma"
            LogStruct::Debug.log(:puma, "Puma gem loaded successfully")
          rescue LoadError
            LogStruct::Debug.log(:puma, "Puma gem not available, skipping integration")
            return nil
          end

          # Switch SemanticLogger to synchronous mode to prevent the async
          # processor thread from dying when Puma forks worker processes.
          # In clustered mode, each forked worker inherits a dead thread
          # reference from the master process. Sync mode processes logs
          # immediately in the calling thread, avoiding this issue entirely.
          LogStruct::Debug.log(:puma, "Switching SemanticLogger to sync mode")
          ::SemanticLogger.sync!

          install_patches!

          if ARGV.include?("server")
            LogStruct::Debug.log(:puma, "Rails server detected, loading Rack::Handler::Puma")
            # For rails server, explicitly load and patch Rack::Handler::Puma
            # (it may not be loaded yet when install_patches! runs)
            begin
              require "rack/handler/puma"
              patch_rack_handler_puma!
            rescue LoadError
              # rack/handler/puma not available
            end

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
            # Register at_exit to emit shutdown log when process exits.
            # We intentionally do NOT use Signal.trap because:
            # 1. Signal handlers in Ruby have restrictions on what operations are safe
            # 2. Logging involves I/O and potential mutex operations (SemanticLogger)
            # 3. at_exit runs in a normal context after signal handling completes
            at_exit do
              emit_shutdown!("process exit")
              begin
                $stdout.flush
              rescue
                nil
              end
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

          LogStruct::Debug.log(:puma, "install_patches! called")
          state_reset!

          patch_puma_classes!
          patch_rack_handler_puma!

          LogStruct::Debug.log(:puma, "install_patches! complete")
        end

        sig { void }
        def patch_puma_classes!
          return unless ::Object.const_defined?(:Puma)

          # rubocop:disable Sorbet/ConstantsFromStrings
          puma_mod = ::Object.const_get(:Puma)

          if puma_mod.const_defined?(:LogWriter)
            puma_mod.const_get(:LogWriter).prepend(LogWriterPatch)
            LogStruct::Debug.log(:puma, "Patched Puma::LogWriter")
          end

          if puma_mod.const_defined?(:Events)
            puma_mod.const_get(:Events).prepend(EventsPatch)
            LogStruct::Debug.log(:puma, "Patched Puma::Events")
          end
          # rubocop:enable Sorbet/ConstantsFromStrings
        rescue => e
          handle_integration_error(e)
        end

        sig { params(e: StandardError).void }
        def handle_integration_error(e)
          server_mode = ::LogStruct.server_mode?
          if defined?(::Rails) && ::Rails.respond_to?(:env) && ::Rails.env.test? && !server_mode
            raise e
          else
            LogStruct.handle_exception(e, source: Source::Puma)
          end
        end

        # Patch Rack::Handler::Puma if available and not already patched.
        # Returns true if patched, false if already patched or not available.
        sig { returns(T::Boolean) }
        def patch_rack_handler_puma!
          return false if STATE[:rack_handler_patched]
          return false unless ::Object.const_defined?(:Rack)

          # rubocop:disable Sorbet/ConstantsFromStrings
          rack_mod = ::Object.const_get(:Rack)
          return false unless rack_mod.const_defined?(:Handler)

          handler_mod = rack_mod.const_get(:Handler)
          return false unless handler_mod.const_defined?(:Puma)

          handler = handler_mod.const_get(:Puma)
          handler.singleton_class.prepend(RackHandlerPatch)
          STATE[:rack_handler_patched] = true
          LogStruct::Debug.log(:puma, "Patched Rack::Handler::Puma")
          # rubocop:enable Sorbet/ConstantsFromStrings
          true
        rescue => e
          handle_integration_error(e)
          false
        end

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

        sig { void }
        def emit_started!
          si = T.cast(STATE[:start_info], T::Hash[Symbol, T.untyped])
          LogStruct::Debug.log(:puma, "emit_started! called, pid=#{Process.pid}")
          LogStruct::Debug.log(:puma, "  mode=#{si[:mode]}, env=#{si[:environment]}")
          LogStruct::Debug.log(:puma, "  listening=#{si[:listening].inspect}")

          log = Log::Puma::Start.new(
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

          LogStruct::Debug.log(:puma, "emit_shutdown! called, pid=#{Process.pid}")

          log = Log::Puma::Shutdown.new(
            process_id: T.cast(STATE[:start_info], T::Hash[Symbol, T.untyped])[:pid] || Process.pid,
            level: Level::Info,
            timestamp: Time.now
          )
          begin
            LogStruct.info(log)
          rescue ThreadError, IOError
            # During shutdown, SemanticLogger may not be able to process logs.
            # Write JSON directly to stdout as a fallback.
            data = log.serialize
            data[:prog] = "Rails"
            $stdout.write("#{data.to_json}\n")
          end
          $stdout.flush
        rescue => e
          handle_integration_error(e)
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
          super unless consumed
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
            options: T.untyped,
            block: T.nilable(T.proc.returns(T.untyped))
          ).returns(T.untyped)
        end
        def run(app, **options, &block)
          begin
            si = T.cast(::LogStruct::Integrations::Puma::STATE[:start_info], T::Hash[Symbol, T.untyped])
            si[:mode] ||= "single"
            si[:environment] ||= ((defined?(::Rails) && ::Rails.respond_to?(:env)) ? ::Rails.env : nil)
            si[:pid] ||= Process.pid
            si[:listening] ||= []
            port = options[:Port] || options[:port]
            host = options[:Host] || options[:host]
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
            result = super
          ensure
            state = ::LogStruct::Integrations::Puma::STATE
            # Emit pending started log if we haven't yet
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
            # Emit shutdown log when server stops
            # This runs right after Rack::Handler::Puma.run returns, before at_exit
            begin
              ::LogStruct::Integrations::Puma.emit_shutdown!("server stopped")
            rescue => e
              ::LogStruct::Integrations::Puma.handle_integration_error(e)
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
