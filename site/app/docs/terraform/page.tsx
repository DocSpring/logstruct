import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';

export const metadata = {
  title: 'Terraform Provider',
  description:
    'Use the DocSpring/logstruct Terraform provider to validate struct/event combos and compile CloudWatch filter patterns.',
};

export default function TerraformDocsPage() {
  // Module-first examples
  const moduleMetricFilter = `module "email_delivered_metric" {
  source  = "DocSpring/logstruct/aws//modules/metric-filter"
  version = ">= 0.1.0"

  name           = "Email Delivered Count"
  log_group_name = var.log_group_name
  log_source     = "mailer"
  log_event      = "delivered"
  namespace      = var.namespace
}`;

  const moduleSqlCount = `module "sql_query_count" {
  source  = "DocSpring/logstruct/aws//modules/metric-filter"
  version = ">= 0.1.0"

  name           = "SQL Query Count"
  log_group_name = var.log_group_name
  log_source     = "app"
  log_event      = "database"
  namespace      = var.namespace
}`;

  const moduleGoodJobFinish = `module "goodjob_finish_count" {
  source  = "DocSpring/logstruct/aws//modules/metric-filter"
  version = ">= 0.1.0"

  name           = "GoodJob Finish Count"
  log_group_name = var.log_group_name
  log_source     = "job"
  log_event      = "finish"
  namespace      = var.namespace
}`;

  // Provider reference (for advanced usage)
  const providerPattern = `data "logstruct_source" "mailer" {
  name = "mailer"
}

data "logstruct_pattern" "email_delivered" {
  source = data.logstruct_source.mailer.canonical
  event  = "delivered"
}`;

  return (
    <div className="space-y-10">
      <h1 className="text-3xl font-bold mb-2">Terraform Provider</h1>
      <p className="text-neutral-600 dark:text-neutral-400">
        The LogStruct Terraform provider offers type-safe helpers for building
        CloudWatch filter patterns from your structured logs, and validates
        struct/event combinations at plan time.
      </p>

      <section id="installation" className="space-y-4">
        <h2 className="text-2xl font-semibold">Installation</h2>
        <p>
          Use the AWS module wrappers for common patterns. They resolve the
          provider internally and compile patterns safely.
        </p>
      </section>

      <section id="example" className="space-y-4">
        <h2 className="text-2xl font-semibold">
          CloudWatch Metric Filter Example
        </h2>
        <p>
          Module-first: create an AWS metric filter for a known LogStruct
          source/event combo. Invalid combinations fail at plan time.
        </p>
        <CodeBlock language="hcl" title="Module: Metric Filter">
          {moduleMetricFilter}
        </CodeBlock>
        <CodeBlock language="hcl" title="Variables">
          {`variable "log_group_name" { type = string }
variable "namespace" { type = string }`}
        </CodeBlock>
      </section>

      <section id="validation" className="space-y-4">
        <h2 className="text-2xl font-semibold">Validation and Safety</h2>
        <ul className="list-disc pl-6 space-y-1">
          <li>
            Structs and events are validated at plan time using the embedded
            LogStruct catalog exported from this repository.
          </li>
          <li>
            If allowed events or keys change in a newer LogStruct release, your
            Terraform plan will fail fast with clear diagnostics.
          </li>
        </ul>
      </section>

      <section id="versioning" className="space-y-4">
        <h2 className="text-2xl font-semibold">Versioning</h2>
        <ul className="list-disc pl-6 space-y-1">
          <li>
            Provider versions mirror LogStruct tags (for example,{' '}
            <code>v0.2.0</code>).
          </li>
          <li>
            Use a compatible constraint like <code>~&gt; 0.2</code> to receive
            non-breaking updates.
          </li>
        </ul>
      </section>

      <section id="recipes" className="space-y-4">
        <h2 className="text-2xl font-semibold">Recipes</h2>
        <p className="text-neutral-600 dark:text-neutral-400">
          A few helpful patterns you can copy and adapt:
        </p>
        <CodeBlock language="hcl" title="Count Email Deliveries">
          {moduleMetricFilter}
        </CodeBlock>
        <CodeBlock language="hcl" title="Count Successful GoodJob Runs">
          {moduleGoodJobFinish}
        </CodeBlock>
        <CodeBlock language="hcl" title="Count All SQL Queries">
          {moduleSqlCount}
        </CodeBlock>
        <CodeBlock language="hcl" title="Provider Reference: Compile Pattern">
          {providerPattern}
        </CodeBlock>
        <p className="text-neutral-600 dark:text-neutral-400">
          For delivery failures, use metric math to compare attempts vs.
          delivered counts. CloudWatch filter patterns do not support numeric
          comparisons, so slow-query thresholds are usually handled downstream
          (for example, count + percentiles in metrics/dashboards). See the
          provider README for more examples and details.
        </p>
      </section>

      <section id="links" className="space-y-2">
        <h2 className="text-2xl font-semibold">Links</h2>
        <ul className="list-disc pl-6">
          <li>
            <a
              href="https://github.com/DocSpring/terraform-provider-logstruct"
              target="_blank"
              rel="noopener noreferrer"
            >
              Provider README (GitHub)
            </a>
          </li>
          <li>
            <a
              href="https://registry.terraform.io/modules/DocSpring/logstruct/aws"
              target="_blank"
              rel="noopener noreferrer"
            >
              AWS Module (Terraform Registry)
            </a>
          </li>
        </ul>
      </section>

      <EditPageLink path="app/docs/terraform/page.tsx" />
    </div>
  );
}
