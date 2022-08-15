resource "aws_ssm_parameter" "activation_code" {
  name        = "/workspaces/activation_code"
  description = "activation code for ssm"
  type        = "SecureString"
  value       = aws_ssm_activation.activation.activation_code
}

resource "aws_ssm_parameter" "activation_id" {
  name        = "/workspaces/activation_id"
  description = "activation code for ssm"
  type        = "SecureString"
  value       = aws_ssm_activation.activation.id
}

resource "aws_ssm_parameter" "activation_script" {
  name        = "/workspaces/activation_script"
  description = "activation code for ssm"
  type        = "SecureString"
  value       = <<EOF
$code = "${aws_ssm_activation.activation.activation_code}"
$id = "${aws_ssm_activation.activation.id}"
$region = "${var.region}"
$dir = $env:TEMP + "\ssm"
New-Item -ItemType directory -Path $dir -Force
cd $dir
(New-Object System.Net.WebClient).DownloadFile("https://amazon-ssm-$region.s3.amazonaws.com/latest/windows_amd64/AmazonSSMAgentSetup.exe", $dir + "\AmazonSSMAgentSetup.exe")
Start-Process .\AmazonSSMAgentSetup.exe -ArgumentList @("/q", "/log", "install.log", "CODE=$code", "ID=$id", "REGION=$region") -Wait
Get-Content ($env:ProgramData + "\Amazon\SSM\InstanceData\registration")
Get-Service -Name "AmazonSSMAgent"
EOF
}