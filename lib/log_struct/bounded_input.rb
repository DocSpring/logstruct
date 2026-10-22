# typed: strict
# frozen_string_literal: true

require "action_controller"

module LogStruct
  module BoundedInput
    extend T::Sig

    MAX_DEPTH = 20
    MAX_NODES = 1_000

    class State < T::Struct
      prop :remaining_nodes, Integer, default: MAX_NODES
      prop :truncated, T::Boolean, default: false
    end

    sig do
      params(value: T.untyped, state: State, depth: Integer, ancestors: T::Hash[T.untyped, T::Boolean]).returns(T.untyped)
    end
    def self.copy(value, state:, depth: 0, ancestors: {}.compare_by_identity)
      if depth > MAX_DEPTH || ancestors.key?(value) || state.remaining_nodes <= 0
        state.truncated = true
        return nil
      end
      state.remaining_nodes -= 1

      case value
      when Hash, ::ActionController::Parameters
        ancestors[value] = true
        begin
          result = {}
          limit = LogStruct.config.limits.max_hash_keys
          value.each_pair.with_index do |(key, child), index|
            if index >= limit
              state.truncated = true
              break
            end
            if key.to_s.bytesize > LogStruct.config.limits.max_string_bytes
              state.truncated = true
              next
            end

            result[key] = copy(child, state: state, depth: depth + 1, ancestors: ancestors)
          end
          result
        ensure
          ancestors.delete(value)
        end
      when Array
        ancestors[value] = true
        begin
          limit = LogStruct.config.limits.max_array_items
          state.truncated = true if value.length > limit
          value.first(limit).map do |child|
            copy(child, state: state, depth: depth + 1, ancestors: ancestors)
          end
        ensure
          ancestors.delete(value)
        end
      else
        value
      end
    end
  end
end
