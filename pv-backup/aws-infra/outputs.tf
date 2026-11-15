output "bucket_name" {
  value = aws_s3_bucket.backup.id
}

output "bucket_arn" {
  value = aws_s3_bucket.backup.arn
}

output "region" {
  value = var.region
}

output "backup_target_url" {
  description = "Value for BackupTarget.spec.backupTargetURL (trailing slash required)."
  value       = "s3://${aws_s3_bucket.backup.id}@${var.region}/${local.target_path}/"
}

output "iam_user_name" {
  value = aws_iam_user.longhorn_backup.name
}

output "access_key_id" {
  value = aws_iam_access_key.longhorn_backup.id
}

output "secret_access_key" {
  value     = aws_iam_access_key.longhorn_backup.secret
  sensitive = true
}

output "store_in_vault" {
  description = "Command to seed Vault KV (adjust the mount/path to match your setup)."
  value       = "vault kv put secret/longhorn/backup-target AWS_ACCESS_KEY_ID=${aws_iam_access_key.longhorn_backup.id} AWS_SECRET_ACCESS_KEY=${aws_iam_access_key.longhorn_backup.secret}"
  sensitive   = true
}
