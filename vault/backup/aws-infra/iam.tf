resource "aws_iam_role" "vault_backup" {
  name = "vault-backup-role"

  max_session_duration = 36000
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
    Purpose   = "Short-lived credentials for vault backups"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy" "vault_backup" {
  name = "VaultBackupS3Access"
  role = aws_iam_role.vault_backup.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.vault_backups.arn
        ]
      },
      {
        Sid    = "WriteObjects"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:AbortMultipartUpload"
        ]
        Resource = [
          "${aws_s3_bucket.vault_backups.arn}/vault/*"
        ]
      },
      {
        Sid    = "ReadObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "${aws_s3_bucket.vault_backups.arn}/vault/*"
        ]
      }
    ]
  })
}
