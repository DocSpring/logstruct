// What LogStruct's formatter does to each value of a line (lib/log_struct/formatter.rb#process_values),
// with the default filters and limits, for the demo lines

import { RAILS_FILTERED_MASK, shouldFilterKey, shouldIncludeStringHash } from './param-filters';
import { scrubName, scrubString, valueHash } from './string-scrubber';

/** config.limits defaults (lib/log_struct/config_struct/limits.rb) */
export const LIMITS = {
  maxHashKeys: 100,
  maxArrayItems: 10,
  maxBacktraceLines: 20,
  maxStringBytes: 32_768,
} as const;

/** A filtered value's summary (ParamFilters.summarize_json_attribute) */
export interface FilteredValue {
  _filtered: {
    _class: string;
    _hash?: string;
    _count?: number;
    _keys?: string[];
    _keys_count?: number;
    _empty?: boolean;
  };
}

type Json = unknown;

const isPlainObject = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

function rubyClass(value: unknown): string {
  if (typeof value === 'string') return 'String';
  if (typeof value === 'number') return Number.isInteger(value) ? 'Integer' : 'Float';
  if (value === true) return 'TrueClass';
  if (value === false) return 'FalseClass';
  if (value === null || value === undefined) return 'NilClass';
  if (Array.isArray(value)) return 'Array';
  return 'Hash';
}

/** The summary LogStruct writes in place of a filtered value: no lengths or sizes */
export function summarize(key: string, value: unknown): FilteredValue {
  if (Array.isArray(value)) {
    return {
      _filtered:
        value.length === 0
          ? { _class: 'Array', _empty: true }
          : { _class: 'Array', _count: value.length },
    };
  }
  if (isPlainObject(value)) {
    const keys = Object.keys(value);
    return {
      _filtered:
        keys.length === 0
          ? { _class: 'Hash', _empty: true }
          : { _class: 'Hash', _keys_count: keys.length, _keys: keys.slice(0, 10).map(scrubName) },
    };
  }
  if (typeof value === 'string' && shouldIncludeStringHash(key)) {
    return { _filtered: { _class: 'String', _hash: valueHash(value) } };
  }
  return { _filtered: { _class: rubyClass(value) } };
}

function utf8Bytes(string: string): number {
  let bytes = 0;
  for (const char of string) {
    const code = char.codePointAt(0) ?? 0;
    bytes += code < 0x80 ? 1 : code < 0x800 ? 2 : code < 0x10000 ? 3 : 4;
  }
  return bytes;
}

// A string scrubbed, and cut to max_string_bytes
function scrubLimitedString(string: string): string {
  const bytes = utf8Bytes(string);
  if (bytes <= LIMITS.maxStringBytes) return scrubString(string);

  let kept = '';
  let keptBytes = 0;
  for (const char of scrubString(string)) {
    const charBytes = utf8Bytes(char);
    if (keptBytes + charBytes > LIMITS.maxStringBytes) break;
    kept += char;
    keptBytes += charBytes;
  }
  return `${kept}... (cut from ${bytes} bytes)`;
}

// Three of the first five items look like file:line
function looksLikeBacktrace(array: unknown[]): boolean {
  const lines = array
    .slice(0, 5)
    .filter((item) => typeof item === 'string' && /^[^:\s]+:\d+/.test(item));
  return lines.length >= 3;
}

function processArray(array: unknown[]): Json[] {
  const backtrace = looksLikeBacktrace(array);
  const max = backtrace ? LIMITS.maxBacktraceLines : LIMITS.maxArrayItems;
  const processed = array.slice(0, max).map((item) => processValues(item));
  if (array.length > max) {
    processed.push(`... and ${array.length - max} more ${backtrace ? 'lines' : 'items'}`);
  }
  return processed;
}

function processHash(hash: Record<string, unknown>): Record<string, Json> {
  const result: Record<string, Json> = {};
  const entries = Object.entries(hash);
  for (const [index, [key, value]] of entries.entries()) {
    if (index >= LIMITS.maxHashKeys) {
      result._more_keys = entries.length - LIMITS.maxHashKeys;
      break;
    }
    if (!shouldFilterKey(key)) {
      result[scrubName(key)] = processValues(value);
    } else if (value === RAILS_FILTERED_MASK) {
      // Rails' parameter filter has already replaced the value
      result[scrubName(key)] = value;
    } else {
      result[scrubName(key)] = summarize(key, value);
    }
  }
  return result;
}

/** Filters keys at any depth, scrubs strings and applies the size limits, as LogStruct does to a line */
export function processValues(value: unknown): Json {
  if (Array.isArray(value)) return processArray(value);
  if (isPlainObject(value)) return processHash(value);
  if (typeof value === 'string') return scrubLimitedString(value);
  return value;
}
