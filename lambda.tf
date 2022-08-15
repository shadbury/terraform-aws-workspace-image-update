data "archive_file" "zipit" {
  type        = "zip"
  source_file = "${path.module}/run_updates/run_updates.py"
  output_path = "run_updates.zip"
}


resource "aws_lambda_function" "updates_function" {
  
  function_name = "workspace_bundle_updates"
  role          = aws_iam_role.workspaces_patch_role.arn
  handler       = "run_updates.lambda_handler"
  runtime       = "python3.9"
  filename      = "run_updates.zip"
  layers = [aws_lambda_layer_version.lambda_layer.arn]
  source_code_hash = data.archive_file.zipit.output_base64sha256
  timeout = 300
  environment {
    variables = {
      role_arn = aws_iam_role.activation_role.arn
    }
  }
}

resource "aws_lambda_layer_version" "lambda_layer" {
  filename   = "./modules/run_updates/lambda-layer.zip"
  layer_name = "boto3"

  compatible_runtimes = ["python3.9"]
}
