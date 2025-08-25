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
readonly VERSES_FILE="$CONFIG_DIR/verses.txt"
readonly DISPLAY_SCRIPT="$CONFIG_DIR/display-verse.sh"
readonly SESSION_FILE="$CONFIG_DIR/current_session"
readonly BASHRC_FILE="$HOME/.bashrc"

# Check for required dependencies
check_dependencies() {
    local missing_deps=()
    local deps=("shuf" "tput" "fold" "date")
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Error: Missing required dependencies: ${missing_deps[*]}${NC}"
        echo -e "${YELLOW}Please install these commands and run the script again.${NC}"
        exit 1
    fi
}

# Show ASCII title
show_title() {
    clear
    echo -e "${CYAN}"
    echo "██████╗  █████╗ ██╗██╗  ██╗   ██╗     ██████╗ ██╗   ██╗██████╗  █████╗ ███╗   ██╗"
    echo "██╔══██╗██╔══██╗██║██║  ╚██╗ ██╔╝    ██╔═══██╗██║   ██║██╔══██╗██╔══██╗████╗  ██║"
    echo "██║  ██║███████║██║██║   ╚████╔╝     ██║   ██║██║   ██║██████╔╝███████║██╔██╗ ██║"
    echo "██║  ██║██╔══██║██║██║    ╚██╔╝      ██║▄▄ ██║██║   ██║██╔══██╗██╔══██║██║╚██╗██║"
    echo "██████╔╝██║  ██║██║███████╗██║       ╚██████╔╝╚██████╔╝██║  ██║██║  ██║██║ ╚████║"
    echo "╚═════╝ ╚═╝  ╚═╝╚═╝╚══════╝╚═╝        ╚══▀▀═╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝"
    echo -e "${NC}"
    echo -e "${WHITE}                    Terminal Verse Display Setup${NC}"
    echo -e "${YELLOW}                     Bringing inspiration to your terminal${NC}"
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

# Create configuration file
create_config_file() {
    local display_mode="$1"
    
    cat > "$CONFIG_DIR/config" << EOF
# Daily Quran Terminal Configuration
DISPLAY_MODE="$display_mode"
VERSES_FILE="$VERSES_FILE"
WRAP_WIDTH=60
HEADER_TEXT="✨ Daily Reflection ✨"
EOF
}

# Create window-based display script with embedded logic
create_window_display_script() {
    cat > "$DISPLAY_SCRIPT" << 'EOF'
#!/bin/bash
set -euo pipefail

# Source configuration
readonly CONFIG_FILE="$HOME/.config/quran-verses/config"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
else
    # Fallback defaults
    readonly VERSES_FILE="$HOME/.config/quran-verses/verses.txt"
    readonly WRAP_WIDTH=60
    readonly HEADER_TEXT="✨ Daily Reflection ✨"
fi

# Display verse function
display_verse() {
    if [[ ! -f "$VERSES_FILE" ]]; then
        echo "Error: Verses file not found at $VERSES_FILE" >&2
        return 1
    fi
    
    local verse
    verse=$(shuf -n 1 "$VERSES_FILE")
    
    local cols
    cols=$(tput cols 2>/dev/null || echo "80")
    
    # Colors
    local green='\e[0;32m'
    local white='\e[1;37m'
    local nc='\e[0m'
    
    echo ""
    
    # Centered header
    local header_len=25
    local left_pad=$(((cols - header_len) / 2))
    printf "%*s${green}%s${nc}\n" "$left_pad" "" "$HEADER_TEXT"
    
    echo ""
    
    # Centered verse with wrapping
    echo "$verse" | fold -s -w "$WRAP_WIDTH" | while IFS= read -r line; do
        local line_len=${#line}
        local line_pad=$(((cols - line_len) / 2))
        printf "%*s${white}%s${nc}\n" "$line_pad" "" "$line"
    done
    
    echo ""
}

# Main execution
display_verse
EOF
    chmod +x "$DISPLAY_SCRIPT"
}

# Create session-based display script with embedded logic (UPDATED - Twice Daily)
create_session_display_script() {
    cat > "$DISPLAY_SCRIPT" << 'EOF'
#!/bin/bash
set -euo pipefail

# Source configuration
readonly CONFIG_FILE="$HOME/.config/quran-verses/config"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
else
    # Fallback defaults
    readonly VERSES_FILE="$HOME/.config/quran-verses/verses.txt"
    readonly WRAP_WIDTH=60
    readonly HEADER_TEXT="✨ Daily Reflection ✨"
fi

readonly SESSION_FILE="$HOME/.config/quran-verses/current_session"

# Session management - TWICE DAILY (12 AM and 12 PM)
check_session() {
    local current_hour current_session
    current_hour=$(date +%H)
    
    # Determine session: morning (AM) or evening (PM)
    if [[ $current_hour -ge 12 ]]; then
        current_session=$(date +%Y%m%d)_PM  # 12:00 PM - 11:59 PM
    else
        current_session=$(date +%Y%m%d)_AM  # 12:00 AM - 11:59 AM
    fi
    
    if [[ -f "$SESSION_FILE" ]]; then
        local last_session
        last_session=$(cat "$SESSION_FILE")
        if [[ "$current_session" == "$last_session" ]]; then
            return 1  # Same session, don't display
        fi
    fi
    
    echo "$current_session" > "$SESSION_FILE"
    return 0  # New session, display verse
}

# Display verse function
display_verse() {
    if [[ ! -f "$VERSES_FILE" ]]; then
        echo "Error: Verses file not found at $VERSES_FILE" >&2
        return 1
    fi
    
    local verse
    verse=$(shuf -n 1 "$VERSES_FILE")
    
    local cols
    cols=$(tput cols 2>/dev/null || echo "80")
    
    # Colors
    local green='\e[0;32m'
    local white='\e[1;37m'
    local nc='\e[0m'
    
    echo ""
    
    # Centered header with time indication
    local current_hour
    current_hour=$(date +%H)
    local time_indicator
    if [[ $current_hour -ge 12 ]]; then
        time_indicator="Evening Reflection"
    else
        time_indicator="Morning Reflection"
    fi
    
    # Simple, reliable centering with plain text
    local header_len=${#time_indicator}
    local left_pad=$(((cols - header_len) / 2))
    
    # Add decorative elements that don't affect centering calculation
    local current_time
    current_time=$(date +"%I:%M %p")
    printf "%*s${green}✨ %s ✨${nc}\n" "$left_pad" "" "$time_indicator"
    printf "%*s${green}%s${nc}\n" $(((cols - ${#current_time}) / 2)) "" "$current_time"
    
    echo ""
    
    # Centered verse with wrapping
    echo "$verse" | fold -s -w "$WRAP_WIDTH" | while IFS= read -r line; do
        local line_len=${#line}
        local line_pad=$(((cols - line_len) / 2))
        printf "%*s${white}%s${nc}\n" "$line_pad" "" "$line"
    done
    
    echo ""
}

# Main execution
if check_session; then
    display_verse
fi
EOF
    chmod +x "$DISPLAY_SCRIPT"
}

# Preview the verse display
preview_display() {
    echo -e "${PURPLE}🔍 Here's a preview of how verses will look in your terminal:${NC}"
    echo ""
    if [[ -x "$DISPLAY_SCRIPT" ]]; then
        "$DISPLAY_SCRIPT"
    else
        echo -e "${RED}❌ Error: Display script not executable${NC}"
        return 1
    fi
    echo ""
}

# Backup bashrc with timestamp
backup_bashrc() {
    if [[ -f "$BASHRC_FILE" ]]; then
        local backup_file="$BASHRC_FILE.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$BASHRC_FILE" "$backup_file"
        echo -e "${GREEN}✅ Backup created: $backup_file${NC}"
    else
        echo -e "${YELLOW}⚠️  No existing .bashrc found${NC}"
    fi
}

# Add to bashrc
add_to_bashrc() {
    if grep -q "quran-verses/display-verse.sh" "$BASHRC_FILE" 2>/dev/null; then
        echo -e "${BLUE}ℹ️  Quran verses already configured in .bashrc${NC}"
        return 0
    fi
    
    {
        echo ""
        echo "# Display daily Quran verse"
        echo "\"$DISPLAY_SCRIPT\""
    } >> "$BASHRC_FILE"
    
    echo -e "${GREEN}✅ Added to .bashrc${NC}"
}

# Cleanup function for graceful exit
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo -e "\n${RED}❌ Setup interrupted. Cleaning up...${NC}"
        # Remove partial installation if it exists
        if [[ -d "$CONFIG_DIR" ]]; then
            echo -e "${YELLOW}Removing partial installation...${NC}"
            rm -rf "$CONFIG_DIR"
        fi
    fi
    exit $exit_code
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Main setup process
main() {
    # Check dependencies first
    check_dependencies
    
    show_title
    
    echo -e "${GREEN}🚀 Welcome to Daily Quran Terminal Setup!${NC}"
    echo ""
    
    # Step 1: Choose display mode
    echo -e "${YELLOW}📋 Step 1: Choose Display Mode${NC}"
    echo ""
    echo -e "${WHITE}1) Window-based${NC} - Show a verse in ${BLUE}every new terminal window${NC}"
    echo -e "${WHITE}2) Session-based${NC} - Show a verse ${BLUE}twice daily (12 AM & 12 PM)${NC}"
    echo ""
    
    local display_mode
    while true; do
        echo -e "${BLUE}Enter your choice${WHITE} (1 or 2):${NC} \c"
        read -r choice
        case $choice in
            1) 
                display_mode="window"
                echo -e "${GREEN}✅ Window-based mode selected!${NC}"
                break
                ;;
            2) 
                display_mode="session"
                echo -e "${GREEN}✅ Twice-daily session mode selected!${NC}"
                echo -e "${CYAN}   🌙 Morning verses: 12:00 AM - 11:59 AM${NC}"
                echo -e "${CYAN}   🌅 Evening verses: 12:00 PM - 11:59 PM${NC}"
                break
                ;;
            *) 
                echo -e "${RED}Please enter 1 or 2.${NC}"
                ;;
        esac
    done
    
    echo ""
    
    # Step 2: Backup option
    echo -e "${YELLOW}📋 Step 2: Backup Options${NC}"
    echo ""
    if ask_yes_no "Would you like to backup your current .bashrc file?"; then
        backup_bashrc
    else
        echo -e "${BLUE}ℹ️  No backup created.${NC}"
    fi
    
    echo ""
    
    # Step 3: Create configuration
    echo -e "${YELLOW}📋 Step 3: Creating Configuration${NC}"
    echo ""
    
    # Create directory structure
    mkdir -p "$CONFIG_DIR"
    echo -e "${GREEN}✅ Created configuration directory${NC}"
    
    # Copy verses file
    if [[ -f "./verses.txt" ]]; then
        cp ./verses.txt "$VERSES_FILE"
        echo -e "${GREEN}✅ Verses file installed${NC}"
    else
        echo -e "${RED}❌ Error: verses.txt not found in current directory${NC}"
        exit 1
    fi
    
    # Create configuration file
    create_config_file "$display_mode"
    echo -e "${GREEN}✅ Configuration file created${NC}"
    
    # Create appropriate display script
    if [[ "$display_mode" == "window" ]]; then
        create_window_display_script
        echo -e "${GREEN}✅ Window-based display script created${NC}"
    else
        create_session_display_script
        echo -e "${GREEN}✅ Twice-daily session display script created${NC}"
    fi
    
    # Add loading animation
    show_loading "Setting up your configuration" 1
    
    echo ""
    
    # Step 4: Preview
    echo -e "${YELLOW}📋 Step 4: Preview${NC}"
    echo ""
    
    if ask_yes_no "Would you like to see a preview of how verses will look?"; then
        show_loading "Preparing preview" 1
        preview_display
        echo -e "${GREEN}✨ Preview complete! This is how your verses will appear.${NC}"
        if [[ "$display_mode" == "session" ]]; then
            echo -e "${CYAN}💡 Note: The header will show 'Morning Reflection' (12 AM-11:59 AM) or 'Evening Reflection' (12 PM-11:59 PM)${NC}"
        fi
    else
        echo -e "${BLUE}ℹ️  Skipping preview.${NC}"
    fi
    
    show_loading "Finalizing setup" 1
    
    echo ""
    
    # Step 5: Deploy
    echo -e "${YELLOW}📋 Step 5: Deployment${NC}"
    echo ""
    
    add_to_bashrc
    
    echo ""
    echo -e "${GREEN}🎉 Setup completed successfully!${NC}"
    echo ""
    
    if [[ "$display_mode" == "session" ]]; then
        echo -e "${CYAN}📅 Your verses will appear:${NC}"
        echo -e "${WHITE}   🌙 Morning: First terminal opened between 12:00 AM - 11:59 AM${NC}"
        echo -e "${WHITE}   🌅 Evening: First terminal opened between 12:00 PM - 11:59 PM${NC}"
        echo ""
    fi
    
    if ask_yes_no "Ready to activate? This will reload your terminal configuration"; then
        # shellcheck source=/dev/null
        source "$BASHRC_FILE"
        echo ""
        echo -e "${PURPLE}🌟 Daily Quran Terminal is now active!${NC}"
        echo -e "${WHITE}Open a new terminal window to see your inspiring verses.${NC}"
        echo ""
        echo -e "${CYAN}Thank you for using Daily Quran Terminal! 🤲${NC}"
    else
        echo ""
        echo -e "${YELLOW}⏳ To activate later, run: ${WHITE}source ~/.bashrc${NC}"
        echo -e "${CYAN}Thank you for using Daily Quran Terminal! 🤲${NC}"
    fi
}

# Execute main function
main "$@"
