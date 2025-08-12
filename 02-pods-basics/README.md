# Module 2: Pods & Container Basics

## 🎯 Learning Objectives

By the end of this module, you will:
- ✅ Understand what pods are and why they're fundamental
- ✅ Create and manage single and multi-container pods
- ✅ Master pod lifecycle and states
- ✅ Debug pods using logs, exec, and describe
- ✅ Use port-forwarding to access pod services
- ✅ Implement init containers and sidecar patterns

## 📚 Prerequisites

- ✅ Completed Module 1: Cluster Setup
- ✅ Working kind cluster running
- ✅ Basic understanding of containers

## 🚀 Quick Start

```bash
# Run the interactive lesson
./start.sh

# Or follow the manual steps below
```

## 📖 Lesson 1: Understanding Pods

### What is a Pod?

A Pod is the smallest deployable unit in Kubernetes:
- Wraps one or more containers
- Shares network and storage
- Has a unique IP address
- Ephemeral by design

### Your First Pod

Create a simple pod:

```yaml
# simple-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-first-pod
  labels:
    app: nginx
    environment: learning
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
```

Apply it:
```bash
kubectl apply -f manifests/simple-pod.yaml

# Check pod status
kubectl get pods

# Get detailed information
kubectl describe pod my-first-pod
```

### 🧪 Exercise 1: Pod Creation
```bash
./exercises/01-create-pods.sh
```

## 📖 Lesson 2: Pod Lifecycle

### Pod Phases

1. **Pending** - Pod accepted but not running
2. **Running** - Pod bound to node, containers created
3. **Succeeded** - All containers terminated successfully
4. **Failed** - At least one container failed
5. **Unknown** - Pod state cannot be determined

### Observing Lifecycle

```bash
# Watch pod creation in real-time
kubectl apply -f manifests/lifecycle-pod.yaml
kubectl get pods -w

# In another terminal, check events
kubectl get events --sort-by='.lastTimestamp'
```

### Container States

Within a pod, containers can be:
- **Waiting** - Not yet started
- **Running** - Executing normally
- **Terminated** - Execution completed

```bash
# Check container states
kubectl get pod my-first-pod -o jsonpath='{.status.containerStatuses[*].state}'
```

### 🧪 Exercise 2: Lifecycle Management
```bash
./exercises/02-lifecycle.sh
```

## 📖 Lesson 3: Multi-Container Pods

### Common Patterns

1. **Sidecar** - Enhances main container
2. **Ambassador** - Proxy for main container
3. **Adapter** - Standardizes output

### Creating a Multi-Container Pod

```yaml
# multi-container.yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-pod
spec:
  containers:
  # Main application
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo "App starting" && while true; do echo "$(date) - App running" >> /var/log/app.log; sleep 5; done']
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log
  
  # Sidecar container for log processing
  - name: sidecar
    image: busybox
    command: ['sh', '-c', 'while true; do if [ -f /var/log/app.log ]; then echo "Logs: $(tail -n 5 /var/log/app.log)"; fi; sleep 10; done']
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log
  
  volumes:
  - name: shared-logs
    emptyDir: {}
```

```bash
# Apply and observe
kubectl apply -f manifests/multi-container.yaml

# Check logs from each container
kubectl logs multi-container-pod -c app
kubectl logs multi-container-pod -c sidecar
```

### 🧪 Exercise 3: Multi-Container Patterns
```bash
./exercises/03-multi-container.sh
```

## 📖 Lesson 4: Debugging Pods

### Essential Debugging Commands

```bash
# 1. Check pod status
kubectl get pod <pod-name> -o wide

# 2. Describe for details
kubectl describe pod <pod-name>

# 3. View logs
kubectl logs <pod-name>
kubectl logs <pod-name> -c <container-name>  # For multi-container
kubectl logs <pod-name> --previous           # Previous container logs

# 4. Execute commands in pod
kubectl exec <pod-name> -- ls /
kubectl exec -it <pod-name> -- /bin/sh      # Interactive shell

# 5. Check events
kubectl get events --field-selector involvedObject.name=<pod-name>

# 6. View pod YAML
kubectl get pod <pod-name> -o yaml
```

### Common Issues and Solutions

#### ImagePullBackOff
```bash
# Check the image name
kubectl describe pod <pod-name> | grep -A5 "Events"

# Fix: Correct image name or add image pull secrets
```

#### CrashLoopBackOff
```bash
# Check logs for error
kubectl logs <pod-name> --previous

# Fix: Debug application error or add proper health checks
```

#### Pending State
```bash
# Check why pod is pending
kubectl describe pod <pod-name> | grep -A10 "Events"

# Common causes: Insufficient resources, node selector issues
```

### 🧪 Exercise 4: Debugging Practice
```bash
./exercises/04-debugging.sh
```

## 📖 Lesson 5: Port Forwarding

### Accessing Pod Services

```bash
# Forward local port to pod port
kubectl port-forward pod/my-first-pod 8080:80

# Access in browser or curl
curl http://localhost:8080

# Forward to a random local port
kubectl port-forward pod/my-first-pod :80
```

### Advanced Port Forwarding

```bash
# Multiple ports
kubectl port-forward pod/my-pod 8080:80 8443:443

# Bind to all interfaces (careful in production!)
kubectl port-forward --address 0.0.0.0 pod/my-pod 8080:80
```

### 🧪 Exercise 5: Port Forwarding
```bash
./exercises/05-port-forward.sh
```

## 📖 Lesson 6: Init Containers

### Purpose of Init Containers

Init containers run before app containers and must complete successfully:
- Database migration
- Waiting for dependencies
- Fetching configuration
- Setting up volumes

### Example with Init Container

```yaml
# init-container.yaml
apiVersion: v1
kind: Pod
metadata:
  name: init-demo
spec:
  initContainers:
  - name: init-myservice
    image: busybox:1.28
    command: ['sh', '-c', 'echo "Waiting for myservice..." && sleep 5 && echo "Service ready!"']
  
  - name: init-mydb
    image: busybox:1.28
    command: ['sh', '-c', 'echo "Waiting for database..." && sleep 5 && echo "Database ready!"']
  
  containers:
  - name: app
    image: busybox:1.28
    command: ['sh', '-c', 'echo "App is running!" && sleep 3600']
```

```bash
# Apply and watch init process
kubectl apply -f manifests/init-container.yaml
kubectl get pod init-demo -w

# Check init container logs
kubectl logs init-demo -c init-myservice
kubectl logs init-demo -c init-mydb
```

### 🧪 Exercise 6: Init Containers
```bash
./exercises/06-init-containers.sh
```

## 🏆 Module Challenge

Complete the comprehensive pod challenge:

```bash
./challenge/pod-challenge.sh
```

This challenge includes:
1. Creating a complex multi-container pod
2. Implementing proper health checks
3. Debugging a broken pod
4. Setting up init containers
5. Configuring resource limits

## 📊 Knowledge Check

Test your understanding:

```bash
./test/knowledge-check.sh
```

## 🔧 Troubleshooting Guide

### Pod Won't Start

```bash
# Diagnosis workflow
kubectl get pod <pod-name>
kubectl describe pod <pod-name>
kubectl get events --field-selector involvedObject.name=<pod-name>
kubectl logs <pod-name>
```

### Container Keeps Restarting

```bash
# Check restart count
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[*].restartCount}'

# View previous logs
kubectl logs <pod-name> --previous

# Check resource limits
kubectl describe pod <pod-name> | grep -A5 "Limits"
```

### Can't Access Pod

```bash
# Verify pod is running
kubectl get pod <pod-name>

# Check pod IP
kubectl get pod <pod-name> -o wide

# Test connectivity
kubectl exec <another-pod> -- ping <pod-ip>

# Check port forwarding
kubectl port-forward pod/<pod-name> 8080:80
```

## 💡 Best Practices

1. **Always use labels** - Makes selection and organization easier
2. **Set resource requests/limits** - Prevents resource starvation
3. **Use health checks** - Ensures pod reliability
4. **One process per container** - Follow container best practices
5. **Use init containers** - For setup and dependency management
6. **Avoid running as root** - Security best practice
7. **Use specific image tags** - Never use `latest` in production

## 📚 Additional Resources

- [Pod Overview](https://kubernetes.io/docs/concepts/workloads/pods/)
- [Debug Running Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/)
- [Multi-Container Pod Patterns](https://kubernetes.io/blog/2015/06/the-distributed-system-toolkit-patterns/)
- [Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)

## ✅ Module Completion

Excellent work! You've mastered pod fundamentals. You can now:
- Create and manage single and multi-container pods
- Debug pod issues effectively
- Implement common pod patterns
- Use init containers for setup tasks
- Access pods using port forwarding

### Next Steps
```bash
# Mark module as complete
./complete.sh

# Continue to Module 3: Workload Controllers
cd ../03-workloads
```

### Skills Acquired
- Pod creation and management
- Container debugging techniques
- Multi-container patterns
- Port forwarding
- Init container usage
- Troubleshooting skills