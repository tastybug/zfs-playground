#!/usr/bin/env bash
# render.sh <config.yaml>
# Reads a playground config, creates the VM's Lima disks (idempotent),
# and renders lima/.generated-<vm>.yaml from lima/base.yaml.
set -euo pipefail

CONFIG="${1:?usage: render.sh <config.yaml>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="$ROOT/lima/base.yaml"

[ -f "$CONFIG" ] || { echo "config not found: $CONFIG" >&2; exit 1; }

VM="$(yq -r '.vm.name' "$CONFIG")"
CPUS="$(yq -r '.vm.cpus' "$CONFIG")"
MEMORY="$(yq -r '.vm.memory' "$CONFIG")"
ROOTDISK="$(yq -r '.vm.rootDisk' "$CONFIG")"
COUNT="$(yq -r '.disks | length' "$CONFIG")"

[ -n "$VM" ] && [ "$VM" != "null" ] || { echo "vm.name missing in $CONFIG" >&2; exit 1; }

GEN="$ROOT/lima/.generated-$VM.yaml"

# Create each disk if it doesn't already exist (names scoped by VM).
existing="$(limactl disk ls 2>/dev/null | awk 'NR>1 {print $1}')"
for i in $(seq 0 $((COUNT - 1))); do
  name="$(yq -r ".disks[$i].name" "$CONFIG")"
  size="$(yq -r ".disks[$i].size" "$CONFIG")"
  disk="$VM-$name"
  if echo "$existing" | grep -qx "$disk"; then
    echo "disk exists: $disk"
  else
    echo "creating disk: $disk ($size)"
    limactl disk create "$disk" --size "$size" >/dev/null
  fi
done

# Render the generated Lima config: base fragment + per-VM values.
{
  cat "$BASE"
  echo ""
  echo "# ---- rendered from $CONFIG ----"
  echo "cpus: $CPUS"
  echo "memory: \"$MEMORY\""
  echo "disk: \"$ROOTDISK\""
  # format:false => Lima attaches the disk raw (no ext4, no mount), so ZFS
  # gets a pristine block device. Bare-string disks would default to
  # format:true and be formatted+mounted, which breaks `zpool create`.
  echo "additionalDisks:"
  for i in $(seq 0 $((COUNT - 1))); do
    name="$(yq -r ".disks[$i].name" "$CONFIG")"
    echo "- name: \"$VM-$name\""
    echo "  format: false"
  done
} > "$GEN"

echo "rendered: $GEN"
