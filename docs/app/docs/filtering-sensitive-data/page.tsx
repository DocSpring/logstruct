import { EditPageLink } from '@/components/edit-page-link';
import { CodeBlock } from '@/components/code-block';
import { RubyCodeExample } from '@/components/ruby-code-example';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { Callout } from '@/components/ui/callout';

export default function FilteringSensitiveDataPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="filtering-sensitive-data" level={1}>
        Filtering Sensitive Data
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-300">
        LogStruct provides comprehensive protection for sensitive data through
        parameter filtering and string scrubbing, keeping your logs secure while
        still providing useful information for debugging.
      </p>

      <HeadingWithAnchor id="parameter-filtering" level={1} className="mt-16">
        Parameter Filtering
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct automatically filters sensitive data in request parameters,
        job arguments, and other structured data based on key names. When a
        sensitive key is detected, the actual value is replaced with metadata
        instead.
      </p>

      <HeadingWithAnchor id="how-parameter-filtering-works" level={3}>
        How Parameter Filtering Works
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        When LogStruct encounters a key that matches one of the configured
        sensitive keys, it replaces the value with metadata that provides
        context without exposing sensitive information:
      </p>

      <CodeBlock language="ruby">
        {`# Original data
{
  email: "user@example.com",
  password: "secret123",
  user_data: { name: "John Doe", age: 30 }
}

# After filtering
{
  email: { _filtered: { _class: "String", _hash: "a1b2c3d4e5f6" } },
  password: { _filtered: { _class: "String" } },
  user_data: { name: "John Doe", age: 30 }
}`}
      </CodeBlock>

      <p className="text-neutral-600 dark:text-neutral-300 mt-6 mb-4">
        For different data types, LogStruct provides different types of
        metadata:
      </p>

      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-300 ml-4">
        <li>
          <strong>Strings</strong>: Shows class name, but omits byte size for
          sensitive keys
        </li>
        <li>
          <strong>Hashable strings</strong>: For keys configured in{' '}
          <code>filter_keys_with_hashes</code> (like email addresses), includes
          a hash for tracing across logs
        </li>
        <li>
          <strong>Hashes</strong>: Shows class name, key count, and first 10
          keys (but hides byte size if sensitive keys are present)
        </li>
        <li>
          <strong>Arrays</strong>: Shows class name, count, and byte size
        </li>
      </ul>

      <HeadingWithAnchor id="default-filtered-keys" level={3}>
        Default Filtered Keys
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct filters these keys by default:
      </p>

      <CodeBlock language="ruby">
        {`# Passwords and authentication
:password, :password_confirmation, :pass, :pw
:token, :secret
:credentials, :auth, :authentication, :authorization

# Sensitive personal information
:credit_card, :ssn, :social_security`}
      </CodeBlock>

      <HeadingWithAnchor id="email-hashing" level={3}>
        Email Hashing for Request Tracing
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        For email addresses, LogStruct provides special handling by generating a
        consistent hash that allows tracing user activity across different log
        entries while still protecting personal information:
      </p>

      <CodeBlock language="ruby">
        {`# These keys have hashed values by default
:email, :email_address

# Example of a log with hashed email
{
  email: { _filtered: { _class: "String", _hash: "a1b2c3d4e5f6" } }
}`}
      </CodeBlock>

      <HeadingWithAnchor id="configuring-parameter-filtering" level={3}>
        Configuring Parameter Filtering
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        You can customize which keys are filtered and which keys should include
        hashes:
      </p>

      <RubyCodeExample name="filter_configuration" />

      <HeadingWithAnchor id="string-scrubbing" level={1} className="mt-16">
        String Scrubbing
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        In addition to filtering based on key names, LogStruct automatically
        scans all string values for patterns that might contain sensitive
        information, regardless of the key they&apos;re associated with.
      </p>

      <Callout type="info">
        Special thanks to{' '}
        <a
          className="text-blue-200 hover:text-white"
          href="https://github.com/ankane"
        >
          ankane
        </a>{' '}
        for creating the{' '}
        <a
          className="text-blue-200 hover:text-white"
          href="https://github.com/ankane/logstop"
        >
          logstop
        </a>{' '}
        gem. We use a vendored fork of the logstop formatter code with some
        modifications.
      </Callout>

      <HeadingWithAnchor id="how-string-scrubbing-works" level={3}>
        How String Scrubbing Works
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        String scrubbing uses regular expressions to identify and replace
        sensitive data patterns with descriptive placeholders:
      </p>

      <CodeBlock language="ruby">
        {`# Original log message
"User user@example.com created credit card 4111-1111-1111-1111"

# After string scrubbing
"User [EMAIL:a1b2c3d4e5f6] created credit card [CREDIT_CARD]"`}
      </CodeBlock>

      <HeadingWithAnchor id="types-of-scrubbed-data" level={3}>
        Types of Scrubbed Data
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct can detect and scrub the following types of sensitive data:
      </p>

      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-300 ml-4">
        <li>
          <strong>Email addresses</strong>: Replaced with{' '}
          <code>[EMAIL:hash]</code>
        </li>
        <li>
          <strong>Passwords in URLs</strong>: Replaced with{' '}
          <code>[PASSWORD]</code>
        </li>
        <li>
          <strong>Credit card numbers</strong>: Replaced with{' '}
          <code>[CREDIT_CARD]</code>
        </li>
        <li>
          <strong>Phone numbers</strong>: Replaced with <code>[PHONE]</code>
        </li>
        <li>
          <strong>Social security numbers</strong>: Replaced with{' '}
          <code>[SSN]</code>
        </li>
        <li>
          <strong>IP addresses</strong>: Replaced with <code>[IP]</code>{' '}
          (disabled by default)
        </li>
        <li>
          <strong>MAC addresses</strong>: Replaced with <code>[MAC]</code>{' '}
          (disabled by default)
        </li>
      </ul>

      <HeadingWithAnchor id="configuring-string-scrubbing" level={3}>
        Configuring String Scrubbing
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        You can enable or disable specific scrubbers as part of the filter
        configuration:
      </p>

      <RubyCodeExample name="filter_configuration" />

      <HeadingWithAnchor id="custom-string-scrubbing" level={3}>
        Custom String Scrubbing
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        For data patterns not covered by the built-in scrubbers, you can
        implement a custom string scrubbing handler:
      </p>
      <RubyCodeExample name="custom_string_scrubber" />

      <HeadingWithAnchor id="examples" level={1} className="mt-16">
        Examples
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        Here are examples of how LogStruct filters and scrubs sensitive data in
        different scenarios:
      </p>

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
  "email": {
    "_filtered": {
      "_class": "String",
      "_hash": "a1b2c3d4e5f6"
    }
  },
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
        Filtered Array with Sensitive Data
      </HeadingWithAnchor>
      <CodeBlock language="ruby">
        {`# Original array
[
  "Public message",
  "Email: user@example.com",
  "Password: secret123",
  { user_id: 123, email: "another@example.com" }
]

# Logged output
[
  "Public message",
  "Email: [EMAIL:a1b2c3d4e5f6]",
  "Password: [PASSWORD]",
  {
    "user_id": 123,
    "email": {
      "_filtered": {
        "_class": "String",
        "_hash": "g7h8i9j0k1l2"
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
"Connecting to database at https://user:password123@db.example.com:5432/mydb"

# Logged output
"Connecting to database at https://user:[PASSWORD]@db.example.com:5432/mydb"`}
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
        "email": {
          "_filtered": {
            "_class": "String",
            "_hash": "m3n4o5p6q7r8"
          }
        },
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
      "email": "[EMAIL:m3n4o5p6q7r8]"
    }
  }
}`}
      </CodeBlock>

      <EditPageLink />
    </div>
  );
}
