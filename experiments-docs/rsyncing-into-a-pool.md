# Rsyncing into a pool

Create a raidz2 pool, then rsync data into it from the host (not `limactl shell`).

```sh
make up   # configs/a.yaml has 10 disks, raidz2 needs >=4
make ssh
```

Inside the VM:
```sh
sudo zpool create tank raidz2 /dev/vdb /dev/vdc /dev/vdd /dev/vde
sudo chown $(whoami) /tank
zpool status
exit
```

On the host — make a test file and checksum it:
```sh
dd if=/dev/urandom of=file.bin bs=1M count=1024   # 1 GiB; adjust count for other sizes
shasum -a 256 file.bin
```

Rsync it in, using Lima's per-VM ssh config directly:
```sh
rsync -avz --progress -e "ssh -F ${HOME}/.lima/zfs-a/ssh.config" file.bin lima-zfs-a:/tank/
```

Verify inside the VM:
```sh
make ssh
ls -lh /tank
shasum -a 256 /tank/file.bin   # must match the host digest
sudo zpool destroy tank
```

```sh
make down
```
