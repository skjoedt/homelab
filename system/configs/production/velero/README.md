# Velero Backup Configuration

This directory contains Velero backup configuration with CSI snapshot support for Ceph storage.

## Backup Strategy

### GFS (Grandfather-Father-Son) Retention Policy

- **Daily backups**: 7-day retention (Son) - runs at 2 AM
- **Weekly backups**: 4-week retention (Father) - runs Sunday 3 AM  
- **Monthly backups**: 3-month retention (Grandfather) - runs 1st of month 4 AM

### Storage Locations

- **Backup metadata**: AWS S3 (`homelab-velero-metadata`)
- **Volume snapshots**: Ceph CSI snapshots (local storage)
- **Data backups**: AWS S3 (`homelab-velero-data`) - not yet implemented

## Exclusion Labels

### PVC Exclusion

To exclude specific PVCs from backup, add this label:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: temp-cache
  labels:
    velero.io/exclude-from-backup: "true"
spec:
  # ... rest of PVC spec
```

### Namespace Exclusion

To exclude entire namespaces from backup, add this label:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: development
  labels:
    velero.io/exclude-from-backup: "true"
```

### Default Exclusions

These namespaces are excluded by default:
- `velero` - Velero system namespace
- `kube-system` - Kubernetes system components
- `kube-public` - Kubernetes public namespace
- `kube-node-lease` - Node heartbeat data

See the schedules yaml files.

## Supported Storage Classes

The backup system supports both Ceph storage classes:

- **ceph-rbd**: Block storage with RBD CSI snapshots
- **cephfs**: Shared filesystem with CephFS CSI snapshots

## Manual Backup

To create a manual backup:

```bash
velero backup create manual-backup-$(date +%Y%m%d-%H%M%S) \
  --snapshot-volumes \
  --csi-snapshot-timeout 10m
```

## Restore Operations

To restore from a backup:

```bash
# List available backups
velero backup get

# Create restore
velero restore create --from-backup <backup-name>

# Monitor restore progress
velero restore describe <restore-name>
```

## Monitoring

Check backup status:

```bash
# List recent backups
velero backup get

# Check backup details
velero backup describe <backup-name>

# View logs
velero backup logs <backup-name>
```

## Troubleshooting

### Common Issues

1. **CSI Snapshot Timeout**: Increase `csiSnapshotTimeout` if Ceph snapshots take longer
2. **Permission Denied**: Verify AWS credentials in `homelab/velero/aws-credentials` secret
3. **Storage Class Issues**: Ensure VolumeSnapshotClass has the correct `velero.io/csi-volumesnapshot-class: "true"` label

### Debug Commands

```bash
# Check Velero pods
kubectl get pods -n velero

# View Velero logs
kubectl logs -n velero deployment/velero

# Check CSI snapshots
kubectl get volumesnapshot -A

# Verify storage classes
kubectl get volumesnapshotclass
```