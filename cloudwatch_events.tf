resource "aws_cloudwatch_event_rule" "event_rules" {
  count       = length(var.event_rules)
  name        = var.event_rules[count.index].name
  description = "Rule for patching ${var.event_rules[count.index].name}"
  schedule_expression = var.event_rules[count.index].cron
}