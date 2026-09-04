#!/usr/bin/env bash
set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
# Each keyboard entry maps a volume label to a space-separated list of firmware
# files. For split keyboards with the same label, the script flashes one file
# per bootloader appearance, waiting for reconnect between halves.
declare -A KEYBOARDS=(
    # Both Adv360 halves expose the same volume label, so their files are flashed
    # in the order listed here: left first, then right. The script prints the
    # file it is writing and prompts before the second half.
    ["ADV360PRO"]="firmware/adv360pro_left.uf2 firmware/adv360pro_right.uf2"
    ["NICENANO"]="firmware/handwired65-nice_nano_v2.uf2"
    ["NRF52BOOT"]="firmware/handwired65-nice_nano_v2.uf2"
    # XIAO nRF52840 dongle. Confirmed label on the Sense (2886:0045); other
    # bootloader versions may differ, so if it is never detected, double-tap
    # reset and check `ls /dev/disk/by-label/`.
    ["XIAO-SENSE"]="firmware/adv360pro_dongle-seeeduino_xiao_ble.uf2"
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

# Track remaining files per label: label -> "file1 file2 ..."
declare -A REMAINING
for label in "${!KEYBOARDS[@]}"; do
    REMAINING[$label]="${KEYBOARDS[$label]}"
done

while true; do
    # Check if anything left to flash
    any_left=false
    for label in "${!REMAINING[@]}"; do
        [[ -n "${REMAINING[$label]}" ]] && any_left=true && break
    done
    $any_left || break

    # Poll for any known device
    found_label=""
    for label in "${!REMAINING[@]}"; do
        [[ -z "${REMAINING[$label]}" ]] && continue
        if find_device "$label" &>/dev/null; then
            found_label="$label"
            break
        fi
    done

    if [[ -z "$found_label" ]]; then
        sleep "$POLL_INTERVAL"
        continue
    fi

    # Flash the next file for this device
    read -ra files <<< "${REMAINING[$found_label]}"
    fw="${SCRIPT_DIR}/${files[0]}"

    if [[ ! -f "$fw" ]]; then
        echo "Firmware not found: $fw"
        echo "Run 'just build' first."
        exit 1
    fi

    echo "[$found_label] Detected! ($(basename "$fw"))"
    if flash_file "$found_label" "$fw"; then
        echo "  Flashed $(basename "$fw")!"

        # Remove the flashed file from the list
        REMAINING[$found_label]="${files[*]:1}"

        # If more files for this label, wait for disconnect and prompt
        if [[ -n "${REMAINING[$found_label]}" ]]; then
            wait_for_disconnect "$found_label"
            echo ""
            echo "Now put the other half into bootloader mode..."
        fi
    else
        echo "  Flash failed, will retry..."
        sleep 2
    fi
    echo ""
done

echo "All devices flashed. Done!"
