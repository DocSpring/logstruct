import Link from 'next/link';
import type { ReactNode } from 'react';
import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { RubyCodeExample } from '@/components/ruby-code-example';
import { Callout } from '@/components/ui/callout';

function FieldTable({ rows }: { rows: [string, ReactNode][] }) {
  return (
    <div className="relative overflow-x-auto">
      <table className="w-full text-sm text-left text-neutral-600 dark:text-neutral-300">
        <thead className="text-neutral-700 dark:text-neutral-300 border-b border-neutral-200 dark:border-neutral-700">
          <tr>
            <th scope="col" className="px-4 py-2 font-medium">
              Field
            </th>
            <th scope="col" className="px-4 py-2 font-medium">
              Value
            </th>
          </tr>
        </thead>
        <tbody>
          {rows.map(([field, value]) => (
            <tr key={field} className="border-b border-neutral-200 dark:border-neutral-700">
              <td className="px-4 py-2 font-mono text-xs align-top whitespace-nowrap">{field}</td>
              <td className="px-4 py-2">{value}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export default function SqlIntegrationPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="sql" level={1}>
        SQL Queries
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-300">
        SQL logging is off by default. With{' '}
        <code>config.integrations.enable_sql_logging = true</code>, LogStruct subscribes to
        ActiveRecord&apos;s <code>sql.active_record</code> events and writes an <code>app</code>{' '}
        <code>database</code> line for each query that takes at least{' '}
        <code>sql_slow_query_threshold</code> milliseconds (100 by default). It detaches Rails&apos;
        own SQL log lines while it&apos;s on.
      </p>

      <HeadingWithAnchor id="lines">Lines</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        Each query is one line at <code>info</code> level. These two were logged with{' '}
        <code>sql_slow_query_threshold = 0</code> in the test environment, where bind values are
        logged:
      </p>
      <CodeBlock language="json">
        {`{
  "src": "app",
  "evt": "database",
  "lvl": "info",
  "ts": "2026-10-17T03:21:04.676+00:00",
  "msg": "User Create executed",
  "sql": "INSERT INTO \\"users\\" (\\"email\\", \\"name\\", \\"password_digest\\", \\"reset_token\\", \\"avatar\\") VALUES (?, ?, ?, ?, ?) RETURNING \\"id\\"",
  "name": "User Create",
  "duration_ms": 0.18,
  "row_count": 1,
  "adapter": "SQLite3Adapter",
  "bind_params": [
    "[FILTERED]",
    "Test User",
    "[FILTERED]",
    "[FILTERED]",
    "<3 bytes of binary data>"
  ],
  "pool_size": 5,
  "active_count": 1,
  "op_type": "INSERT",
  "table_names": [
    "users"
  ],
  "prog": "Rails"
}`}
      </CodeBlock>
      <CodeBlock language="json">
        {`{
  "src": "app",
  "evt": "database",
  "lvl": "info",
  "ts": "2026-10-17T03:21:04.681+00:00",
  "msg": "User Load executed",
  "sql": "SELECT \\"users\\".* FROM \\"users\\" WHERE \\"users\\".\\"email\\" = ? ORDER BY \\"users\\".\\"id\\" ASC LIMIT ?",
  "name": "User Load",
  "duration_ms": 0.04,
  "row_count": 1,
  "adapter": "SQLite3Adapter",
  "bind_params": [
    "[FILTERED]",
    1
  ],
  "pool_size": 5,
  "active_count": 1,
  "op_type": "SELECT",
  "table_names": [
    "users"
  ],
  "prog": "Rails"
}`}
      </CodeBlock>

      <HeadingWithAnchor id="fields">Fields</HeadingWithAnchor>
      <FieldTable
        rows={[
          [
            'msg',
            <>
              <code>&lt;name&gt; executed</code>.
            </>,
          ],
          [
            'sql',
            'The SQL, scrubbed like any other string (email addresses, card numbers and so on), but not filtered.',
          ],
          [
            'name',
            <>
              ActiveRecord&apos;s name for the query, such as <code>User Load</code>, or{' '}
              <code>SQL Query</code> when it has none.
            </>,
          ],
          ['duration_ms', 'How long the query took, in milliseconds, to two decimal places.'],
          ['row_count', 'The number of rows, when ActiveRecord reports it.'],
          [
            'adapter',
            <>
              The connection adapter&apos;s class name, such as <code>PostgreSQLAdapter</code>.
            </>,
          ],
          [
            'bind_params',
            <>
              The bind values, filtered (see{' '}
              <a href="#bind-values" className="underline">
                Bind values
              </a>
              ). Left out when <code>sql_log_bind_params</code> is off.
            </>,
          ],
          [
            'db_name',
            <>
              The database name, from adapters that have <code>current_database</code> (PostgreSQL
              and MySQL).
            </>,
          ],
          ['pool_size', "The size of the connection's pool."],
          ['active_count', 'How many connections in the pool are in use.'],
          [
            'op_type',
            <>
              The SQL&apos;s first word, in capitals (<code>SELECT</code>, <code>INSERT</code>,{' '}
              <code>BEGIN</code>, ...).
            </>,
          ],
          [
            'table_names',
            <>
              The tables named after <code>FROM</code>, <code>JOIN</code>, <code>UPDATE</code> and{' '}
              <code>INTO</code>, found with a regular expression: for a schema-qualified name such
              as <code>&quot;public&quot;.&quot;users&quot;</code> it&apos;s the schema&apos;s name.
            </>,
          ],
        ]}
      />

      <HeadingWithAnchor id="threshold">Which queries are logged</HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          Queries that take at least <code>sql_slow_query_threshold</code> milliseconds (default{' '}
          <code>100.0</code>). With <code>0</code> or <code>nil</code>, every query is logged,
          transactions&apos; <code>BEGIN</code> and <code>COMMIT</code> included.
        </li>
        <li>
          Not logged: queries named <code>SCHEMA</code> or <code>CACHE</code> (query cache hits),
          queries on <code>schema_migrations</code> or <code>ar_internal_metadata</code>, and{' '}
          <code>SHOW</code>, <code>DESCRIBE</code> and <code>EXPLAIN</code> statements.
        </li>
      </ul>

      <HeadingWithAnchor id="rails-lines">Rails&apos; own SQL lines</HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300">
        While SQL logging is on, LogStruct detaches Rails&apos;{' '}
        <code>ActiveRecord::LogSubscriber</code> and turns off{' '}
        <code>ActiveRecord.verbose_query_logs</code> (the &quot;↳ caller&quot; lines), so each query
        is logged once. With SQL logging off, Rails&apos; own lines stay: debug-level lines with the
        query as text in <code>msg</code>, which aren&apos;t written at the <code>info</code> level
        that Rails&apos; generated production config sets.
      </p>

      <HeadingWithAnchor id="bind-values">Bind values</HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          <code>sql_log_bind_params</code> defaults to <code>true</code> unless{' '}
          <code>Rails.env</code> is <code>production</code>. An environment with another name, such
          as <code>staging</code>, logs bind values unless you turn it off.
        </li>
        <li>
          Each value is filtered by its column name, like a request parameter: a column that matches
          your filter keys, LogStruct&apos;s default sensitive keys, Rails&apos;{' '}
          <code>filter_parameters</code> or <code>filter_keys_with_hashes</code> (<code>email</code>{' '}
          by default) is written as <code>[FILTERED]</code>. In the lines above, that&apos;s{' '}
          <code>email</code>, <code>password_digest</code> and <code>reset_token</code>.
        </li>
        <li>
          Binary columns are written as their size (<code>&lt;3 bytes of binary data&gt;</code>).
        </li>
        <li>
          Other strings are written as <code>[FILTERED]</code> when they look like a secret: longer
          than 50 characters with no whitespace, 32 or more hex digits, 20 or more Base64
          characters, a JWT, or a <code>Bearer</code> token. Merely containing a word such as{' '}
          <code>password</code> or <code>key</code> does not make a value sensitive.
        </li>
        <li>What&apos;s left is scrubbed like any other value.</li>
      </ul>

      <HeadingWithAnchor id="settings">Settings</HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          <code>config.integrations.enable_sql_logging</code> (default <code>false</code>).
        </li>
        <li>
          <code>config.integrations.sql_slow_query_threshold</code>, in milliseconds, as a Float
          (default <code>100.0</code>).
        </li>
        <li>
          <code>config.integrations.sql_log_bind_params</code> (default <code>true</code> unless{' '}
          <code>Rails.env</code> is <code>production</code>).
        </li>
      </ul>
      <p className="text-neutral-600 dark:text-neutral-300">
        See{' '}
        <Link href="/docs/configuration" className="underline">
          Configuration
        </Link>{' '}
        for the other settings.
      </p>
      <RubyCodeExample name="sql_configuration" />

      <HeadingWithAnchor id="limits">Limits</HeadingWithAnchor>
      <ul className="list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300">
        <li>
          The <code>sql</code> field isn&apos;t filtered. Values written into the SQL itself (a
          string condition such as <code>where(&quot;token = &apos;...&apos;&quot;)</code>, or every
          value when <code>prepared_statements</code> is off) are logged, scrubbed but not filtered.
        </li>
        <li>A low threshold in a busy app writes a line for nearly every query.</li>
      </ul>

      <Callout type="info">
        Lines logged during a request have the request&apos;s <code>req_id</code>, so a query can be
        matched to the request that ran it.
      </Callout>

      <EditPageLink />
    </div>
  );
}
