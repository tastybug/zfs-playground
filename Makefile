# ZFS playground - Lima VMs with YAML-defined virtual disks.
# Select a VM with CONFIG=... (default: configs/a.yaml). Up to 3 run in parallel.

CONFIG ?= configs/a.yaml
VM      = $(shell yq -r '.vm.name' $(CONFIG))
CONFIGS = $(wildcard configs/*.yaml)

.PHONY: up down recreate ssh status up-all down-all list help

help: ## Show this help
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | sed 's/:.*## /\t/' | column -t -s '	'

up: ## Create + start a VM        (CONFIG=configs/a.yaml)
	@scripts/up.sh $(CONFIG)

down: ## Delete a VM + its disks   (CONFIG=configs/a.yaml)
	@scripts/down.sh $(CONFIG)

recreate: down up ## Tear down and recreate a VM from its config

ssh: ## Shell into a VM
	@limactl shell $(VM)

status: ## Show one VM and its disks
	@limactl list $(VM) || true
	@echo "--- disks ---"
	@limactl disk ls | grep -E "NAME|^$(VM)-" || true

up-all: ## Bring up every config in configs/
	@for c in $(CONFIGS); do echo "== $$c =="; scripts/up.sh $$c; done

down-all: ## Tear down every config in configs/
	@for c in $(CONFIGS); do echo "== $$c =="; scripts/down.sh $$c; done

list: ## List all Lima VMs and disks
	@limactl list
	@echo "--- disks ---"
	@limactl disk ls
