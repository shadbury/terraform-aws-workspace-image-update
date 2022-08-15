# workspaces-bundles-update

This module uses the following resources.

- iam
- cloudwatch events
- resource groups
- lambda
- ssm activation
- ssm parameter store
- state machine

# Functionality
The State machine is configured to remember the following values

- Pending - the initial state, a workspace will be pending until it is started and available
- Waiting - a workspace will be in a waiting state until the update runcommand is complete
- Success - a workspace will be in a success state when the update is complete, from here an image will be created as well as the bundle updates
- CycleCount - keep count of retries, if this gets to 3 the step function will fail
- Started - keeps a list of started workspaces before moving them to waiting
- RunCommand - keeps the run command id to check the status of the command.

## Steps
The state machine uses the following steps:
- Start - initial startup of the step function, this phase will start all workspaces in the update list.
- StatusCheck - checks to see if the step function should continue. If lambda returns 0, the next step is 'Succeed'. If lambda returns results, the nest step is wait.
- Wait - this step will stop the step function from running for 5 minutes, this allows the workspaces to process the last request from the lambda function.
- StatusCheckTask - This will trigger the lambda function to run and will provide the latest results for the lambda function to use.
- CountCheck - this will check the retry count, if the count excceed 10 then the function fails. The count is only used while there are workspaces in pending.

### State Machine.
![Shadbury Step Function](https://github.com/shadbury/terraform-aws-workspace-image-update/blob/v1.0.0/images/step_function.png)

# How to deploy

after deploying with terraform, a script will be created in the ssm parameter store. To run this script follow the below steps:

Go to ssm parameter store and open /workspaces/activation_script

Copy the contents and log into the golden image workspace.

Open Powershell as an administrator, paste the code and enter


# Amazon Workspaces Using AWS Systems Manager

## Details

This solution uses SSM Hybrid activation to registed workspaces in ssm inventory.
This allows run commands to be triggered and used on AWS WOrkspaces.

Each workspaces that requires updates to be installed through SSM run command will need the poweshell script ran on the workspace.

## script example

```
$code = "RbKh5ztAhrrAvz3Nyryx"
$id = "65758268-a3d7-4b7b-99ab-94d7dc72699b"
$region = "ap-southeast-2"
$dir = $env:TEMP + "\ssm"
New-Item -ItemType directory -Path $dir -Force
cd $dir
(New-Object System.Net.WebClient).DownloadFile("https://amazon-ssm-$region.s3.amazonaws.com/latest/windows_amd64/AmazonSSMAgentSetup.exe", $dir + "\AmazonSSMAgentSetup.exe")
Start-Process .\AmazonSSMAgentSetup.exe -ArgumentList @("/q", "/log", "install.log", "CODE=$code", "ID=$id", "REGION=$region") -Wait
Get-Content ($env:ProgramData + "\Amazon\SSM\InstanceData\registration")
Get-Service -Name "AmazonSSMAgent"
```


## Prerequisites
Before you begin, you must have the following:

An AWS account to create or administer a WorkSpace.
The ability to download and access Amazon WorkSpaces from Windows, macOS, or Linux (Ubuntu) computers, Chromebooks, iPads, Fire tablets, Android tablets, and the Chrome and Firefox web browsers.


![Shadbury Systems Manager](https://github.com/shadbury/terraform-aws-workspace-image-update/blob/v1.0.0/images/systems_manager.png)


## Note

You only have a short time to run this command as the access key and code will expire.

# Resource Groups

A resource group will be created, this resource group looks for tags 'Bundle_Image:True'
The instances in this group will be sent a run command to install the latest windows updates

# Variables 

variable "event_rules" {
  type        = list(any)
  description = "(Required) Details of event rules."
}

variable "account_id"{
  type        = string
  description = "(Required) account for lambda function env"
}

variable "workspace_ids"{
  type        = string
  description = "(Required) golden image workspace id's"
}

variable "region"{
  type        = string
  description = "(Required) region for ps script"
}

# locals example

```
locals {
  client = "test-client"

  env = {
    prod = {
      aws_profile = "test-client"
      region      = "ap-southeast-2"
      account_id = "123456789"
      lambda_function_name = "patch_workspaces_bundle"
      workspace_ids = "[\"ws-111111111\", \"ws-222222222\", \"ws-333333333\"]"
      event_rules = [
          {
            name  = "patch_workspaces_bundle"
            cron  = "cron(0 16 25 * ? *)"
          }
        ]
    }
  }

  workspace = local.env[terraform.workspace]
}
```

# module example

```
module "patching" {
  source        = "shadbury/workspace-image-update/aws"
  version       = 1.0.0.0
  event_rules   = local.workspace.event_rules
  workspace_ids = local.workspace["workspace_ids"]
  region        = local.workspace["region"]
}
```