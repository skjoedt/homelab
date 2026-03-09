## Setup Instructions

1. **Deploy Infrastructure**:
   ```bash
   cd cloud/aws/cnpg
   terraform init
   terraform plan
   terraform apply
   ```

2. **Create Access Keys**:
   - Go to AWS Console → IAM → Users → cnpg-backup
   - Create access key (programmatic access)
   - Note down: Access Key ID and Secret Access Key

3. **Store Credentials in AWS Secrets Manager**:
   - Go to AWS Console → Secrets Manager → Create secret
   - Choose "Other type of secret"
   - Secret name: `homelab/cnpg/aws-credentials`
   - Add key-value pairs:
     ```json
{
"AWS_ACCESS_KEY_ID": "your-access-key-id",
"AWS_SECRET_ACCESS_KEY": "your-secret-access-key"
}
     ```
