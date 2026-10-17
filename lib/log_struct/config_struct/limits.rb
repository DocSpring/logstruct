# typed: strict
# frozen_string_literal: true

module LogStruct
  module ConfigStruct
    # How much of each logged value LogStruct writes. The limits keep a huge value (a request body,
    # a large Hash) from slowing down the thread that writes the logs.
    class Limits < T::Struct
      include Sorbet::SerializeSymbolKeys

      # The most keys written from a Hash. The rest are counted in _more_keys.
      # Default: 100
      prop :max_hash_keys, Integer, default: 100

      # The most items written from an Array, followed by "... and N more items"
      # Default: 10
      prop :max_array_items, Integer, default: 10

      # The most lines written from an Array that looks like a backtrace, such as an error line's
      # backtrace. The rest are counted in a last "... and N more lines" item.
      # Default: 20
      prop :max_backtrace_lines, Integer, default: 20

      # Strings longer than this many bytes are cut, and say how long they were
      # Default: 32768 (32 KB)
      prop :max_string_bytes, Integer, default: 32_768
    end
  end
end
