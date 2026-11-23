resource "aws_kms_key" "vault_unseal" {
  description             = "Vault Auto-Unseal Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name    = "Homelab Vault unseal key"
    Purpose = "Vault Auto-Unseal"
  }
}

resource "aws_kms_alias" "vault_unseal" {
  name          = "alias/homelab-vault-unseal"
  target_key_id = aws_kms_key.vault_unseal.key_id
}

data "aws_iam_policy_document" "vault_kms" {
  statement {
    sid    = "VaultAutoUnseal"
    effect = "Allow"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey",
    ]

    resources = [
      aws_kms_key.vault_unseal.arn
    ]
  }
}

resource "aws_iam_policy" "vault_kms" {
  name        = "homelab-vault-kms-unseal-policy"
  description = "Allows Vault to use KMS for auto-unseal"
  policy      = data.aws_iam_policy_document.vault_kms.json
}

resource "aws_iam_user" "vault" {
  name = "homelab-vault-kms-user"
}

resource "aws_iam_user_policy_attachment" "vault" {
  user       = aws_iam_user.vault.name
  policy_arn = aws_iam_policy.vault_kms.arn
}

resource "aws_iam_access_key" "vault" {
  user = aws_iam_user.vault.name
}
