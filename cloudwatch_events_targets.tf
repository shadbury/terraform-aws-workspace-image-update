resource "aws_cloudwatch_event_target" "targets" {
    count       = length(aws_cloudwatch_event_rule.event_rules)
    target_id = "target"
    role_arn  = aws_iam_role.workspaces_patch_role.arn
    arn       = aws_sfn_state_machine.updates_state_machine.arn
    rule      = aws_cloudwatch_event_rule.event_rules[count.index].name

    input = <<JSON
        {
            "workspace_ids" : ${var.workspace_ids}
        }
        JSON
}