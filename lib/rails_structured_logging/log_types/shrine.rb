# typed: strict
# frozen_string_literal: true

require_relative "base"

module RailsStructuredLogging
  module LogTypes
    # Shrine operation log data class
    class ShrineLogData < BaseLogData
      # Shrine-specific fields
      sig { returns(Symbol) }
      attr_reader :operation

      sig { returns(T.nilable(Float)) }
      attr_reader :duration

      sig { returns(T.nilable(String)) }
      attr_reader :uploader

      sig { returns(T.nilable(T.any(Integer, String))) }
      attr_reader :record_id

      sig { returns(T.nilable(String)) }
      attr_reader :record_class

      sig { returns(T.nilable(String)) }
      attr_reader :storage

      sig { returns(T.nilable(String)) }
      attr_reader :location

      sig { returns(T.nilable(Integer)) }
      attr_reader :io_size

      # Initialize with all fields
      sig do
        params(
          src: Symbol,
          evt: Symbol,
          operation: Symbol,
          ts: T.nilable(Time),
          msg: T.nilable(String),
          duration: T.nilable(Float),
          uploader: T.nilable(String),
          record_id: T.nilable(T.any(Integer, String)),
          record_class: T.nilable(String),
          storage: T.nilable(String),
          location: T.nilable(String),
          io_size: T.nilable(Integer)
        ).void
      end
      def initialize(src:, evt:, operation:, ts: nil, msg: nil, duration: nil,
        uploader: nil, record_id: nil, record_class: nil,
        storage: nil, location: nil, io_size: nil)
        super(src: src, evt: evt, ts: ts, msg: msg)
        @operation = operation
        @duration = duration
        @uploader = uploader
        @record_id = record_id
        @record_class = record_class
        @storage = storage
        @location = location
        @io_size = io_size
      end

      # Convert to hash for logging
      sig { returns(T::Hash[Symbol, T.untyped]) }
      def to_h
        super.merge({
          operation: @operation,
          duration: @duration,
          uploader: @uploader,
          record_id: @record_id,
          record_class: @record_class,
          storage: @storage,
          location: @location,
          io_size: @io_size
        }.compact)
      end
    end

    # Valid Shrine event types
    SHRINE_EVENT_TYPES = T.let(
      %i[upload download open exists delete metadata].freeze,
      T::Array[Symbol]
    )

    # Helper method to create a Shrine log data object
    sig do
      params(
        event_name: Symbol,
        duration: T.nilable(Float),
        payload: T::Hash[Symbol, T.untyped]
      ).returns(ShrineLogData)
    end
    def self.create_shrine_log_data(event_name, duration, payload)
      # Validate event name
      raise ArgumentError, "Invalid Shrine event type: #{event_name}" unless SHRINE_EVENT_TYPES.include?(event_name)

      # Extract record info safely
      record_id = nil
      record_class = nil
      if payload.dig(:options, :record).present?
        record = payload[:options][:record]
        record_id = record.respond_to?(:id) ? record.id : nil
        record_class = record.class.to_s
      end

      # Create Shrine log data
      ShrineLogData.new(
        src: :shrine,
        evt: event_name,
        operation: event_name,
        duration: duration,
        uploader: payload[:uploader],
        storage: payload[:storage],
        location: payload[:location],
        io_size: payload[:io]&.size,
        record_id: record_id,
        record_class: record_class
      )
    end
  end
end
