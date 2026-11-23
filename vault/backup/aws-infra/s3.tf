resource "random_id" "bucket_suffix" {
  byte_length = 8
}

locals {
  bucket_name = "${var.bucket_prefix}-${random_id.bucket_suffix.hex}"
}

resource "aws_s3_bucket" "vault_backups" {
  bucket = local.bucket_name

  tags = {
    Name      = "vault-backups"
    Purpose   = "Homelab Hashicorp Vault backups"
    ManagedBy = "terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "vault_backups" {
  bucket = aws_s3_bucket.vault_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "vault_backups" {
  bucket = aws_s3_bucket.vault_backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "vault_backups" {
  bucket = aws_s3_bucket.vault_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "vault_backups" {
  bucket = aws_s3_bucket.vault_backups.id

  rule {
    id     = "vault-backup-retention"
    status = "Enabled"

    filter {
      prefix = "vault/"
    }

    expiration {
      days = var.retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}
