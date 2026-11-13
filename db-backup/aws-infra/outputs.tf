output "s3_bucket_name" {
  description = "Name of the S3 bucket for db backups"
  value       = aws_s3_bucket.db_backups.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.db_backups.arn
}

output "db_backup_role_arn" {
  description = "IAM Role ARN that Vault should use (credential_type = assumed_role)"
  value       = aws_iam_role.db_backup.arn
}

output "aws_region" {
  value = var.aws_region
}

output "aws_account_id" {
  value = var.aws_account_id
}
