variable "event_rules" {
  type        = list(any)
  description = "Details of event rules."
  presence = required
}

variable "workspace_ids"{
  type        = string
  description = "account for lambda function env"
  presence = required
}

variable "region"{
  type        = string
  description = "region for ps script"
  presence = required
}