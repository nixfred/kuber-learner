# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a comprehensive Kubernetes learning framework designed for enterprise-ready education. The project uses kind (Kubernetes in Docker) to create local clusters for hands-on learning experiences covering all major K8s concepts from basics to production scenarios.

## Key Development Commands

### Cluster Management
```bash
# Create a kind cluster (after setup)
kind create cluster --config 01-cluster-setup/kind-config.yaml

# Delete cluster
kind delete cluster

# Get cluster info
kubectl cluster-info --context kind-kind
```

### Common Operations
```bash
# Apply manifests
kubectl apply -f <manifest.yaml>

# Check pod status
kubectl get pods -A

# View logs
kubectl logs <pod-name>

# Clean up resources
kubectl delete -f <manifest.yaml>
```

### Project Scripts (to be implemented)
```bash
# Reset environment between exercises
./scripts/reset-environment.sh

# Setup initial cluster
./scripts/setup-cluster.sh

# Run tests for specific module
./scripts/test-module.sh <module-number>
```

## Architecture & Structure

The learning framework follows a progressive module structure:

1. **01-cluster-setup/** - Kind cluster configurations, multi-node setups
2. **02-pods-basics/** - Pod lifecycle, debugging, port-forwarding
3. **03-workloads/** - Deployments, ReplicaSets, DaemonSets, Jobs, CronJobs
4. **04-services-networking/** - Service types, Ingress controllers, network policies
5. **05-config-secrets/** - ConfigMaps, Secrets, environment injection
6. **06-storage/** - Persistent volumes, storage classes, local storage
7. **07-monitoring/** - Metrics server, basic observability setup
8. **08-troubleshooting/** - Failure scenarios, debugging techniques
9. **09-real-world/** - Multi-tier applications, databases, scaling scenarios

Each module contains:
- README.md with step-by-step instructions
- Working YAML manifests with detailed comments
- Shell scripts for automation
- Troubleshooting guides
- Clean-up scripts

## Technical Requirements

- **Platform**: Ubuntu 22.04/24.04
- **Container Runtime**: Docker (pre-installed)
- **Kubernetes Distribution**: kind (Kubernetes in Docker)
- **Tools**: kubectl, helm, kind
- **Approach**: Production-oriented learning with real-world scenarios

## Development Guidelines

### When Creating New Modules
1. Include realistic examples (nginx, redis, postgres) not toy applications
2. Add extensive inline comments explaining the "why" behind configurations
3. Include resource limits, health checks, and production best practices
4. Create both working and broken examples for troubleshooting practice
5. Provide reset scripts to clean state between exercises

### Manifest Standards
- Use explicit API versions
- Include resource limits and requests
- Add health checks (liveness/readiness probes)
- Include security contexts where appropriate
- Use namespaces for isolation
- Add comprehensive labels and annotations

### Script Requirements
- Make scripts idempotent
- Include error handling and validation
- Add helpful output messages
- Support both setup and teardown operations
- Test on Ubuntu 22.04 and 24.04

## Testing Approach

Each module should be testable independently:
1. Setup script creates required resources
2. Validation script checks expected state
3. Cleanup script removes all resources
4. Reset script returns to clean state

## Common Troubleshooting

### Kind Cluster Issues
- Check Docker is running: `systemctl status docker`
- Verify kind is installed: `kind version`
- Check cluster status: `kind get clusters`

### Kubectl Connection
- Verify context: `kubectl config current-context`
- Check kubeconfig: `echo $KUBECONFIG`
- Switch context: `kubectl config use-context kind-kind`

## Project Implementation Status

Currently implementing the full learning framework structure with all modules, scripts, and documentation as specified in kuber-learner-prompt.md.