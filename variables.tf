variable "event_rules" {
  type        = list(any)
  description = "Details of event rules."
}

variable "workspace_ids"{
  type        = string
  description = "account for lambda function env"
}

variable "region"{
  type        = string
  description = "region for ps script"
}