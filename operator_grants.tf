# IAM grants for the secret containers this root owns. The IAM *users*
# (julian, k3s-bootstrap-local) stay owned by bootstrap/terraform-state --
# only the policies and attachments granting them access to the migrated
# secrets live here, so that the grant list stays next to the resources it
# grants access to (and shrinks/grows in lockstep with them during the
# migration campaign).
#
# This root is applied only as root / an admin-equivalent identity, never
# as julian -- same self-escalation guarantee as
# bootstrap/terraform-state/operator.tf's own header: this root grants
# julian its Secrets Manager access, so julian applying it could widen its
# own permissions. julian's operator policy is scoped to repo-infra/* state
# and cannot touch secrets-manager/terraform.tfstate.

data "aws_caller_identity" "current" {}

# julian's read/write access to every secret container migrated into this
# root -- replaces the ManageSecretsManagerSecrets statement that lived in
# bootstrap/terraform-state/operator.tf's terraform-operator policy. Real
# resource references, not hand-built ARN strings, so the list can never
# drift from what this root actually owns. Grows one Resource entry per
# migrated secret; the corresponding ARN is removed from
# bootstrap/terraform-state/operator.tf in the same change.
resource "aws_iam_policy" "julian_secrets_manager_operator" {
  name = "secrets-manager-operator"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ManageMigratedSecretsManagerSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:PutSecretValue",
        ]
        Resource = [
          aws_secretsmanager_secret.k3s_apps_sankey_export.arn,
        ]
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "julian_secrets_manager_operator" {
  user       = "julian"
  policy_arn = aws_iam_policy.julian_secrets_manager_operator.arn
}
