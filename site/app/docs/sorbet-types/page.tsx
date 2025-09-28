import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';
import { EnumsList } from '@/components/enums-list';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { LogStructuresList } from '@/components/log-structures-list';
import { RubyCodeExample } from '@/components/ruby-code-example';
import { Callout } from '@/components/ui/callout';
import Image from 'next/image';

export default async function TypeSafetyPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="what-is-sorbet" level={1}>
        What is Sorbet?
      </HeadingWithAnchor>
      <Image
        src="/images/sorbet-logo.svg"
        alt="Sorbet Logo"
        width={100}
        height={100}
      />
      <p className="text-lg text-neutral-600 dark:text-neutral-400">
        <a href="https://sorbet.org/" target="_blank" rel="noopener noreferrer">
          Sorbet
        </a>{' '}
        is a static type checker for Ruby. Static type-checking has many
        benefits:
      </p>
      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-400">
        <li>Catches errors at development time, not at runtime</li>
        <li>Ensures consistent log structure</li>
        <li>Provides better IDE documentation and autocompletion</li>
      </ul>

      <p className="text-lg text-neutral-600 dark:text-neutral-400">
        LogStruct is built with Sorbet and provides full type-checking support.
        We use it to catch errors during development and test and keep the code
        bug-free.
      </p>

      <HeadingWithAnchor id="adding-sorbet">
        Adding Sorbet to Your Application
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        To fully utilize LogStruct&apos;s type safety features, you can add
        Sorbet to your application:
      </p>

      <CodeBlock language="ruby">
        {`# In your Gemfile
gem "sorbet", group: :development
gem "sorbet-runtime"`}
      </CodeBlock>

      <p>Then run:</p>
      <CodeBlock language="bash">
        {`bundle install
bundle exec srb init`}
      </CodeBlock>

      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        See the <a href="https://sorbet.org/site/overview">Sorbet docs</a> for
        more details.
      </p>

      <HeadingWithAnchor id="using-logstruct-with-sorbet">
        Using LogStruct with Sorbet
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct uses predefined log classes with strict typing. This ensures
        that your logs have a consistent format and that required fields are
        present and have the right type.
      </p>

      <RubyCodeExample name="basic_typed_logging" />

      <HeadingWithAnchor id="error-handling">
        Error Handling for Type Errors
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct configures Sorbet error handlers to log and report
        type-checking errors. If you already use Sorbet and you want to keep
        using your own error handlers, set{' '}
        <code>enable_sorbet_error_handlers</code> to <code>false</code>. This
        will prevent LogStruct from overriding your handlers.
      </p>
      <RubyCodeExample name="test_disable_sorbet_error_handler" />

      <HeadingWithAnchor id="custom-log-classes">
        Custom Typed Logs
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        Define your own typed logs by composing LogStruct interfaces and
        helpers. Include <code>LogStruct::Log::Interfaces::CommonFields</code>,{' '}
        <code>LogStruct::Log::Interfaces::AdditionalDataField</code>, and the
        serialization helpers <code>SerializeCommon</code> +{' '}
        <code>MergeAdditionalDataFields</code> to get consistent JSON keys and
        behavior. Use the existing <code>LogStruct::Source</code> and{' '}
        <code>LogStruct::Event</code> enums in your struct.
      </p>

      <RubyCodeExample name="custom_log_class" />

      <Callout type="info">
        Custom types are for your application logs and won&apos;t be exported to
        the Terraform provider catalog or docs generator. Use the built-in
        LogStruct types when you need provider support (patterns/validation),
        and use custom types for app-specific events.
      </Callout>

      <HeadingWithAnchor id="builtin-log-classes" level={1}>
        Built-In Log Classes
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        Log classes are{' '}
        <a href="https://sorbet.org/site/tstruct">typed structs</a> under the{' '}
        <code className="text-neutral-800 dark:text-neutral-100">
          LogStruct::
        </code>{' '}
        module.
      </p>
      <LogStructuresList />

      <HeadingWithAnchor id="built-in-enums" level={1}>
        Built-In Enums
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        Common values are defined as{' '}
        <a href="https://sorbet.org/site/tenum">
          <code>Typed Enums</code>
        </a>{' '}
        under the <code>LogStruct::</code> module.
      </p>
      <EnumsList />

      <EditPageLink />
    </div>
  );
}
