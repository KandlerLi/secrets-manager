# Non-secret deployment configuration. The only variable here is
# required (no default in variables.tf) -- explicitly listed as an
# exception to this repo's own blanket *.tfvars gitignore rule (see
# .gitignore), since it holds no secret value itself.
aws_region = "eu-central-1"
