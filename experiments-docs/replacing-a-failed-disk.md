# Replacing a failed disk

raidz2 (4 disks), kill one mid-flight, watch `zpool status` report the fault, swap in a new disk, resilver.

```sh
make up   # configs/a.yaml has 10 disks, raidz2 needs >=4
```

Create the pool, write a 2 GiB test file into the root dataset, checksum it, inspect the healthy baseline:
```sh
ssh -F ~/.lima/zfs-a/ssh.config lima-zfs-a <<'EOF'
sudo zpool create tank raidz2 /dev/vdb /dev/vdc /dev/vdd /dev/vde
sudo chown $(whoami) /tank
dd if=/dev/urandom of=/tank/file.bin bs=1M count=2048
shasum -a 256 /tank/file.bin
zpool status -v tank   # state: ONLINE, all 4 members ONLINE
EOF
```

Kill the 4th member (`/dev/vde`, backed by Lima disk `zfs-a-d04`) by dropping it
from the VM entirely — not `zpool offline`, the device disappears for real:
```sh
limactl stop zfs-a
limactl edit zfs-a --set 'del(.additionalDisks[3])' --start
```

After failure — the disk is gone, not just offline. `/dev/vde` now refers to a
different, blank disk (device letters shift down to fill the gap), so ZFS can't
be fooled by the reused path — it reports the missing member by GUID instead:
```sh
ssh -F ~/.lima/zfs-a/ssh.config lima-zfs-a <<'EOF'
zpool status -v tank
# state: DEGRADED
#   raidz2-0                DEGRADED
#     vdb ONLINE  vdc ONLINE  vdd ONLINE
#     15257435499842936386  UNAVAIL   was /dev/vde1
shasum -a 256 /tank/file.bin   # unchanged — raidz2 absorbed the loss
EOF
```

Provision a genuinely different disk and attach it:
```sh
limactl disk create zfs-a-d11 --size 2GiB
limactl stop zfs-a
limactl edit zfs-a --set '.additionalDisks += [{"name": "zfs-a-d11", "format": false}]' --start
```

Replace the missing member (GUID from the status above) with the new disk
(last one attached — confirm with `lsblk` if unsure, here `/dev/vdk`), then
verify and tear the pool down:
```sh
ssh -F ~/.lima/zfs-a/ssh.config lima-zfs-a <<'EOF'
sudo zpool replace tank 15257435499842936386 /dev/vdk
zpool status tank   # state: ONLINE, scan: resilvered ...
shasum -a 256 /tank/file.bin   # still matches
EOF
```

```sh
make down
```
