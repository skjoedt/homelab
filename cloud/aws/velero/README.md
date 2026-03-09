# Velero AWS Infrastructure

This Terraform configuration creates the necessary AWS resources for Velero backup operations.

## Resources Created

- **S3 Metadata Bucket**: `homelab-velero-metadata` for backup metadata storage
- **S3 Backups Bucket**: `homelab-velero-data` for future data backup storage  
- **IAM User**: `velero-backup` with minimal required permissions
- **IAM Policy**: `VeleroBackupPolicy` for S3 bucket access
- **Lifecycle Policy**: Automatically cleans up old versions after 90 days

## Setup Instructions

1. **Deploy Infrastructure**:
   ```bash
   cd cloud/aws
   terraform init
   terraform plan
   terraform apply
   ```

2. **Create Access Keys**:
   - Go to AWS Console → IAM → Users → velero-backup
   - Create access key (programmatic access)
   - Note down: Access Key ID and Secret Access Key

3. **Store Credentials in AWS Secrets Manager**:
   - Go to AWS Console → Secrets Manager → Create secret
   - Choose "Other type of secret"
   - Secret name: `homelab/velero/aws-credentials`
   - Add key-value pairs:
     ```json
     {
       "AWS_ACCESS_KEY_ID": "your-access-key-id",
       "AWS_SECRET_ACCESS_KEY": "your-secret-access-key"
     }
     ```
