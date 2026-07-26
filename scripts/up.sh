#!/usr/bin/env bash
# up.sh <config.yaml>  -  render config, create disks, start the VM.
set -euo pipefail

CONFIG="${1:?usage: up.sh <config.yaml>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VM="$(yq -r '.vm.name' "$CONFIG")"
"$ROOT/scripts/render.sh" "$CONFIG"

GEN="$ROOT/lima/.generated-$VM.yaml"
limactl start --name "$VM" --tty=false "$GEN"

echo ""
echo "VM '$VM' is up. Shell in with:  limactl shell $VM"
