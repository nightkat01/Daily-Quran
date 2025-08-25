#!/bin/bash

# Robust shell script settings
set -euo pipefail

# Global constants
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'

# Configuration constants
readonly CONFIG_DIR="$HOME/.config/quran-verses"
readonly BASHRC_FILE="$HOME/.bashrc"
readonly BACKUP_PATTERN="$BASHRC_FILE.backup.*"

# Show ASCII title
show_title() {
    clear
    echo -e "${RED}"
    echo "██╗   ██╗███╗   ██╗██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     "
    echo "██║   ██║████╗  ██║██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     "
    echo "██║   ██║██╔██╗ ██║██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     "
    echo "██║   ██║██║╚██╗██║██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     "
    echo "╚██████╔╝██║ ╚████║██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗"
    echo " ╚═════╝ ╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝"
    echo -e "${NC}"
    echo -e "${WHITE}                    Daily Quran Terminal Uninstaller${NC}"
    echo -e "${YELLOW}                     Cleaning up your system${NC}"
    echo ""
}

# Function to ask yes/no questions
ask_yes_no() {
    local question="$1"
    local response
    while true; do
        echo -e "${BLUE}$question ${WHITE}(y/n):${NC} \c"
        read -r response
        case $response in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo -e "${RED}Please answer yes (y) or no (n).${NC}";;
        esac
    done
}

# Function to show loading animation
show_loading() {
    local message="$1"
    local duration="${2:-2}"
    echo -e "${BLUE}$message${NC}"
    
    local spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local count=0
    
    for ((i=0; i<duration*10; i++)); do
        printf "\r${YELLOW}${spinner[count]} Processing...${NC}"
        count=$(((count+1) % ${#spinner[@]}))
        sleep 0.1
    done
    printf "\r${GREEN}✅ Complete!${NC}\n"
}

# Check if Daily Quran Terminal is installed
check_installation() {
    local is_installed=false
    
    if [[ -d "$CONFIG_DIR" ]]; then
        echo -e "${GREEN}✅ Configuration directory found${NC}"
        is_installed=true
    fi
    
    if grep -q "quran-verses/display-verse.sh" "$BASHRC_FILE" 2>/dev/null; then
        echo -e "${GREEN}✅ .bashrc entries found${NC}"
        is_installed=true
    fi
    
    if [[ "$is_installed" == "false" ]]; then
        echo -e "${YELLOW}⚠️  Daily Quran Terminal doesn't appear to be installed.${NC}"
        if ! ask_yes_no "Continue with cleanup anyway?"; then
            echo -e "${BLUE}ℹ️  Uninstall cancelled.${NC}"
            exit 0
        fi
    fi
}

# Find and list available backups
list_backups() {
    local backups
    mapfile -t backups < <(find "$HOME" -maxdepth 1 -name "$(basename "$BASHRC_FILE").backup.*" 2>/dev/null | sort)
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No .bashrc backups found${NC}"
        return 1
    fi
    
    echo -e "${CYAN}📁 Available .bashrc backups:${NC}"
    for i in "${!backups[@]}"; do
        local backup_file="${backups[$i]}"
        local backup_date
        backup_date=$(basename "$backup_file" | sed 's/.*backup\.//')
        local formatted_date
        formatted_date=$(date -d "${backup_date:0:8} ${backup_date:9:2}:${backup_date:11:2}:${backup_date:13:2}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$backup_date")
        echo -e "${WHITE}$((i+1))) ${backup_file}${NC} ${BLUE}(${formatted_date})${NC}"
    done
    
    return 0
}

# Restore bashrc from backup
restore_bashrc() {
    if ! list_backups; then
        echo -e "${YELLOW}⚠️  Cannot restore .bashrc - no backups available${NC}"
        return 1
    fi
    
    echo ""
    if ask_yes_no "Would you like to restore your .bashrc from a backup?"; then
        local backups
        mapfile -t backups < <(find "$HOME" -maxdepth 1 -name "$(basename "$BASHRC_FILE").backup.*" 2>/dev/null | sort)
        
        local choice
        while true; do
            echo -e "${BLUE}Enter backup number to restore (or 0 to skip):${NC} \c"
            read -r choice
            
            if [[ "$choice" == "0" ]]; then
                echo -e "${BLUE}ℹ️  Skipping .bashrc restoration${NC}"
                return 0
            elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#backups[@]} ]]; then
                local selected_backup="${backups[$((choice-1))]}"
                cp "$selected_backup" "$BASHRC_FILE"
                echo -e "${GREEN}✅ .bashrc restored from: $(basename "$selected_backup")${NC}"
                return 0
            else
                echo -e "${RED}Please enter a valid number (1-${#backups[@]}) or 0 to skip.${NC}"
            fi
        done
    else
        echo -e "${BLUE}ℹ️  Skipping .bashrc restoration${NC}"
        return 0
    fi
}

# Remove entries from bashrc without restoration
remove_bashrc_entries() {
    if [[ ! -f "$BASHRC_FILE" ]]; then
        echo -e "${YELLOW}⚠️  .bashrc file not found${NC}"
        return 0
    fi
    
    # Create a temporary file
    local temp_file
    temp_file=$(mktemp)
    
    # Remove the Quran verses section
    awk '
    /^# Display daily Quran verse$/ {
        getline
        if ($0 ~ /quran-verses\/display-verse\.sh/) {
            # Skip both the comment and the command
            next
        } else {
            # Print the comment if the next line is not our command
            print "# Display daily Quran verse"
            print $0
        }
        next
    }
    /quran-verses\/display-verse\.sh/ {
        # Skip standalone command lines
        next
    }
    {
        print $0
    }
    ' "$BASHRC_FILE" > "$temp_file"
    
    # Replace original with cleaned version
    mv "$temp_file" "$BASHRC_FILE"
    echo -e "${GREEN}✅ Removed Daily Quran entries from .bashrc${NC}"
}

# Remove configuration directory
remove_config_dir() {
    if [[ -d "$CONFIG_DIR" ]]; then
        rm -rf "$CONFIG_DIR"
        echo -e "${GREEN}✅ Removed configuration directory${NC}"
    else
        echo -e "${BLUE}ℹ️  Configuration directory not found${NC}"
    fi
}

# Clean up backup files (optional)
cleanup_backups() {
    local backups
    mapfile -t backups < <(find "$HOME" -maxdepth 1 -name "$(basename "$BASHRC_FILE").backup.*" 2>/dev/null)
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        echo -e "${BLUE}ℹ️  No backup files found${NC}"
        return 0
    fi
    
    echo ""
    echo -e "${YELLOW}📋 Backup Cleanup${NC}"
    echo -e "${WHITE}Found ${#backups[@]} backup file(s):${NC}"
    
    for backup in "${backups[@]}"; do
        echo -e "${CYAN}  • $(basename "$backup")${NC}"
    done
    
    echo ""
    if ask_yes_no "Would you like to remove these backup files?"; then
        for backup in "${backups[@]}"; do
            rm -f "$backup"
            echo -e "${GREEN}✅ Removed: $(basename "$backup")${NC}"
        done
    else
        echo -e "${BLUE}ℹ️  Backup files preserved${NC}"
    fi
}

# Final verification
verify_cleanup() {
    echo -e "${PURPLE}🔍 Verifying cleanup...${NC}"
    echo ""
    
    local issues_found=false
    
    # Check config directory
    if [[ -d "$CONFIG_DIR" ]]; then
        echo -e "${RED}❌ Configuration directory still exists: $CONFIG_DIR${NC}"
        issues_found=true
    else
        echo -e "${GREEN}✅ Configuration directory removed${NC}"
    fi
    
    # Check bashrc entries
    if grep -q "quran-verses" "$BASHRC_FILE" 2>/dev/null; then
        echo -e "${RED}❌ References still found in .bashrc${NC}"
        issues_found=true
    else
        echo -e "${GREEN}✅ .bashrc cleaned${NC}"
    fi
    
    if [[ "$issues_found" == "true" ]]; then
        echo -e "${YELLOW}⚠️  Some cleanup issues detected. You may need to manually remove remaining files.${NC}"
        return 1
    else
        echo -e "${GREEN}🎉 Complete cleanup verified!${NC}"
        return 0
    fi
}

# Main uninstall process
main() {
    show_title
    
    echo -e "${RED}⚠️  WARNING: This will completely remove Daily Quran Terminal from your system${NC}"
    echo ""
    
    if ! ask_yes_no "Are you sure you want to uninstall Daily Quran Terminal?"; then
        echo -e "${BLUE}ℹ️  Uninstall cancelled.${NC}"
        exit 0
    fi
    
    echo ""
    
    # Step 1: Check installation
    echo -e "${YELLOW}📋 Step 1: Checking Installation${NC}"
    echo ""
    check_installation
    
    show_loading "Analyzing installation" 1
    
    echo ""
    
    # Step 2: Handle .bashrc
    echo -e "${YELLOW}📋 Step 2: .bashrc Restoration${NC}"
    echo ""
    
    if ! restore_bashrc; then
        echo ""
        if ask_yes_no "Would you like to manually remove Daily Quran entries from .bashrc?"; then
            remove_bashrc_entries
        else
            echo -e "${YELLOW}⚠️  .bashrc entries will remain. You may need to remove them manually.${NC}"
        fi
    fi
    
    show_loading "Processing .bashrc changes" 1
    
    echo ""
    
    # Step 3: Remove configuration
    echo -e "${YELLOW}📋 Step 3: Removing Configuration${NC}"
    echo ""
    
    remove_config_dir
    
    show_loading "Cleaning up configuration files" 1
    
    echo ""
    
    # Step 4: Backup cleanup
    echo -e "${YELLOW}📋 Step 4: Backup Cleanup${NC}"
    cleanup_backups
    
    echo ""
    
    # Step 5: Verification
    echo -e "${YELLOW}📋 Step 5: Verification${NC}"
    echo ""
    
    if verify_cleanup; then
        echo ""
        echo -e "${GREEN}🎉 Daily Quran Terminal has been successfully uninstalled!${NC}"
        echo ""
        if ask_yes_no "Would you like to reload your terminal configuration now?"; then
            # shellcheck source=/dev/null
            source "$BASHRC_FILE"
            echo -e "${PURPLE}🔄 Terminal configuration reloaded${NC}"
        else
            echo -e "${YELLOW}⏳ Please restart your terminal or run 'source ~/.bashrc' to apply changes${NC}"
        fi
        echo ""
        echo -e "${CYAN}Thank you for trying Daily Quran Terminal! 🤲${NC}"
    else
        echo ""
        echo -e "${YELLOW}⚠️  Uninstall completed with some issues. Please check the messages above.${NC}"
        exit 1
    fi
}

# Execute main function
main "$@"
