import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { RubyCodeExample } from '@/components/ruby-code-example';
import { Callout } from '@/components/ui/callout';

export default function FilteringSensitiveDataPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="filtering-sensitive-data" level={1}>
        Filtering Sensitive Data
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-300">
        LogStruct keeps sensitive data out of your logs in two ways: it filters values by the names
        of their keys, and it scrubs patterns such as email addresses and card numbers out of every
        string. Both apply to every line LogStruct writes, whatever logged it.
      </p>

      <HeadingWithAnchor id="parameter-filtering" level={1} className="mt-16">
        Parameter Filtering
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct filters sensitive values in request parameters, job arguments and any other
        structured data by their key names, at any depth. A filtered value is replaced with a
        summary of it.
      </p>

      <HeadingWithAnchor id="how-parameter-filtering-works" level={3}>
        How Parameter Filtering Works
      </HeadingWithAnchor>
      <CodeBlock language="ruby">
        {`# Original data
{
  password: "secret123",
  api_key: "sk_live_abc",
  user_data: { name: "John Doe", age: 30 }
}

# After filtering
{
  password: { _filtered: { _class: "String" } },
  api_key: { _filtered: { _class: "String" } },
  user_data: { name: "John Doe", age: 30 }
}`}
      </CodeBlock>

      <p className="text-neutral-600 dark:text-neutral-300 mt-6 mb-4">
        The summary depends on the value&apos;s type:
      </p>

      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-300 ml-4">
        <li>
          <strong>Strings</strong>: the class only. The length isn&apos;t logged, since it would say
          how long a password or token is.
        </li>
        <li>
          <strong>Hashed strings</strong>: for keys in <code>filter_keys_with_hashes</code>, the
          class and a hash of the value (see{' '}
          <a href="#hashed-values" className="underline">
            Hashed Values
          </a>
          ).
        </li>
        <li>
          <strong>Hashes</strong>: the class, the number of keys and the first 10 keys (scrubbed
          like any string), plus the size as JSON when none of the keys are sensitive.
        </li>
        <li>
          <strong>Arrays</strong>: the class, the number of items and the size as JSON.
        </li>
      </ul>

      <HeadingWithAnchor id="default-filtered-keys" level={3}>
        Default Filtered Keys
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct filters these keys by default (<code>filter_keys</code>):
      </p>

      <CodeBlock language="ruby">
        {`:password, :password_confirmation, :pass, :pw, :token, :secret,
:credentials, :auth, :authentication, :authorization,
:credit_card, :ssn, :social_security`}
      </CodeBlock>

      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        Keys are matched by their words, whatever their case or separators, so{' '}
        <code>:credit_card</code> also filters <code>creditCard</code> and <code>Credit-Card</code>.
        A default pattern filters these words anywhere in a key, with plurals like passwords and
        tokens: password, passwd, passphrase, pwd, token, secret, auth, authorization,
        authentication, cred, credential, cookie, session, jwt, bearer, otp, cvv, cvc, ssn and
        crypt. It also filters <code>api_key</code>, <code>secret_key</code>,{' '}
        <code>private_key</code>, <code>access_key</code>, <code>encryption_key</code>,{' '}
        <code>signing_key</code> and <code>master_key</code>, and keys that end in signature, sig,
        salt or certificate. For example:
      </p>

      <CodeBlock language="ruby">
        {`# Filtered
apiKey, X-Api-Key, accessToken, client_secret, HTTP_AUTHORIZATION, Set-Cookie,
session_id, newPassword, otp_code, X-Amz-Signature

# Not filtered: the words don't match
author, keyboard, cron_key, primary_key, signature_field_id`}
      </CodeBlock>

      <HeadingWithAnchor id="rails-filter-parameters" level={3}>
        Rails filter_parameters
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct also filters the keys in your app&apos;s <code>config.filter_parameters</code>,
        and matches them the way Rails does:
      </p>
      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-300 ml-4">
        <li>
          A Symbol or String matches any key that contains it, ignoring case (<code>:passw</code>{' '}
          filters <code>user_password</code>), and a Regexp is matched as it is.
        </li>
        <li>
          Entries with a dot (<code>&quot;credit_card.code&quot;</code>, or a Regexp with{' '}
          <code>\.</code>) match a nested key by its path. A request line&apos;s params match from
          the params down, as they do in Rails.
        </li>
        <li>
          Filter blocks get copies of the key and value, as they do in Rails. LogStruct filters a
          key when its block returns a truthy value or changes the String it was given (Rails&apos;
          blocks mask a value by changing it in place). A block that takes a third argument gets the
          parameters around the key, with indifferent access: a request line&apos;s params, or the
          line itself for a top-level key.
        </li>
        <li>
          Partial matches don&apos;t apply to the names of LogStruct&apos;s own fields at the top of
          a line, so Rails&apos; default <code>:_key</code> doesn&apos;t filter{' '}
          <code>cron_key</code>. Exact names and Regexps do.
        </li>
      </ul>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        Rails&apos; list is left in place, so <code>request.filtered_parameters</code> and{' '}
        <code>ActiveRecord::Base.filter_attributes</code> keep working, and values Rails has already
        replaced are logged as <code>[FILTERED]</code>.
      </p>

      <HeadingWithAnchor id="hashed-values" level={3}>
        Hashed Values
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        Email addresses are replaced with a hash, so you can follow one person through your logs
        (sign up, sign in, password reset) without logging their address. Every email address in a
        string becomes <code>[EMAIL:hash]</code>. A filtered key in{' '}
        <code>filter_keys_with_hashes</code> (<code>:email</code> and <code>:email_address</code> by
        default) logs the hash in its summary. Both use the same hash for the same address:
      </p>

      <CodeBlock language="ruby">
        {`# An email key is scrubbed like any string
{ email: "[EMAIL:a1b2c3d4e5f6a7b8]" }

# When the key is filtered too (Rails 8's default filter_parameters include :email)
{ email: { _filtered: { _class: "String", _hash: "a1b2c3d4e5f6a7b8" } } }`}
      </CodeBlock>

      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        The hash is an HMAC-SHA256 of the value, cut to <code>hash_length</code> characters (16 by
        default). Its key is <code>hash_salt</code>, or by default a key derived from your Rails
        app&apos;s <code>secret_key_base</code>, so the hashes differ from one app to the next.
      </p>

      <Callout type="warning">
        Hashes are pseudonyms, not anonymous data: anyone who has the key and a list of email
        addresses can work out which hash belongs to which address. Keep <code>hash_salt</code>{' '}
        secret, and expect every hash to change when you change it or your{' '}
        <code>secret_key_base</code>.
      </Callout>

      <HeadingWithAnchor id="configuring-parameter-filtering" level={3}>
        Configuring Filtering
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        Add keys and rules to the defaults, and turn the string scrubbers on or off:
      </p>

      <RubyCodeExample name="filter_configuration" />

      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        Assigning a new list (<code>config.filters.filter_keys = [...]</code>) replaces the
        defaults, and assigning <code>filter_matchers</code> removes the default pattern, so add to
        them as the example does.
      </p>

      <HeadingWithAnchor id="string-scrubbing" level={1} className="mt-16">
        String Scrubbing
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct scans every string it logs for patterns that look like sensitive data, whatever
        key they&apos;re under. That includes messages, Hash keys that aren&apos;t plain identifiers
        (an email address used as a key), Symbols and GlobalIDs.
      </p>

      <Callout type="info">
        Special thanks to{' '}
        <a className="text-blue-200 hover:text-white" href="https://github.com/ankane">
          ankane
        </a>{' '}
        for creating the{' '}
        <a className="text-blue-200 hover:text-white" href="https://github.com/ankane/logstop">
          logstop
        </a>{' '}
        gem, which LogStruct&apos;s string scrubbing is based on.
      </Callout>

      <HeadingWithAnchor id="how-string-scrubbing-works" level={3}>
        How String Scrubbing Works
      </HeadingWithAnchor>
      <CodeBlock language="ruby">
        {`# Original log message
"User user@example.com paid with 4111-1111-1111-1111"

# After string scrubbing
"User [EMAIL:a1b2c3d4e5f6a7b8] paid with [CREDIT_CARD]"`}
      </CodeBlock>

      <HeadingWithAnchor id="types-of-scrubbed-data" level={3}>
        Types of Scrubbed Data
      </HeadingWithAnchor>
      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-300 ml-4">
        <li>
          <strong>Email addresses</strong>: replaced with <code>[EMAIL:hash]</code>
        </li>
        <li>
          <strong>Passwords in URLs</strong>: <code>postgres://user:secret@host</code>,{' '}
          <code>redis://:secret@host</code> and URL-encoded URLs, replaced with{' '}
          <code>[PASSWORD]</code>
        </li>
        <li>
          <strong>Sensitive query params</strong>: params whose names would be filtered as keys (
          <code>?token=</code>, <code>?api_key=</code>, <code>user[password]=</code>), and
          OAuth&apos;s <code>?code=</code>, get the value <code>[FILTERED]</code>
        </li>
        <li>
          <strong>Credit card numbers</strong>: 13 to 19 digits, written together, in fours with
          spaces or dashes, or in American Express groups, replaced with <code>[CREDIT_CARD]</code>.
          Numbers that fail the Luhn check every card number passes are left alone, which keeps most
          IDs and timestamps.
        </li>
        <li>
          <strong>Phone numbers</strong>: replaced with <code>[PHONE]</code>
        </li>
        <li>
          <strong>Social security numbers</strong>: replaced with <code>[SSN]</code>
        </li>
        <li>
          <strong>IP addresses</strong>: replaced with <code>[IP]</code> (off by default)
        </li>
        <li>
          <strong>MAC addresses</strong>: replaced with <code>[MAC]</code> (off by default)
        </li>
      </ul>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        Each scrubber has a setting in <code>config.filters</code> (see{' '}
        <a href="#configuring-parameter-filtering" className="underline">
          Configuring Filtering
        </a>
        ). Plain lines from the development color formatter, and messages sent to loggers added with{' '}
        <code>broadcast_to</code>, are scrubbed too.
      </p>

      <HeadingWithAnchor id="custom-string-scrubbing" level={3}>
        Custom String Scrubbing
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        For patterns the built-in scrubbers don&apos;t cover, add a handler. It runs after them, on
        every string and on every Hash key that isn&apos;t a plain identifier:
      </p>
      <RubyCodeExample name="custom_string_scrubber" />

      <HeadingWithAnchor id="left-out" level={1} className="mt-16">
        What the Integrations Leave Out
      </HeadingWithAnchor>
      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-300 ml-4">
        <li>
          <strong>Referer headers</strong>: request, blocked host and security lines, and the
          request context sent to error reporters, have the Referer without its query string. The
          page a request came from can have a password reset, confirmation or magic link token in
          its URL.
        </li>
        <li>
          <strong>ActiveStorage URLs</strong>: <code>url</code> lines have the service and the
          file&apos;s key, but not the signed URL, which lets anyone read the file until it expires.
        </li>
        <li>
          <strong>Mail delivery jobs</strong> (<code>deliver_later</code>) are logged with only the
          mailer, the mail and the delivery method as their arguments. A mail&apos;s own arguments
          can be secrets with no key to filter on, such as the tokens Devise passes to its
          confirmation, password reset and invitation emails. This applies while the ActiveJob
          integration is on and the delivery job is <code>ActionMailer::MailDeliveryJob</code> or a
          subclass of it. With the integration off, Rails&apos; own job logs include the arguments.
        </li>
        <li>
          <strong>Mail subjects</strong> are logged, scrubbed like any string. Keep one-time codes
          and other secrets out of subjects, which mail clients show in notifications too.
        </li>
        <li>
          <strong>SQL bind values</strong> (when <code>sql_log_bind_params</code> is on) are
          filtered by their column names, like parameters. The SQL itself is scrubbed but not
          filtered: it can hold literal values, from string conditions or when{' '}
          <code>prepared_statements</code> is off.
        </li>
        <li>
          <strong>Error reports</strong>: the context LogStruct sends to Sentry, Bugsnag, Rollbar,
          Honeybadger or your own reporting handler is filtered and scrubbed like a log line.
        </li>
      </ul>

      <HeadingWithAnchor id="examples" level={1} className="mt-16">
        Examples
      </HeadingWithAnchor>

      <HeadingWithAnchor id="example-filtered-hash" level={3}>
        Filtered Hash with Sensitive Keys
      </HeadingWithAnchor>
      <CodeBlock language="ruby">
        {`# Original hash
{
  user_id: 123,
  email: "user@example.com",
  password: "secret123",
  profile: {
    name: "John Doe",
    phone: "555-123-4567"
  }
}

# Logged output
{
  "user_id": 123,
  "email": "[EMAIL:a1b2c3d4e5f6a7b8]",
  "password": {
    "_filtered": {
      "_class": "String"
    }
  },
  "profile": {
    "name": "John Doe",
    "phone": "[PHONE]"
  }
}`}
      </CodeBlock>

      <HeadingWithAnchor id="example-filtered-array" level={3}>
        Array with Sensitive Data
      </HeadingWithAnchor>
      <CodeBlock language="ruby">
        {`# Original array
[
  "Public message",
  "Email: user@example.com",
  "Reset link: https://app.example.com/reset?token=abc123&locale=en",
  { user_id: 123, api_key: "sk_live_abc" }
]

# Logged output
[
  "Public message",
  "Email: [EMAIL:a1b2c3d4e5f6a7b8]",
  "Reset link: https://app.example.com/reset?token=[FILTERED]&locale=en",
  {
    "user_id": 123,
    "api_key": {
      "_filtered": {
        "_class": "String"
      }
    }
  }
]`}
      </CodeBlock>

      <HeadingWithAnchor id="example-sensitive-url" level={3}>
        Sensitive URL in Log Message
      </HeadingWithAnchor>
      <CodeBlock language="ruby">
        {`# Original message
"Connecting to database at postgres://user:password123@db.example.com:5432/mydb"

# Logged output
"Connecting to database at postgres://user:[PASSWORD]@db.example.com:5432/mydb"`}
      </CodeBlock>

      <HeadingWithAnchor id="example-complex-object" level={3}>
        Complex Object with Nested Sensitive Data
      </HeadingWithAnchor>
      <CodeBlock language="ruby">
        {`# Original object
{
  request: {
    method: "POST",
    path: "/api/users",
    params: {
      user: {
        name: "Jane Smith",
        email: "jane@example.com",
        password: "secure_password",
        credit_card: "4111-1111-1111-1111"
      }
    },
    headers: {
      "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    }
  },
  response: {
    status: 201,
    body: {
      id: 456,
      name: "Jane Smith",
      email: "jane@example.com"
    }
  }
}

# Logged output
{
  "request": {
    "method": "POST",
    "path": "/api/users",
    "params": {
      "user": {
        "name": "Jane Smith",
        "email": "[EMAIL:c9d8e7f6a5b4c3d2]",
        "password": {
          "_filtered": {
            "_class": "String"
          }
        },
        "credit_card": {
          "_filtered": {
            "_class": "String"
          }
        }
      }
    },
    "headers": {
      "Authorization": {
        "_filtered": {
          "_class": "String"
        }
      }
    }
  },
  "response": {
    "status": 201,
    "body": {
      "id": 456,
      "name": "Jane Smith",
      "email": "[EMAIL:c9d8e7f6a5b4c3d2]"
    }
  }
}`}
      </CodeBlock>

      <EditPageLink />
    </div>
  );
}
