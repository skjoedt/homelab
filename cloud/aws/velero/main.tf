terraform {
  backend "s3" {
    bucket = "csh-terraform"
    key    = "homelab-velero-aws"
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

# S3 bucket for Velero metadata
resource "aws_s3_bucket" "velero_metadata" {
  bucket = var.metadata_bucket_name
}

resource "aws_s3_bucket_versioning" "velero_metadata" {
  bucket = aws_s3_bucket.velero_metadata.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "velero_metadata" {
  bucket = aws_s3_bucket.velero_metadata.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "velero_metadata" {
  bucket = aws_s3_bucket.velero_metadata.id

  rule {
    id     = "velero_metadata_lifecycle"
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

# S3 bucket for Velero data backups
resource "aws_s3_bucket" "velero_backups" {
  bucket = var.backups_bucket_name
}

resource "aws_s3_bucket_versioning" "velero_backups" {
  bucket = aws_s3_bucket.velero_backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "velero_backups" {
  bucket = aws_s3_bucket.velero_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "velero_backups" {
  bucket = aws_s3_bucket.velero_backups.id

  rule {
    id     = "velero_backups_lifecycle"
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

# IAM user for Velero
resource "aws_iam_user" "velero" {
  name = "velero-backup"
  path = "/"
}

# IAM policy for Velero
resource "aws_iam_policy" "velero_backup" {
  name        = "VeleroBackupPolicy"
  description = "Policy for Velero backup operations"

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
        Resource = [
          "${aws_s3_bucket.velero_metadata.arn}/*",
          "${aws_s3_bucket.velero_backups.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketVersioning",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.velero_metadata.arn,
          aws_s3_bucket.velero_backups.arn
        ]
      },
      # Future-proofing for S3 data backups
      {
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets",
          "s3:GetBucketLocation"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "s3:prefix" = ["backups/"]
          }
        }
      }
    ]
  })
}

# Attach policy to user
resource "aws_iam_user_policy_attachment" "velero_backup" {
  user       = aws_iam_user.velero.name
  policy_arn = aws_iam_policy.velero_backup.arn
}