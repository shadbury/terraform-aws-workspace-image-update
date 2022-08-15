resource "aws_resourcegroups_group" "workspaces" {
    name = "Workspace-Bundle-Updates"

  resource_query {
    query = <<JSON
{
  "ResourceTypeFilters": [
    "AWS::SSM::ManagedInstance"
  ],
  "TagFilters": [
    {
      "Key": "Bundle_Image",
      "Values": ["True"]
    }
  ]
}
JSON
  }
}