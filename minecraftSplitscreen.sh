#!/bin/bash

set +e  # Allow script to continue on errors for robustness

# =============================
# Minecraft Splitscreen Launcher for Steam Deck & Linux
# =============================
# This script launches 1–4 Minecraft instances in splitscreen mode.
# On Steam Deck Game Mode, it launches a nested KDE Plasma session for clean splitscreen.
# On desktop mode, it launches Minecraft instances directly.
# Handles controller detection, per-instance mod config, KDE panel hiding/restoring, and reliable autostart in a nested session.
#
# HOW IT WORKS:
# 1. If in Steam Deck Game Mode, launches a nested Plasma Wayland session (if not already inside).
# 2. Sets up an autostart .desktop file to re-invoke itself inside the nested session.
# 3. Detects how many controllers are connected (1–4, with Steam Input quirks handled).
# 4. For each player, writes the correct splitscreen mod config and launches a Minecraft instance.
# 5. Hides KDE panels for a clean splitscreen experience (by killing plasmashell), then restores them.
# 6. Logs out of the nested session when done.
#
# NOTE: This script is robust and heavily commented for clarity and future maintainers!
# The main script file should be named minecraftSplitscreen.sh for clarity and version-agnostic usage.

# Set a temporary directory for intermediate files (used for wrappers, etc)
export target=/tmp

# =============================
# Function: detectLauncher
# =============================
# Detects available launcher (PollyMC or PrismLauncher) for splitscreen gameplay.
# Returns launcher paths and executable info.
detectLauncher() {
    # Check if PollyMC is available
    if [ -f "$HOME/.local/share/PollyMC/PollyMC-Linux-x86_64.AppImage" ] && [ -x "$HOME/.local/share/PollyMC/PollyMC-Linux-x86_64.AppImage" ]; then
        export LAUNCHER_DIR="$HOME/.local/share/PollyMC"
        export LAUNCHER_EXEC="$HOME/.local/share/PollyMC/PollyMC-Linux-x86_64.AppImage"
        export LAUNCHER_NAME="PollyMC"
        return 0
    fi
    
    # Fallback: Check if PrismLauncher is available
    if [ -f "$HOME/.local/share/PrismLauncher/PrismLauncher.AppImage" ] && [ -x "$HOME/.local/share/PrismLauncher/PrismLauncher.AppImage" ]; then
        export LAUNCHER_DIR="$HOME/.local/share/PrismLauncher"
        export LAUNCHER_EXEC="$HOME/.local/share/PrismLauncher/PrismLauncher.AppImage"
        export LAUNCHER_NAME="PrismLauncher"
        return 0
    fi
    
    echo "[Error] No compatible Minecraft launcher found!" >&2
    echo "[Error] Expected PollyMC at: $HOME/.local/share/PollyMC/PollyMC-Linux-x86_64.AppImage" >&2
    echo "[Error] Or PrismLauncher at: $HOME/.local/share/PrismLauncher/PrismLauncher.AppImage" >&2
    echo "[Error] Please run the Minecraft Splitscreen installer to set up a launcher" >&2
    return 1
}

# Detect and set launcher variables at startup
if ! detectLauncher; then
    echo "[Error] Cannot continue without a compatible Minecraft launcher" >&2
    exit 1
fi

echo "[Info] Using $LAUNCHER_NAME for splitscreen gameplay"

# =============================
# Function: selfUpdate
# =============================
# Checks if this script is the latest version from GitHub. If not, downloads and replaces itself.
selfUpdate() {
    local repo_url="https://raw.githubusercontent.com/LuisM360/MinecraftSplitscreenSteamdeck/main/minecraftSplitscreen.sh"
    local tmpfile
    tmpfile=$(mktemp)
    local script_path
    script_path="$(readlink -f "$0")"
    # Download the latest version
    if ! curl -fsSL "$repo_url" -o "$tmpfile"; then
        echo "[Self-Update] Failed to check for updates." >&2
        rm -f "$tmpfile"
        return
    fi
    # Compare files byte-for-byte
    if ! cmp -s "$tmpfile" "$script_path"; then
        # --- Terminal Detection and Relaunch Logic ---
        # If not running in an interactive shell (no $PS1), not launched by a terminal program, and not attached to a tty,
        # then we are likely running from a GUI (e.g., .desktop launcher) and cannot prompt the user for input.
        if [ -z "$PS1" ] && [ -z "$TERM_PROGRAM" ] && ! tty -s; then
            # Try to find a terminal emulator to relaunch the script for the update prompt.
            # This loop checks for common terminal emulators in order of preference.
            for term in x-terminal-emulator gnome-terminal konsole xfce4-terminal xterm; do
                if command -v $term >/dev/null 2>&1; then
                    # Relaunch this script in the found terminal emulator, passing all arguments.
                    exec $term -e "$script_path" "$@"
                fi
            done
            # If no terminal emulator is found, print an error and exit.
            echo "[Self-Update] Update available, but no terminal found for prompt. Please run this script from a terminal to update." >&2
            rm -f "$tmpfile"
            exit 1
        fi
        # --- Interactive Update Prompt ---
        # If we are running in a terminal, prompt the user for update confirmation.
        echo "[Self-Update] A new version is available. Update now? [y/N]"
        read -r answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            echo "[Self-Update] Updating..."
            cp "$tmpfile" "$script_path"
            chmod +x "$script_path"
            rm -f "$tmpfile"
            echo "[Self-Update] Update complete. Restarting..."
            exec "$script_path" "$@"
        else
            echo "[Self-Update] Update skipped by user."
            rm -f "$tmpfile"
        fi
    else
        rm -f "$tmpfile"
        echo "[Self-Update] Already up to date."
    fi
}

# Call selfUpdate at the very start of the script
selfUpdate

# =============================
# Function: nestedPlasma
# =============================
# Launches a nested KDE Plasma Wayland session and sets up Minecraft autostart.
# Needed so Minecraft can run in a clean, isolated desktop environment (avoiding SteamOS overlays, etc).
# The autostart .desktop file ensures Minecraft launches automatically inside the nested session.
nestedPlasma() {
    # Unset variables that may interfere with launching a nested session
    unset LD_PRELOAD XDG_DESKTOP_PORTAL_DIR XDG_SEAT_PATH XDG_SESSION_PATH
    # Get current screen resolution (e.g., 1280x800)
    RES=$(xdpyinfo 2>/dev/null | awk '/dimensions/{print $2}')
    [ -z "$RES" ] && RES="1280x800"
    # Create a wrapper for kwin_wayland with the correct resolution
    cat <<EOF > $target/kwin_wayland_wrapper
#!/bin/bash
/usr/bin/kwin_wayland_wrapper --width ${RES%x*} --height ${RES#*x} --no-lockscreen \$@
EOF
    chmod +x $target/kwin_wayland_wrapper
    export PATH=$target:$PATH
    # Write an autostart .desktop file that will re-invoke this script with a special argument
    SCRIPT_PATH="$(readlink -f "$0")"
    mkdir -p ~/.config/autostart
    cat <<EOF > ~/.config/autostart/minecraft-launch.desktop
[Desktop Entry]
Name=Minecraft Split Launch
Exec=$SCRIPT_PATH launchFromPlasma
Type=Application
X-KDE-AutostartScript=true
EOF
    # Start nested Plasma session (never returns)
    exec dbus-run-session startplasma-wayland
}

# =============================
# Function: launchGame
# =============================
# Launches a single Minecraft instance using the detected launcher, with KDE inhibition to prevent
# the system from sleeping, activating the screensaver, or changing color profiles.
# Arguments:
#   $1 = Launcher instance name (e.g., latestUpdate-1)
#   $2 = Player name (e.g., P1)
launchGame() {
    if command -v kde-inhibit >/dev/null 2>&1; then
        kde-inhibit --power --screenSaver --colorCorrect --notifications "$LAUNCHER_EXEC" -l "$1" -a "$2" &
    else
        echo "[Warning] kde-inhibit not found. Running $LAUNCHER_NAME without KDE inhibition."
        "$LAUNCHER_EXEC" -l "$1" -a "$2" &
    fi
    sleep 10 # Give time for the instance to start (avoid race conditions)
}

# =============================
# Function: hidePanels
# =============================
# Kills all plasmashell processes to remove KDE panels and widgets. This is a brute-force workaround
# that works even in nested Plasma Wayland sessions, where scripting APIs may not work.
hidePanels() {
    if command -v plasmashell >/dev/null 2>&1; then
        pkill plasmashell
        sleep 1
        if pgrep -u "$USER" plasmashell >/dev/null; then
            killall plasmashell
            sleep 1
        fi
        if pgrep -u "$USER" plasmashell >/dev/null; then
            pkill -9 plasmashell
            sleep 1
        fi
    else
        echo "[Info] plasmashell not found. Skipping KDE panel hiding."
    fi
}

# =============================
# Function: restorePanels
# =============================
# Restarts plasmashell to restore all KDE panels and widgets after gameplay.
restorePanels() {
    if command -v plasmashell >/dev/null 2>&1; then
        nohup plasmashell >/dev/null 2>&1 &
        sleep 2
    else
        echo "[Info] plasmashell not found. Skipping KDE panel restore."
    fi
}

# =============================
# Function: getControllerCount
# =============================
# Detects the number of external controllers (1–4) by counting /dev/input/js* devices.
# Excludes Steam Deck built-in controller and handles Steam Input duplicates intelligently.
# Ensures at least 1 and at most 4 controllers are reported.
# 
# Logic:
#   - Identifies all joystick/gamepad devices using /dev/input/js*
#   - Excludes Steam Deck controller devices using udev properties
#   - Groups duplicate devices created by Steam Input
#   - Counts unique controller groups
#   - Falls back to simpler detection if udevadm unavailable
#
# Debug output can be enabled by setting MINECRAFT_DEBUG=1 environment variable
getControllerCount() {
    local debug="${MINECRAFT_DEBUG:-0}"
    local steam_running=0
    local devices=()
    local excluded_devices=()
    local controller_groups=()
    local count=0
    
    # Check if Steam is running
    if pgrep -x steam >/dev/null \
        || pgrep -f '^/app/bin/steam$' >/dev/null \
        || pgrep -f 'flatpak run com.valvesoftware.Steam' >/dev/null; then
        steam_running=1
    fi
    
    # Collect all joystick devices
    for js_device in /dev/input/js*; do
        [ ! -e "$js_device" ] && continue
        devices+=("$js_device")
    done
    
    [ "$debug" = "1" ] && echo "[Debug] Found ${#devices[@]} joystick device(s)" >&2
    
    # If no devices found, return 1 (minimum)
    if [ ${#devices[@]} -eq 0 ]; then
        [ "$debug" = "1" ] && echo "[Debug] No controllers detected, defaulting to 1" >&2
        echo "1"
        return 0
    fi
    
    # Check if udevadm is available for device identification
    if command -v udevadm >/dev/null 2>&1; then
        # Use udevadm to identify and filter devices
        local valid_controllers=()
        local device_names=()
        
        for js_device in "${devices[@]}"; do
            local is_steam_deck=0
            local device_name=""
            local vendor_id=""
            local product_id=""
            
            # Get device properties using udevadm
            local udev_info
            udev_info=$(udevadm info -q property -n "$js_device" 2>/dev/null)
            
            if [ -n "$udev_info" ]; then
                # Extract device name
                device_name=$(echo "$udev_info" | grep -E "^ID_NAME=" | cut -d'=' -f2- | tr -d '"')
                vendor_id=$(echo "$udev_info" | grep -E "^ID_VENDOR_ID=" | cut -d'=' -f2- | tr -d '"')
                product_id=$(echo "$udev_info" | grep -E "^ID_MODEL_ID=" | cut -d'=' -f2- | tr -d '"')
                
                # Check if this is a Steam Deck controller
                # Steam Deck controller identifiers:
                # - Device name contains "Steam Deck" or "Valve"
                # - Vendor ID 28de (Valve Corporation)
                # - Device path might indicate built-in controller
                if echo "$device_name" | grep -qiE "steam.*deck|valve.*controller" \
                    || [ "$vendor_id" = "28de" ] \
                    || echo "$js_device" | grep -qE "event[0-9]+.*steam"; then
                    # Additional check: verify it's actually the built-in controller
                    # by checking if it's a system device (not USB)
                    local sys_path
                    sys_path=$(echo "$udev_info" | grep -E "^DEVPATH=" | cut -d'=' -f2-)
                    if echo "$sys_path" | grep -qE "platform|pci.*0000:00" || [ -z "$sys_path" ]; then
                        is_steam_deck=1
                    fi
                fi
            else
                # Fallback: check device name from /sys
                local sys_name_path="/sys/class/input/$(basename "$js_device" | sed 's/js/input/')/device/name"
                if [ -f "$sys_name_path" ]; then
                    device_name=$(cat "$sys_name_path" 2>/dev/null)
                    if echo "$device_name" | grep -qiE "steam.*deck|valve.*controller"; then
                        is_steam_deck=1
                    fi
                fi
            fi
            
            if [ "$is_steam_deck" -eq 1 ]; then
                excluded_devices+=("$js_device")
                [ "$debug" = "1" ] && echo "[Debug] Excluding Steam Deck controller: $js_device ($device_name)" >&2
            else
                valid_controllers+=("$js_device")
                device_names+=("$device_name")
                [ "$debug" = "1" ] && echo "[Debug] Valid controller: $js_device ($device_name)" >&2
            fi
        done
        
        # Group duplicate devices created by Steam Input
        # Steam Input typically creates devices with similar names but different suffixes
        if [ "$steam_running" -eq 1 ] && [ ${#valid_controllers[@]} -gt 0 ]; then
            local grouped_controllers=()
            local processed=()
            
            for i in "${!valid_controllers[@]}"; do
                local device="${valid_controllers[$i]}"
                local name="${device_names[$i]}"
                
                # Check if we've already processed this device
                local already_processed=0
                for proc_dev in "${processed[@]}"; do
                    [ "$proc_dev" = "$device" ] && already_processed=1 && break
                done
                [ "$already_processed" -eq 1 ] && continue
                
                # Try to find duplicates of this device
                local base_name=""
                if [ -n "$name" ]; then
                    # Extract base name (remove Steam Input suffixes)
                    base_name=$(echo "$name" | sed 's/[[:space:]]*Steam.*$//' | sed 's/[[:space:]]*Virtual.*$//')
                fi
                
                # Count this device and its potential duplicates
                local group_count=1
                processed+=("$device")
                
                if [ -n "$base_name" ]; then
                    # Look for other devices with similar names
                    for j in "${!valid_controllers[@]}"; do
                        [ "$i" -eq "$j" ] && continue
                        local other_device="${valid_controllers[$j]}"
                        local other_name="${device_names[$j]}"
                        
                        # Check if already processed
                        local already_proc=0
                        for proc_dev in "${processed[@]}"; do
                            [ "$proc_dev" = "$other_device" ] && already_proc=1 && break
                        done
                        [ "$already_proc" -eq 1 ] && continue
                        
                        # Check if names match (accounting for Steam Input variations)
                        local other_base=$(echo "$other_name" | sed 's/[[:space:]]*Steam.*$//' | sed 's/[[:space:]]*Virtual.*$//')
                        if [ "$base_name" = "$other_base" ] || [ -z "$base_name" ] && [ -z "$other_base" ]; then
                            group_count=$((group_count + 1))
                            processed+=("$other_device")
                            [ "$debug" = "1" ] && echo "[Debug] Grouping duplicate: $other_device with $device" >&2
                        fi
                    done
                fi
                
                # Add one controller per group
                grouped_controllers+=("$device")
            done
            
            count=${#grouped_controllers[@]}
            [ "$debug" = "1" ] && echo "[Debug] Grouped ${#valid_controllers[@]} devices into $count unique controller(s)" >&2
        else
            # No Steam running or no valid controllers, use direct count
            count=${#valid_controllers[@]}
            [ "$debug" = "1" ] && echo "[Debug] Counting ${#valid_controllers[@]} controller(s) directly" >&2
        fi
    else
        # Fallback: udevadm not available, use simpler detection
        [ "$debug" = "1" ] && echo "[Debug] udevadm not available, using fallback detection" >&2
        
        count=${#devices[@]}
        
        # Simple exclusion: try to identify Steam Deck controller by device path
        # Steam Deck controller is often js0 or appears early in the sequence
        # This is a heuristic and may not be perfect
        local potential_steam_deck=0
        for js_device in "${devices[@]}"; do
            # Check if device name suggests Steam Deck (heuristic)
            if echo "$js_device" | grep -qE "js0$" && [ ${#devices[@]} -gt 1 ]; then
                # If we have multiple devices and js0 exists, it might be Steam Deck
                # But we can't be sure without udevadm, so we'll be conservative
                potential_steam_deck=1
            fi
        done
        
        # If Steam is running, halve the count (rounding up) as fallback
        if [ "$steam_running" -eq 1 ]; then
            # Subtract potential Steam Deck controller
            if [ "$potential_steam_deck" -eq 1 ] && [ "$count" -gt 1 ]; then
                count=$((count - 1))
                [ "$debug" = "1" ] && echo "[Debug] Excluding potential Steam Deck controller (heuristic)" >&2
            fi
            # Halve remaining count for Steam Input duplicates
            count=$(( (count + 1) / 2 ))
            [ "$debug" = "1" ] && echo "[Debug] Halving count for Steam Input duplicates: $count" >&2
        else
            # No Steam, subtract potential Steam Deck if detected
            if [ "$potential_steam_deck" -eq 1 ] && [ "$count" -gt 1 ]; then
                count=$((count - 1))
                [ "$debug" = "1" ] && echo "[Debug] Excluding potential Steam Deck controller (heuristic)" >&2
            fi
        fi
    fi
    
    # Clamp the count between 1 and 4
    [ "$count" -gt 4 ] && count=4
    [ "$count" -lt 1 ] && count=1
    
    [ "$debug" = "1" ] && echo "[Debug] Final controller count: $count" >&2
    [ "$debug" = "1" ] && echo "[Debug] Excluded ${#excluded_devices[@]} Steam Deck device(s)" >&2
    
    # Output the detected controller count
    echo "$count"
}

# =============================
# Function: setSplitscreenModeForPlayer
# =============================
# Writes the splitscreen.properties config for the splitscreen mod for each player instance.
# This tells the mod which part of the screen each instance should use.
# Arguments:
#   $1 = Player number (1–4)
#   $2 = Total number of controllers/players
setSplitscreenModeForPlayer() {
    local player=$1
    local numberOfControllers=$2
    local config_path="$LAUNCHER_DIR/instances/latestUpdate-${player}/.minecraft/config/splitscreen.properties"
    mkdir -p "$(dirname $config_path)"
    local mode="FULLSCREEN"
    # Decide the splitscreen mode for this player based on total controllers
    case "$numberOfControllers" in
        1)
            mode="FULLSCREEN" # Single player: use whole screen
            ;;
        2)
            if [ "$player" = 1 ]; then mode="TOP"; else mode="BOTTOM"; fi # 2 players: split top/bottom
            ;;
        3)
            if [ "$player" = 1 ]; then mode="TOP";
            elif [ "$player" = 2 ]; then mode="BOTTOM_LEFT";
            else mode="BOTTOM_RIGHT"; fi # 3 players: 1 top, 2 bottom corners
            ;;
        4)
            if [ "$player" = 1 ]; then mode="TOP_LEFT";
            elif [ "$player" = 2 ]; then mode="TOP_RIGHT";
            elif [ "$player" = 3 ]; then mode="BOTTOM_LEFT";
            else mode="BOTTOM_RIGHT"; fi # 4 players: 4 corners
            ;;
    esac
    # Write the config file for the mod
    echo -e "gap=1\nmode=$mode" > "$config_path"
    sync
    sleep 0.5
}

# =============================
# Function: launchGames
# =============================
# Hides panels, launches the correct number of Minecraft instances, and restores panels after.
# Handles all splitscreen logic and per-player config.
launchGames() {
    hidePanels # Remove KDE panels for a clean game view
    numberOfControllers=$(getControllerCount) # Detect how many players
    for player in $(seq 1 $numberOfControllers); do
        setSplitscreenModeForPlayer "$player" "$numberOfControllers" # Write config for this player
        launchGame "latestUpdate-$player" "P$player" # Launch Minecraft instance for this player
    done
    wait # Wait for all Minecraft instances to exit
    restorePanels # Bring back KDE panels
    sleep 2 # Give time for panels to reappear
}

# =============================
# Function: isSteamDeckGameMode
# =============================
# Returns 0 if running on Steam Deck in Game Mode, 1 otherwise.
isSteamDeckGameMode() {
    local dmi_file="/sys/class/dmi/id/product_name"
    local dmi_contents=""
    if [ -f "$dmi_file" ]; then
        dmi_contents="$(cat "$dmi_file" 2>/dev/null)"
    fi
    if echo "$dmi_contents" | grep -Ei 'Steam Deck|Jupiter' >/dev/null; then
        if [ "$XDG_SESSION_DESKTOP" = "gamescope" ] && [ "$XDG_CURRENT_DESKTOP" = "gamescope" ]; then
            return 0
        fi
        if pgrep -af 'steam' | grep -q '\-gamepadui'; then
            return 0
        fi
    else
        # Fallback: If both XDG vars are gamescope and user is deck, assume Steam Deck Game Mode
        if [ "$XDG_SESSION_DESKTOP" = "gamescope" ] && [ "$XDG_CURRENT_DESKTOP" = "gamescope" ] && [ "$USER" = "deck" ]; then
            return 0
        fi
        # Additional fallback: nested session (gamescope+KDE, user deck)
        if [ "$XDG_SESSION_DESKTOP" = "gamescope" ] && [ "$XDG_CURRENT_DESKTOP" = "KDE" ] && [ "$USER" = "deck" ]; then
            return 0
        fi
    fi
    return 1
}

# =============================
# Always remove the autostart file on script exit to prevent unwanted autostart on boot
cleanup_autostart() {
    rm -f "$HOME/.config/autostart/minecraft-launch.desktop"
}
trap cleanup_autostart EXIT


# =============================
# MAIN LOGIC: Entry Point
# =============================
# Universal: Steam Deck Game Mode = nested KDE, else just launch on current desktop
if isSteamDeckGameMode; then
    if [ "$1" = launchFromPlasma ]; then
        # Inside nested Plasma session: launch Minecraft splitscreen and logout when done
        rm ~/.config/autostart/minecraft-launch.desktop
        launchGames
        qdbus org.kde.Shutdown /Shutdown org.kde.Shutdown.logout
    else
        # Not yet in nested session: start it
        nestedPlasma
    fi
else
    # Not in Game Mode: just launch Minecraft instances directly
    numberOfControllers=$(getControllerCount)
    for player in $(seq 1 $numberOfControllers); do
        setSplitscreenModeForPlayer "$player" "$numberOfControllers"
        launchGame "latestUpdate-$player" "P$player"
    done
    wait
fi



