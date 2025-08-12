# Kubernetes Learning Lab - Makefile
# Provides convenient commands for managing the learning environment

.PHONY: help setup start status test clean reset dashboard install-tools create-cluster delete-cluster

# Default target
help:
	@echo "╔══════════════════════════════════════════════════════════════╗"
	@echo "║          Kubernetes Learning Lab - Commands                  ║"
	@echo "╚══════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "Available commands:"
	@echo "  make setup          - Complete setup (install tools + create cluster)"
	@echo "  make start          - Start the interactive trainer"
	@echo "  make dashboard      - Open the web dashboard"
	@echo "  make status         - Check cluster and environment status"
	@echo "  make test           - Run validation tests"
	@echo "  make clean          - Clean up pods and resources"
	@echo "  make reset          - Full reset (delete cluster + clean progress)"
	@echo ""
	@echo "Individual commands:"
	@echo "  make install-tools  - Install kubectl and kind"
	@echo "  make create-cluster - Create the learning cluster"
	@echo "  make delete-cluster - Delete the learning cluster"
	@echo ""

# Complete setup
setup: install-tools create-cluster
	@echo "✅ Setup complete! Run 'make start' to begin learning."

# Start interactive trainer
start:
	@echo "🚀 Starting Kubernetes Learning Lab..."
	@./trainer/trainer.sh

# Open web dashboard
dashboard:
	@echo "🌐 Opening web dashboard..."
	@if command -v xdg-open > /dev/null; then \
		xdg-open trainer/index.html; \
	elif command -v open > /dev/null; then \
		open trainer/index.html; \
	else \
		echo "Please open trainer/index.html in your browser"; \
	fi

# Check status
status:
	@echo "📊 Checking environment status..."
	@echo ""
	@echo "=== System ==="
	@echo -n "Docker: "
	@if command -v docker > /dev/null && docker info > /dev/null 2>&1; then \
		echo "✓ Running"; \
	else \
		echo "✗ Not running or not installed"; \
	fi
	@echo -n "kubectl: "
	@if command -v kubectl > /dev/null; then \
		kubectl version --client --short 2>/dev/null || echo "Installed"; \
	else \
		echo "✗ Not installed"; \
	fi
	@echo -n "kind: "
	@if command -v kind > /dev/null; then \
		kind version 2>/dev/null || echo "Installed"; \
	else \
		echo "✗ Not installed"; \
	fi
	@echo ""
	@echo "=== Cluster ==="
	@if kind get clusters 2>/dev/null | grep -q .; then \
		echo "Active clusters:"; \
		kind get clusters | sed 's/^/  - /'; \
		echo ""; \
		echo "Nodes:"; \
		kubectl get nodes 2>/dev/null || echo "  Unable to connect"; \
	else \
		echo "No active clusters"; \
	fi
	@echo ""
	@echo "=== Resources ==="
	@echo -n "Memory: "
	@free -h | awk '/^Mem:/ {print $$3 " used / " $$2 " total"}'
	@echo -n "Disk: "
	@df -h / | awk 'NR==2 {print $$3 " used / " $$2 " total (" $$5 " full)"}'

# Run tests
test:
	@echo "🧪 Running validation tests..."
	@if [ -f 01-cluster-setup/exercises/01-verify-tools.sh ]; then \
		bash 01-cluster-setup/exercises/01-verify-tools.sh; \
	else \
		echo "No tests found. Complete Module 1 first."; \
	fi

# Clean up resources
clean:
	@echo "🧹 Cleaning up resources..."
	@echo -n "Delete all pods? (y/N): "
	@read confirm && [ "$$confirm" = "y" ] && kubectl delete pods --all || echo "Skipped"
	@echo -n "Delete all services? (y/N): "
	@read confirm && [ "$$confirm" = "y" ] && kubectl delete services --all || echo "Skipped"
	@echo "✅ Cleanup complete"

# Full reset
reset:
	@echo "⚠️  This will delete your cluster and reset all progress!"
	@echo -n "Are you sure? (y/N): "
	@read confirm && [ "$$confirm" = "y" ] && (make delete-cluster; rm -rf .progress/*; echo "✅ Reset complete") || echo "Reset cancelled"

# Install tools
install-tools:
	@echo "📦 Installing required tools..."
	@echo ""
	@# Check and install kubectl
	@if ! command -v kubectl > /dev/null; then \
		echo "Installing kubectl..."; \
		curl -LO "https://dl.k8s.io/release/$$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"; \
		chmod +x kubectl; \
		sudo mv kubectl /usr/local/bin/; \
		echo "✓ kubectl installed"; \
	else \
		echo "✓ kubectl already installed"; \
	fi
	@# Check and install kind
	@if ! command -v kind > /dev/null; then \
		echo "Installing kind..."; \
		curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64; \
		chmod +x ./kind; \
		sudo mv ./kind /usr/local/bin/kind; \
		echo "✓ kind installed"; \
	else \
		echo "✓ kind already installed"; \
	fi
	@echo ""
	@echo "✅ All tools installed"

# Create cluster
create-cluster:
	@echo "🔧 Creating Kubernetes cluster..."
	@if kind get clusters 2>/dev/null | grep -q k8s-learning; then \
		echo "✓ Cluster 'k8s-learning' already exists"; \
	else \
		if [ -f 01-cluster-setup/configs/multi-node.yaml ]; then \
			kind create cluster --config 01-cluster-setup/configs/multi-node.yaml --name k8s-learning; \
		else \
			mkdir -p 01-cluster-setup/configs; \
			echo "kind: Cluster\napiVersion: kind.x-k8s.io/v1alpha4\nnodes:\n  - role: control-plane\n  - role: worker\n  - role: worker" > 01-cluster-setup/configs/multi-node.yaml; \
			kind create cluster --config 01-cluster-setup/configs/multi-node.yaml --name k8s-learning; \
		fi; \
		echo "✅ Cluster created successfully"; \
	fi

# Delete cluster
delete-cluster:
	@echo "🗑️  Deleting Kubernetes cluster..."
	@kind delete cluster --name k8s-learning 2>/dev/null || echo "No cluster to delete"
	@echo "✅ Cluster deleted"

# Module-specific targets
module1:
	@cd 01-cluster-setup && ./start.sh

module2:
	@cd 02-pods-basics && ./start.sh

module3:
	@cd 03-workloads && ./start.sh

# Quick checks
.PHONY: check-docker check-cluster check-progress

check-docker:
	@docker info > /dev/null 2>&1 && echo "Docker: ✓" || echo "Docker: ✗"

check-cluster:
	@kubectl cluster-info > /dev/null 2>&1 && echo "Cluster: ✓" || echo "Cluster: ✗"

check-progress:
	@echo "Progress files:"
	@ls -la .progress/ 2>/dev/null || echo "No progress tracked yet"