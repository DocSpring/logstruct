import Image from 'next/image';
import Link from 'next/link';
import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';
import { EnumsList } from '@/components/enums-list';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { LogStructuresList } from '@/components/log-structures-list';
import { RubyCodeExample } from '@/components/ruby-code-example';
import { Callout } from '@/components/ui/callout';

// test/code_examples/sorbet_types_test.rb reads the lines below from this file and checks them
// against what LogStruct writes.

// The sorbet_type_error example in production, with the message's first line and without the backtrace
const TYPE_ERROR_LINE = `{
  "src": "type_checking",
  "evt": "error",
  "lvl": "error",
  "ts": "2026-10-17T09:30:15.123+00:00",
  "error_class": "TypeError",
  "msg": "Parameter 'name': Expected type String, got type Integer with value 42",
  "prog": "Rails"
}`;

// What LogStruct writes for the custom_log_usage example
const CUSTOM_LOG_LINE = `{
  "src": "payments",
  "evt": "processed",
  "lvl": "info",
  "ts": "2026-10-17T09:30:15.123+00:00",
  "note": "Receipt sent to [EMAIL:bf02ccc06e51f611]",
  "payment_id": "pay_123456",
  "amount_cents": 9999,
  "currency": "USD",
  "status": "succeeded",
  "user_id": 123,
  "prog": "Rails"
}`;

const pClass = 'text-neutral-600 dark:text-neutral-300';
const listClass = 'list-disc list-outside ml-6 space-y-2 text-neutral-600 dark:text-neutral-300';

export default async function TypeSafetyPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="what-is-sorbet" level={1}>
        What is Sorbet?
      </HeadingWithAnchor>
      <Image src="/images/sorbet-logo.svg" alt="Sorbet Logo" width={100} height={100} />
      <p className="text-lg text-neutral-600 dark:text-neutral-300">
        <a href="https://sorbet.org/" target="_blank" rel="noopener noreferrer">
          Sorbet
        </a>{' '}
        is a type checker for Ruby. Its static checker (<code>srb tc</code>) checks your code before
        it runs, and <code>sorbet-runtime</code> checks method signatures (<code>sig</code>s) and
        typed structs while it runs. It:
      </p>
      <ul className={listClass}>
        <li>Finds type errors before the code runs</li>
        <li>
          Checks the values that reach typed code at runtime, such as params and parsed JSON, which
          the static checker can&apos;t see
        </li>
        <li>Gives editors that use Sorbet&apos;s language server types for completion</li>
      </ul>

      <p className={pClass}>
        LogStruct is written with Sorbet: its files are <code># typed: strict</code> and its methods
        have <code>sig</code>s. Its log lines are typed structs (<code>T::Struct</code>), with a
        type for every field.
      </p>

      <HeadingWithAnchor id="adding-sorbet">Adding Sorbet to Your Application</HeadingWithAnchor>
      <p className={pClass}>
        You don&apos;t need Sorbet to use LogStruct. LogStruct depends on{' '}
        <code>sorbet-runtime</code>, so your app has it already. To type-check your own code, add
        the static checker and{' '}
        <a href="https://github.com/Shopify/tapioca" target="_blank" rel="noopener noreferrer">
          Tapioca
        </a>
        , which writes RBI files that describe your gems to Sorbet:
      </p>

      <CodeBlock language="ruby" title="Gemfile">
        {`gem "sorbet", group: :development
gem "tapioca", require: false, group: [:development, :test]`}
      </CodeBlock>

      <p className={pClass}>Then run:</p>
      <CodeBlock language="bash">
        {`bundle install
bundle exec tapioca init
bundle exec srb tc`}
      </CodeBlock>

      <p className={pClass}>
        <code>tapioca init</code> creates the <code>sorbet/</code> directory and an RBI file for
        each gem. LogStruct&apos;s includes its method signatures, so <code>srb tc</code> checks
        your calls to LogStruct. See{' '}
        <a href="https://sorbet.org/docs/adopting" target="_blank" rel="noopener noreferrer">
          Adopting Sorbet
        </a>{' '}
        for the next steps.
      </p>

      <HeadingWithAnchor id="using-logstruct-with-sorbet">
        Using LogStruct with Sorbet
      </HeadingWithAnchor>
      <p className={pClass}>
        Each built-in log line is a typed struct under <code>LogStruct::Log</code>. Build one and
        pass it to <code>LogStruct.info</code> (or <code>debug</code>, <code>warn</code>,{' '}
        <code>error</code> and <code>fatal</code>), which logs it with <code>Rails.logger</code>.
      </p>

      <RubyCodeExample name="basic_typed_logging" />

      <p className={pClass}>
        With Sorbet in your app, <code>srb tc</code> checks the fields you pass. At runtime,{' '}
        <code>sorbet-runtime</code> checks them when the struct is built: a missing field or a field
        of the wrong type is a type error, which is raised in development and test. In production
        it&apos;s logged and reported, and the struct is built anyway (see below).
      </p>

      <HeadingWithAnchor id="error-handling">Error Handling for Type Errors</HeadingWithAnchor>
      <p className={pClass}>
        When a runtime check fails, Sorbet calls one of four handlers, which raise the error by
        default. In the processes where LogStruct is on (see{' '}
        <Link href="/docs/configuration#enabling-logstruct">Enabling LogStruct</Link>), LogStruct
        sets all four:
      </p>
      <ul className={listClass}>
        <li>
          <code>inline_type_error_handler</code>: a failed <code>T.let</code>, <code>T.cast</code>{' '}
          or <code>T.must</code>
        </li>
        <li>
          <code>call_validation_error_handler</code>: an argument or a return value that
          doesn&apos;t match a method&apos;s <code>sig</code>, or a struct field of the wrong type
        </li>
        <li>
          <code>sig_builder_error_handler</code>: a <code>sig</code> block that can&apos;t be built
        </li>
        <li>
          <code>sig_validation_error_handler</code>: a <code>sig</code> that fails validation, such
          as an override that doesn&apos;t match its parent&apos;s <code>sig</code>
        </li>
      </ul>
      <p className={pClass}>
        Each one passes the error to the{' '}
        <Link href="/docs/configuration#error-handling-configuration">
          <code>type_checking_errors</code> mode
        </Link>
        . The default, <code>ReportProduction</code>, raises the error in the{' '}
        <code>local_environments</code> (development and test), as Sorbet does. Elsewhere it logs
        the error and reports it to your error reporter, and the code carries on with the wrong
        value. These handlers cover type errors in your app and in its gems.
      </p>
      <p className={pClass}>For example, with this method:</p>

      <RubyCodeExample name="sorbet_typed_method" />

      <p className={pClass}>
        a value from outside the typed code that isn&apos;t a String raises a <code>TypeError</code>{' '}
        in development and test:
      </p>

      <RubyCodeExample name="sorbet_type_error" />

      <p className={pClass}>
        In production the call returns <code>&quot;Hello, 42&quot;</code> and writes this line. Its{' '}
        <code>msg</code> goes on with the file and line of the call and of the method, and its{' '}
        <code>backtrace</code> (left out here) starts at the call:
      </p>

      <CodeBlock language="json">{TYPE_ERROR_LINE}</CodeBlock>

      <p className={pClass}>To handle type errors another way, change the mode:</p>

      <RubyCodeExample name="sorbet_type_checking_mode" />

      <p className={pClass}>
        To keep Sorbet&apos;s own behavior, or handlers your app sets, turn LogStruct&apos;s off.
        LogStruct sets its handlers after <code>config/initializers</code> run, so it replaces
        handlers set there unless this is <code>false</code>:
      </p>

      <RubyCodeExample name="test_disable_sorbet_error_handler" />

      <HeadingWithAnchor id="custom-log-classes">Custom Typed Logs</HeadingWithAnchor>
      <p className={pClass}>
        You can define typed log lines of your own. A custom log is a <code>T::Struct</code> that
        includes:
      </p>
      <ul className={listClass}>
        <li>
          <code>LogStruct::Log::Interfaces::PublicCommonFields</code>, which asks for{' '}
          <code>level</code> (a <code>LogStruct::Level</code>), <code>timestamp</code> (a{' '}
          <code>Time</code>) and <code>serialize</code>.
        </li>
        <li>
          <code>LogStruct::Log::SerializeCommonPublic</code>, whose{' '}
          <code>serialize_common_public</code> returns <code>src</code>, <code>evt</code>,{' '}
          <code>lvl</code> and <code>ts</code> from your <code>source</code>, <code>event</code>,{' '}
          <code>level</code> and <code>timestamp</code>. The struct must define <code>source</code>{' '}
          and <code>event</code>; each can be a String, a Symbol or a <code>T::Enum</code>.
        </li>
        <li>
          <code>LogStruct::Log::Interfaces::AdditionalDataField</code> and{' '}
          <code>LogStruct::Log::Shared::MergeAdditionalDataFields</code>, for an optional{' '}
          <code>additional_data</code> Hash whose keys go at the top level of the line. A key that
          matches any built-in log field, such as <code>msg</code> or <code>ts</code>, is a
          LogStruct error (<code>logstruct_errors</code>): raised in development and test, and
          logged and left out in production.
        </li>
      </ul>
      <p className={pClass}>
        Your <code>serialize</code> starts from <code>serialize_common_public</code>, merges the
        additional data, and adds your own fields:
      </p>

      <RubyCodeExample name="custom_log_class" />

      <p className={pClass}>
        Log it like a built-in line. Its fields are filtered and scrubbed like the rest of the line:
      </p>

      <RubyCodeExample name="custom_log_usage" />

      <CodeBlock language="json">{CUSTOM_LOG_LINE}</CodeBlock>

      <Callout type="info">
        The Terraform provider only knows LogStruct&apos;s built-in sources and events, so it
        rejects a custom log&apos;s <code>src</code>. Write CloudWatch patterns for custom logs
        yourself (see <Link href="/docs/terraform#numeric-comparisons">Match on other fields</Link>
        ). The generated TypeScript types and the lists below cover the built-in log types only.
      </Callout>

      <HeadingWithAnchor id="builtin-log-classes" level={1}>
        Built-In Log Classes
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        LogStruct&apos;s log lines are <a href="https://sorbet.org/docs/tstruct">typed structs</a>{' '}
        under <code className="text-neutral-800 dark:text-neutral-100">LogStruct::Log</code>.
      </p>
      <LogStructuresList />

      <HeadingWithAnchor id="built-in-enums" level={1}>
        Built-In Enums
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-300 mb-4">
        Levels, sources, events and error handling modes are{' '}
        <a href="https://sorbet.org/docs/tenum">typed enums</a> (<code>T::Enum</code>) under{' '}
        <code>LogStruct::</code>.
      </p>
      <EnumsList />

      <EditPageLink />
    </div>
  );
}
