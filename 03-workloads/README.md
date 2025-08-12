# Module 3: Workload Controllers - The Power of Kubernetes

## 🎯 Learning Objectives

By the end of this module, you will deeply understand:
- ✅ WHY we need controllers (not just what they are)
- ✅ How ReplicaSets maintain desired state
- ✅ Deployments and their rolling update magic
- ✅ StatefulSets for databases and stateful apps
- ✅ DaemonSets for node-level services
- ✅ Jobs and CronJobs for batch processing
- ✅ The reconciliation loop - Kubernetes' core pattern

## 🤔 The Problem We're Solving

Remember Module 2 where we created pods manually? What happens when:
- A pod crashes?
- We need 50 copies of our app?
- We want to update our app without downtime?
- We need guaranteed ordering for databases?

**This is where controllers come in - they're the automation layer of Kubernetes.**

## 📚 Prerequisites

- ✅ Completed Module 2: Pods & Container Basics
- ✅ Understanding of pod lifecycle
- ✅ Working kind cluster

## 🚀 Quick Start

```bash
# Start the interactive lesson
./start.sh

# This module is heavily hands-on - you'll be typing commands
# and observing behaviors, not just running scripts!
```

## 📖 Lesson 1: Understanding Controllers - The Theory

### What is a Controller?

A controller is a control loop that:
1. **Observes** the current state
2. **Compares** to desired state
3. **Acts** to reconcile differences

Think of it like a thermostat:
- Desired state: 72°F
- Current state: 68°F
- Action: Turn on heat

### The Reconciliation Loop

```
┌─────────────────────────────────────┐
│                                     │
│    ┌──────────────────────┐        │
│    │  Observe Current     │        │
│    │  State               │        │
│    └──────────┬───────────┘        │
│               │                     │
│    ┌──────────▼───────────┐        │
│    │  Compare to Desired  │        │
│    │  State               │        │
│    └──────────┬───────────┘        │
│               │                     │
│         Difference?                 │
│          Yes │ No                   │
│              │  │                   │
│    ┌─────────▼──┴─────────┐        │
│    │  Take Action to      │        │
│    │  Reconcile           │        │
│    └──────────┬───────────┘        │
│               │                     │
└───────────────┴─────────────────────┘
         Continuous Loop
```

### Let's See It In Action

First, let's manually experience what a controller does:

```bash
# Create a pod manually
kubectl run manual-pod --image=nginx:alpine

# Now delete it
kubectl delete pod manual-pod

# Check - is it back?
kubectl get pods
# No! Because there's no controller watching it
```

Now let's use a controller:

```bash
# We'll create this step by step - don't copy/paste yet!
```

## 📖 Lesson 2: ReplicaSets - The Foundation

### Understanding ReplicaSets

A ReplicaSet ensures a specified number of pod replicas are running at any time.

Let's build one from scratch to understand it:

```yaml
# replicaset-demo.yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-replicaset
  labels:
    app: nginx
    tier: frontend
spec:
  replicas: 3  # Desired state: 3 pods
  selector:    # Which pods does this RS manage?
    matchLabels:
      app: nginx
  template:    # Template for creating pods
    metadata:
      labels:
        app: nginx  # MUST match selector
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
```

### Key Concepts to Understand

1. **replicas**: The desired number of pods
2. **selector**: How the RS identifies its pods (via labels)
3. **template**: The pod specification to create

### Hands-On: Observing the Controller

```bash
# Apply the ReplicaSet
kubectl apply -f manifests/replicaset-demo.yaml

# Watch what happens (keep this running in one terminal)
kubectl get pods -w

# In another terminal, delete a pod
kubectl delete pod <pod-name>

# Watch the first terminal - what happened?
# The ReplicaSet immediately created a new pod!
```

### Experiment: Breaking and Fixing

```bash
# Scale the ReplicaSet
kubectl scale replicaset nginx-replicaset --replicas=5

# Watch pods being created
kubectl get pods

# Now scale down
kubectl scale replicaset nginx-replicaset --replicas=2

# Watch pods being terminated
kubectl get pods

# What decides which pods get terminated?
```

### 🧪 Exercise: ReplicaSet Behavior

```bash
# Try to create a pod with the same label manually
kubectl run manual-nginx --image=nginx:alpine -l app=nginx

# What happens?
kubectl get pods

# The ReplicaSet adopts it or deletes it!
# Why? Because it matches the selector
```

## 📖 Lesson 3: Deployments - The Orchestrator

### Why Deployments?

ReplicaSets are great, but they can't:
- Update pods (change image version)
- Roll back to previous versions
- Pause/resume updates

Deployments add these capabilities!

### Building Understanding Step-by-Step

```yaml
# deployment-v1.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
        version: v1  # We'll use this to track versions
    spec:
      containers:
      - name: nginx
        image: nginx:1.19  # Specific version
        ports:
        - containerPort: 80
```

### Deploy and Observe

```bash
# Deploy version 1
kubectl apply -f manifests/deployment-v1.yaml

# Look at what was created
kubectl get deployments
kubectl get replicasets
kubectl get pods

# Notice: Deployment created a ReplicaSet, which created Pods!
# Deployment -> ReplicaSet -> Pods
```

### The Magic: Rolling Updates

Now let's update our application:

```bash
# First, let's watch the rollout status in one terminal
kubectl rollout status deployment/nginx-deployment --watch

# In another terminal, update the image
kubectl set image deployment/nginx-deployment nginx=nginx:1.20

# Watch what happens to pods
kubectl get pods -w

# What do you see?
# - New pods are created one by one
# - Old pods are terminated one by one
# - Zero downtime!
```

### Understanding Rollout Strategy

```yaml
# deployment-with-strategy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2        # Max pods above desired replicas during update
      maxUnavailable: 1  # Max pods that can be unavailable
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.19
        readinessProbe:  # Important for safe rollouts!
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
```

### Rollback - Your Safety Net

```bash
# Check rollout history
kubectl rollout history deployment/nginx-deployment

# Rollback to previous version
kubectl rollout undo deployment/nginx-deployment

# Watch the magic
kubectl get pods -w

# Rollback to specific revision
kubectl rollout undo deployment/nginx-deployment --to-revision=1
```

### 🧪 Exercise: Breaking and Fixing Deployments

```bash
# Let's deliberately break something
kubectl set image deployment/nginx-deployment nginx=nginx:invalid-version

# Watch what happens
kubectl rollout status deployment/nginx-deployment
kubectl get pods

# See the problem?
kubectl describe pod <failing-pod>

# Fix it with rollback
kubectl rollout undo deployment/nginx-deployment
```

## 📖 Lesson 4: StatefulSets - Order and Identity Matter

### The Stateful Challenge

Imagine deploying a database cluster:
- Each instance needs persistent storage
- They need stable network identities
- They must start in order (primary first, then replicas)
- Scaling must be controlled

StatefulSets solve these problems!

### Key Differences from Deployments

| Deployment | StatefulSet |
|------------|-------------|
| Pods are interchangeable | Each pod has unique identity |
| Random pod names | Predictable pod names (app-0, app-1) |
| No ordering | Ordered deployment and scaling |
| No stable storage | Stable persistent storage |

### Hands-On StatefulSet

```yaml
# statefulset-demo.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: "nginx"  # Requires a headless service
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:  # Each pod gets its own PVC!
  - metadata:
      name: www
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi
```

### Observe Ordered Creation

```bash
# First create a headless service (required for StatefulSets)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  clusterIP: None  # Headless service
  selector:
    app: nginx
  ports:
  - port: 80
EOF

# Now create the StatefulSet
kubectl apply -f manifests/statefulset-demo.yaml

# Watch the ordered creation
kubectl get pods -w

# Notice: web-0 starts first, then web-1, then web-2
# They start sequentially, not in parallel!
```

### Test Stable Identity

```bash
# Delete a pod
kubectl delete pod web-1

# Watch it come back with THE SAME NAME
kubectl get pods -w

# In a Deployment, you'd get a random new name
# In a StatefulSet, it's always web-1
```

### Ordered Termination

```bash
# Scale down
kubectl scale statefulset web --replicas=1

# Watch the order - terminates from highest to lowest
kubectl get pods -w

# web-2 terminates first, then web-1
```

## 📖 Lesson 5: DaemonSets - One Per Node

### Use Cases for DaemonSets

- Log collectors (one per node)
- Monitoring agents
- Network plugins
- Storage drivers

### Creating a DaemonSet

```yaml
# daemonset-demo.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-monitor
spec:
  selector:
    matchLabels:
      app: node-monitor
  template:
    metadata:
      labels:
        app: node-monitor
    spec:
      containers:
      - name: monitor
        image: busybox
        command: ['sh', '-c']
        args:
        - while true; do
            echo "Monitoring node $(hostname)";
            sleep 30;
          done
        resources:
          limits:
            memory: "128Mi"
            cpu: "100m"
```

### Observe DaemonSet Behavior

```bash
# Apply the DaemonSet
kubectl apply -f manifests/daemonset-demo.yaml

# Check pods - one per node!
kubectl get pods -o wide

# How many nodes do you have?
kubectl get nodes

# Same number of pods as nodes!
```

## 📖 Lesson 6: Jobs and CronJobs - Task Runners

### Jobs - Run to Completion

```yaml
# job-demo.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi-calculator
spec:
  completions: 3      # Run 3 times total
  parallelism: 2      # Run 2 at a time
  backoffLimit: 4     # Retry 4 times on failure
  template:
    spec:
      containers:
      - name: pi
        image: perl:5.34
        command: ["perl", "-Mbignum=bpi", "-wle", "print bpi(2000)"]
      restartPolicy: Never  # Important for Jobs!
```

### Run and Observe

```bash
# Create the job
kubectl apply -f manifests/job-demo.yaml

# Watch the pods
kubectl get pods -w

# Check job status
kubectl describe job pi-calculator

# See the output
kubectl logs <pod-name>
```

### CronJobs - Scheduled Tasks

```yaml
# cronjob-demo.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hello
spec:
  schedule: "*/1 * * * *"  # Every minute
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: hello
            image: busybox:1.28
            command: ['sh', '-c']
            args:
            - date; echo Hello from Kubernetes CronJob
          restartPolicy: OnFailure
```

```bash
# Create CronJob
kubectl apply -f manifests/cronjob-demo.yaml

# Wait a minute and check
kubectl get jobs
kubectl get pods

# Check logs
kubectl logs <pod-name>
```

## 🏆 Module Challenge: Design Your Architecture

Now that you understand controllers, design a solution:

**Scenario**: You need to deploy a web application with:
1. Frontend (3 replicas, stateless)
2. API server (5 replicas, stateless)
3. Redis cache (1 instance, needs persistence)
4. Background job processor (runs every hour)
5. Log collector (one per node)

**Your Task**: 
- Which controller for each component?
- Write the YAML manifests
- Deploy and verify

Run the challenge:
```bash
./challenge/controller-challenge.sh
```

## 💡 Key Takeaways

1. **Controllers implement the reconciliation loop** - constantly ensuring desired state
2. **ReplicaSets** maintain a number of identical pods
3. **Deployments** add rollout strategies to ReplicaSets
4. **StatefulSets** provide ordering and stable identity
5. **DaemonSets** ensure one pod per node
6. **Jobs** run tasks to completion
7. **CronJobs** run jobs on a schedule

## 🔍 Debugging Controllers

```bash
# Check controller status
kubectl describe deployment <name>
kubectl describe replicaset <name>

# View controller events
kubectl get events --sort-by='.lastTimestamp'

# Check rollout status
kubectl rollout status deployment/<name>

# View rollout history
kubectl rollout history deployment/<name>
```

## 📚 Additional Resources

- [Kubernetes Controllers](https://kubernetes.io/docs/concepts/architecture/controller/)
- [Deployment Strategies](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#strategy)
- [StatefulSet Basics](https://kubernetes.io/docs/tutorials/stateful-application/basic-stateful-set/)

## ✅ Module Completion

You now understand not just WHAT controllers do, but WHY they exist and HOW they work!

### Skills Mastered
- Controller patterns and reconciliation
- Deployment strategies and rollbacks
- Stateful vs stateless workloads
- Job scheduling and batch processing
- Node-level service deployment

### Next Steps
```bash
# Mark module complete
./complete.sh

# Continue to Module 4: Services & Networking
cd ../04-services-networking
```