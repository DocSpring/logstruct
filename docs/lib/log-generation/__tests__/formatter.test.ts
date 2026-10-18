import { LIMITS, processValues } from '../formatter';
import { railsFilterParameters } from '../param-filters';
import { valueHash } from '../string-scrubber';

describe('processValues', () => {
  test('summarizes filtered values as LogStruct does, without lengths', () => {
    // LogStruct 0.2.0's Formatter#process_values writes the same summaries for this Hash
    const processed = processValues({
      params: {
        password: 'x',
        tokens: ['a', 'b'],
        creds: { value: 'x', other: 1 },
        email: 'Jo@Example.com',
        empty_secret: {},
        token_list: [],
        pw: 42,
        note: '[FILTERED]',
        password_digest: '[FILTERED]',
      },
    });

    expect(processed).toEqual({
      params: {
        password: { _filtered: { _class: 'String' } },
        tokens: { _filtered: { _class: 'Array', _count: 2 } },
        creds: { _filtered: { _class: 'Hash', _keys_count: 2, _keys: ['value', 'other'] } },
        email: { _filtered: { _class: 'String', _hash: valueHash('jo@example.com') } },
        empty_secret: { _filtered: { _class: 'Hash', _empty: true } },
        token_list: { _filtered: { _class: 'Array', _empty: true } },
        pw: { _filtered: { _class: 'Integer' } },
        note: '[FILTERED]',
        password_digest: '[FILTERED]',
      },
    });
    expect(JSON.stringify(processed)).not.toContain('_bytes');
  });

  test('filters invite_token and other keys by their words', () => {
    expect(processValues({ invite_token: 'bea847f3', apiKey: 'abc', remember_me: '1' })).toEqual({
      invite_token: { _filtered: { _class: 'String' } },
      apiKey: { _filtered: { _class: 'String' } },
      remember_me: '1',
    });
  });

  test('scrubs strings and keys at any depth', () => {
    expect(
      processValues({ notes: ['Call 555-201-7788'], 'linda.martinez@example.com': { id: 1 } }),
    ).toEqual({
      notes: ['Call [PHONE]'],
      [`[EMAIL:${valueHash('linda.martinez@example.com')}]`]: { id: 1 },
    });
  });

  test('applies the size limits', () => {
    const hash = Object.fromEntries(
      Array.from({ length: LIMITS.maxHashKeys + 2 }, (_, i) => [`k${i}`, i]),
    );
    const processed = processValues({
      hash,
      ids: Array.from({ length: 15 }, (_, i) => i),
      trace: Array.from({ length: 120 }, (_, i) => `app/models/invoice.rb:${i}:in 'total'`),
      text: 'a'.repeat(40_000),
    }) as Record<string, unknown>;

    expect((processed.hash as Record<string, unknown>)._more_keys).toBe(2);
    expect((processed.ids as unknown[]).at(-1)).toBe('... and 5 more items');
    expect((processed.trace as unknown[]).at(-1)).toBe('... and 100 more lines');
    expect(processed.text).toBe(`${'a'.repeat(32_768)}... (cut from 40000 bytes)`);
  });
});

describe('railsFilterParameters', () => {
  test("masks the keys Rails 8's default filter_parameters match anywhere in the key", () => {
    expect(
      railsFilterParameters({
        user: { email: 'a@example.com', password: 'x', password_confirmation: 'x', name: 'Linda' },
        invite_token: 'bea847f3',
        payment: { credit_card: '4111 1111 1111 1111', cvc: '123' },
        items: [{ api_key: 'k', qty: 1 }],
      }),
    ).toEqual({
      user: {
        email: '[FILTERED]',
        password: '[FILTERED]',
        password_confirmation: '[FILTERED]',
        name: 'Linda',
      },
      invite_token: '[FILTERED]',
      payment: { credit_card: '4111 1111 1111 1111', cvc: '[FILTERED]' },
      items: [{ api_key: '[FILTERED]', qty: 1 }],
    });
  });
});
