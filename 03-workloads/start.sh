#!/bin/bash

# Module 3: Workload Controllers - Interactive Learning Script
# This module focuses on UNDERSTANDING, not just doing

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

# Progress tracking
PROGRESS_FILE="../.progress/module_3.progress"
mkdir -p "../.progress"
mkdir -p "manifests"

clear

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      MODULE 3: WORKLOAD CONTROLLERS                          ║${NC}"
echo -e "${BLUE}║      Understanding Kubernetes Automation                      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Welcome to the heart of Kubernetes - Controllers!${NC}"
echo ""
echo -e "${YELLOW}This module is different:${NC}"
echo "• We'll build understanding step-by-step"
echo "• You'll type commands and observe behaviors"
echo "• We'll break things to understand how they fix themselves"
echo "• This is about the 'why', not just the 'how'"
echo ""

# Helper functions
pause() {
    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
    read
}

ask_user() {
    local prompt=$1
    echo -e "${CYAN}$prompt${NC}"
    read -r user_response
    echo "$user_response"
}

run_command() {
    local explanation=$1
    local command=$2
    echo -e "\n${CYAN}$explanation${NC}"
    echo -e "${WHITE}$ ${YELLOW}$command${NC}\n"
    eval $command || true
}

create_manifest() {
    local filename=$1
    local content=$2
    echo "$content" > "manifests/$filename"
    echo -e "${GREEN}✓${NC} Created manifests/$filename"
}

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}✗ No cluster found. Please complete Module 1 first.${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} Kubernetes cluster is running"

pause

# Part 1: Understanding the Problem
clear
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}     PART 1: THE PROBLEM WITH MANUAL POD MANAGEMENT            ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}Let's start with a story...${NC}"
echo ""
echo "Imagine you're running a web service with 50 pods."
echo "It's 3 AM and 5 pods crash."
echo ""
echo -e "${YELLOW}Question: What happens with manually created pods?${NC}"
echo "a) They automatically restart"
echo "b) They stay dead until you wake up"
echo "c) Kubernetes emails you"
echo ""
answer=$(ask_user "Your answer (a/b/c):")

if [ "$answer" = "b" ]; then
    echo -e "${GREEN}✓ Correct!${NC} Manual pods don't resurrect themselves."
else
    echo -e "${YELLOW}Actually, it's 'b' - manual pods stay dead!${NC}"
fi

echo -e "\n${CYAN}Let's prove this...${NC}"

run_command "Create a manual pod:" "kubectl run manual-nginx --image=nginx:alpine"

run_command "Verify it's running:" "kubectl get pod manual-nginx"

echo -e "\n${YELLOW}Now, let's 'accidentally' delete it (simulating a crash):${NC}"
run_command "Delete the pod:" "kubectl delete pod manual-nginx --grace-period=0 --force"

run_command "Check if it came back:" "kubectl get pods"

echo -e "\n${RED}It's gone forever!${NC} This is why we need controllers."

pause

# Part 2: Enter the ReplicaSet
clear
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}     PART 2: REPLICASETS - YOUR FIRST CONTROLLER               ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}The Controller Pattern:${NC}"
echo "┌────────────────────────┐"
echo "│  1. Observe state      │"
echo "│  2. Compare to desired │"
echo "│  3. Take action        │"
echo "│  4. Repeat forever     │"
echo "└────────────────────────┘"
echo ""

echo -e "${CYAN}Let's build a ReplicaSet step by step...${NC}"
echo ""
echo -e "${YELLOW}First, let's think about what we need:${NC}"
echo "1. How many pods do we want? (replicas)"
echo "2. How do we identify our pods? (labels)"
echo "3. What should the pods look like? (template)"
echo ""

create_manifest "replicaset-v1.yaml" 'apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-rs
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
      controller: replicaset-demo
  template:
    metadata:
      labels:
        app: nginx
        controller: replicaset-demo
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80'

echo -e "\n${CYAN}Before we apply this, predict what will happen:${NC}"
echo "a) 1 pod will be created"
echo "b) 3 pods will be created"
echo "c) Nothing will happen"
answer=$(ask_user "Your prediction (a/b/c):")

run_command "Let's apply and see:" "kubectl apply -f manifests/replicaset-v1.yaml"

run_command "Watch the pods appear:" "kubectl get pods -l controller=replicaset-demo"

if [ "$answer" = "b" ]; then
    echo -e "${GREEN}✓ You were right! 3 pods were created.${NC}"
else
    echo -e "${YELLOW}3 pods were created - one for each replica!${NC}"
fi

pause

# Demonstrate self-healing
echo -e "\n${CYAN}Now for the magic - self-healing!${NC}"
echo -e "${YELLOW}Let's 'accidentally' delete a pod and watch what happens...${NC}"
echo ""

# Get a pod name
pod_name=$(kubectl get pods -l controller=replicaset-demo -o jsonpath='{.items[0].metadata.name}')

echo -e "${CYAN}Watch this carefully - I'll delete pod ${pod_name}${NC}"
echo -e "${YELLOW}Keep your eyes on the pod list!${NC}"
echo ""

# Start watching in background
kubectl get pods -l controller=replicaset-demo -w &
WATCH_PID=$!

sleep 2

echo -e "\n${RED}Deleting pod now...${NC}"
kubectl delete pod $pod_name --grace-period=0 --force &> /dev/null

sleep 5

# Stop watching
kill $WATCH_PID 2>/dev/null || true

echo -e "\n${GREEN}Did you see it? The ReplicaSet immediately created a replacement!${NC}"

run_command "Final count - still 3 pods:" "kubectl get pods -l controller=replicaset-demo"

pause

# Part 3: Deployments - The Full Power
clear
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}     PART 3: DEPLOYMENTS - UPDATES WITHOUT DOWNTIME            ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}ReplicaSets are great, but they have a limitation...${NC}"
echo ""
echo -e "${YELLOW}Challenge: How do you update your app to a new version?${NC}"
echo "With ReplicaSet: Delete all pods and recreate (downtime!)"
echo "With Deployment: Rolling update (zero downtime!)"
echo ""

echo -e "${CYAN}Let's create a Deployment and watch it work:${NC}"

create_manifest "deployment-v1.yaml" 'apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 4
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
        version: v1
    spec:
      containers:
      - name: web
        image: nginx:1.19
        ports:
        - containerPort: 80
        env:
        - name: VERSION
          value: "1.19"'

run_command "Create the deployment:" "kubectl apply -f manifests/deployment-v1.yaml"

run_command "Watch the rollout:" "kubectl rollout status deployment/web-app"

run_command "See what was created:" "kubectl get deploy,rs,pods -l app=web"

echo -e "\n${CYAN}Notice the hierarchy:${NC}"
echo "Deployment → ReplicaSet → Pods"
echo ""
echo "The Deployment manages ReplicaSets"
echo "The ReplicaSet manages Pods"

pause

# Rolling Update Demo
echo -e "\n${CYAN}Now the magic - Rolling Updates!${NC}"
echo -e "${YELLOW}We'll update from nginx:1.19 to nginx:1.20${NC}"
echo "Watch how pods are replaced one by one..."
echo ""

echo -e "${CYAN}In a production environment, this means:${NC}"
echo "• No downtime"
echo "• Gradual rollout"
echo "• Ability to rollback if something goes wrong"
echo ""

echo -e "${YELLOW}Starting the update...${NC}"

# Watch pods in background
kubectl get pods -l app=web -w &
WATCH_PID=$!

sleep 2

run_command "Update the image:" "kubectl set image deployment/web-app web=nginx:1.20"

echo -e "\n${CYAN}Watch the pods above - see how they're replaced gradually?${NC}"

sleep 10

kill $WATCH_PID 2>/dev/null || true

run_command "Check the new version:" "kubectl get pods -l app=web -o jsonpath='{.items[*].spec.containers[0].image}' | tr ' ' '\n' | sort -u"

pause

# Rollback Demo
echo -e "\n${CYAN}What if the new version has a bug? ROLLBACK!${NC}"

run_command "Check rollout history:" "kubectl rollout history deployment/web-app"

run_command "Rollback to previous version:" "kubectl rollout undo deployment/web-app"

run_command "Verify we're back to 1.19:" "kubectl get pods -l app=web -o jsonpath='{.items[*].spec.containers[0].image}' | tr ' ' '\n' | sort -u"

echo -e "\n${GREEN}✓ Rollback complete! Crisis averted!${NC}"

pause

# Part 4: StatefulSets - When Order Matters
clear
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}     PART 4: STATEFULSETS - DATABASES & ORDERED APPS           ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}Imagine deploying a database cluster...${NC}"
echo ""
echo "With Deployments:"
echo "• Pods get random names (web-7d4f9b7c4-x2k9p)"
echo "• They start in random order"
echo "• They have no stable identity"
echo ""
echo "With StatefulSets:"
echo "• Pods get predictable names (database-0, database-1)"
echo "• They start in order (0, then 1, then 2)"
echo "• Each keeps its identity even after restart"
echo ""

# Create headless service first
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: nginx-headless
spec:
  clusterIP: None
  selector:
    app: nginx-sts
  ports:
  - port: 80
EOF

create_manifest "statefulset-demo.yaml" 'apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web-sts
spec:
  serviceName: "nginx-headless"
  replicas: 3
  selector:
    matchLabels:
      app: nginx-sts
  template:
    metadata:
      labels:
        app: nginx-sts
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80'

echo -e "${CYAN}Watch the ordered creation - they start one by one:${NC}"

kubectl apply -f manifests/statefulset-demo.yaml

# Watch creation
kubectl get pods -l app=nginx-sts -w &
WATCH_PID=$!

sleep 15

kill $WATCH_PID 2>/dev/null || true

echo -e "\n${GREEN}Notice the names: web-sts-0, web-sts-1, web-sts-2${NC}"
echo -e "${GREEN}They started in order!${NC}"

pause

# Part 5: DaemonSets and Jobs
clear
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}     PART 5: SPECIALIZED CONTROLLERS                           ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}DaemonSets - One Pod Per Node${NC}"
echo "Perfect for:"
echo "• Log collectors"
echo "• Monitoring agents"
echo "• Network plugins"
echo ""

create_manifest "daemonset-demo.yaml" 'apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-monitor
spec:
  selector:
    matchLabels:
      app: monitor
  template:
    metadata:
      labels:
        app: monitor
    spec:
      containers:
      - name: monitor
        image: busybox
        command: ["sh", "-c", "while true; do echo Monitoring $(hostname); sleep 60; done"]'

run_command "Create DaemonSet:" "kubectl apply -f manifests/daemonset-demo.yaml"

run_command "Check pods - one per node:" "kubectl get pods -l app=monitor -o wide"

echo -e "\n${CYAN}Jobs - Run to Completion${NC}"

create_manifest "job-demo.yaml" 'apiVersion: batch/v1
kind: Job
metadata:
  name: calculate-pi
spec:
  template:
    spec:
      containers:
      - name: pi
        image: perl:5.34
        command: ["perl", "-Mbignum=bpi", "-wle", "print bpi(100)"]
      restartPolicy: Never'

run_command "Run a job:" "kubectl apply -f manifests/job-demo.yaml"

sleep 5

run_command "Check job status:" "kubectl get jobs"

pod_name=$(kubectl get pods -l job-name=calculate-pi -o jsonpath='{.items[0].metadata.name}')
run_command "See the result:" "kubectl logs $pod_name"

pause

# Interactive Quiz
clear
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}     KNOWLEDGE CHECK                                           ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}Scenario-based questions to test understanding:${NC}"
echo ""

echo -e "${YELLOW}1. You need to deploy a web application with 10 replicas that can be updated without downtime.${NC}"
echo "   Which controller?"
answer=$(ask_user "Your answer:")
echo -e "${GREEN}Answer: Deployment${NC} - It handles replicas and rolling updates\n"

echo -e "${YELLOW}2. You're deploying MongoDB with 3 replicas that need persistent storage and ordered startup.${NC}"
echo "   Which controller?"
answer=$(ask_user "Your answer:")
echo -e "${GREEN}Answer: StatefulSet${NC} - It provides ordering and stable identity\n"

echo -e "${YELLOW}3. You need to run a log collector on every node in your cluster.${NC}"
echo "   Which controller?"
answer=$(ask_user "Your answer:")
echo -e "${GREEN}Answer: DaemonSet${NC} - It ensures one pod per node\n"

echo -e "${YELLOW}4. You need to run a database backup every night at 2 AM.${NC}"
echo "   Which controller?"
answer=$(ask_user "Your answer:")
echo -e "${GREEN}Answer: CronJob${NC} - It runs jobs on a schedule\n"

pause

# Module Summary
clear
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}     MODULE 3 COMPLETE: YOU UNDERSTAND CONTROLLERS!            ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${GREEN}🎉 Congratulations! You've mastered Kubernetes Controllers!${NC}"
echo ""
echo "Key Insights You've Gained:"
echo -e "  ${GREEN}✓${NC} Controllers implement reconciliation loops"
echo -e "  ${GREEN}✓${NC} ReplicaSets maintain desired pod count"
echo -e "  ${GREEN}✓${NC} Deployments add rolling updates and rollbacks"
echo -e "  ${GREEN}✓${NC} StatefulSets provide ordering and identity"
echo -e "  ${GREEN}✓${NC} DaemonSets ensure node coverage"
echo -e "  ${GREEN}✓${NC} Jobs run tasks to completion"
echo ""

# Save progress
touch "$PROGRESS_FILE"
echo "$(date): Module 3 completed" >> "$PROGRESS_FILE"

echo -e "${CYAN}Practice Exercises:${NC}"
echo "1. Deploy an app with 5 replicas and practice scaling"
echo "2. Perform a rolling update and rollback"
echo "3. Create a StatefulSet with persistent volumes"
echo "4. Set up a CronJob that runs every 5 minutes"
echo ""

echo -e "${CYAN}Clean up this module's resources:${NC}"
echo "kubectl delete deploy,rs,sts,ds,job,cronjob --all"
echo ""

echo -e "${YELLOW}Ready for Module 4: Services & Networking${NC}"
echo -e "${GREEN}Press Enter to exit${NC}"
read