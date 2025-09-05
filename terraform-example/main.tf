terraform {
  required_version = ">= 1.3.0"
  required_providers {
    logstruct = {
      source  = "DocSpring/logstruct"
      version = ">= 0.0.4"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Validate allowed events for a canonical source
data "logstruct_source" "mailer" {
  source = "mailer"
}

variable "event" {
  type = string
  default = "delivered"
  validation {
    condition     = contains(keys(data.logstruct_source.mailer.events), var.event)
    error_message = "Invalid event for source=mailer"
  }
}

# Compile exact CloudWatch pattern (optional; module also compiles internally)
data "logstruct_pattern" "email" {
  source = "mailer"
  event  = var.event
}

# Example module usage: metric filter
module "email_delivered_metric" {
  # Use local relative path for CI/demo; switch to Registry in real usage:
  # source = "DocSpring/logstruct/aws//modules/metric-filter"
  source         = "../terraform-aws-logstruct/modules/metric-filter"

  name           = "Email Delivered Count"
  log_group_name = var.log_group_name
  log_source     = "mailer"
  log_event      = var.event
  namespace      = var.namespace
}

variable "log_group_name" { type = string }
variable "namespace" { type = string }

output "compiled_pattern" {
  value = data.logstruct_pattern.email.pattern
}
