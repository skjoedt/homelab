# Velero Deployment Guide

This guide provides step-by-step instructions for deploying Velero backup solution with Ceph CSI snapshot support.

## Prerequisites

- Kubernetes cluster with Ceph storage
- Existing Ceph CSI RBD and CephFS drivers
- External Secrets Operator configured with AWS Secrets Manager
- kubectl and helm CLI tools

## Deployment Steps

### 1. Deploy AWS Infrastructure

```bash
cd cloud/aws
terraform init
terraform plan
terraform apply
```

**Expected Output:**
- S3 metadata bucket: `homelab-velero-metadata`
- S3 backups bucket: `homelab-velero-data` (for future data backups)
- IAM user: `velero-backup`
- IAM policy with minimal S3 permissions

### 2. Create AWS Access Keys

1. Go to AWS Console → IAM → Users → `velero-backup`
2. Create access key (Application running outside AWS)
3. Save the Access Key ID and Secret Access Key

### 3. Store Credentials in AWS Secrets Manager

1. Go to AWS Console → Secrets Manager → Create secret
2. Choose "Other type of secret"
3. **Secret name**: `homelab/velero/aws-credentials`
4. **Key-value pairs**:
   ```json
   {
     "AWS_ACCESS_KEY_ID": "AKIA...",
     "AWS_SECRET_ACCESS_KEY": "your-secret-key"
   }
   ```

### 4. Deploy Volume Snapshot Classes

```bash
kubectl apply -k system/configs/production/ceph/
```

**Verify:**
```bash
kubectl get volumesnapshotclass
# Should show: ceph-rbd and cephfs
```

### 5. Deploy Velero Configuration

```bash
kubectl apply -k system/configs/production/velero/
```

**Verify External Secret:**
```bash
kubectl get externalsecret -n velero
kubectl get secret -n velero velero-aws-credentials
```

### 6. Install Velero Helm Chart

```bash
cd system/controllers/velero
helm dependency update
helm install velero . -n velero
```

**Verify Installation:**
```bash
kubectl get pods -n velero
kubectl get backupstoragelocation -n velero
kubectl get volumesnapshotlocation -n velero
```

### 7. Verify Backup Schedules

```bash
kubectl get schedule -n velero
```

**Expected schedules:**
- `daily-backup`: Daily at 2 AM (7d retention)
- `weekly-backup`: Sunday at 3 AM (4w retention)  
- `monthly-backup`: 1st of month at 4 AM (3m retention)

### 8. Run Validation Tests

```bash
cd system/configs/production/velero
./test-velero-backup.sh
```

## Post-Deployment Verification

### Check Velero Status

```bash
# Velero server status
kubectl logs -n velero deployment/velero

# Backup storage location
kubectl describe backupstoragelocation aws-s3 -n velero

# Volume snapshot location
kubectl describe volumesnapshotlocation csi-snapshots -n velero
```

### Manual Backup Test

```bash
# Create test backup
kubectl create -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: test-backup
  namespace: velero
spec:
  includedNamespaces: ["*"]
  snapshotVolumes: true
  csiSnapshotTimeout: 10m0s
  storageLocation: aws-s3
  volumeSnapshotLocations:
  - csi-snapshots
EOF

# Check backup status
kubectl get backup test-backup -n velero
kubectl describe backup test-backup -n velero
```

### Verify CSI Snapshots

```bash
# List volume snapshots created by Velero
kubectl get volumesnapshot -A

# Check snapshot details
kubectl describe volumesnapshot <snapshot-name> -n <namespace>
```

## Troubleshooting

### Common Issues

**1. AWS Credentials Error**
```bash
# Check secret exists
kubectl get secret velero-aws-credentials -n velero -o yaml

# Verify External Secrets
kubectl describe externalsecret velero-aws-credentials -n velero
```

**2. CSI Snapshot Timeout**
```bash
# Check CSI driver pods
kubectl get pods -n ceph-csi-rbd
kubectl get pods -n ceph-csi-cephfs

# Check VolumeSnapshotClass labels
kubectl get volumesnapshotclass -o yaml | grep velero.io/csi-volumesnapshot-class
```

**3. Backup Fails**
```bash
# Check Velero logs
kubectl logs -n velero deployment/velero

# Check backup details
kubectl describe backup <backup-name> -n velero
```

### Debug Commands

```bash
# Velero server info
kubectl exec -n velero deployment/velero -- velero version

# Plugin status
kubectl exec -n velero deployment/velero -- velero plugin get

# Storage location validation
kubectl exec -n velero deployment/velero -- velero backup-location get
```

## Monitoring and Maintenance

### Regular Checks

1. **Weekly**: Verify backups are running successfully
   ```bash
   kubectl get backup -n velero --sort-by=.metadata.creationTimestamp
   ```

2. **Monthly**: Check storage usage in S3 buckets
   ```bash
   aws s3 ls s3://homelab-velero-metadata --recursive --human-readable --summarize
   aws s3 ls s3://homelab-velero-data --recursive --human-readable --summarize
   ```

3. **Quarterly**: Test restore functionality with non-production workloads

### Backup Status Monitoring

```bash
# Get recent backups
kubectl get backup -n velero --sort-by=.metadata.creationTimestamp -o wide

# Check for failed backups
kubectl get backup -n velero -o json | jq '.items[] | select(.status.phase == "Failed") | .metadata.name'

# Backup size and duration
kubectl get backup -n velero -o custom-columns=NAME:.metadata.name,PHASE:.status.phase,CREATED:.metadata.creationTimestamp,SIZE:.status.progress.totalItems
```

## Configuration Updates

### Adding New Applications

When deploying new applications, ensure they use supported storage classes:
- `ceph-rbd` for block storage
- `cephfs` for shared filesystem storage

### Excluding Applications from Backup

Add the exclusion label to PVCs or namespaces:
```yaml
metadata:
  labels:
    velero.io/exclude-from-backup: "true"
```

### Custom Retention Policies

Override default retention using annotations:
```yaml
metadata:
  annotations:
    velero.io/backup-ttl: "720h0m0s"  # 30 days
```

## Next Steps

1. **Monitor backup success rates** for the first few weeks
2. **Plan restore testing** for critical applications  
3. **Consider S3 data backup migration** in follow-up PR
4. **Implement automated restore testing** for disaster recovery validation

The Velero backup solution is now ready to protect your Kubernetes workloads with automated CSI snapshots and configurable retention policies.