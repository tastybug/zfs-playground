#!/usr/bin/env bash
# down.sh <config.yaml>  -  delete the VM and all disks it owns.
# Scoped strictly to this VM's name prefix; other VMs are untouched.
set -euo pipefail

CONFIG="${1:?usage: down.sh <config.yaml>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VM="$(yq -r '.vm.name' "$CONFIG")"
[ -n "$VM" ] && [ "$VM" != "null" ] || { echo "vm.name missing in $CONFIG" >&2; exit 1; }

# Delete the instance (ignore if it isn't there).
limactl delete -f "$VM" 2>/dev/null || true

# Delete every disk owned by this VM ("<vm>-..."), leaving other VMs alone.
limactl disk ls 2>/dev/null | awk 'NR>1 {print $1}' | { grep "^$VM-" || true; } | while read -r disk; do
  echo "deleting disk: $disk"
  limactl disk delete "$disk" >/dev/null || true
done

# Drop the generated config.
rm -f "$ROOT/lima/.generated-$VM.yaml"

echo "VM '$VM' and its disks removed."
