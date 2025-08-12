# Module 1: Cluster Setup & Architecture

## 🎯 Learning Objectives

By the end of this module, you will:
- ✅ Install and configure kind (Kubernetes in Docker)
- ✅ Create single and multi-node Kubernetes clusters
- ✅ Understand Kubernetes architecture and components
- ✅ Configure kubectl for cluster management
- ✅ Explore control plane and worker node components

## 📚 Prerequisites

- Docker installed and running
- Basic command line knowledge
- 4GB+ RAM available
- Internet connection for downloading images

## 🚀 Quick Start

```bash
# Run the interactive setup
./start.sh

# Or follow the manual steps below
```

## 📖 Lesson 1: Installing Tools

### Step 1.1: Install kubectl

```bash
# Download kubectl (Linux)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Make it executable
chmod +x kubectl

# Move to PATH
sudo mv kubectl /usr/local/bin/

# Verify installation
kubectl version --client
```

### Step 1.2: Install kind

```bash
# Download kind (Linux AMD64)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64

# Make executable
chmod +x ./kind

# Move to PATH
sudo mv ./kind /usr/local/bin/kind

# Verify installation
kind version
```

### 🧪 Exercise 1: Verify Installations

Run the validation script:
```bash
./exercises/01-verify-tools.sh
```

## 📖 Lesson 2: Your First Cluster

### Step 2.1: Create a Simple Cluster

```bash
# Create a single-node cluster
kind create cluster --name learning-cluster

# Check cluster status
kubectl cluster-info --context kind-learning-cluster

# View nodes
kubectl get nodes

# View all pods in all namespaces
kubectl get pods -A
```

### Step 2.2: Understanding What Just Happened

When you created the cluster, kind:
1. Downloaded Kubernetes node images
2. Created Docker containers as "nodes"
3. Installed Kubernetes components
4. Configured kubectl to connect

### 🧪 Exercise 2: Explore Your Cluster

```bash
# Run the exploration script
./exercises/02-explore-cluster.sh
```

## 📖 Lesson 3: Multi-Node Clusters

### Step 3.1: Create a Production-Like Cluster

First, let's delete the simple cluster:
```bash
kind delete cluster --name learning-cluster
```

Now create a multi-node cluster using our configuration:

```bash
# Apply the multi-node configuration
kind create cluster --config configs/multi-node.yaml
```

### Step 3.2: Examine the Cluster Architecture

```bash
# View all nodes
kubectl get nodes -o wide

# Check node roles
kubectl get nodes --show-labels

# Inspect a node
kubectl describe node kind-control-plane
```

### 🧪 Exercise 3: Node Management

```bash
./exercises/03-node-management.sh
```

## 📖 Lesson 4: Kubernetes Components

### Control Plane Components

The control plane manages the cluster. Let's explore its components:

```bash
# View control plane pods
kubectl get pods -n kube-system

# Key components:
# - kube-apiserver: API endpoint
# - etcd: Cluster database
# - kube-scheduler: Assigns pods to nodes
# - kube-controller-manager: Runs controllers
# - coredns: DNS for services
```

### Worker Node Components

```bash
# kubelet: Node agent (runs as system service, not a pod)
docker exec kind-worker crictl ps

# kube-proxy: Network proxy
kubectl get pods -n kube-system | grep kube-proxy
```

### 🧪 Exercise 4: Component Deep Dive

```bash
./exercises/04-components.sh
```

## 📖 Lesson 5: kubectl Configuration

### Understanding Contexts

```bash
# View current context
kubectl config current-context

# View all contexts
kubectl config get-contexts

# View full config
kubectl config view

# Switch context (if multiple clusters)
kubectl config use-context kind-kind
```

### Setting Defaults

```bash
# Set default namespace
kubectl config set-context --current --namespace=default

# Create an alias for convenience
echo "alias k=kubectl" >> ~/.bashrc
source ~/.bashrc
```

### 🧪 Exercise 5: kubectl Mastery

```bash
./exercises/05-kubectl-config.sh
```

## 🏆 Module Challenge

Complete the final challenge to test your knowledge:

```bash
./challenge/setup-challenge.sh
```

This challenge will ask you to:
1. Create a specific cluster configuration
2. Verify all components are running
3. Configure kubectl with custom settings
4. Troubleshoot a broken cluster

## 📊 Knowledge Check

Run the knowledge check to review key concepts:

```bash
./test/knowledge-check.sh
```

## 🔧 Troubleshooting Guide

### Common Issues and Solutions

#### Docker not running
```bash
# Check Docker status
systemctl status docker

# Start Docker
sudo systemctl start docker
```

#### kind cluster creation fails
```bash
# Check Docker resources
docker system df

# Clean up Docker
docker system prune -a

# Retry cluster creation
kind create cluster
```

#### kubectl cannot connect
```bash
# Check kubeconfig
echo $KUBECONFIG

# Reset kubeconfig
kind get kubeconfig --name kind > ~/.kube/config
```

## 📚 Additional Resources

- [Official kind Documentation](https://kind.sigs.k8s.io/)
- [Kubernetes Components](https://kubernetes.io/docs/concepts/overview/components/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

## ✅ Module Completion

Congratulations! You've completed Module 1. You should now be able to:
- Create and manage kind clusters
- Understand Kubernetes architecture
- Use kubectl effectively
- Troubleshoot basic cluster issues

### Next Steps
Run the completion script to mark this module as complete:
```bash
./complete.sh
```

Then proceed to Module 2: Pods & Container Basics!