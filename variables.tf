variable "event_rules" {
  type        = list(any)
  description = "(Required) Details of event rules."
}

variable "workspace_ids"{
  type        = string
  description = "(Required) account for lambda function env"
}

variable "region"{
  type        = string
  description = "(Required) region for ps script"
}