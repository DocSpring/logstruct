import type { Metadata } from 'next';
import Link from 'next/link';
import type { ReactNode } from 'react';
import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { RubyCodeExample } from '@/components/ruby-code-example';
import { Callout } from '@/components/ui/callout';
import exampleLines from './example-lines.json';
import { logFieldRows, shortTypeName, typeCategory } from './log-field-usage';

export const metadata: Metadata = {
  title: 'Log Fields | LogStruct',
  description:
    'The JSON keys LogStruct writes: the keys on every line, the short names of each log type’s fields, example lines and the formats of their values.',
};

type JsonLine = Record<string, unknown>;

const LINES = exampleLines.lines as Record<string, JsonLine>;
const FORMATS = exampleLines.formats as Record<string, JsonLine>;

const json = (line: JsonLine): string => JSON.stringify(line, null, 2);

const text = 'text-neutral-600 dark:text-neutral-300';
const list = `list-disc list-outside ml-6 space-y-2 ${text}`;

function exampleGroups(): Array<[string, string[]]> {
  const groups = new Map<string, string[]>();
  for (const name of Object.keys(LINES).sort()) {
    const category = typeCategory(name);
    groups.set(category, [...(groups.get(category) ?? []), name]);
  }
  return [...groups.entries()].sort(([a], [b]) => a.localeCompare(b));
}

function KeyTable({ rows }: { rows: Array<[string, ReactNode]> }) {
  return (
    <div className="relative overflow-x-auto">
      <table className="w-full text-sm text-left">
        <thead className="text-neutral-700 dark:text-neutral-300 border-b border-neutral-200 dark:border-neutral-700">
          <tr>
            <th scope="col" className="px-4 py-3 font-medium">
              Key
            </th>
            <th scope="col" className="px-4 py-3 font-medium">
              Value
            </th>
          </tr>
        </thead>
        <tbody className={text}>
          {rows.map(([key, description]) => (
            <tr key={key} className="border-b border-neutral-200 dark:border-neutral-700 align-top">
              <td className="px-4 py-3 font-mono text-xs whitespace-nowrap">{key}</td>
              <td className="px-4 py-3">{description}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export default function LogFieldsPage() {
  const fieldRows = logFieldRows();

  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="log-fields" level={1}>
        Log Fields
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-300">
        Each line LogStruct writes is one JSON object. This page lists its keys: the ones every line
        has, the ones LogStruct adds from the logger&apos;s context, and the short names of each log
        type&apos;s fields. It ends with an example line for each built-in log type and the formats
        of the values.
      </p>

      <HeadingWithAnchor id="common-keys">Keys on Every Line</HeadingWithAnchor>
      <KeyTable
        rows={[
          [
            'src',
            <>
              Where the line came from: a <code>LogStruct::Source</code> value such as{' '}
              <code>rails</code>, <code>app</code>, <code>job</code> or <code>mailer</code>, or the{' '}
              <code>src</code> of a Hash you log. Lines without one get <code>app</code>.
            </>,
          ],
          [
            'evt',
            <>
              What happened: a <code>LogStruct::Event</code> value such as <code>request</code>,{' '}
              <code>log</code> or <code>error</code>, or the <code>evt</code> of a Hash you log.
              Lines without one get <code>log</code>.
            </>,
          ],
          [
            'lvl',
            <>
              The level the line was logged at (see <a href="#levels">Levels</a>).
            </>,
          ],
          [
            'ts',
            <>
              When the line was logged (see <a href="#timestamps">Timestamps</a>).
            </>,
          ],
          [
            'msg',
            <>
              The message, on lines that have one: a string you log, the message field of the log
              types that have one (see <a href="#short-names">Short Names</a>), or the{' '}
              <code>msg</code> of a Hash you log.
            </>,
          ],
          [
            'prog',
            <>
              The name of the logger that wrote the line: <code>Rails</code> for{' '}
              <code>Rails.logger</code> and the framework loggers LogStruct replaces,{' '}
              <code>Sidekiq-Server</code> or <code>Sidekiq-Client</code> for Sidekiq&apos;s own
              lines and <code>GoodJob</code> for GoodJob&apos;s. Lines written without a logger name
              have no <code>prog</code>.
            </>,
          ],
        ]}
      />
      <p className={text}>
        LogStruct&apos;s own log types write <code>src</code>, <code>evt</code>, <code>lvl</code>{' '}
        and <code>ts</code> first, then their fields. A Hash you log keeps its own keys first.
      </p>

      <HeadingWithAnchor id="context-keys">Keys from the Logger&apos;s Context</HeadingWithAnchor>
      <p className={text}>
        LogStruct adds these keys after the line&apos;s own fields. It filters and scrubs them like
        the rest of the line.
      </p>
      <KeyTable
        rows={[
          [
            'req_id',
            <>
              The request&apos;s ID (Rails&apos; <code>request.request_id</code>), on every line
              logged while Rails handles a request. Blocked host lines don&apos;t have it: Rails
              checks the host before it sets the request ID. A line with its own <code>req_id</code>{' '}
              keeps it.
            </>,
          ],
          [
            'tags',
            <>
              The logger&apos;s tags, as an array: <code>logger.tagged(&quot;billing&quot;)</code>{' '}
              and <code>config.log_tags</code>. The <code>config/environments/production.rb</code>{' '}
              that Rails generates sets <code>config.log_tags = [:request_id]</code>, so the lines
              logged during a request in production have the request ID in <code>tags</code> too. A
              line with its own <code>tags</code> keeps them.
            </>,
          ],
          [
            'ctx',
            <>
              Named tags (<code>logger.tagged(account_id: 42)</code>) and, while a Sidekiq job runs,
              the job&apos;s <code>jid</code> and <code>class</code>. When a line has its own{' '}
              <code>ctx</code> Hash, its keys win and the other keys are added to it.
            </>,
          ],
        ]}
      />
      <RubyCodeExample name="log_fields_tags" />
      <CodeBlock language="json">{json(FORMATS.tags)}</CodeBlock>

      <HeadingWithAnchor id="logged-hashes">Logged Hashes</HeadingWithAnchor>
      <p className={text}>
        A Hash you log is written with its keys at the top level of the line. It can set its own{' '}
        <code>src</code> and <code>evt</code>. The timestamp and level come from the logger: a{' '}
        <code>ts</code> or <code>lvl</code> key in the Hash is dropped and handled as a LogStruct
        error (<code>error_handling_modes.logstruct_errors</code>: raised in{' '}
        <code>local_environments</code>, logged elsewhere).
      </p>
      <RubyCodeExample name="log_fields_hash" />
      <CodeBlock language="json">{json(FORMATS.hash)}</CodeBlock>

      <HeadingWithAnchor id="additional-data">additional_data</HeadingWithAnchor>
      <p className={text}>
        LogStruct&apos;s log types take an <code>additional_data</code> Hash for fields the type
        doesn&apos;t have. Its keys are written at the top level of the line, after the type&apos;s
        own fields, not under an <code>additional_data</code> key.
      </p>
      <RubyCodeExample name="log_fields_additional_data" />
      <CodeBlock language="json">{json(FORMATS.additional_data)}</CodeBlock>
      <ul className={list}>
        <li>
          A key with the same name as one of the type&apos;s fields replaces that field: an{' '}
          <code>additional_data</code> of <code>{'{msg: "..."}'}</code> replaces the message.
        </li>
        <li>
          <code>src</code>, <code>evt</code>, <code>lvl</code> and <code>ts</code> are reserved.
          LogStruct drops them and handles the <code>ArgumentError</code> as a LogStruct error
          (raised in <code>local_environments</code>, logged elsewhere).
        </li>
      </ul>

      <HeadingWithAnchor id="short-names">Short Names</HeadingWithAnchor>
      <p className={text}>
        LogStruct&apos;s log types name their fields with <code>LogStruct::LogField</code>, which
        maps each name to a short JSON key: <code>MailerClass</code> is written as{' '}
        <code>mailer</code> and <code>Database</code> as <code>db</code>. The table lists every
        field. <code>Log::ActiveJob::*</code> stands for every ActiveJob log type, and some fields
        aren&apos;t written by any built-in log type. At the top of a line, Rails&apos; partial{' '}
        <code>filter_parameters</code> matches don&apos;t apply to these keys: Rails 8&apos;s
        default <code>:_key</code> would otherwise filter <code>cron_key</code>.
      </p>
      <div className="relative overflow-x-auto">
        <table className="w-full text-sm text-left" data-testid="log-field-table">
          <thead className="text-neutral-700 dark:text-neutral-300 border-b border-neutral-200 dark:border-neutral-700">
            <tr>
              <th scope="col" className="px-4 py-3 font-medium">
                Key
              </th>
              <th scope="col" className="px-4 py-3 font-medium">
                LogField
              </th>
              <th scope="col" className="px-4 py-3 font-medium">
                Written by
              </th>
            </tr>
          </thead>
          <tbody className={text}>
            {fieldRows.map((row) => (
              <tr
                key={row.name}
                className="border-b border-neutral-200 dark:border-neutral-700 align-top"
              >
                <td className="px-4 py-2 font-mono text-xs whitespace-nowrap">{row.key}</td>
                <td className="px-4 py-2 font-mono text-xs whitespace-nowrap">{row.name}</td>
                <td className="px-4 py-2 text-xs">
                  {row.key === 'req_id' ? (
                    <a href="#context-keys">Added from the request (see above)</a>
                  ) : row.usedBy.length === 0 ? (
                    'No built-in log type'
                  ) : (
                    row.usedBy.join(', ')
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <HeadingWithAnchor id="example-lines">Example Lines</HeadingWithAnchor>
      <p className={text}>
        One line for each built-in log type, as LogStruct&apos;s formatter writes it from the values
        its integration sets. The values are made up. Each line is shown over several lines here;
        LogStruct writes it on one. The fields of each type are listed in{' '}
        <Link href="/docs/sorbet-types#builtin-log-classes">Built-In Log Classes</Link>.
      </p>
      <div className="space-y-6">
        {exampleGroups().map(([category, names]) => (
          <section key={category} className="space-y-2">
            <h3 className="text-xl font-semibold text-neutral-800 dark:text-neutral-200">
              <code>{category}</code>
            </h3>
            {names.map((name) => (
              <details
                key={name}
                className="rounded-md border border-neutral-200 dark:border-neutral-700"
              >
                <summary className="cursor-pointer px-4 py-2 text-sm text-neutral-700 dark:text-neutral-300">
                  <code>{shortTypeName(name)}</code>{' '}
                  <span className="text-neutral-500 dark:text-neutral-400">
                    src: {String(LINES[name].src)}, evt: {String(LINES[name].evt)}
                  </span>
                </summary>
                <div className="px-2 pb-2">
                  <CodeBlock language="json">{json(LINES[name])}</CodeBlock>
                </div>
              </details>
            ))}
          </section>
        ))}
      </div>

      <HeadingWithAnchor id="value-formats">Value Formats</HeadingWithAnchor>

      <HeadingWithAnchor id="timestamps" level={3}>
        Timestamps
      </HeadingWithAnchor>
      <p className={text}>
        <code>ts</code> is an ISO 8601 time with milliseconds and the UTC offset of the
        process&apos;s time zone: <code>2026-10-17T09:30:15.123+00:00</code> on a server whose time
        zone is UTC, <code>2026-10-17T22:30:15.123+13:00</code> on one in New Zealand. Rails&apos;{' '}
        <code>config.time_zone</code> doesn&apos;t change it. Every other time in a line is written
        the same way: the times of the built-in log types, such as ActiveJob&apos;s{' '}
        <code>scheduled_at</code>, and the times in a Hash you log.
      </p>

      <HeadingWithAnchor id="levels" level={3}>
        Levels
      </HeadingWithAnchor>
      <p className={text}>
        <code>lvl</code> is <code>debug</code>, <code>info</code>, <code>warn</code>,{' '}
        <code>error</code>, <code>fatal</code> or <code>unknown</code>. It comes from the logger
        method that wrote the line (<code>logger.warn</code> writes <code>warn</code>), not from the
        log type&apos;s own <code>level</code>. Any other severity is written as{' '}
        <code>unknown</code>.
      </p>

      <HeadingWithAnchor id="filtered-values" level={3}>
        Filtered Values
      </HeadingWithAnchor>
      <p className={text}>
        A value whose key is filtered is replaced by a summary under <code>_filtered</code>. Which
        keys are filtered is described in{' '}
        <Link href="/docs/filtering-sensitive-data">Filtering Sensitive Data</Link>.
      </p>
      <RubyCodeExample name="log_fields_filtered" />
      <CodeBlock language="json">{json(FORMATS.filtered)}</CodeBlock>
      <ul className={list}>
        <li>
          A String: <code>{'{"_class": "String"}'}</code>, without its length. For keys in{' '}
          <code>filter_keys_with_hashes</code> (<code>email</code> and <code>email_address</code> by
          default) the summary also has a <code>_hash</code> of the value: 16 hex characters of an
          HMAC-SHA256 keyed with <code>filters.hash_salt</code>, or by default with a key derived
          from the app&apos;s <code>secret_key_base</code>. An email address has one hash however
          it&apos;s capitalized.
        </li>
        <li>
          A Hash: <code>_class</code>, <code>_keys_count</code> and its first 10 keys in{' '}
          <code>_keys</code>. An empty Hash is <code>{'{"_class": "Hash", "_empty": true}'}</code>.
        </li>
        <li>
          An Array: <code>_class</code> and <code>_count</code>. An empty Array is{' '}
          <code>{'{"_class": "Array", "_empty": true}'}</code>.
        </li>
        <li>
          Any other value: its class, such as <code>{'{"_class": "Integer"}'}</code>.
        </li>
        <li>
          A value that Rails&apos; <code>filter_parameters</code> already replaced, such as the
          params on request lines, is kept as Rails wrote it: <code>&quot;[FILTERED]&quot;</code>.
        </li>
        <li>
          Values nested more than 20 levels deep, and values that contain themselves, are written as
          a summary without <code>_keys</code>.
        </li>
      </ul>
      <p className={text}>
        Scrubbed strings keep their text, with the sensitive part replaced:{' '}
        <code>[EMAIL:&lt;hash&gt;]</code> (the same hash as <code>_hash</code> above),{' '}
        <code>[PHONE]</code>, <code>[SSN]</code>, <code>[CREDIT_CARD]</code>,{' '}
        <code>[PASSWORD]</code> for a password in a URL, and <code>[FILTERED]</code> for the
        credentials after <code>Bearer</code> or <code>Basic</code> and sensitive query params.{' '}
        <code>[IP]</code> and <code>[MAC]</code> appear only when you turn those scrubbers on.
      </p>

      <HeadingWithAnchor id="truncation" level={3}>
        Truncation
      </HeadingWithAnchor>
      <p className={text}>
        <code>config.limits</code> sets how much of each value LogStruct writes:
      </p>
      <ul className={list}>
        <li>
          <code>max_hash_keys</code> (default 100): a Hash writes its first 100 keys, then{' '}
          <code>_more_keys</code> with the number left out. The line&apos;s own keys count too.
        </li>
        <li>
          <code>max_array_items</code> (default 10): an Array writes its first 10 items, then a last
          item <code>&quot;... and N more items&quot;</code>.
        </li>
        <li>
          <code>max_backtrace_lines</code> (default 20): for an Array that looks like a backtrace (3
          of its first 5 items start with <code>file:line</code>), such as an error line&apos;s{' '}
          <code>backtrace</code>, the first 20 lines, then{' '}
          <code>&quot;... and N more lines&quot;</code>.
        </li>
        <li>
          <code>max_string_bytes</code> (default 32768, 32 KB): a longer string is cut to that many
          bytes after it&apos;s scrubbed, and ends with{' '}
          <code>&quot;... (cut from N bytes)&quot;</code>.
        </li>
      </ul>
      <RubyCodeExample name="log_fields_limits" />
      <CodeBlock language="json">{json(FORMATS.limits)}</CodeBlock>

      <Callout type="info">
        The settings on this page are described in{' '}
        <Link href="/docs/configuration">Configuration</Link>.
      </Callout>

      <EditPageLink />
    </div>
  );
}
