#!/usr/bin/env bash
set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
# Each keyboard entry maps a volume label to a space-separated list of firmware
# files. For split keyboards with the same label, the script flashes one file
# per bootloader appearance, waiting for reconnect between halves.
declare -A KEYBOARDS=(
    ["ADV360PRO"]="firmware/adv360_left.uf2"
    ["NICENANO"]="firmware/handwired65-nice_nano_v2.uf2"
    ["NRF52BOOT"]="firmware/handwired65-nice_nano_v2.uf2"
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLL_INTERVAL=1

# ── Helpers ──────────────────────────────────────────────────────────────────
find_device() {
    local label=$1
    local dev
    dev=$(readlink -f "/dev/disk/by-label/$label" 2>/dev/null) || return 1
    [[ -b "$dev" ]] && echo "$dev" || return 1
}

wait_for_disconnect() {
    local label=$1
    echo "  Waiting for device to disconnect..."
    while find_device "$label" &>/dev/null; do
        sleep 0.5
    done
}

flash_file() {
    local label=$1
    local fw=$2

    local dev
    dev=$(find_device "$label") || return 1

    # Mount via udisksctl (doesn't need root)
    local mount_output mount_point
    mount_output=$(udisksctl mount -b "$dev" 2>&1) || {
        # Already mounted? Extract mount point from lsblk
        mount_point=$(lsblk -no MOUNTPOINT "$dev" | head -1)
        if [[ -z "$mount_point" ]]; then
            echo "  Failed to mount $dev: $mount_output"
            return 1
        fi
    }
    mount_point=${mount_point:-$(echo "$mount_output" | grep -oP 'at \K.+')}

    echo "  Mounted $dev at $mount_point"
    echo "  Copying $(basename "$fw")..."
    cp "$fw" "$mount_point/"

    # The device resets itself after receiving the UF2 file, so sync/unmount
    # may fail if it disconnects quickly. That's fine — the copy succeeded.
    sync 2>/dev/null || true
    sleep 1
    udisksctl unmount -b "$dev" 2>/dev/null || true
}

# ── Main ─────────────────────────────────────────────────────────────────────
echo "Watching for bootloader devices..."
echo "Known labels: ${!KEYBOARDS[*]}"
echo "Put your keyboard into bootloader mode."
echo ""

for label in "${!KEYBOARDS[@]}"; do
    read -ra files <<< "${KEYBOARDS[$label]}"
    file_index=0

    while (( file_index < ${#files[@]} )); do
        fw="${SCRIPT_DIR}/${files[$file_index]}"

        if [[ ! -f "$fw" ]]; then
            echo "Firmware not found: $fw"
            echo "Run 'just build adv360' first."
            exit 1
        fi

        # Wait for device to appear
        while ! find_device "$label" &>/dev/null; do
            sleep "$POLL_INTERVAL"
        done

        echo "[$label] Detected! ($(basename "$fw"))"
        if flash_file "$label" "$fw"; then
            echo "  Flashed $(basename "$fw")!"
            (( file_index++ ))

            # If more files to flash, wait for disconnect then prompt
            if (( file_index < ${#files[@]} )); then
                wait_for_disconnect "$label"
                echo ""
                echo "Now put the other half into bootloader mode..."
            fi
        else
            echo "  Flash failed, will retry..."
            sleep 2
        fi
        echo ""
    done
done

echo "All devices flashed. Done!"
