// cspell:ignore Nlcjpw Fuser Asecret Bpassword martí
import { shouldFilterKey } from '../param-filters';
import { hashValue, scrubString, valueHash } from '../string-scrubber';

// The expected values are what LogStruct 0.2.0 writes with its default settings
// (ParamFilters.should_filter_key? and StringScrubber.scrub)
describe('key filtering', () => {
  test.each([
    'password',
    'password_confirmation',
    'current_password',
    'invite_token',
    'apiKey',
    'X-Api-Key',
    'HTTP_AUTHORIZATION',
    'Set-Cookie',
    'passwords',
    'token',
    'tokens',
    'access_token',
    'api_key',
    'api_key_id',
    'secret',
    'client_secret',
    'credit_card',
    'credit_card_number',
    'card_number',
    'creditCard',
    'ssn',
    'social_security_number',
    'email',
    'Email',
    'email_address',
    'emailAddress',
    'X-Amz-Signature',
    'salt',
    'passcode',
    'otp',
    'otp_code',
    'session',
    'session_id',
    'jwt',
    'bearer',
    'auth',
    'authorization',
    'authentication',
    'credentials',
    'creds',
  ])('filters %s', (key) => {
    expect(shouldFilterKey(key)).toBe(true);
  });

  test.each([
    'user_email',
    'author',
    'keyboard',
    'signature_field_id',
    'cron_key',
    'primary_key',
    'pin',
    'account_number',
    'phone',
    'name',
    'remember_me',
    'q',
    'page',
  ])('keeps %s', (key) => {
    expect(shouldFilterKey(key)).toBe(false);
  });
});

describe('string scrubbing', () => {
  // LogStruct's email hashes are HMACs, so only the [EMAIL:...] marker is compared
  const withoutHashes = (string: string) => string.replace(/\[EMAIL:[0-9a-f]{16}\]/g, '[EMAIL:…]');

  test.each([
    ['Bearer abcdefghijklmnopqrst', 'Bearer [FILTERED]'],
    ['Bearer short', 'Bearer short'],
    ['Basic dXNlcjpwYXNz', 'Basic [FILTERED]'],
    ['Basic plan', 'Basic plan'],
    ['Authorization: Bearer 9f8e7d6c5b4a39281706f5e4d3c2b1a0', 'Authorization: Bearer [FILTERED]'],
    ['postgres://u:p@h', 'postgres://u:[PASSWORD]@h'],
    ['redis://:pw@h', 'redis://:[PASSWORD]@h'],
    [
      'postgres://app:s3cr:et@db.internal:5432/app',
      'postgres://app:[PASSWORD]@db.internal:5432/app',
    ],
    ['https%3A%2F%2Fuser%3Asecret%40example.com', 'https%3A%2F%2Fuser%3A[PASSWORD]%40example.com'],
    [
      'https://x.com/?token=abc&code=1&page=2',
      'https://x.com/?token=[FILTERED]&code=[FILTERED]&page=2',
    ],
    ['/reset?user%5Bpassword%5D=x&a=1', '/reset?user%5Bpassword%5D=[FILTERED]&a=1'],
    ['/search?q=rails&page=2', '/search?q=rails&page=2'],
    ['/cb?api_key=a1b2&limit=10', '/cb?api_key=[FILTERED]&limit=10'],
    ['linda.martínez@gmail.com', '[EMAIL:…]'],
    ['Write to Linda.Martinez@Example.com today', 'Write to [EMAIL:…] today'],
    ['wei.müller@company.org', '[EMAIL:…]'],
    ['名前@例え.jp', '[EMAIL:…]'],
    ['4111111111111111', '[CREDIT_CARD]'],
    ['4111 1111 1111 1111', '[CREDIT_CARD]'],
    ['4111-1111-1111-1111', '[CREDIT_CARD]'],
    ['4111111111111112', '4111111111111112'],
    ['378282246310005', '[CREDIT_CARD]'],
    ['3782 822463 10005', '[CREDIT_CARD]'],
    ['5555 5555 5555 4444', '[CREDIT_CARD]'],
    ['555-123-4567', '[PHONE]'],
    ['(555) 123-4567', '[PHONE]'],
    ['+1 555-123-4567', '[PHONE]'],
    ['+1-555-201-7788', '[PHONE]'],
    ['555.123.4567', '[PHONE]'],
    ['1-555-123-4567', '[PHONE]'],
    ['1 (555) 123-4567', '[PHONE]'],
    ['5551234567', '5551234567'],
    ['+44 20 7946 0958', '+44 20 7946 0958'],
    ['123-45-6789', '[SSN]'],
    ['123 45 6789', '[SSN]'],
    ['Part 123-45-6789-0', 'Part 123-45-6789-0'],
    ['Part 9-123-45-6789', 'Part 9-123-45-6789'],
    ['123456789', '123456789'],
    ['10.0.0.1', '10.0.0.1'],
    ['00:1A:2B:3C:4D:5E', '00:1A:2B:3C:4D:5E'],
    ['6f1c9a2e-7b4d-4e8a-9c61-2d5b8f0e4a17', '6f1c9a2e-7b4d-4e8a-9c61-2d5b8f0e4a17'],
    ['<6710e3a7c41b2_1f2e3d4c5b6a@web-1.mail>', '<[EMAIL:…]>'],
  ])('scrubs %s', (input, expected) => {
    expect(withoutHashes(scrubString(input))).toBe(expected);
  });

  test('scrubs an accented email address whole', () => {
    const scrubbed = scrubString('Sent to linda.martínez@gmail.com');
    expect(scrubbed).toMatch(/^Sent to \[EMAIL:[0-9a-f]{16}\]$/);
    expect(scrubbed).not.toContain('linda');
  });

  test('gives an address one hash, however it is capitalized', () => {
    const lower = scrubString('linda.martinez@example.com');
    expect(scrubString('Linda.Martinez@Example.com')).toBe(lower);
    expect(scrubString('Write to linda.martinez@example.com today')).toBe(
      `Write to ${lower} today`,
    );
    expect(valueHash('Linda.Martinez@Example.com')).toBe(valueHash('linda.martinez@example.com'));
    expect(scrubString('wei.chen@example.com')).not.toBe(lower);
  });

  test('hashes are 16 hex characters', () => {
    expect(hashValue('anything')).toMatch(/^[0-9a-f]{16}$/);
  });
});
