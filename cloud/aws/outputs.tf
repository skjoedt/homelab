output "metadata_bucket_name" {
  description = "Name of the S3 bucket for Velero metadata"
  value       = aws_s3_bucket.velero_metadata.bucket
}

output "metadata_bucket_arn" {
  description = "ARN of the S3 bucket for Velero metadata"
  value       = aws_s3_bucket.velero_metadata.arn
}

output "backups_bucket_name" {
  description = "Name of the S3 bucket for Velero data backups"
  value       = aws_s3_bucket.velero_backups.bucket
}

output "backups_bucket_arn" {
  description = "ARN of the S3 bucket for Velero data backups"
  value       = aws_s3_bucket.velero_backups.arn
}

output "iam_user_name" {
  description = "Name of the IAM user for Velero"
  value       = aws_iam_user.velero.name
}

output "iam_user_arn" {
  description = "ARN of the IAM user for Velero"
  value       = aws_iam_user.velero.arn
}

output "iam_policy_arn" {
  description = "ARN of the IAM policy for Velero"
  value       = aws_iam_policy.velero_backup.arn
}