resource "aws_sfn_state_machine" "updates_state_machine" {
  name     = "workspaces_bundles_state_machine"
  role_arn = aws_iam_role.workspaces_patch_role.arn
  type     = "STANDARD"

  definition = <<EOF
{
  "Comment": "State machine to update workspace golden images.",
  "StartAt": "Start",
  "States": {
    "Start": {
      "Type": "Task",
      "ResultPath": "$.Results",
      "Resource": "${aws_lambda_function.updates_function.arn}",
      "Next": "StatusCheck"
    },
    "StatusCheck": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.Results.Pending",
          "IsPresent": true,
          "Next": "wait"
        },
        {
          "Variable": "$.Results",
          "NumericEquals": 0,
          "Next": "Succeed"
        }
      ],
      "Default": "Failed"
    },
    "wait": {
      "Type": "Wait",
      "Seconds": 300,
      "Next": "StatusCheckTask"
    },
    "StatusCheckTask": {
      "Type": "Task",
      "ResultPath": "$.Results",
      "Resource": "${aws_lambda_function.updates_function.arn}",
      "Next": "CountCheck"
    },
    "CountCheck": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.Results.CycleCount",
          "IsPresent": false,
          "Next": "StatusCheck"
        },
        {
          "Variable": "$.Results.CycleCount",
          "NumericGreaterThan": 10,
          "Next": "Failed"
        }
      ],
      "Default": "StatusCheck"
    },
    "Succeed": {
      "Type": "Succeed"
    },
    "Failed": {
      "Type": "Fail"
    }
  }
}
EOF
}