import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';
import { EnumsList } from '@/components/enums-list';
import { HeadingWithAnchor } from '@/components/heading-with-anchor';
import { LogStructuresList } from '@/components/log-structures-list';
import { RubyCodeExample } from '@/components/ruby-code-example';

export default async function TypeSafetyPage() {
  return (
    <div className="space-y-6">
      <HeadingWithAnchor id="sorbet-types" level={1}>
        Sorbet Types
      </HeadingWithAnchor>
      <p className="text-lg text-neutral-600 dark:text-neutral-400">
        LogStruct is built with type safety in mind and provides full type
        checking support through{' '}
        <a className="text-gray-200 hover:underline" href="https://sorbet.org/">
          Sorbet
        </a>
        . This helps catch errors at development time and provides better
        documentation and IDE support.
      </p>

      <HeadingWithAnchor id="using-logstruct-with-sorbet">
        Using LogStruct with Sorbet
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct includes predefined log structures with strict typing. These
        structures ensure your logs have a consistent format and that required
        fields are always present.
      </p>

      <RubyCodeExample
        name="basic_typed_logging"
        title="Basic Typed Logging Example"
      />

      <HeadingWithAnchor id="adding-sorbet">
        Adding Sorbet to Your Application
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        To fully utilize LogStruct&apos;s type safety features, you should add
        Sorbet to your application:
      </p>

      <CodeBlock language="bash">
        {`# In your Gemfile
gem "sorbet", group: :development
gem "sorbet-runtime"

# Then run
# bundle install
# bundle exec srb init`}
      </CodeBlock>

      <HeadingWithAnchor id="benefits">
        Benefits of Type Safety
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        Using LogStruct&apos;s typed structures provides several benefits:
      </p>

      <ul className="list-disc list-inside space-y-2 text-neutral-600 dark:text-neutral-400">
        <li>Catches errors at development time, not at runtime</li>
        <li>Ensures consistent log structure</li>
        <li>Provides better IDE autocompletion</li>
      </ul>

      <HeadingWithAnchor id="error-handling">
        Error Handling for Type Errors
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        LogStruct installs appropriate error handlers for Sorbet type checking
        errors.
      </p>

      <RubyCodeExample
        name="sorbet_error_handler"
        title="Sorbet Error Handler Configuration"
      />

      <HeadingWithAnchor id="custom-log-classes">
        Creating Custom Log Classes
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        You can create your own typed log classes by extending LogStruct&apos;s
        base classes:
      </p>

      <RubyCodeExample
        name="custom_log_class"
        title="Creating Custom Log Classes"
      />

      <HeadingWithAnchor id="available-log-classes" level={1}>
        Log Classes
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        Log classes are{' '}
        <a href="https://sorbet.org/docs/tstruct">
          <code>Typed Structs</code>
        </a>{' '}
        under the <code>LogStruct::</code> module.
      </p>
      <LogStructuresList />

      <HeadingWithAnchor id="enums" level={1}>
        Enums
      </HeadingWithAnchor>
      <p className="text-neutral-600 dark:text-neutral-400 mb-4">
        Common values are defined as{' '}
        <a href="https://sorbet.org/docs/tenum">
          <code>Typed Enums</code>
        </a>{' '}
        under the <code>LogStruct::</code> module.
      </p>
      <EnumsList />

      <EditPageLink />
    </div>
  );
}
