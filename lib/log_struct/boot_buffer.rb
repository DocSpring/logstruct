# typed: strict
# frozen_string_literal: true

module LogStruct
  # Collects structured logs during very early boot before the logger is ready.
  module BootBuffer
    extend T::Sig

    @@logs = T.let([], T::Array[LogStruct::Log::Interfaces::CommonFields])

    sig { params(log: LogStruct::Log::Interfaces::CommonFields).void }
    def self.add(log)
      @@logs << log
    end

    sig { void }
    def self.flush
      return if @@logs.empty?
      @@logs.each { |l| LogStruct.info(l) }
      @@logs.clear
    end

    sig { void }
    def self.clear
      @@logs.clear
    end
  end
end
