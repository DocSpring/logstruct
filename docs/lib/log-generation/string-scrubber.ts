// The string scrubbers LogStruct runs by default (lib/log_struct/string_scrubber.rb), for the demo
// lines. IP and MAC address scrubbing are off by default, so they're left out.

import { shouldFilterKey } from './param-filters';

// The password in a URL's user info (postgres://user:password@host, redis://:password@host)
const URL_PASSWORD_REGEX = /(\/\/[^\s/:@]*:)[^\s/]+(@)/g;
// The same in a URL-encoded URL
const ENCODED_URL_PASSWORD_REGEX =
  /(%2F%2F(?:(?!%3A|%2F|%40)[^\s/&])*%3A)(?:(?!%2F)[^\s/&])+(%40)/gi;
const URL_PASSWORD_REPLACEMENT = '$1[PASSWORD]$2';

// A URL's query string, and OAuth's authorization codes, which no key pattern would filter
const QUERY_STRING_REGEX = /\?([^\s#"'<>]+)/g;
const SENSITIVE_QUERY_PARAMS = ['code'];
const FILTERED = '[FILTERED]';

// Letters and digits of any script (an accented name, a domain in another alphabet)
const EMAIL_PATTERN = String.raw`(?<![\p{L}\p{N}._%+-])[\p{L}\p{N}._%+-]+@[\p{L}\p{N}.-]+\.\p{L}{2,}(?![\p{L}\p{N}])`;
const EMAIL_REGEX = new RegExp(EMAIL_PATTERN, 'gu');
const WHOLE_EMAIL_REGEX = new RegExp(`^${EMAIL_PATTERN}$`, 'u');

// The credentials after Bearer or Basic. A Bearer token has at least 16 characters, and Basic
// credentials must decode to user:password, so "Bearer token" and "Basic plan" stay.
const AUTHORIZATION_CREDENTIALS_REGEX = /\b(Bearer|Basic)(\s+)([A-Za-z0-9\-._~+/]+=*)/gi;

// 13 to 19 digits, written together, in fours, or in American Express and Diners Club groups.
// Numbers that fail the Luhn check are left alone. (\1 and \2: the same separator throughout.)
const CREDIT_CARD_REGEX =
  /(?<![A-Za-z0-9.-])(?:[2-6]\d{12,18}|[2-6]\d{3}([ -])\d{4}\1\d{4}\1\d{4}(?:\1\d{3})?|3\d{3}([ -])\d{6}\2\d{4,5})(?![A-Za-z0-9]|-\d)/g;

// US numbers: 555-123-4567, 555 123 4567, 555.123.4567 and (555) 123-4567, with or without 1 or +1
const PHONE_REGEX =
  /(?<![\w+])(?:\+?1[\s.-]?)?(?:\(\d{3}\)[\s.-]?|\d{3}[\s.-])\d{3}[\s.-]\d{4}(?!\w)/g;

// 123-45-6789 and 123 45 6789, but not inside a longer number (Part 123-45-6789-0)
const SSN_REGEX = /(?<!\w|\d-)\d{3}[\s-]\d{2}[\s-]\d{4}(?!\w|-\d)/g;

// Hash keys like these are never changed by the scrubbers
const IDENTIFIER_REGEX = /^[A-Za-z_][A-Za-z0-9_]*$/;

/**
 * 16 hex characters for a value. LogStruct writes an HMAC-SHA256 keyed with filters.hash_salt; the demo
 * uses a quick hash that, like LogStruct's, always gives the same value the same hash.
 */
export function hashValue(value: string): string {
  let h1 = 0xdeadbeef;
  let h2 = 0x41c6ce57;
  for (let i = 0; i < value.length; i++) {
    const char = value.charCodeAt(i);
    h1 = Math.imul(h1 ^ char, 2654435761);
    h2 = Math.imul(h2 ^ char, 1597334677);
  }
  h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507) ^ Math.imul(h2 ^ (h2 >>> 13), 3266489909);
  h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507) ^ Math.imul(h1 ^ (h1 >>> 13), 3266489909);
  return (h2 >>> 0).toString(16).padStart(8, '0') + (h1 >>> 0).toString(16).padStart(8, '0');
}

/** StringScrubber.value_hash: an email address is hashed in lowercase, so it has one hash */
export function valueHash(value: string): string {
  return hashValue(WHOLE_EMAIL_REGEX.test(value) ? value.toLowerCase() : value);
}

function decodesToUserAndPassword(credentials: string): boolean {
  if (credentials.length < 8 || credentials.length % 4 !== 0) return false;
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(credentials)) return false;
  try {
    return atob(credentials).includes(':');
  } catch {
    return false;
  }
}

function scrubAuthorizationCredentials(string: string): string {
  if (!/bearer|basic/i.test(string)) return string;

  return string.replace(
    AUTHORIZATION_CREDENTIALS_REGEX,
    (match, scheme: string, space: string, credentials: string) => {
      const sensitive =
        scheme.toLowerCase() === 'bearer'
          ? credentials.length >= 16
          : decodesToUserAndPassword(credentials);
      return sensitive ? `${scheme}${space}${FILTERED}` : match;
    },
  );
}

// user[password] is checked as password
function sensitiveQueryParam(name: string): boolean {
  let decoded = name;
  try {
    decoded = decodeURIComponent(name.replace(/\+/g, ' '));
  } catch {
    // A malformed escape: check the name as it is
  }
  const key = decoded.match(/\[([^[\]]*)\]$/)?.[1] ?? decoded;
  if (key === '') return false;

  return SENSITIVE_QUERY_PARAMS.includes(key.toLowerCase()) || shouldFilterKey(key);
}

function scrubQueryParams(string: string): string {
  return string.replace(QUERY_STRING_REGEX, (_match, query: string) => {
    const params = query.split('&').map((param) => {
      const equals = param.indexOf('=');
      if (equals === -1) return param;
      const name = param.slice(0, equals);
      const value = param.slice(equals + 1);
      if (value === '' || value === FILTERED) return param;

      return sensitiveQueryParam(name) ? `${name}=${FILTERED}` : param;
    });
    return `?${params.join('&')}`;
  });
}

function luhnValid(digits: string): boolean {
  let sum = 0;
  digits
    .split('')
    .reverse()
    .forEach((char, index) => {
      let digit = Number(char);
      if (index % 2 === 1) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
    });
  return sum % 10 === 0;
}

/** StringScrubber.scrub with LogStruct's default filters */
export function scrubString(input: string): string {
  if (input === '') return input;

  let string = scrubAuthorizationCredentials(input);
  if (string.includes('?')) string = scrubQueryParams(string);
  string = string.replace(URL_PASSWORD_REGEX, URL_PASSWORD_REPLACEMENT);
  if (string.includes('%')) {
    string = string.replace(ENCODED_URL_PASSWORD_REGEX, URL_PASSWORD_REPLACEMENT);
  }
  string = string.replace(EMAIL_REGEX, (email) => `[EMAIL:${valueHash(email)}]`);
  string = string.replace(CREDIT_CARD_REGEX, (number) =>
    luhnValid(number.replace(/[ -]/g, '')) ? '[CREDIT_CARD]' : number,
  );
  string = string.replace(PHONE_REGEX, '[PHONE]');
  string = string.replace(SSN_REGEX, '[SSN]');
  return string;
}

/** StringScrubber.scrub_name: a Hash key is scrubbed unless it's a plain identifier */
export function scrubName(name: string): string {
  return IDENTIFIER_REGEX.test(name) ? name : scrubString(name);
}
