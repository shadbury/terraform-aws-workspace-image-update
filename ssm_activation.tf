resource "aws_ssm_activation" "activation" {
  name               = "workspaces_ssm_activation"
  description        = "SSM activation for workspace bundles"
  iam_role           = aws_iam_role.activation_role.id
  registration_limit = "5"
  depends_on         = [aws_iam_role_policy_attachment.activation_attach]

  tags = {
    Bundle_Image = "True" 
  }
}