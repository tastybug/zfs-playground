# Snapshot pruning

raidz2 (4 disks), snapshot a dataset, delete + replace its data, watch a stale
snapshot keep the deleted data alive, prune it to reclaim space.

```sh
make up   # configs/a.yaml has 10 disks, raidz2 needs >=4
```

Create pool + dataset, write data, snapshot it:
```sh
ssh -F ~/.lima/zfs-a/ssh.config lima-zfs-a <<'EOF'
sudo zpool create tank raidz2 /dev/vdb /dev/vdc /dev/vdd /dev/vde
sudo zfs create tank/data
sudo chown $(whoami) /tank/data
dd if=/dev/urandom of=/tank/data/a.bin bs=1M count=200 status=none
sudo zfs snapshot tank/data@day1
zfs list -t snapshot tank/data   # @day1 USED: 0B - nothing unique to it yet
zfs list tank/data               # USED: 200M
EOF
```

Delete the file, write a different one, snapshot again. The dataset's `USED`
now covers live data *and* whatever old data a snapshot still references:
```sh
ssh -F ~/.lima/zfs-a/ssh.config lima-zfs-a <<'EOF'
rm /tank/data/a.bin
dd if=/dev/urandom of=/tank/data/b.bin bs=1M count=200 status=none
sudo zfs snapshot tank/data@day2
zfs list -t snapshot tank/data
#   @day1   200M   <- a.bin is gone from the filesystem, but @day1 keeps it alive
#   @day2     0B
zfs list tank/data   # USED: 400M even though only 200M (b.bin) is live
EOF
```

Prune the snapshot pinning the deleted data — space comes back immediately:
```sh
ssh -F ~/.lima/zfs-a/ssh.config lima-zfs-a <<'EOF'
sudo zfs destroy tank/data@day1
zfs list -t snapshot tank/data   # only @day2 left
zfs list tank/data                # USED: 200M - back to just the live file
EOF
```

```sh
make down
```
