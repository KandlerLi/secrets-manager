variable "aws_region" {
  description = "AWS region the secret containers live in (matches KandlerLi/terraform-state's own var.aws_region -- these secrets were created there originally)"
  type        = string
}
