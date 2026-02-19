# Velero Backup Testing Guide

This guide provides manual testing procedures to validate Velero backup and restore functionality.

## Prerequisites

- Velero deployed and running
- kubectl access to the cluster
- (Optional) Velero CLI installed

## Test 1: Deploy Test Resources

### 1.1 Create Test Resources

```bash
cd system/configs/production/velero
kubectl apply -f tests/
```

This creates:
- `velero-test` namespace
- Test PVCs for both RBD and CephFS storage
- Test pods that write data to volumes
- An excluded PVC to test exclusion labels

### 1.2 Verify Resources

```bash
# Check namespace
kubectl get namespace velero-test

# Check PVCs are bound
kubectl get pvc -n velero-test

# Check pods are running
kubectl get pods -n velero-test

# Verify test data was written
kubectl exec -n velero-test test-rbd-pod -- cat /data/test-file.txt
kubectl exec -n velero-test test-cephfs-pod -- cat /data/test-file.txt
```

**Expected output**: Both commands should show test data with timestamps.

## Test 2: Manual Backup

### 2.1 Create Manual Backup

```bash
kubectl create -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: test-backup-$(date +%Y%m%d-%H%M%S)
  namespace: velero
spec:
  includedNamespaces:
  - velero-test
  snapshotVolumes: true
  csiSnapshotTimeout: 10m0s
  storageLocation: aws-s3
  volumeSnapshotLocations:
  - csi-snapshots
  labelSelector:
    matchExpressions:
    - key: velero.io/exclude-from-backup
      operator: NotIn
      values: ["true"]
EOF
```

### 2.2 Monitor Backup Progress

```bash
# List recent backups
kubectl get backup -n velero --sort-by=.metadata.creationTimestamp

# Check backup status (replace with your backup name)
kubectl get backup <backup-name> -n velero -o wide

# Get detailed backup information
kubectl describe backup <backup-name> -n velero
```

### 2.3 Verify Volume Snapshots

```bash
# List volume snapshots created
kubectl get volumesnapshot -n velero-test

# Check snapshot details
kubectl describe volumesnapshot <snapshot-name> -n velero-test
```

**Expected result**: 
- Backup status should be "Completed"
- 2 volume snapshots should be created (RBD and CephFS)
- Excluded PVC should NOT have a snapshot

## Test 3: Exclusion Labels

### 3.1 Verify Exclusion Works

```bash
# Check if excluded PVC has any snapshots (should be empty)
kubectl get volumesnapshot -n velero-test -l velero.io/exclude-from-backup=true

# List all snapshots to confirm only 2 exist
kubectl get volumesnapshot -n velero-test
```

**Expected result**: Only 2 snapshots should exist (for non-excluded PVCs).

## Test 4: Restore Test (Optional)

**⚠️ Warning**: This test is destructive and will delete the test namespace.

### 4.1 Delete Test Namespace

```bash
kubectl delete namespace velero-test
```

### 4.2 Wait for Complete Deletion

```bash
# Wait until namespace is fully deleted
while kubectl get namespace velero-test >/dev/null 2>&1; do
  echo "Waiting for namespace deletion..."
  sleep 10
done
echo "Namespace deleted successfully"
```

### 4.3 Create Restore

```bash
# Find your backup name
BACKUP_NAME=$(kubectl get backup -n velero --sort-by=.metadata.creationTimestamp -o name | tail -1 | cut -d/ -f2)
echo "Using backup: $BACKUP_NAME"

# Create restore
kubectl create -f - <<EOF
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: test-restore-$(date +%Y%m%d-%H%M%S)
  namespace: velero
spec:
  backupName: $BACKUP_NAME
  includedNamespaces:
  - velero-test
EOF
```

### 4.4 Monitor Restore Progress

```bash
# Check restore status
kubectl get restore -n velero --sort-by=.metadata.creationTimestamp

# Get restore details (replace with your restore name)
kubectl describe restore <restore-name> -n velero
```

### 4.5 Verify Restored Data

```bash
# Wait for pods to be ready
kubectl wait --for=condition=Ready pod/test-rbd-pod -n velero-test --timeout=300s
kubectl wait --for=condition=Ready pod/test-cephfs-pod -n velero-test --timeout=300s

# Verify restored data
kubectl exec -n velero-test test-rbd-pod -- cat /data/test-file.txt
kubectl exec -n velero-test test-cephfs-pod -- cat /data/test-file.txt
```

**Expected result**: The original test data should be present in both files.

## Test 5: Cleanup

```bash
# Remove test resources
kubectl delete namespace velero-test

# (Optional) Clean up test backups and restores
kubectl delete backup -n velero -l velero.io/backup-name
kubectl delete restore -n velero -l velero.io/restore-name
```

## Validation Checklist

- [ ] Test resources deploy successfully
- [ ] PVCs bind to correct storage classes (ceph-rbd, cephfs)
- [ ] Test pods write data to volumes
- [ ] Manual backup completes successfully
- [ ] Volume snapshots are created for non-excluded PVCs
- [ ] Excluded PVC is not backed up (exclusion labels work)
- [ ] Restore process completes successfully (if tested)
- [ ] Restored data matches original test data

## Troubleshooting

### Common Issues

**Backup Stuck in InProgress**
```bash
# Check Velero logs
kubectl logs -n velero deployment/velero

# Check CSI driver status
kubectl get pods -n ceph-csi-rbd
kubectl get pods -n ceph-csi-cephfs
```

**Volume Snapshots Not Created**
```bash
# Verify VolumeSnapshotClass labels
kubectl get volumesnapshotclass -o yaml | grep "velero.io/csi-volumesnapshot-class"

# Check if snapshotter secrets exist
kubectl get secret -n ceph-csi-rbd csi-rbd-secret
kubectl get secret -n ceph-csi-cephfs csi-cephfs-secret
```

**AWS S3 Connection Issues**
```bash
# Check AWS credentials secret
kubectl get secret -n velero velero-aws-credentials -o yaml

# Verify External Secrets status
kubectl get externalsecret -n velero
kubectl describe externalsecret velero-aws-credentials -n velero
```

### Debug Commands

```bash
# Velero server status
kubectl get pods -n velero
kubectl logs -n velero deployment/velero

# Backup storage location
kubectl get backupstoragelocation -n velero -o yaml

# Volume snapshot location  
kubectl get volumesnapshotlocation -n velero -o yaml

# All Velero resources
kubectl get all -n velero
```

## Expected Results Summary

- ✅ **Backups complete successfully** with "Completed" status
- ✅ **CSI snapshots are created** for supported storage classes
- ✅ **Exclusion labels work** - excluded resources not backed up
- ✅ **Restores work correctly** - data is preserved and accessible
- ✅ **Scheduled backups run** according to GFS retention policy

This testing validates that Velero is properly integrated with your Ceph storage infrastructure and ready for production use.