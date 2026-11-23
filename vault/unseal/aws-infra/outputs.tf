output "kms_key_id" {
  value = aws_kms_key.vault_unseal.key_id
}

output "kms_key_arn" {
  value = aws_kms_key.vault_unseal.arn
}

output "kms_alias" {
  value = aws_kms_alias.vault_unseal.name
}

output "access_key_id" {
  value     = aws_iam_access_key.vault.id
  sensitive = true
}

output "secret_access_key" {
  value     = aws_iam_access_key.vault.secret
  sensitive = true
}
