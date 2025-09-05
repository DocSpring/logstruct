import { CodeBlock } from '@/components/code-block';
import { EditPageLink } from '@/components/edit-page-link';

export const metadata = {
  title: 'Terraform Provider',
  description:
    'Use the DocSpring/logstruct Terraform provider to validate struct/event combos and compile CloudWatch filter patterns.',
};

export default function TerraformDocsPage() {
  const requiredProviders = `terraform {
  required_providers {
    logstruct = {
      source  = "DocSpring/logstruct"
      version = "~> 0.2" # matches LogStruct tag
    }
  }
}`;

  const cwFilterDataSource = `data "logstruct_cloudwatch_filter" "email_delivered" {
  struct = "ActionMailer"
  event  = "delivered"
}`;

  const cwMetricFilter = `resource "aws_cloudwatch_log_metric_filter" "email_delivered_count" {
  name           = "Email Delivered Count"
  log_group_name = var.log_group.docspring
  pattern        = data.logstruct_cloudwatch_filter.email_delivered.pattern

  metric_transformation {
    name          = "docspring_email_delivered_count"
    namespace     = var.namespace.logs
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
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
          Add the provider to your Terraform configuration. The provider version
          tracks LogStruct releases and uses the same tag.
        </p>
        <CodeBlock language="hcl" title="Required Providers">
          {requiredProviders}
        </CodeBlock>
      </section>

      <section id="example" className="space-y-4">
        <h2 className="text-2xl font-semibold">
          CloudWatch Metric Filter Example
        </h2>
        <p>
          Compile a CloudWatch JSON filter for a known struct/event and wire it
          into an AWS metric filter. Invalid combinations produce Terraform
          diagnostics during validate/plan.
        </p>
        <div className="grid gap-6 md:grid-cols-2">
          <CodeBlock language="hcl" title="Data Source">
            {cwFilterDataSource}
          </CodeBlock>
          <CodeBlock language="hcl" title="AWS Metric Filter">
            {cwMetricFilter}
          </CodeBlock>
        </div>
        <p className="text-neutral-600 dark:text-neutral-400">
          The compiled pattern looks like:{' '}
          <code>{`{ $.src = "mailer" && $.evt = "delivered" ... }`}</code>
          and includes canonical key names with any fixed source constraints.
        </p>
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
        <div className="grid gap-6 md:grid-cols-2">
          <CodeBlock language="hcl" title="Count Email Deliveries">
            {`data "logstruct_cloudwatch_filter" "email_delivered" {
  struct = "ActionMailer"
  event  = "delivered"
}

resource "aws_cloudwatch_log_metric_filter" "email_delivered_count" {
  name           = "Email Delivered Count"
  log_group_name = var.log_group.app
  pattern        = data.logstruct_cloudwatch_filter.email_delivered.pattern

  metric_transformation {
    name          = "app_email_delivered_count"
    namespace     = var.namespace.logs
    value         = "1"
    unit          = "Count"
  }
}`}
          </CodeBlock>

          <CodeBlock language="hcl" title="Count Successful GoodJob Runs">
            {`data "logstruct_cloudwatch_filter" "goodjob_finish" {
  struct = "GoodJob"
  event  = "finish"
}

resource "aws_cloudwatch_log_metric_filter" "goodjob_finish_count" {
  name           = "GoodJob Finish Count"
  log_group_name = var.log_group.app
  pattern        = data.logstruct_cloudwatch_filter.goodjob_finish.pattern

  metric_transformation {
    name      = "app_goodjob_finish_count"
    namespace = var.namespace.logs
    value     = "1"
    unit      = "Count"
  }
}`}
          </CodeBlock>
        </div>
        <p className="text-neutral-600 dark:text-neutral-400">
          See the provider README for more examples and details.
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
        </ul>
      </section>

      <EditPageLink path="app/docs/terraform/page.tsx" />
    </div>
  );
}
