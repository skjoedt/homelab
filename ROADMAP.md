# Roadmap

## Basic requirements

Everything needed for speed of iteration and security

- [ ] Automated bare metal provisioning
- [x] Automated cluster provisioning
- [x] Full develop and production environment compatibility
- [ ] GitOps deployment (ArgoCD)
- [x] Automated DNS management
- [x] Observability
  - [x] Monitoring
  - [x] Logging
- [ ] Security
  - [x] Automated certificate management
  - [x] External secret management
  - [ ] Backup solution (3 copies, 2 seperate devices, 1 offsite)
- [ ] Reclaimable CSI with cephfs or ceph rbd

# Production requirements

Everything needed for family onboarding

- [ ] NordVPN
- [ ] Add ceph radosgw s3 endpoint
- [ ] Applications
  - [ ] Immich
  - [ ] Budget Planning (tbd)
  - [ ] Jellyfin
- [ ] Adblock DNS with failover on home network
- [ ] Observability
  - [ ] Alert notifications
  - [ ] More dashboards and alert rules
- [ ] SSO
- [ ] Expose services to the internet securely with Wireguard
- [ ] Ceph exposure
  - [ ] Connect ceph dashboard to traefik
  - [ ] Send ceph logs and node exporters to grafana
  - [ ] Send ceph alerts to alert manager

# Unplanned

Things I might get to at some point

- [ ] Automated app upgrades (tbd)
- [ ] HA on at least three phyiscal nodes
- [ ] Bare metal with talos linux or similar
- [ ] Bare-metal OS rolling upgrade
- [ ] Kubernetes version rolling upgrade
- [ ] Measure power consumption (send to grafana?)

# Issues

- [ ] Fix ceph provisioner permission error
- [ ] Fix continue dev mcp problems
