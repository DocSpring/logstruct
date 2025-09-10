# typed: strict
# frozen_string_literal: true

module LogStruct
  module Integrations
    module Puma
      extend T::Sig
      extend T::Helpers

      class << self
        extend T::Sig
        STATE = T.let({
          installed: false,
          boot_emitted: false,
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
          T::Hash[Symbol, T.untyped])

        sig { params(config: LogStruct::Configuration).returns(T.nilable(T::Boolean)) }
        def setup(config)
          return nil unless config.integrations.enable_puma

          # Install patches now if Puma is already loaded; otherwise, hook into Kernel.require
          if Object.const_defined?(:Puma)
            install_patches!
          else
            begin
              ::Kernel.module_eval do
                alias_method :logstruct_orig_require, :require
                sig { params(path: String).returns(T::Boolean) }
                def require(path)
                  res = logstruct_orig_require(path)
                  if path == "puma" || path.start_with?("puma/")
                    ::LogStruct::Integrations::Puma.install_patches!
                  end
                  res
                end
              end
            rescue
              # Best-effort; if we can't hook require, we rely on late explicit install
            end
          end

          # Emit an early boot event with current PID
          emit_boot_if_needed!
          if ARGV.include?("server")
            # Do not emit starting early; wait for full details
            begin
              %w[TERM INT].each do |sig|
                prev = Signal.trap(sig) { emit_shutdown!(sig) }
                Signal.trap(sig, prev) if prev
              end
            rescue
              # ignore
            end
            at_exit do
              emit_shutdown!("Exiting")
            rescue
              # ignore
            end
          end
          true
        end

        sig { void }
        def install_patches!
          return if STATE[:installed]
          STATE[:installed] = true

          state_reset!

          begin
            puma_mod = ::Object.const_defined?(:Puma) ? T.unsafe(::Object.const_get(:Puma)) : nil # rubocop:disable Sorbet/ConstantsFromStrings
            # rubocop:disable Sorbet/ConstantsFromStrings
            if puma_mod&.const_defined?(:LogWriter)
              T.unsafe(::Object.const_get("Puma::LogWriter")).prepend(LogWriterPatch)
            end
            if puma_mod&.const_defined?(:Events)
              ev = T.unsafe(::Object.const_get("Puma::Events"))
              ev.prepend(EventsPatch)
            end
            # Avoid patching CLI to minimize version-specific risks
            # rubocop:enable Sorbet/ConstantsFromStrings
          rescue => e
            # Don't crash the app due to patching errors
            # Use standard error handling
            LogStruct::Concerns::ErrorHandling::ClassMethods.instance_method(:log_error).bind_call(self, e, source: Source::Internal, context: {integration: "puma"})
          end
        end

        sig { void }
        def state_reset!
          STATE[:boot_emitted] = false
          STATE[:started_emitted] = false
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

          if l.start_with?("Puma starting in ")
            # Example: Puma starting in single mode...
            T.cast(STATE[:start_info], T::Hash[Symbol, T.untyped])[:mode] = l.sub("Puma starting in ", "").sub(" mode...", "")
            emit_boot_if_needed!
            return true
          end

          if (m = l.match(/^\* Puma version: (\S+)(?:.*"([^\"]+)")?/))
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

          if (m = l.match(/^\*\s+Min threads: (\d+)/))
            T.cast(STATE[:start_info], T::Hash[Symbol, T.untyped])[:min_threads] = m[1].to_i
            return true
          end

          if (m = l.match(/^\*\s+Max threads: (\d+)/))
            T.cast(STATE[:start_info], T::Hash[Symbol, T.untyped])[:max_threads] = m[1].to_i
            return true
          end

          if (m = l.match(/^\*\s+Environment: (\S+)/))
            T.cast(STATE[:start_info], T::Hash[Symbol, T.untyped])[:environment] = m[1]
            return true
          end

          if (m = l.match(/^\*\s+PID:\s+(\d+)/))
            T.cast(STATE[:start_info], T::Hash[Symbol, T.untyped])[:pid] = m[1].to_i
            return true
          end

          if (m = l.match(/^\* Listening on (.+)$/))
            si = T.cast(STATE[:start_info], T::Hash[Symbol, T.untyped])
            si[:listening] << T.must(m[1])
            # If we have PID and at least one listening address, emit started now
            if !STATE[:started_emitted] && si[:pid]
              emit_started!
              STATE[:started_emitted] = true
            end
            return true
          end

          if l == "Use Ctrl-C to stop"
            si = T.cast(STATE[:start_info], T::Hash[Symbol, T.untyped])
            if !STATE[:started_emitted] && si[:pid] && T.cast(si[:listening], T::Array[T.untyped]).any?
              emit_started!
              STATE[:started_emitted] = true
            end
            return true
          end

          if l.start_with?("- Gracefully stopping")
            # Swallow
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
            # Swallow
            return true
          end

          false
        end

        sig { void }
        def emit_boot_if_needed!
          return if STATE[:boot_emitted]
          STATE[:boot_emitted] = true
          pid = T.cast(STATE[:start_info], T::Hash[Symbol, T.untyped])[:pid] || Process.pid
          log = Log::Puma::Boot.new(
            process_id: pid,
            level: Level::Info,
            timestamp: Time.now
          )
          LogStruct.info(log)
        end

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
        end

        sig { params(_message: String).void }
        def emit_shutdown!(_message)
          log = Log::Puma::Shutdown.new(
            process_id: T.cast(STATE[:start_info], T::Hash[Symbol, T.untyped])[:pid] || Process.pid,
            level: Level::Info,
            timestamp: Time.now
          )
          LogStruct.info(log)
        end
      end

      # (Removed stdout interception: we rely on Puma::LogWriter/Events patches.)

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

      class InterceptorIO
        extend T::Sig

        sig { params(io: T.untyped).void }
        def initialize(io)
          @io = T.let(io, T.untyped)
        end

        sig { params(msg: String).returns(T.untyped) }
        def write(msg)
          any = T.let(false, T::Boolean)
          msg.to_s.each_line { |l| any = true if ::LogStruct::Integrations::Puma.process_line(l) }
          return nil if any
          @io.write(msg)
        end

        sig { params(msg: String).returns(T.untyped) }
        def <<(msg)
          any = T.let(false, T::Boolean)
          msg.to_s.each_line { |l| any = true if ::LogStruct::Integrations::Puma.process_line(l) }
          return self if any
          @io << msg
        end

        sig { params(msg: T.untyped).returns(T.untyped) }
        def puts(msg = "")
          any = T.let(false, T::Boolean)
          msg.to_s.each_line { |l| any = true if ::LogStruct::Integrations::Puma.process_line(l) }
          return nil if any
          @io.puts(msg)
        end

        sig { params(args: T.untyped).returns(T.untyped) }
        def print(*args)
          s = args.join
          any = T.let(false, T::Boolean)
          s.to_s.each_line { |l| any = true if ::LogStruct::Integrations::Puma.process_line(l) }
          return nil if any
          @io.print(*args)
        end
      end

      # Removed EventsInitPatch and CLIPatch to avoid version-specific conflicts
    end
  end
end
