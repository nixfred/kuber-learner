#!/bin/bash

# Kubernetes Learning Lab - Interactive Trainer
# This script provides an interactive learning experience for Kubernetes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Progress tracking
PROGRESS_DIR=".progress"
mkdir -p "$PROGRESS_DIR"

# ASCII Art Banner
show_banner() {
    clear
    echo -e "${BLUE}"
    cat << "EOF"
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║     🚀 KUBERNETES LEARNING LAB - INTERACTIVE TRAINER 🚀      ║
    ║                                                               ║
    ║           Master Kubernetes with Hands-On Practice           ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"
    
    local missing_tools=()
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    else
        echo -e "${GREEN}✓${NC} Docker installed"
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        echo -e "${YELLOW}⚠${NC} kubectl not found - will install in Module 1"
    else
        echo -e "${GREEN}✓${NC} kubectl installed"
    fi
    
    # Check kind
    if ! command -v kind &> /dev/null; then
        echo -e "${YELLOW}⚠${NC} kind not found - will install in Module 1"
    else
        echo -e "${GREEN}✓${NC} kind installed"
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "${RED}❌ Missing required tools: ${missing_tools[*]}${NC}"
        echo -e "${YELLOW}Please install Docker before continuing.${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Prerequisites check complete!${NC}\n"
    return 0
}

# Get current progress
get_progress() {
    local module=$1
    if [ -f "$PROGRESS_DIR/module_$module.complete" ]; then
        echo "completed"
    elif [ -f "$PROGRESS_DIR/module_$module.progress" ]; then
        echo "in_progress"
    else
        echo "not_started"
    fi
}

# Mark module complete
mark_complete() {
    local module=$1
    touch "$PROGRESS_DIR/module_$module.complete"
    echo -e "${GREEN}🎉 Module $module completed!${NC}"
}

# Show main menu
show_menu() {
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                    LEARNING MODULES                              ${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}\n"
    
    local modules=(
        "Cluster Setup & Architecture"
        "Pods & Container Basics"
        "Workload Controllers"
        "Services & Networking"
        "Configuration & Secrets"
        "Storage Solutions"
        "Monitoring & Observability"
        "Troubleshooting Mastery"
        "Production Applications"
    )
    
    for i in "${!modules[@]}"; do
        local num=$((i + 1))
        local status=$(get_progress $num)
        local status_icon=""
        local status_color=""
        
        case $status in
            "completed")
                status_icon="✓"
                status_color="${GREEN}"
                ;;
            "in_progress")
                status_icon="▶"
                status_color="${YELLOW}"
                ;;
            *)
                status_icon=" "
                status_color="${WHITE}"
                ;;
        esac
        
        printf "${status_color}[%s] %2d. %-40s${NC}\n" "$status_icon" "$num" "${modules[$i]}"
    done
    
    echo -e "\n${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                    ADDITIONAL OPTIONS                            ${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}\n"
    
    echo -e "${WHITE} P. Show Progress Report${NC}"
    echo -e "${WHITE} R. Reset All Progress${NC}"
    echo -e "${WHITE} H. Open HTML Dashboard${NC}"
    echo -e "${WHITE} T. Run Tests${NC}"
    echo -e "${WHITE} Q. Quit${NC}\n"
}

# Show progress report
show_progress_report() {
    clear
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                    PROGRESS REPORT                               ${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}\n"
    
    local total_modules=9
    local completed_count=0
    
    for i in $(seq 1 $total_modules); do
        if [ -f "$PROGRESS_DIR/module_$i.complete" ]; then
            ((completed_count++))
        fi
    done
    
    local percentage=$((completed_count * 100 / total_modules))
    
    echo -e "${WHITE}Overall Progress:${NC}"
    echo -n "["
    
    local filled=$((percentage / 5))
    for i in $(seq 1 20); do
        if [ $i -le $filled ]; then
            echo -n "█"
        else
            echo -n "░"
        fi
    done
    
    echo "] $percentage%"
    echo -e "\n${WHITE}Modules Completed: $completed_count / $total_modules${NC}"
    
    # Show time spent
    if [ -f "$PROGRESS_DIR/time_spent.txt" ]; then
        local time_spent=$(cat "$PROGRESS_DIR/time_spent.txt")
        echo -e "${WHITE}Time Invested: $time_spent hours${NC}"
    fi
    
    # Show achievements
    echo -e "\n${YELLOW}🏆 Achievements:${NC}"
    if [ $completed_count -ge 1 ]; then
        echo -e "${GREEN}✓ First Steps - Completed your first module${NC}"
    fi
    if [ $completed_count -ge 5 ]; then
        echo -e "${GREEN}✓ Halfway There - 5 modules completed${NC}"
    fi
    if [ $completed_count -eq 9 ]; then
        echo -e "${GREEN}✓ Kubernetes Master - All modules completed!${NC}"
    fi
    
    echo -e "\nPress Enter to continue..."
    read
}

# Launch module
launch_module() {
    local module_num=$1
    local module_dirs=(
        "01-cluster-setup"
        "02-pods-basics"
        "03-workloads"
        "04-services-networking"
        "05-config-secrets"
        "06-storage"
        "07-monitoring"
        "08-troubleshooting"
        "09-real-world"
    )
    
    if [ $module_num -lt 1 ] || [ $module_num -gt 9 ]; then
        echo -e "${RED}Invalid module number${NC}"
        return 1
    fi
    
    # Check if previous module is completed (except for module 1)
    if [ $module_num -gt 1 ]; then
        local prev_module=$((module_num - 1))
        if [ ! -f "$PROGRESS_DIR/module_$prev_module.complete" ]; then
            echo -e "${YELLOW}⚠ Please complete Module $prev_module first!${NC}"
            echo "Press Enter to continue..."
            read
            return 1
        fi
    fi
    
    local module_dir="${module_dirs[$((module_num - 1))]}"
    
    if [ ! -d "$module_dir" ]; then
        echo -e "${YELLOW}Module directory not found. Creating it now...${NC}"
        mkdir -p "$module_dir"
    fi
    
    # Mark module as in progress
    touch "$PROGRESS_DIR/module_$module_num.progress"
    
    clear
    echo -e "${CYAN}Starting Module $module_num...${NC}"
    
    # Check if start script exists
    if [ -f "$module_dir/start.sh" ]; then
        cd "$module_dir"
        bash start.sh
        cd ..
    else
        echo -e "${YELLOW}Module content is being prepared...${NC}"
        echo -e "Check $module_dir/ directory for exercises"
    fi
    
    echo -e "\nPress Enter to return to main menu..."
    read
}

# Reset progress
reset_progress() {
    echo -e "${YELLOW}⚠ Warning: This will reset all your progress!${NC}"
    echo -n "Are you sure? (y/N): "
    read -r confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        rm -rf "$PROGRESS_DIR"/*
        echo -e "${GREEN}Progress reset successfully${NC}"
    else
        echo -e "${BLUE}Reset cancelled${NC}"
    fi
    
    echo "Press Enter to continue..."
    read
}

# Open HTML dashboard
open_dashboard() {
    local dashboard_file="trainer/index.html"
    
    if [ -f "$dashboard_file" ]; then
        echo -e "${CYAN}Opening dashboard in your browser...${NC}"
        
        # Try different commands to open browser
        if command -v xdg-open &> /dev/null; then
            xdg-open "$dashboard_file" 2>/dev/null &
        elif command -v open &> /dev/null; then
            open "$dashboard_file" 2>/dev/null &
        else
            echo -e "${YELLOW}Please open $dashboard_file in your browser manually${NC}"
        fi
    else
        echo -e "${RED}Dashboard file not found${NC}"
    fi
    
    echo "Press Enter to continue..."
    read
}

# Run tests
run_tests() {
    echo -e "${CYAN}Running validation tests...${NC}\n"
    
    # Check cluster status
    if command -v kind &> /dev/null && kind get clusters 2>/dev/null | grep -q kind; then
        echo -e "${GREEN}✓ Kind cluster is running${NC}"
        kubectl cluster-info --context kind-kind 2>/dev/null || true
    else
        echo -e "${YELLOW}⚠ No kind cluster found${NC}"
    fi
    
    echo -e "\nPress Enter to continue..."
    read
}

# Main loop
main() {
    show_banner
    
    if ! check_prerequisites; then
        echo "Please install the missing prerequisites and try again."
        exit 1
    fi
    
    while true; do
        clear
        show_banner
        show_menu
        
        echo -n "Enter your choice: "
        read -r choice
        
        case $choice in
            [1-9])
                launch_module "$choice"
                ;;
            [Pp])
                show_progress_report
                ;;
            [Rr])
                reset_progress
                ;;
            [Hh])
                open_dashboard
                ;;
            [Tt])
                run_tests
                ;;
            [Qq])
                echo -e "${GREEN}Thanks for learning with Kubernetes Lab! Keep practicing! 🚀${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Run main function
main