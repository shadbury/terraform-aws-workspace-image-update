resource "aws_iam_role" "workspaces_patch_role" {
  name = "AWS-Workspaces-AutomationExecutionRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "events.amazonaws.com",
          "states.amazonaws.com",
          "lambda.amazonaws.com",
          "ssm.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${local.account_id}:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
  EOF
}


resource "aws_iam_role_policy" "patch_policy" {
  name = "${aws_iam_role.workspaces_patch_role.name}-account-access"
  role = aws_iam_role.workspaces_patch_role.name

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "lambda:InvokeFunction",
            "Resource": [
                "arn:aws:lambda:ap-southeast-2:${local.account_id}:function:workspace_bundle_updates*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "tag:getResources",
                "tag:getTagKeys",
                "tag:getTagValues",
                "tag:TagResources",
                "tag:UntagResources",
                "resource-groups:*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "workspaces:DescribeWorkspaceImages",
                "workspaces:DescribeWorkspaceBundles",
                "workspaces:DescribeWorkspaces",
                "workspaces:UpdateWorkspaceBundle",
                "workspaces:CreateUpdatedWorkspaceImage",
                "workspaces:DescribeWorkspaceSnapshots",
                "workspaces:CreateWorkspaceBundle",
                "workspaces:StartWorkspaces",
                "workspaces:CreateWorkspaceImage"
            ],
            "Resource": "arn:aws:workspaces:ap-southeast-2:${local.account_id}:*/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:ListCommands",
                "ssm:DescribeInstanceInformation",
                "ssm:ListCommandInvocations",
                "ssm:SendCommand",
                "ssm:GetAutomationExecution",
                "ssm:GetParameters",
                "ssm:DescribeAutomationStepExecutions",
                "ssm:StartAutomationExecution",
                "ssm:UpdateInstanceInformation"
            ],
            "Resource": [
                "arn:aws:ssm:ap-southeast-2:${local.account_id}:*",
                "arn:aws:ssm:ap-southeast-2::document/AWS-InstallWindowsUpdates"
            ]
        },
        {
            "Effect": "Allow",
            "Action": "logs:*",
            "Resource": "arn:aws:logs:ap-southeast-2:${local.account_id}:log-group:/aws/lambda/workspace_bundle_updates:*"
        }
    ]
}
EOF
}


resource "aws_iam_role" "activation_role" {
  name = "activation_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "events.amazonaws.com",
          "states.amazonaws.com",
          "lambda.amazonaws.com",
          "ssm.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${local.account_id}:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "activation_attach" {
  role       = aws_iam_role.activation_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}