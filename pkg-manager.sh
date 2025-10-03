#!/bin/bash

# An interactive CLI to browse and manage packages from pacman and yay using fzf.
# Created for an Arch Linux system.

# --- Colors for styling the output ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Function to display help keybindings ---
# This function is called when the script is run with the --_get_help flag.
_display_help_keys() {
    echo -e "
  \033[1;33mKEYBINDINGS\033[0m

  \033[0;32mTab\033[0m      Switch between pacman (native) and yay (AUR)
  \033[0;32m?\033[0m        Toggle this help view
  \033[0;32mUp/Down\033[0m  Navigate packages (resets to info view)
  \033[0;32mEnter\033[0m    Select package to view details below
  \033[0;32mu\033[0m        Update selected package
  \033[0;32md\033[0m        Remove selected package
  \033[0;32mr\033[0m        Reinstall selected package
  \033[0;32mESC\033[0m      Exit the application

  The preview pane on the right shows detailed
  package information.
"
}

# --- Argument handler for internal calls ---
# If the script is called with '--_get_help', just show the help and exit.
# This is used by fzf's preview binding to avoid shell context issues.
if [[ "$1" == "--_get_help" ]]; then
    _display_help_keys
    exit 0
fi

# --- Function to check for dependencies ---
# We now need `fzf` for the UI and `yay` for AUR packages.
check_deps() {
    for cmd in pacman yay fzf; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "${YELLOW}Error: '$cmd' command not found.${NC}"
            case "$cmd" in
                fzf)
                    echo "fzf is required for the interactive interface."
                    echo "You can install it with: sudo pacman -S fzf"
                    ;;
                yay)
                    echo "yay is required for browsing AUR packages."
                    echo "You can find installation instructions on its GitHub page."
                    ;;
                pacman)
                     echo "This script is intended for Arch Linux or other Arch-based distributions."
                    ;;
            esac
            exit 1
        fi
    done
}

# --- Function to display the interactive package list ---
show_packages() {
    # --- State management ---
    # Create temp files to store the current source (pacman/yay) and preview (info/help)
    local SOURCE_STATE_FILE
    SOURCE_STATE_FILE=$(mktemp)
    echo "pacman" > "$SOURCE_STATE_FILE"

    local PREVIEW_STATE_FILE
    PREVIEW_STATE_FILE=$(mktemp)
    echo "info" > "$PREVIEW_STATE_FILE"

    # Ensure temp files are removed when the script exits
    trap 'rm -f -- "$SOURCE_STATE_FILE" "$PREVIEW_STATE_FILE"' EXIT

    # --- fzf command strings ---
    # The command strings now use double quotes to allow shell variables
    # (like the temp file paths) to be expanded correctly.

    # This command generates the dynamic header for fzf.
    local HEADER_GEN_CMD="echo \"\$(tr 'a-z' 'A-Z' < '$SOURCE_STATE_FILE') PACKAGES | TAB: Switch | ?: Help\""

    # This command reloads the package list when you press Tab.
    local RELOAD_CMD="
        if [[ \"\$(cat '$SOURCE_STATE_FILE')\" == 'pacman' ]]; then
            echo yay > '$SOURCE_STATE_FILE';
            yay -Qem;
        else
            echo pacman > '$SOURCE_STATE_FILE';
            pacman -Qen;
        fi
    "
    # This dynamic preview command checks the state and shows either package info or help text.
    # It now uses `cut` instead of `awk` to avoid complex shell escaping issues.
    local DYNAMIC_PREVIEW_CMD="
        if [[ \"\$(cat '$PREVIEW_STATE_FILE')\" == 'info' ]]; then
            echo -e \"\033[1;33mSOURCE: \$(tr 'a-z' 'A-Z' < '$SOURCE_STATE_FILE')\033[0m\\n---\";
            pacman -Qi \"\$(echo {} | cut -d' ' -f1)\";
        else
            '$0' --_get_help;
        fi
    "
    # This command flips the preview state between "info" and "help".
    local TOGGLE_PREVIEW_CMD="
        if [[ \"\$(cat '$PREVIEW_STATE_FILE')\" == 'info' ]]; then
            echo 'help' > '$PREVIEW_STATE_FILE';
        else
            echo 'info' > '$PREVIEW_STATE_FILE';
        fi
    "

    # This command resets the preview to the default package info view.
    local RESET_PREVIEW_CMD="echo 'info' > '$PREVIEW_STATE_FILE'"

    # --- fzf invocation ---
    # --expect is added to handle custom key presses for actions.
    local fzf_output
    fzf_output=$(pacman -Qen | fzf \
        --expect=u,d,r \
        --header "$($HEADER_GEN_CMD)" \
        --height="90%" --layout=reverse --border=rounded --ansi \
        --preview "$DYNAMIC_PREVIEW_CMD" \
        --preview-window=right:50%:border-left \
        --bind "tab:reload($RELOAD_CMD)+change-header($HEADER_GEN_CMD)" \
        --bind "?:execute($TOGGLE_PREVIEW_CMD)+refresh-preview" \
        --bind "up:execute($RESET_PREVIEW_CMD)+refresh-preview+up" \
        --bind "down:execute($RESET_PREVIEW_CMD)+refresh-preview+down"
    )

    # --- Post-selection actions ---
    clear

    # Exit if fzf was cancelled (e.g., via ESC)
    if [ -z "$fzf_output" ]; then
        echo "No action taken. Exiting."
        return
    fi

    local key
    key=$(head -n1 <<< "$fzf_output")
    local selection
    selection=$(tail -n1 <<< "$fzf_output")
    local package_name
    package_name=$(echo "$selection" | cut -d' ' -f1)
    local current_source
    current_source=$(cat "$SOURCE_STATE_FILE")

    # Check if a package was actually selected
    if [ -z "$package_name" ]; then
        echo "No package selected. Exiting."
        return
    fi

    # Decide which command to use based on the source
    local pkg_manager_cmd
    if [[ "$current_source" == "yay" ]]; then
        pkg_manager_cmd="yay"
    else
        pkg_manager_cmd="sudo pacman"
    fi

    # Handle the action based on the key pressed
    case "$key" in
        u|r)
            if [[ "$key" == "u" ]]; then
                echo -e "${GREEN}Attempting to update:${NC} $package_name"
            else
                echo -e "${GREEN}Attempting to reinstall:${NC} $package_name"
            fi
            $pkg_manager_cmd -S "$package_name"
            ;;
        d)
            echo -e "${YELLOW}You are about to remove:${NC} $package_name"
            read -p "Are you sure you want to proceed? [y/N] " -n 1 -r
            echo # move to a new line
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "Removing package..."
                $pkg_manager_cmd -Rns "$package_name"
            else
                echo "Removal cancelled."
            fi
            ;;
        *) # This case handles the Enter key, where the 'key' is empty
            echo -e "${GREEN}You selected:${NC} $package_name"
            echo
            echo "Full details:"
            pacman -Qi "$package_name"
            echo
            ;;
    esac
}

# --- Main execution ---
main() {
    check_deps
    show_packages
}

# Run the main function
main


