// LogStruct's default key filtering (lib/log_struct/param_filters.rb and
// lib/log_struct/config_struct/filters.rb), and Rails 8's default filter_parameters, for the demo lines

/**
 * A key's words, lowercase and joined by underscores (KeyWords.normalize): apiKey, api-key,
 * X-Api-Key and HTTP_X_API_KEY all contain "api_key"
 */
export function normalizeKeyWords(key: string): string {
  return key
    .replace(/([a-z\d])([A-Z])/g, '$1_$2')
    .replace(/([A-Z]+)([A-Z][a-z])/g, '$1_$2')
    .replace(/[- .]/g, '_')
    .toLowerCase();
}

/** filters.filter_keys */
export const DEFAULT_FILTER_KEYS: readonly string[] = [
  'password',
  'password_confirmation',
  'pass',
  'pw',
  'token',
  'secret',
  'credentials',
  'auth',
  'authentication',
  'authorization',
  'credit_card',
  'ssn',
  'social_security',
];

/** filters.filter_keys_with_hashes: filtered, with a hash of their String values */
export const DEFAULT_FILTER_KEYS_WITH_HASHES: readonly string[] = ['email', 'email_address'];

/** Filters::DEFAULT_SENSITIVE_KEY_PATTERN, matched against a key's words */
export const DEFAULT_SENSITIVE_KEY_PATTERN =
  /(?:^|_)(?:passwords?|passwd|passphrases?|passcodes?|pwd|tokens?|secrets?|auth|authorization|authentication|creds?|credentials?|cookies?|sessions?|jwts?|bearer|otps?|apikeys?|cvv|cvc|ssn|social_security(?:_numbers?)?|credit_cards?|card_numbers?|crypt|crypted)(?:_|$)|(?:^|_)(?:api|secret|private|access|encryption|signing|master)_keys?(?:_|$)|(?:^|_)(?:signature|sig|salt|certificate)s?$/;

const listed = (keys: readonly string[], key: string): boolean =>
  keys.includes(key.toLowerCase()) || keys.includes(normalizeKeyWords(key));

/** ParamFilters.should_filter_key? with LogStruct's default settings */
export function shouldFilterKey(key: string): boolean {
  if (listed(DEFAULT_FILTER_KEYS, key) || listed(DEFAULT_FILTER_KEYS_WITH_HASHES, key)) {
    return true;
  }
  return DEFAULT_SENSITIVE_KEY_PATTERN.test(normalizeKeyWords(key));
}

/** ParamFilters.should_include_string_hash? */
export function shouldIncludeStringHash(key: string): boolean {
  return listed(DEFAULT_FILTER_KEYS_WITH_HASHES, key);
}

/** The filter_parameters in config/initializers/filter_parameter_logging.rb of a new Rails 8 app */
export const RAILS_DEFAULT_FILTER_PARAMETERS: readonly string[] = [
  'passw',
  'email',
  'secret',
  'token',
  '_key',
  'crypt',
  'salt',
  'certificate',
  'otp',
  'ssn',
  'cvv',
  'cvc',
];

/** The mask Rails puts in place of a filtered parameter */
export const RAILS_FILTERED_MASK = '[FILTERED]';

// Rails matches each entry anywhere in a key, ignoring case
const RAILS_FILTER_REGEX = new RegExp(RAILS_DEFAULT_FILTER_PARAMETERS.join('|'), 'i');

const isPlainObject = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

function railsFilterValue(key: string, value: unknown): unknown {
  if (RAILS_FILTER_REGEX.test(key)) return RAILS_FILTERED_MASK;
  if (isPlainObject(value)) return railsFilterParameters(value);
  if (Array.isArray(value)) return value.map((item) => railsFilterValue(key, item));
  return value;
}

/**
 * Request params as Rails hands them to the request line (ActiveSupport::ParameterFilter with Rails 8's
 * defaults): a matching key's whole value is replaced by "[FILTERED]"
 */
export function railsFilterParameters(params: Record<string, unknown>): Record<string, unknown> {
  return Object.fromEntries(
    Object.entries(params).map(([key, value]) => [key, railsFilterValue(key, value)]),
  );
}
