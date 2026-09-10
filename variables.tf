variable "aws_region" {
  description = "AWS region the secret containers live in (matches bootstrap/terraform-state's own var.aws_region -- these secrets were created there originally)"
  type        = string
  default     = "eu-central-1"
}
