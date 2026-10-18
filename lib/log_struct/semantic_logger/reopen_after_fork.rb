# typed: strict
# frozen_string_literal: true

module LogStruct
  module SemanticLogger
    # SemanticLogger writes lines from a background thread, and a forked child doesn't get its parent's threads, so
    # lines logged in Puma, Unicorn, Passenger or Pitchfork workers, Resque jobs and other forked children were never
    # written. Ruby calls Process._fork for every fork, so each child reopens the appenders (a new writer thread).
    module ReopenAfterFork
      extend T::Sig

      @installed = T.let(false, T::Boolean)

      sig { void }
      def self.install!
        return if @installed
        @installed = true

        Process.singleton_class.prepend(ForkHook)
      end

      module ForkHook
        extend T::Sig

        sig { returns(Integer) }
        def _fork
          pid = T.let(super, Integer)
          if pid.zero?
            begin
              ::SemanticLogger.reopen
            rescue => e
              LogStruct.handle_exception(e, source: LogStruct::Source::Internal, context: {integration: :semantic_logger})
            end
          end
          pid
        end
      end
    end
  end
end
