# Scrubbing and corruption repair

raidz2 (4 disks), corrupt raw sectors on one member directly (bypassing ZFS), scrub, watch it detect + repair from parity.

```sh
make up   # configs/a.yaml has 10 disks, raidz2 needs >=4
```

Create the pool, write a test file, checksum it:
```sh
ssh -F ~/.lima/zfs-a/ssh.config lima-zfs-a <<'EOF'
sudo zpool create tank raidz2 /dev/vdb /dev/vdc /dev/vdd /dev/vde
sudo chown $(whoami) /tank
dd if=/dev/urandom of=/tank/file.bin bs=1M count=512
shasum -a 256 /tank/file.bin
zpool status -v tank   # state: ONLINE, all 4 members ONLINE
EOF
```

Simulate silent bit rot: write garbage straight to `/dev/vdc`'s raw sectors,
skipping ZFS entirely. `zpool status` stays clean — ZFS hasn't read those
sectors yet, so it doesn't know anything's wrong:
```sh
ssh -F ~/.lima/zfs-a/ssh.config lima-zfs-a <<'EOF'
sudo dd if=/dev/urandom of=/dev/vdc bs=1M seek=100 count=50 conv=notrunc
zpool status -v tank   # still ONLINE, 0 CKSUM errors — corruption not yet observed
EOF
```

Scrub forces a read of every block and compares against checksums:
```sh
ssh -F ~/.lima/zfs-a/ssh.config lima-zfs-a <<'EOF'
sudo zpool scrub tank
zpool status -v tank
# status: One or more devices has experienced an unrecoverable error. An
#         attempt was made to correct the error.
#   scan: scrub repaired 4.50K in 00:00:00 with 0 errors
#     vdc   ONLINE   0   0   9   <- CKSUM count, the rest clean
shasum -a 256 /tank/file.bin   # unchanged - repaired from raidz2 parity
EOF
```

CKSUM counters persist until cleared — clear them once the cause (bad
sectors, cabling, etc.) has been addressed:
```sh
ssh -F ~/.lima/zfs-a/ssh.config lima-zfs-a <<'EOF'
sudo zpool clear tank
zpool status tank   # CKSUM back to 0
EOF
```

```sh
make down
```
