# zfs-playground

Disposable Lima VMs (Debian 12) with a batch of raw virtual disks for exercising ZFS.
Disks are declared in `configs/*.yaml`. Up to 3 VMs (`zfs-a`/`zfs-b`/`zfs-c`) run in parallel.

Requires: `limactl`, `qemu`, `yq`, `make`.

### Bootstrap
```sh
make up                        # start zfs-a (configs/a.yaml)
make up CONFIG=configs/b.yaml  # start another VM in parallel
make up-all                    # start every config
```
First boot compiles the ZFS module via DKMS (a few minutes); later boots are fast.

### Experiment
```sh
make ssh                       # or: make ssh CONFIG=configs/b.yaml
# inside the VM — disks are /dev/vdb, /dev/vdc, ... in config order:
lsblk
sudo zpool create tank raidz /dev/vdb /dev/vdc /dev/vdd
zpool status
sudo zpool destroy tank
```

2x RAIDZ2 vdevs, 5 drives each (default 10-disk config, vdb-vdk):
```sh
sudo zpool create tank \
  raidz2 /dev/vdb /dev/vdc /dev/vdd /dev/vde /dev/vdf \
  raidz2 /dev/vdg /dev/vdh /dev/vdi /dev/vdj /dev/vdk
zpool status tank
sudo zpool destroy tank
```

### Teardown
```sh
make down                      # delete one VM + its disks
make down-all                  # delete everything
make recreate                  # down + up (fresh disks) for one VM
make list                      # all VMs and disks
```

Edit a config's `disks:` list (name + size) and `make recreate` to change the layout.

### Notes
- Disks are attached raw (`format: false`), so Lima's boot script logs a harmless
  failed `mount` for each and `cloud-init status` reports `error`. This is expected —
  `make up` still succeeds and ZFS works. (Raw is required so `zpool` gets whole disks;
  it's also what keeps a pool safe across VM restarts.)
- Pools auto-import after `limactl stop`/`start`. If one ever doesn't, `sudo zpool import tank`.

### Collected Wisdom

- **Growing pools**: add vdevs (striped with existing); can't easily widen a raidz vdev itself.
- **RAIDZ1 vs RAIDZ2 (4x20TB)**: RAIDZ1 ~60TB usable, RAIDZ2 ~40TB usable.
- **12-drive vdev options**: 2x RAIDZ2 6-wide (balanced, ~80TB), 1x RAIDZ2 12-wide (max capacity ~200TB, worst IOPS/resilver), 3x RAIDZ1 (capacity+IOPS, weaker resilience), 6x mirrors (best IOPS/resilver, least capacity), 2x RAIDZ1 (more capacity, riskier).
- **Resilver**: rebuild process after drive replacement; not downtime, but degraded redundancy + performance hit during it.
- **12-wide RAIDZ2 resilver estimate**: ~2-5+ days depending on fill level, drive type, workload.
- **"tank"**: traditional example ZFS pool name, no special meaning.
- **Device Names Are Unstable**: device names aren't guaranteed stable, use `zpool create tank raidz2 /dev/disk/by-id/ata-XXXX`
  - LIMITS OF THIS VIRTUAL SETUP: Lima's virtio disks have no serial, so there's no `/dev/disk/by-id/ata-*`. We ignore this issue here.

### Resources

- <https://klarasystems.com/articles/openzfs-understanding-zfs-vdev-types/>
