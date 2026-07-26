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
