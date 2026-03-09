terraform {
  backend "s3" {
    bucket = "csh-terraform"
    key    = "homelab-cnpg-aws"
    region = "eu-north-1"
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

# S3 bucket for CNPG backups
resource "aws_s3_bucket" "cnpg_backups" {
  bucket = var.backups_bucket_name
}

resource "aws_s3_bucket_versioning" "cnpg_backups" {
  bucket = aws_s3_bucket.cnpg_backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

# AWS-managed KMS encryption (SSE-KMS with aws/s3 managed key)
resource "aws_s3_bucket_server_side_encryption_configuration" "cnpg_backups" {
  bucket = aws_s3_bucket.cnpg_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cnpg_backups" {
  bucket = aws_s3_bucket.cnpg_backups.id

  rule {
    id     = "cnpg_backups_lifecycle"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "cnpg_backups" {
  bucket = aws_s3_bucket.cnpg_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM user for CNPG backups
resource "aws_iam_user" "cnpg" {
  name = "cnpg-backup"
  path = "/"
}

# IAM policy for CNPG backup operations
resource "aws_iam_policy" "cnpg_backup" {
  name        = "CNPGBackupPolicy"
  description = "Policy for CloudNativePG backup operations via Barman Cloud"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:PutObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ]
        Resource = "${aws_s3_bucket.cnpg_backups.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketVersioning",
          "s3:GetBucketLocation"
        ]
        Resource = aws_s3_bucket.cnpg_backups.arn
      }
    ]
  })
}

# Attach policy to user
resource "aws_iam_user_policy_attachment" "cnpg_backup" {
  user       = aws_iam_user.cnpg.name
  policy_arn = aws_iam_policy.cnpg_backup.arn
}
