I need to learn Kubernetes for work and want you to build a comprehensive learning framework that runs on an Intel Ubuntu box with Docker already installed.

REQUIREMENTS:
- Create a complete directory structure for progressive K8s learning
- Use kind (Kubernetes in Docker) for the cluster - no minikube
- Include practical exercises that build on each other
- Focus on real-world scenarios, not toy examples
- Generate example manifests, scripts, and documentation
- Include troubleshooting scenarios and debugging exercises

LEARNING PATH STRUCTURE:
1. /01-cluster-setup/ - kind cluster configs, multiple node setups
2. /02-pods-basics/ - pod creation, logs, exec, port-forward
3. /03-workloads/ - deployments, replicasets, daemonsets, jobs
4. /04-services-networking/ - ClusterIP, NodePort, LoadBalancer, Ingress
5. /05-config-secrets/ - ConfigMaps, Secrets, environment variables
6. /06-storage/ - PVs, PVCs, StorageClasses with local storage
7. /07-monitoring/ - Metrics server, basic observability
8. /08-troubleshooting/ - Common failure scenarios and debugging
9. /09-real-world/ - Multi-tier applications, databases, scaling

TECHNICAL SPECS:
- Ubuntu 22.04/24.04 target
- Use kubectl, kind, helm
- Include shell scripts for automation
- Add Makefile for common operations
- Generate realistic manifests (nginx, redis, postgres examples)
- Include network policies, resource limits, health checks
- Add chaos engineering scenarios for learning failure handling

OUTPUT REQUIREMENTS:
- Complete file structure with all configs
- Step-by-step README files for each module
- Working example applications
- Troubleshooting guides with common errors
- Scripts to reset/clean environments between exercises
- Include comments explaining WHY not just HOW

Make this enterprise-ready learning, not hello-world garbage. I want to understand production concepts from day one.
