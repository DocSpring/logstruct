# typed: strict
# frozen_string_literal: true

require "action_controller"

module LogStruct
  # Copies of logged Hashes and Arrays that stop before an input too large to copy in full
  module BoundedInput
    extend T::Sig

    # A Rails filter block with three arguments gets every parameter, so a copy for it keeps what the formatter
    # leaves out of the line. These limits only stop values no request sends: nesting deeper than the formatter
    # writes, and more values than a form or JSON body has. A copy that reaches one is truncated, and the
    # filters that read it fail closed.
    MAX_DEPTH = 20
    MAX_NODES = 10_000

    # The keys that count what a Hash's copy left out. The formatter writes them as it writes its own counts:
    # Rails' default filter_parameters include :_key, which would filter them.
    COUNT_KEYS = T.let(Set[:_more_keys, :_oversized_keys].freeze, T::Set[Symbol])

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
          value.each_pair do |key, child|
            break if state.truncated

            result[key] = copy(child, state: state, depth: depth + 1, ancestors: ancestors)
          end
          result
        ensure
          ancestors.delete(value)
        end
      when Array
        ancestors[value] = true
        begin
          result = []
          value.each do |child|
            break if state.truncated

            result << copy(child, state: state, depth: depth + 1, ancestors: ancestors)
          end
          result
        ensure
          ancestors.delete(value)
        end
      else
        value
      end
    end

    # How many keys a Hash or ActionController::Parameters has, without converting its values
    sig { params(hash: T.untyped).returns(Integer) }
    def self.key_count(hash)
      hash.is_a?(Hash) ? hash.size : hash.keys.size
    end

    # The first keys of a Hash or ActionController::Parameters as Symbols, for a log struct's Hash field, without
    # converting the keys the formatter would leave out. The formatter writes max_hash_keys entries of a Hash,
    # and the counts of the keys left out here are entries too: the last key's slot goes to _more_keys, and an
    # omitted oversized key's slot to _oversized_keys, so the formatter writes both counts as they are.
    sig { params(hash: T.untyped).returns(T::Hash[Symbol, T.untyped]) }
    def self.symbolize_keys(hash)
      limits = LogStruct.config.limits
      total = key_count(hash)
      examined = (total > limits.max_hash_keys) ? [limits.max_hash_keys - 1, 0].max : total
      result = T.let({}, T::Hash[Symbol, T.untyped])
      oversized_keys = 0
      hash.each_pair.with_index do |(key, value), index|
        break if index >= examined

        if key.to_s.bytesize > limits.max_string_bytes
          oversized_keys += 1
          next
        end

        result[key.to_s.to_sym] = value
      end
      result[:_more_keys] = total - examined if examined < total
      result[:_oversized_keys] = oversized_keys if oversized_keys.positive?
      result
    end
  end
end
