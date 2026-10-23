import Link from 'next/link';
import type { ReactNode } from 'react';
import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { RubyCodeExample } from '@/components/ruby-code-example';
import { Callout } from '@/components/ui/callout';

// cspell:ignore Fuser correo cret José jdoe Nlcjpw passwordless

// test/code_examples/filtering_test.rb reads the lines, key lists and scrubber examples below from this
// file and checks them against what LogStruct writes.

// What LogStruct writes for the filtering_filtered_values example
const FILTERED_VALUES_LINE = `{
  "msg": "Password changed",
  "user_id": 1873,
  "email": {
    "_filtered": {
      "_class": "String",
      "_hash": "a058d5090035d2e1"
    }
  },
  "password": {
    "_filtered": {
      "_class": "String"
    }
  },
  "otp": {
    "_filtered": {
      "_class": "Integer"
    }
  },
  "api_tokens": {
    "_filtered": {
      "_class": "Array",
      "_count": 2
    }
  },
  "credentials": {
    "_filtered": {
      "_class": "Hash",
      "_keys_count": 2
    }
  },
  "src": "app",
  "evt": "log",
  "ts": "2026-10-17T09:30:15.123+00:00",
  "lvl": "info",
  "prog": "Rails"
}`;

// What LogStruct writes for the filtering_hashed_values example
const HASHED_VALUES_LINE = `{
  "msg": "Sent a password reset link to [EMAIL:a058d5090035d2e1]",
  "email": {
    "_filtered": {
      "_class": "String",
      "_hash": "a058d5090035d2e1"
    }
  },
  "reply_to": "[EMAIL:3cfed1fb42ca3f06]",
  "src": "app",
  "evt": "log",
  "ts": "2026-10-17T09:30:15.123+00:00",
  "lvl": "info",
  "prog": "Rails"
}`;

// A request line's params with Rails 8's filter_parameters (from a POST /users request)
const REQUEST_PARAMS = `"params": {
  "user": {
    "email": "[FILTERED]",
    "password": "[FILTERED]",
    "name": "Linda",
    "api_key_id": "[FILTERED]"
  }
}`;

const DEFAULT_FILTER_KEYS = [
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

const DEFAULT_HASHED_KEYS = ['email', 'email_address'];

const PATTERN_FILTERED_KEYS = [
  'apiKey',
  'X-Api-Key',
  'HTTP_AUTHORIZATION',
  'access_token',
  'client_secret',
  'newPassword',
  'encrypted_password',
  'passcode',
  'Set-Cookie',
  'session_id',
  'otp_code',
  'cvv',
  'card_number',
  'credit_card_number',
  'social_security_number',
  'private_key',
  'X-Amz-Signature',
  'password_salt',
];

// Filtered by the default pattern, though they aren't secrets
const PATTERN_OVERMATCHED_KEYS = [
  'token_count',
  'session_count',
  'auth_provider',
  'cookie_consent',
];

const PATTERN_UNFILTERED_KEYS = [
  'author',
  'keyboard',
  'passport',
  'passwordless',
  'secretary',
  'key',
  'cron_key',
  'primary_key',
  'signature_field_id',
  'certificate_id',
  'pin',
  'account_number',
  'username',
  'phone',
  'date_of_birth',
];

// A new Rails 8 app's config/initializers/filter_parameter_logging.rb
const RAILS_8_FILTER_PARAMETERS = [
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

// Not filtered by LogStruct's defaults, but filtered with Rails 8's list
const RAILS_FILTERED_KEYS = [
  'primary_key',
  'foreign_key',
  'user_email',
  'email_verified',
  'passwordless',
  'decrypt',
  'footprint',
];

interface Scrubber {
  setting: string;
  defaultOn: boolean;
  matches: ReactNode;
  // [logged, written, note]
  examples: [string, string, string?][];
}

// In the order LogStruct runs them
const SCRUBBERS: Scrubber[] = [
  {
    setting: 'authorization_credentials',
    defaultOn: true,
    matches: (
      <>
        The credentials after <code>Bearer</code> or <code>Basic</code> (in any case), as in an
        Authorization header logged as text: a Bearer token of 16 or more characters, or Basic
        credentials that decode from Base64 to <code>user:password</code>. Replaced with{' '}
        <code>[FILTERED]</code>.
      </>
    ),
    examples: [
      [
        'Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.abc',
        'Authorization: Bearer [FILTERED]',
      ],
      ['Authorization: Basic dXNlcjpwYXNzd29yZA==', 'Authorization: Basic [FILTERED]'],
      ['Bearer token', 'Bearer token', 'Fewer than 16 characters'],
      ['Basic plan', 'Basic plan', 'Not Base64 of user:password'],
    ],
  },
  {
    setting: 'url_query_params',
    defaultOn: true,
    matches: (
      <>
        In a URL&apos;s query string (after a <code>?</code>), the value of each param whose name
        would be filtered as a key, and of OAuth&apos;s <code>code</code>. A name like{' '}
        <code>user[password]</code> is checked by each part, written plainly or URL-encoded, so{' '}
        <code>password[]</code> and <code>token[value]</code> are filtered too. Dotted Rails filters
        match the nested path. Replaced with <code>[FILTERED]</code>.
      </>
    ),
    examples: [
      ['GET /reset?token=abc123&locale=en', 'GET /reset?token=[FILTERED]&locale=en'],
      [
        '/signup?user[password]=hunter2&user[name]=Jo',
        '/signup?user[password]=[FILTERED]&user[name]=Jo',
      ],
      ['/oauth/callback?code=4/0AY0e&state=xyz', '/oauth/callback?code=[FILTERED]&state=xyz'],
      ['/login?password[]=hunter2', '/login?password[]=[FILTERED]'],
      ['/login?token[value]=abc123', '/login?token[value]=[FILTERED]'],
      ['password=hunter2&user=jo', 'password=hunter2&user=jo', 'No ? before the params'],
    ],
  },
  {
    setting: 'url_passwords',
    defaultOn: true,
    matches: (
      <>
        The password in a URL&apos;s user info (<code>scheme://user:password@host</code>), also in
        URL-encoded URLs. Replaced with <code>[PASSWORD]</code>.
      </>
    ),
    examples: [
      [
        'postgres://app:s3cret@db.internal:5432/app',
        'postgres://app:[PASSWORD]@db.internal:5432/app',
      ],
      ['redis://:s3cret@cache:6379/0', 'redis://:[PASSWORD]@cache:6379/0'],
      [
        'https%3A%2F%2Fuser%3As3cret%40example.com',
        'https%3A%2F%2Fuser%3A[PASSWORD]%40example.com',
      ],
    ],
  },
  {
    setting: 'email_addresses',
    defaultOn: true,
    matches: (
      <>
        Email addresses, with letters and digits of any script and a top-level domain of two or more
        letters. Replaced with <code>[EMAIL:hash]</code> (see{' '}
        <a href="#hashed-values" className="underline">
          Hashed Values
        </a>
        ).
      </>
    ),
    examples: [
      ['Sent to Linda.Martinez@example.com', 'Sent to [EMAIL:a058d5090035d2e1]'],
      ['Sent to linda.martinez@example.com', 'Sent to [EMAIL:a058d5090035d2e1]', 'Same hash'],
      ['José.Núñez@correo.es', '[EMAIL:c28bb257abd35f9c]'],
      ['deploy@localhost', 'deploy@localhost', 'No top-level domain'],
    ],
  },
  {
    setting: 'credit_card_numbers',
    defaultOn: true,
    matches: (
      <>
        13 to 19 digits starting with 2 to 6: written together, in groups of four separated by
        spaces or dashes, or in American Express and Diners Club groups. The number has to pass the
        Luhn check that every card number passes, so most IDs and timestamps are left alone.
        Replaced with <code>[CREDIT_CARD]</code>.
      </>
    ),
    examples: [
      ['Paid with 4111 1111 1111 1111', 'Paid with [CREDIT_CARD]'],
      ['Paid with 4111-1111-1111-1111', 'Paid with [CREDIT_CARD]'],
      ['Paid with 4111111111111111', 'Paid with [CREDIT_CARD]'],
      ['Paid with 3782 822463 10005', 'Paid with [CREDIT_CARD]'],
      ['Paid with 4111 1111 1111 1112', 'Paid with 4111 1111 1111 1112', 'Fails the Luhn check'],
      ['Order 2026101712345679', 'Order [CREDIT_CARD]', 'Not a card, but passes the Luhn check'],
    ],
  },
  {
    setting: 'phone_numbers',
    defaultOn: true,
    matches: (
      <>
        US phone numbers written with separators: <code>555-123-4567</code>,{' '}
        <code>555 123 4567</code>, <code>555.123.4567</code> and <code>(555) 123-4567</code>, with
        or without <code>+1</code> or <code>1</code>. Replaced with <code>[PHONE]</code>.
      </>
    ),
    examples: [
      ['Call 555-123-4567', 'Call [PHONE]'],
      ['Call 555.123.4567', 'Call [PHONE]'],
      ['Call (555) 123-4567', 'Call [PHONE]'],
      ['Call +1 555 123 4567', 'Call [PHONE]'],
      ['Call 1-555-123-4567', 'Call [PHONE]'],
      ['Call 5551234567', 'Call 5551234567', 'No separators'],
      ['Call +44 20 7946 0958', 'Call +44 20 7946 0958', 'Not a US number'],
      ['Reference 100-200-3000', 'Reference [PHONE]', 'Not a phone number'],
    ],
  },
  {
    setting: 'ssns',
    defaultOn: true,
    matches: (
      <>
        US social security numbers written with dashes or spaces (<code>123-45-6789</code>), and not
        part of a longer number. Replaced with <code>[SSN]</code>.
      </>
    ),
    examples: [
      ['SSN 123-45-6789', 'SSN [SSN]'],
      ['SSN 123 45 6789', 'SSN [SSN]'],
      ['Part 123-45-6789-0', 'Part 123-45-6789-0', 'Part of a longer number'],
      ['SSN 123456789', 'SSN 123456789', 'No separators'],
    ],
  },
  {
    setting: 'ip_addresses',
    defaultOn: false,
    matches: (
      <>
        IPv4 addresses (four numbers of 1 to 3 digits, separated by dots) and IPv6 addresses (text
        that Ruby&apos;s <code>IPAddr</code> reads as one and that has a digit). Replaced with{' '}
        <code>[IP]</code>.
      </>
    ),
    examples: [
      ['From 192.168.1.10', 'From [IP]'],
      ['From 2001:db8::1', 'From [IP]'],
      ['From ::ffff:192.168.1.1', 'From [IP]'],
      ['From fe80::1%en0', 'From [IP]'],
      ['Version 1.2.3.4', 'Version [IP]', 'Not an IP address'],
      ['At 12:30:45', 'At 12:30:45', 'A time'],
    ],
  },
  {
    setting: 'mac_addresses',
    defaultOn: false,
    matches: (
      <>
        Six pairs of hex digits separated by colons or by dashes. Replaced with <code>[MAC]</code>.
      </>
    ),
    examples: [
      ['MAC 00:1A:2B:3C:4D:5E', 'MAC [MAC]'],
      ['MAC 00-1A-2B-3C-4D-5E', 'MAC [MAC]'],
      ['MAC 001A.2B3C.4D5E', 'MAC 001A.2B3C.4D5E', 'Dotted groups of four'],
    ],
  },
];

function CodeList({ items }: { items: string[] }) {
  return (
    <>
      {items.map((item, index) => (
        <span key={item}>
          <code>{item}</code>
          {index < items.length - 1 ? ', ' : ''}
        </span>
      ))}
    </>
  );
}

function ScrubberTable() {
  return (
    <div className="relative overflow-x-auto">
      <table className="w-full text-sm text-left text-neutral-600 dark:text-neutral-300">
        <thead className="text-neutral-700 dark:text-neutral-300 border-b border-neutral-200 dark:border-neutral-700">
          <tr>
            <th scope="col" className="px-4 py-2 font-medium">
              Setting
            </th>
            <th scope="col" className="px-4 py-2 font-medium">
              Logged
            </th>
            <th scope="col" className="px-4 py-2 font-medium">
              Written
            </th>
          </tr>
        </thead>
        <tbody>
          {SCRUBBERS.flatMap((scrubber) =>
            scrubber.examples.map(([logged, written, note], index) => (
              <tr
                key={`${scrubber.setting}-${logged}`}
                className="border-b border-neutral-200 dark:border-neutral-700"
              >
                {index === 0 && (
                  <td
                    rowSpan={scrubber.examples.length}
                    className="px-4 py-2 align-top font-mono text-xs whitespace-nowrap"
                  >
                    {scrubber.setting}
                    <div className="font-sans text-neutral-500 dark:text-neutral-400">
                      {scrubber.defaultOn ? 'On by default' : 'Off by default'}
                    </div>
                  </td>
                )}
                <td className="px-4 py-2 align-top font-mono text-xs break-all">{logged}</td>
                <td className="px-4 py-2 align-top font-mono text-xs break-all">
                  {written}
                  {note && (
                    <div className="font-sans text-neutral-500 dark:text-neutral-400">{note}</div>
                  )}
                </td>
              </tr>
            )),
          )}
        </tbody>
      </table>
    </div>
  );
}

export default function FilteringSensitiveDataPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="filtering-sensitive-data" level={1}>
        Filtering Sensitive Data
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-300">
        LogStruct keeps sensitive values out of the lines it writes in two ways: it filters values
        by the names of their keys, and it scrubs data in known formats, such as email addresses and
        card numbers, out of every string. Both run in LogStruct&apos;s formatter, on every line it
        writes while it&apos;s on (see{' '}
        <Link href="/docs/when-logstruct-runs" className="underline">
          When LogStruct Runs
        </Link>
        ). Both match names and patterns, so they can miss sensitive data, and they can replace data
        that isn&apos;t sensitive.
      </p>

      <HeadingWithAnchor id="key-filtering">Filtering by Key</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        When a key&apos;s name is sensitive, LogStruct replaces its value with a summary. This
        applies at any depth: in request params, job arguments, Hashes you log and Arrays of Hashes.
      </p>

      <HeadingWithAnchor id="filtered-values" level={3}>
        What a Filtered Value Looks Like
      </HeadingWithAnchor>
      <RubyCodeExample name="filtering_filtered_values" />
      <p className="text-neutral-600 dark:text-neutral-300">LogStruct writes:</p>
      <CodeBlock language="json">{FILTERED_VALUES_LINE}</CodeBlock>
      <p className="text-neutral-600 dark:text-neutral-300">The summary depends on the value:</p>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          <strong>String</strong>: <code>{'{"_class": "String"}'}</code>. For a key in{' '}
          <code>filter_keys_with_hashes</code>, a <code>_hash</code> of the value too (see{' '}
          <a href="#hashed-values" className="underline">
            Hashed Values
          </a>
          ).
        </li>
        <li>
          <strong>Hash</strong>: its class and how many keys it has (<code>_keys_count</code>).
          Child keys are omitted because they may contain secrets. An empty Hash is{' '}
          <code>{'{"_class": "Hash", "_empty": true}'}</code>.
        </li>
        <li>
          <strong>Array</strong>: its class and how many items it has (<code>_count</code>). An
          empty Array is <code>{'{"_class": "Array", "_empty": true}'}</code>.
        </li>
        <li>
          <strong>Anything else</strong> (a number, <code>nil</code>, <code>true</code>): its class
          only.
        </li>
      </ul>
      <p className="text-neutral-600 dark:text-neutral-300">
        Summaries have no lengths or sizes, which would say how long a password or token is, and no
        value inside a filtered Hash or Array is written. A value that is already{' '}
        <code>&quot;[FILTERED]&quot;</code> (Rails filtered it) is written as it is, with no
        summary.
      </p>

      <HeadingWithAnchor id="filtered-keys" level={3}>
        Which Keys Are Filtered
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        A key is filtered when any of these match it:
      </p>
      <ol className="list-decimal list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          <strong>
            <code>filter_keys</code>
          </strong>
          , by default <CodeList items={DEFAULT_FILTER_KEYS} />, and{' '}
          <strong>
            <code>filter_keys_with_hashes</code>
          </strong>
          , by default <CodeList items={DEFAULT_HASHED_KEYS} />. The whole key has to match an
          entry: LogStruct compares the key in lowercase, and the key&apos;s words joined by
          underscores. So <code>:credit_card</code> filters <code>creditCard</code>,{' '}
          <code>Credit-Card</code> and <code>CREDIT_CARD</code>, but not{' '}
          <code>credit_card_number</code> (the default pattern filters that one). An entry is a
          name, not a pattern: <code>:_key</code> only filters a key named <code>_key</code>.
        </li>
        <li>
          <strong>The default pattern</strong>, which matches whole words in a key (its words joined
          by underscores, so <code>apiKey</code>, <code>X-Api-Key</code> and{' '}
          <code>HTTP_X_API_KEY</code> all contain <code>api_key</code>):
          <ul className="list-disc list-outside ml-6 mt-2 space-y-1">
            <li>
              anywhere in the key: password, passwd, passphrase, passcode, pwd, token, secret, auth,
              authorization, authentication, cred, credential, cookie, session, jwt, bearer, otp,
              apikey, cvv, cvc, ssn, social_security, social_security_number, credit_card,
              card_number, crypt and crypted, most with their plurals (passwords, tokens)
            </li>
            <li>
              anywhere in the key: api_key, secret_key, private_key, access_key, encryption_key,
              signing_key and master_key, and their plurals
            </li>
            <li>as the last word: signature, sig, salt and certificate, and their plurals</li>
          </ul>
        </li>
        <li>
          <strong>
            Rails&apos; <code>filter_parameters</code>
          </strong>
          , matched as Rails matches them (see{' '}
          <a href="#rails-filter-parameters" className="underline">
            Rails filter_parameters
          </a>
          ).
        </li>
        <li>
          <strong>Your own rules</strong> in <code>filter_matchers</code> and{' '}
          <code>path_matchers</code> (see{' '}
          <a href="#adding-keys" className="underline">
            Adding Keys
          </a>
          ).
        </li>
      </ol>
      <p className="text-neutral-600 dark:text-neutral-300">
        Filtered by the defaults: <CodeList items={PATTERN_FILTERED_KEYS} />.
      </p>
      <p className="text-neutral-600 dark:text-neutral-300">
        Not filtered by the defaults: <CodeList items={PATTERN_UNFILTERED_KEYS} />. Their values are
        still scrubbed like any string.
      </p>
      <p className="text-neutral-600 dark:text-neutral-300">
        Because the pattern matches a word anywhere in a key, it also filters keys that aren&apos;t
        secrets, such as <CodeList items={PATTERN_OVERMATCHED_KEYS} />.
      </p>

      <HeadingWithAnchor id="rails-filter-parameters" level={3}>
        Rails filter_parameters
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        After your app&apos;s <code>config/initializers</code> run, LogStruct adds the entries in{' '}
        <code>Rails.application.config.filter_parameters</code> to its own rules, and matches them
        the way Rails does:
      </p>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          A Symbol or String matches any key that contains it, ignoring case (<code>:passw</code>{' '}
          filters <code>user_password</code>). A Regexp is matched as it is.
        </li>
        <li>
          An entry with a dot (<code>&quot;credit_card.code&quot;</code>, or a Regexp with{' '}
          <code>\.</code>) matches a nested key by its path. A request line&apos;s params match from
          the params down, as in Rails.
        </li>
        <li>
          A filter block gets copies of the key and value, as in Rails. LogStruct filters the key
          when the block returns a truthy value or changes the String it was given. A block that
          takes three arguments gets the parameters around the key, with indifferent access: the
          value of the line&apos;s top-level field (a request line&apos;s params), or the line
          itself for a top-level key. They&apos;re all there, including what the size limits leave
          out of the line. Parameters with more than 10,000 values, nested more than 20 levels deep
          or containing themselves aren&apos;t copied for the block: every key it would check is
          filtered.
        </li>
        <li>
          The partial matches of Symbols and Strings don&apos;t apply to the names of
          LogStruct&apos;s own fields at the top of a line, so <code>:_key</code> doesn&apos;t
          filter a GoodJob line&apos;s <code>cron_key</code>. Exact names, Regexps and blocks do.
        </li>
      </ul>
      <p className="text-neutral-600 dark:text-neutral-300">
        A new Rails 8 app filters <CodeList items={RAILS_8_FILTER_PARAMETERS} /> (in{' '}
        <code>config/initializers/filter_parameter_logging.rb</code>). As partial matches, they
        filter keys the defaults leave, some of them not secrets:{' '}
        <CodeList items={RAILS_FILTERED_KEYS} /> (<code>:otp</code> matches footprint).
      </p>
      <p className="text-neutral-600 dark:text-neutral-300">
        Rails filters a request&apos;s params before LogStruct gets them, so in a request line a key
        Rails filters is <code>&quot;[FILTERED]&quot;</code>, with no summary and no hash. A sign-up
        request&apos;s params, with Rails 8&apos;s list:
      </p>
      <CodeBlock language="json">{REQUEST_PARAMS}</CodeBlock>
      <p className="text-neutral-600 dark:text-neutral-300">
        Values Rails doesn&apos;t filter first, such as job arguments and the Hashes you log, get
        LogStruct&apos;s summaries. LogStruct doesn&apos;t change Rails&apos; list, so Rails&apos;
        own filtering keeps working as before.
      </p>

      <HeadingWithAnchor id="hashed-values" level={3}>
        Hashed Values
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        Keys in <code>filter_keys_with_hashes</code> (by default <code>email</code> and{' '}
        <code>email_address</code>) are filtered like the others, and the summary of a String value
        has a <code>_hash</code> of it. Every email address in a string becomes{' '}
        <code>[EMAIL:hash]</code>, with the same hash. So you can find the lines about one address
        without logging it:
      </p>
      <RubyCodeExample name="filtering_hashed_values" />
      <CodeBlock language="json">{HASHED_VALUES_LINE}</CodeBlock>
      <p className="text-neutral-600 dark:text-neutral-300">
        <code>reply_to</code> isn&apos;t a filtered key, so its value is scrubbed like any string.
        An email address is hashed in lowercase, so it has one hash however it&apos;s capitalized.
        Other values are hashed as they are: <code>JDoe</code> and <code>jdoe</code> get different
        hashes.
      </p>
      <p className="text-neutral-600 dark:text-neutral-300">
        The hash is an HMAC-SHA256 of the value, cut to <code>hash_length</code> hex characters (16
        by default). Its key is <code>hash_salt</code>. Without it, LogStruct derives a key from
        your app&apos;s <code>secret_key_base</code>, so the hashes differ from one app to the next,
        and they all change when you change <code>secret_key_base</code>. Set <code>hash_salt</code>{' '}
        to keep them when you rotate it, or to get the same hashes in several apps:
      </p>
      <RubyCodeExample name="filtering_hash_salt" />
      <p className="text-neutral-600 dark:text-neutral-300">
        Outside a Rails app, without <code>hash_salt</code>, LogStruct uses a random process key.
        Set <code>hash_salt</code> if hashes must be stable across processes or restarts. Values
        longer than <code>max_string_bytes</code> are hashed using their bounded prefix and total
        byte length.
      </p>
      <Callout type="warning">
        Hashes are pseudonyms, not anonymous data: anyone who has the key and a list of email
        addresses can work out which hash belongs to which address. Keep the key secret.
      </Callout>

      <HeadingWithAnchor id="adding-keys" level={3}>
        Adding Keys
      </HeadingWithAnchor>
      <RubyCodeExample name="filtering_adding_keys" />
      <p className="text-neutral-600 dark:text-neutral-300">
        Add to the lists with <code>+=</code> and <code>&lt;&lt;</code>, as above. Assigning a list
        replaces the defaults: <code>config.filters.filter_keys = [:pin]</code> stops filtering{' '}
        <code>password</code> and <code>token</code> by name, and assigning{' '}
        <code>filter_matchers</code> removes the default pattern. Keys you add to Rails&apos;{' '}
        <code>filter_parameters</code> work too, and Rails filters them in its own request params.
        Every setting, with its default, is in{' '}
        <Link href="/docs/configuration#filtering-sensitive-data" className="underline">
          Configuration
        </Link>
        .
      </p>

      <p className="text-neutral-600 dark:text-neutral-300">
        If a key or path filter raises, LogStruct handles the error using{' '}
        <code>error_handling_modes.logstruct_errors</code>. When that mode lets logging continue,
        the value is filtered. A failing filter never counts as permission to write the value.
      </p>

      <HeadingWithAnchor id="string-scrubbing">String Scrubbing</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        LogStruct scans every String it writes for data in known formats and replaces it, whatever
        key it&apos;s under: messages, values at any depth, Symbols, GlobalIDs, Hash keys that
        aren&apos;t plain identifiers (an email address used as a key), and the keys in a filtered
        Hash&apos;s summary. Tags, the request ID and the job context are scrubbed too. Numbers
        aren&apos;t: a card number logged as an Integer is written as it is, unless its key is
        filtered.
      </p>
      <p className="text-neutral-600 dark:text-neutral-300">
        The scrubbers are based on ankane&apos;s{' '}
        <a
          href="https://github.com/ankane/logstop"
          className="underline"
          target="_blank"
          rel="noreferrer"
        >
          logstop
        </a>{' '}
        gem. Each has a setting in <code>config.filters</code>, and they run in this order:
      </p>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        {SCRUBBERS.map((scrubber) => (
          <li key={scrubber.setting}>
            <code>{scrubber.setting}</code> ({scrubber.defaultOn ? 'on' : 'off'} by default):{' '}
            {scrubber.matches}
          </li>
        ))}
      </ul>
      <p className="text-neutral-600 dark:text-neutral-300">
        What each one writes (the hashes depend on your key):
      </p>
      <ScrubberTable />

      <HeadingWithAnchor id="scrubbing-limits" level={3}>
        What Scrubbing Misses
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        The scrubbers look for formats, not meaning. They miss sensitive data in other formats, and
        they replace text that only looks like it:
      </p>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>Numbers (Integers and Floats) aren&apos;t scrubbed.</li>
        <li>
          Formats the scrubbers don&apos;t know are left: phone numbers outside the US, phone
          numbers and SSNs without separators, names and street addresses, and secrets in plain
          text, such as <code>password=hunter2</code> outside a URL&apos;s query string or an API
          key like <code>sk_live_...</code> in a message.
        </li>
        <li>
          Text that only looks sensitive is replaced: a reference written like a phone number, an ID
          that passes the Luhn check, a version number like <code>1.2.3.4</code> (with{' '}
          <code>ip_addresses</code> on), and a URL&apos;s user name and host (
          <code>https://user@example.com</code>), which look like an email address.
        </li>
      </ul>
      <p className="text-neutral-600 dark:text-neutral-300">
        Keep secrets out of what you log where you can. Filtering catches the common names and
        formats, not everything.
      </p>

      <HeadingWithAnchor id="custom-string-scrubbing" level={3}>
        Custom String Scrubbing
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        For formats the built-in scrubbers don&apos;t know, set{' '}
        <code>config.string_scrubbing_handler</code>. It gets every string after the built-in
        scrubbers, Hash keys that aren&apos;t plain identifiers included, and returns the string to
        write. See{' '}
        <Link href="/docs/configuration#custom-string-scrubbing" className="underline">
          Custom String Scrubbing
        </Link>{' '}
        in Configuration.
      </p>

      <HeadingWithAnchor id="where-filtering-applies">Where Filtering Applies</HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          <strong>LogStruct&apos;s lines</strong>: every line LogStruct&apos;s appenders write (to
          standard output, and in development and test to Rails&apos; log file) goes through its
          formatter, whatever logged it: your code, Rails and the integrations. In development with{' '}
          <code>prefer_json_in_development</code> off, the colored lines are filtered and scrubbed
          the same way.
        </li>
        <li>
          <strong>Appenders you add</strong> to SemanticLogger yourself write with the formatter you
          give them. SemanticLogger&apos;s own formatters don&apos;t filter anything: pass{' '}
          <code>formatter: LogStruct::SemanticLogger::Formatter.new</code> to filter their lines
          too.
        </li>
        <li>
          <strong>
            Loggers added with <code>broadcast_to</code>
          </strong>{' '}
          get String messages (and what a block returns, and lines written with{' '}
          <code>&lt;&lt;</code>) scrubbed, as text. Hashes and LogStruct entries aren&apos;t passed
          to them.
        </li>
        <li>
          <strong>Error reports</strong>: LogStruct passes the exception itself to Sentry, Bugsnag,
          Rollbar, Honeybadger or your <code>error_reporting_handler</code>. Its message and
          backtrace aren&apos;t scrubbed, so an email address or card number in an exception&apos;s
          message reaches your error tracker. The context LogStruct sends with it is filtered and
          scrubbed like a log line, and so is the error line LogStruct writes. Use your error
          tracker&apos;s own filtering for what it receives.
        </li>
        <li>
          <strong>SQL bind values</strong> (with <code>enable_sql_logging</code> on, and{' '}
          <code>sql_log_bind_params</code>, which is on unless the Rails environment is production):
          a value whose column name would be filtered as a key is written as{' '}
          <code>&quot;[FILTERED]&quot;</code>, with no summary or hash. So is a String value that
          looks like a secret: longer than 50 characters with no spaces, only hex digits (32 or
          more) or Base64 characters (20 or more), a JWT, or a Bearer token. Binary values are
          written as their size in bytes. Other values are scrubbed like any string. The SQL itself
          is scrubbed but not filtered: a value written into it (a string condition, or any value
          with <code>prepared_statements</code> off) is only scrubbed. See{' '}
          <Link href="/docs/integrations/sql" className="underline">
            SQL Queries
          </Link>
          .
        </li>
        <li>
          <strong>
            The <code>log.logstruct</code> notification
          </strong>
          : LogStruct sends it for each LogStruct entry or <code>T::Struct</code> logged through its
          logger (not for Hashes or Strings), with the entry as it was logged, before filtering. If
          a subscriber sends it anywhere, filter it there.
        </li>
        <li>
          <strong>While LogStruct is off</strong>, none of this applies: Rails writes its own lines,
          filtered only by its <code>filter_parameters</code>.
        </li>
      </ul>

      <HeadingWithAnchor id="left-out" level={3}>
        What the Integrations Leave Out
      </HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          <strong>Referer query strings</strong>: request lines, blocked host lines, security and
          error lines, and the context sent with security errors have the Referer without its query
          string, which can hold a password reset, confirmation or sign-in token.
        </li>
        <li>
          <strong>ActiveStorage URLs</strong>: <code>url</code> lines have the service and the
          file&apos;s key, but not the signed URL, which lets anyone read the file until it expires.
        </li>
        <li>
          <strong>File names</strong>: ActiveStorage and Shrine lines have where a file is stored
          (its key or location), not the name it was uploaded with, which often names a person.
          Shrine&apos;s upload options are logged with the file names taken out of a{' '}
          <code>content_disposition</code>. A location your uploader builds from a file&apos;s name
          is logged as it is: scrub it with a <code>string_scrubbing_handler</code>. CarrierWave
          logs an HMAC of the file ID and omits the file name and storage path.
        </li>
        <li>
          <strong>Mail delivery job arguments</strong>: a <code>deliver_later</code> job (
          <code>ActionMailer::MailDeliveryJob</code> or a subclass) is logged with only the mailer,
          the mail and the delivery method as its arguments, while the ActiveJob integration is on.
          A mail&apos;s own arguments can be secrets with no key to filter on, such as the tokens
          Devise passes to its confirmation and password reset emails.
        </li>
        <li>
          <strong>Mail subjects</strong> are logged, scrubbed like any string. Keep one-time codes
          out of subjects.
        </li>
      </ul>

      <HeadingWithAnchor id="large-values">Large and Nested Values</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        A string longer than <code>limits.max_string_bytes</code> is scrubbed before it&apos;s cut:
        the scrubbers see its first <code>max_string_bytes</code> plus 256 bytes, so data at the cut
        is replaced whole (the replacement itself can be cut). A URL password or <code>Basic</code>{' '}
        credentials that the cut runs through are replaced however long they are. A{' '}
        <code>string_scrubbing_handler</code> sees the same part of the string. Values nested more
        than 20 levels deep, and circular references, would skip filtering, so they&apos;re replaced
        with a summary like a filtered value&apos;s (
        <code>{'{"_filtered": {"_class": "Hash", "_keys_count": 2}}'}</code>). The limits on keys,
        items and string sizes are in{' '}
        <Link href="/docs/configuration#limits" className="underline">
          Limits
        </Link>
        .
      </p>

      <EditPageLink />
    </div>
  );
}
