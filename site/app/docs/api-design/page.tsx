import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';

export const metadata = {
  title: 'API Design (Typed vs. Untyped)',
  description:
    'How LogStruct balances an idiomatic Rails logging API with an optional typed path for teams using sorbet-runtime.',
};

export default function ApiDesignPage() {
  const untypedExample = `# Untyped, idiomatic Rails logging (works out of the box)
Rails.logger.info({
  msg: "User signed in",
  user_id: current_user.id,
  feature: "onboarding"
})`;

  const typedExample = `# Optional typed API (sorbet-runtime)
log = LogStruct::Log::Request.new(
  message: "GET /projects",
  event: LogStruct::Event::Request,
  source: LogStruct::Source::Rails,
  controller: "ProjectsController",
  action: "index"
)

LogStruct.info(log)`;

  const customStructSketch = `# Sketch: defining a custom typed log struct
class MyApp::Logs::Checkout < T::Struct
  include LogStruct::Log::Interfaces::CommonFields
  include LogStruct::Log::Interfaces::AdditionalDataField

  const :event, LogStruct::Event::Log
  const :source, LogStruct::Source, default: T.let(LogStruct::Source::App, LogStruct::Source)
  const :message, String
  const :cart_id, String
  const :amount_cents, Integer
end

# Then log it with
LogStruct.info(
  MyApp::Logs::Checkout.new(message: "checkout_completed", cart_id: cart.id, amount_cents: 1299)
)`;

  return (
    <div className="space-y-8">
      <h1 className="text-3xl font-bold">API Design: Typed vs. Untyped</h1>
      <p className="text-neutral-600 dark:text-neutral-400">
        LogStruct is designed for an idiomatic Rails experience first, with an
        optional typed path for teams that use sorbet-runtime. Most Rails
        developers can adopt LogStruct without learning Sorbet. Teams wanting
        stronger guarantees can progressively introduce typed log structs.
      </p>

      <h2 className="text-2xl font-semibold">Untyped, Idiomatic Rails</h2>
      <p>
        You can continue using <code>Rails.logger</code> with hashes and
        strings. LogStruct&apos;s formatter scrubs sensitive values and keeps
        output JSON-friendly.
      </p>
      <CodeBlock language="ruby">{untypedExample}</CodeBlock>

      <h2 className="text-2xl font-semibold">Optional Typed Path</h2>
      <p>
        For teams that want stricter contracts, use LogStruct&apos;s typed
        structs. These are runtime-checked via sorbet-runtime and integrate with
        our formatter seamlessly.
      </p>
      <CodeBlock language="ruby">{typedExample}</CodeBlock>

      <h2 className="text-2xl font-semibold">
        Custom Typed Structures (Sketch)
      </h2>
      <p>
        You can define app-specific typed logs by composing LogStruct
        interfaces. Keep this ergonomic and discoverable; the untyped path
        remains first-class.
      </p>
      <CodeBlock language="ruby">{customStructSketch}</CodeBlock>

      <EditPageLink path="app/docs/api-design/page.tsx" />
    </div>
  );
}
