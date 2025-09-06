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

variable "event" {
  type        = string
  default     = "delivered"
  description = "LogStruct event for source=mailer (e.g., delivered)"
}

# Compile exact CloudWatch pattern (optional; module also compiles internally)
data "logstruct_pattern" "email" {
  source = "mailer"
  event  = var.event
}

# Example module usage: metric filter (Registry)
module "email_delivered_metric" {
  source  = "DocSpring/logstruct/aws//modules/metric-filter"
  version = ">= 0.0.4"

  name           = "Email Delivered Count"
  log_group_name = var.log_group_name
  log_source     = "mailer"
  log_event      = var.event
  namespace      = var.namespace
}

variable "log_group_name" {
  type        = string
  description = "CloudWatch Logs group name"
}

variable "namespace" {
  type        = string
  description = "CloudWatch Metrics namespace"
}

output "compiled_pattern" {
  value       = data.logstruct_pattern.email.pattern
  description = "Compiled CloudWatch filter pattern from source+event"
}
