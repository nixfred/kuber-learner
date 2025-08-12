#!/bin/bash

# Exercise 1: Verify Tools Installation
# This script validates that all required tools are properly installed

set -e

# Colors for web-friendly output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Progress tracking for web platform
EXERCISE_ID="mod1-ex1"
PROGRESS_FILE="../.progress/${EXERCISE_ID}.json"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Exercise 1: Verify Tool Installation                  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to check tool and provide feedback
check_tool() {
    local tool=$1
    local required=$2
    local version_cmd=$3
    
    echo -n "Checking $tool... "
    
    if command -v $tool &> /dev/null; then
        version=$($version_cmd 2>&1 | head -1)
        echo -e "${GREEN}✓ INSTALLED${NC}"
        echo "  Version: $version"
        return 0
    else
        if [ "$required" = "true" ]; then
            echo -e "${RED}✗ NOT FOUND${NC}"
            echo -e "  ${YELLOW}This tool is required. Please install it.${NC}"
            return 1
        else
            echo -e "${YELLOW}⚠ NOT FOUND${NC}"
            echo -e "  ${CYAN}This tool is optional but recommended.${NC}"
            return 0
        fi
    fi
}

# Track results for scoring
score=0
total=4

echo -e "${CYAN}Validating Required Tools:${NC}"
echo "══════════════════════════════════════════════════"

# Check Docker
if check_tool "docker" "true" "docker --version"; then
    ((score++))
    
    # Additional Docker checks
    echo -n "  Checking Docker daemon... "
    if docker info &> /dev/null; then
        echo -e "${GREEN}✓ RUNNING${NC}"
    else
        echo -e "${RED}✗ NOT RUNNING${NC}"
        echo -e "  ${YELLOW}Start Docker: sudo systemctl start docker${NC}"
    fi
fi
echo ""

# Check kubectl
if check_tool "kubectl" "true" "kubectl version --client --short"; then
    ((score++))
fi
echo ""

# Check kind
if check_tool "kind" "true" "kind version"; then
    ((score++))
fi
echo ""

# Check optional tools
echo -e "${CYAN}Checking Optional Tools:${NC}"
echo "══════════════════════════════════════════════════"

check_tool "helm" "false" "helm version --short"
echo ""
check_tool "jq" "false" "jq --version"
echo ""

# System requirements check
echo -e "${CYAN}System Requirements Check:${NC}"
echo "══════════════════════════════════════════════════"

# Check available memory
echo -n "Available Memory: "
available_mem=$(free -h | awk '/^Mem:/ {print $7}')
total_mem=$(free -h | awk '/^Mem:/ {print $2}')
echo "$available_mem / $total_mem"

mem_gb=$(free -g | awk '/^Mem:/ {print $7}')
if [ "$mem_gb" -ge 2 ]; then
    echo -e "  ${GREEN}✓ Sufficient memory available${NC}"
    ((score++))
else
    echo -e "  ${YELLOW}⚠ Low memory - recommend at least 2GB free${NC}"
fi
echo ""

# Check disk space
echo -n "Available Disk Space: "
disk_space=$(df -h / | awk 'NR==2 {print $4}')
echo "$disk_space"

disk_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$disk_gb" -ge 10 ]; then
    echo -e "  ${GREEN}✓ Sufficient disk space${NC}"
else
    echo -e "  ${YELLOW}⚠ Low disk space - recommend at least 10GB free${NC}"
fi
echo ""

# Final score
echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
echo -e "${WHITE}Exercise Score: $score/$total${NC}"

if [ $score -eq $total ]; then
    echo -e "${GREEN}🎉 Perfect! All tools are properly installed!${NC}"
    
    # Save success for web platform
    mkdir -p $(dirname "$PROGRESS_FILE")
    echo "{\"exercise\":\"$EXERCISE_ID\",\"score\":$score,\"total\":$total,\"completed\":true,\"timestamp\":\"$(date -Iseconds)\"}" > "$PROGRESS_FILE"
    
    echo -e "\n${CYAN}You're ready to proceed to the next exercise!${NC}"
elif [ $score -ge 3 ]; then
    echo -e "${YELLOW}⚠ Almost there! Please install the missing tools.${NC}"
else
    echo -e "${RED}❌ Several tools are missing. Please install them before continuing.${NC}"
fi

# Provide installation commands if needed
if [ $score -lt $total ]; then
    echo -e "\n${CYAN}Quick Installation Commands:${NC}"
    echo "════════════════════════════════════════"
    
    if ! command -v kubectl &> /dev/null; then
        echo "kubectl:"
        echo "  curl -LO https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        echo "  chmod +x kubectl && sudo mv kubectl /usr/local/bin/"
        echo ""
    fi
    
    if ! command -v kind &> /dev/null; then
        echo "kind:"
        echo "  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64"
        echo "  chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind"
        echo ""
    fi
fi

echo -e "\n${YELLOW}Press Enter to continue...${NC}"
read