resource "aws_iam_role" "db_backup" {
  name = "db-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:user/${var.vault_user_name}"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Purpose   = "Short-lived credentials for db backups via Vault"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy" "db_backup" {
  name = "DbBackupS3Access"
  role = aws_iam_role.db_backup.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DatabaseBackupBucketLevel"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
        ]
        Resource = [aws_s3_bucket.db_backups.arn]
      },
      {
        Sid    = "DatabaseBackupObjects"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts",
        ]
        Resource = ["${aws_s3_bucket.db_backups.arn}/cnpg/*"]
      },
    ]
  })
}
