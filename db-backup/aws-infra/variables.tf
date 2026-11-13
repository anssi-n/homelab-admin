variable "aws_region" {
  type        = string
  description = "Target AWS Region"
  default     = "eu-north-1"
}

variable "aws_account_id" {
  description = "AWS Account ID (set via TF_VAR_AWS_ACCOUNT_ID"
  type        = string
}

variable "bucket_prefix" {
  description = "Prefix for the S3 bucket name (will be made unique)"
  type        = string
  default     = "homelab-db-backup"
}

variable "retention_days" {
  description = "How many days to keep current versions of backups"
  type        = number
  default     = 14
}

variable "noncurrent_retention_days" {
  description = "How many days to keep non-current versions"
  type        = number
  default     = 7
}

variable "vault_user_name" {
  description = "Name of the IAM user that Vault uses to assume roles"
  type        = string
  default     = "vault-control-plane"
}
