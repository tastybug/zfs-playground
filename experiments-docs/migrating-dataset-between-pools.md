# Migrating a dataset between pools

Two VMs, a quota'd dataset on A, rsync data in, `zfs send`/`recv` it over to B, checksum-verify.

```sh
make up                        # zfs-a
make up CONFIG=configs/b.yaml  # zfs-b
```

Create a pool on each and a dataset on A
```sh
ssh -F ~/.lima/zfs-a/ssh.config lima-zfs-a 'sudo zpool create tank mirror /dev/vdb /dev/vdc'
ssh -F ~/.lima/zfs-b/ssh.config lima-zfs-b 'sudo zpool create tank mirror /dev/vdb /dev/vdc'

ssh -F ~/.lima/zfs-a/ssh.config lima-zfs-a 'sudo zfs create -o quota=2G tank/data'
ssh -F ~/.lima/zfs-a/ssh.config lima-zfs-a 'sudo chown $(whoami) /tank/data'
```

Test file + checksum on the host, then rsync into A's dataset
```sh
dd if=/dev/urandom of=file.bin bs=1M count=512
shasum -a 256 file.bin
rsync -avz --progress -e "ssh -F ${HOME}/.lima/zfs-a/ssh.config" file.bin lima-zfs-a:/tank/data/
```

Migrate A → B. VMs can't reach each other directly (no shared Lima network), so relay
through the host by piping two ssh connections:
```sh
ssh -F ~/.lima/zfs-a/ssh.config lima-zfs-a 'sudo zfs snapshot tank/data@migrate'
ssh -F ~/.lima/zfs-a/ssh.config lima-zfs-a 'sudo zfs send tank/data@migrate' | ssh -F ~/.lima/zfs-b/ssh.config lima-zfs-b 'sudo zfs recv tank/data'
```

Prove it worked, on B:
```sh
ssh -F ~/.lima/zfs-b/ssh.config lima-zfs-b <<EOF
ls -lh /tank/data
zfs get quota tank/data          # quota carried over from A
shasum -a 256 /tank/data/file.bin  # must match the host digest above
EOF
```

Teardown:
```sh
make down-all
```
