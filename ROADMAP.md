# Roadmap

## Basic requirements

Everything needed for speed of iteration and security

- [ ] Automated bare metal provisioning
- [x] Automated cluster provisioning
- [x] Full develop and production environment compatibility
- [ ] GitOps deployment (ArgoCD/Flux)
- [x] Automated DNS management
- [x] Observability
  - [x] Monitoring
  - [x] Logging
- [ ] Security
  - [x] Automated certificate management
  - [x] External secret management
  - [ ] Backup solution (3 copies, 2 seperate devices, 1 offsite)
    - [x] Velero Ceph CSI snapshotter
    - [x] Velero Manifest backups to s3
    - [ ] Velero Data mover to s3
    - [ ] Ceph S3 mirror
    - [x] Cloudnative-pg Backup to s3
- [x] Reclaimable CSI with cephfs or ceph rbd

## Production requirements

Everything needed for family onboarding

- [x] ProtonVPN
- [ ] Add ceph radosgw s3 endpoint
- [x] Applications
  - [x] Immich
  - [x] Actual Budget
  - [x] Jellyfin
  - [x] Automatic Ripping Machine
  - [x] Reactive-resume
- [x] Adblock Home
- [ ] RBAC
- [ ] Observability
  - [ ] Alert notifications, e.g. nfty
  - [ ] Alert rules on container errors
- [ ] SSO
- [x] Expose services to the internet securely with Wireguard
- [ ] Ceph exposure
  - [x] Connect ceph dashboard to traefik
  - [ ] Send ceph logs and node exporters to grafana
  - [ ] Send ceph alerts to alert manager

## Unplanned

Things I might get to at some point

- [ ] Automated app upgrades (tbd)
- [ ] HA on at least three phyiscal nodes
- [ ] Bare metal with talos linux or similar
- [ ] Bare-metal OS rolling upgrade
- [ ] Kubernetes version rolling upgrade
- [ ] Measure power consumption (send to grafana?)
- [x] Have production patch base/ instead of staging/
- [x] Enable wakeonlan
- [ ] Enable homepage service discovery

Applications

- [ ] Local LLM API endpoint using GPU
- [ ] OpenWebUI or Vane (search)
- [ ] Affine
- [ ] Bookmark manager, like Karakeep
- [x] Document manager, like Papra
- [ ] Home Assistant