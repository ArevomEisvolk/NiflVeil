#!/bin/bash
# NiflVeil Rofi Restore Menu
# Displays minimized windows in rofi and restores the selected one

CACHE_FILE="/tmp/minimize-state/windows.json"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
THEME_FILE="$HOME/.config/rofi/niflveil.rasi"

# Check if cache file exists
if [[ ! -f "$CACHE_FILE" ]]; then
    exit 0
fi

# Read and parse JSON
json_content=$(cat "$CACHE_FILE")

# Check if empty array
if [[ "$json_content" == "[]" ]]; then
    exit 0
fi

# Count windows
window_count=$(echo "$json_content" | grep -o '"address"' | wc -l)

if [[ $window_count -eq 0 ]]; then
    exit 0
fi

# Build rofi input
rofi_input=""

# Add "Restore All" option if more than one window
if [[ $window_count -gt 1 ]]; then
    rofi_input="󰁯 Restore All Windows\n"
fi

# Parse each window from JSON and format for rofi
# Format: icon class - title [short_addr]
while IFS= read -r line; do
    address=$(echo "$line" | sed -n 's/.*"address":"\([^"]*\)".*/\1/p')
    icon=$(echo "$line" | sed -n 's/.*"icon":"\([^"]*\)".*/\1/p')
    class=$(echo "$line" | sed -n 's/.*"class":"\([^"]*\)".*/\1/p')
    title=$(echo "$line" | sed -n 's/.*"original_title":"\([^"]*\)".*/\1/p')

    # Get last 4 characters of address
    short_addr="${address: -4}"

    rofi_input+="$icon $class - $title [$short_addr]\n"
done < <(echo "$json_content" | grep -o '{[^}]*}')

# Remove trailing newline
rofi_input=$(echo -e "$rofi_input" | sed '/^$/d')

# Build rofi command
rofi_args=(
    -dmenu
    -i
    -p "󰘸 Restore Window"
    -mesg "$window_count minimized window(s)"
)

# Use custom theme if available
if [[ -f "$THEME_FILE" ]]; then
    rofi_args+=(-theme "$THEME_FILE")
else
    rofi_args+=(-theme-str "window {width: 600px;} listview {lines: 8;}")
fi

# Run rofi and get selection
selection=$(echo -e "$rofi_input" | rofi "${rofi_args[@]}")

# Exit if cancelled
if [[ -z "$selection" ]]; then
    exit 0
fi

# Check if "Restore All" was selected
if [[ "$selection" == *"Restore All Windows"* ]]; then
    niflveil restore-all
    exit 0
fi

# Extract address from selection (text in brackets)
short_addr=$(echo "$selection" | grep -o '\[[^]]*\]' | tr -d '[]')

if [[ -z "$short_addr" ]]; then
    exit 1
fi

# Find full address matching the short address
full_address=$(echo "$json_content" | grep -o '"address":"[^"]*'"$short_addr"'"' | sed 's/"address":"//;s/"$//' | head -1)

if [[ -n "$full_address" ]]; then
    niflveil restore "$full_address"
fi
