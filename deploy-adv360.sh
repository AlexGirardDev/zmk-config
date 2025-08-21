#!/usr/bin/env bash


# ADV360 Firmware Deploy Script
# This script waits for the ADV360PRO to be attached in bootloader mode
# and automatically copies the left side firmware to the device

set -euo pipefail

# Enable debug mode if DEBUG env var is set
if [[ "${DEBUG:-}" == "1" ]]; then
    set -x
fi

# Configuration
FIRMWARE_FILE="firmware/adv360_left.uf2"
DEVICE_LABEL="ADV360PRO"
MOUNT_POINT="/media/$USER/$DEVICE_LABEL"
MAX_WAIT_TIME=300  # 5 minutes timeout

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if firmware file exists
check_firmware_file() {
    if [[ ! -f "$FIRMWARE_FILE" ]]; then
        print_error "Firmware file not found: $FIRMWARE_FILE"
        print_error "Please build the firmware first with: just build adv360"
        exit 1
    fi
    print_status "Found firmware file: $FIRMWARE_FILE ($(du -h "$FIRMWARE_FILE" | cut -f1))"
}

# Find the actual mount point of the ADV360PRO device
find_device_mount() {
    # Check common mount locations
    local possible_mounts=(
        "/media/$USER/$DEVICE_LABEL"
        "/media/$DEVICE_LABEL"
        "/mnt/$DEVICE_LABEL"
        "/run/media/$USER/$DEVICE_LABEL"
    )
    
    # Also check what's currently mounted
    local mounted_devices=$(mount | grep -i "$DEVICE_LABEL" | cut -d' ' -f3 | head -1 || true)
    if [[ -n "$mounted_devices" ]]; then
        echo "$mounted_devices"
        return 0
    fi
    
    # Check predefined locations
    for mount_point in "${possible_mounts[@]}"; do
        if [[ -d "$mount_point" ]] && [[ -n "$(ls -A "$mount_point" 2>/dev/null)" ]]; then
            echo "$mount_point"
            return 0
        fi
    done
    
    # Check if device appears in lsblk output
    local device_path=$(lsblk -o NAME,LABEL,MOUNTPOINT | grep -i "$DEVICE_LABEL" | awk '{print $3}' | head -1 || true)
    if [[ -n "$device_path" ]] && [[ -d "$device_path" ]]; then
        echo "$device_path"
        return 0
    fi
    
    return 1
}

# Check if the device is already mounted
is_device_mounted() {
    local mount_point=$(find_device_mount)
    if [[ -n "$mount_point" ]]; then
        MOUNT_POINT="$mount_point"
        return 0
    else
        return 1
    fi
}

# Wait for device to be attached and mounted
wait_for_device() {
    local wait_time=0
    print_status "Waiting for ADV360PRO to be attached in bootloader mode..."
    print_status "Put your keyboard into bootloader mode now."
    print_status "Checking for device every second..."
    
    while [[ $wait_time -lt $MAX_WAIT_TIME ]]; do
        if is_device_mounted; then
            print_success "ADV360PRO detected and mounted at $MOUNT_POINT"
            return 0
        fi
        
        # Show debug info every 10 seconds
        if (( wait_time % 10 == 0 )) && [[ $wait_time -gt 0 ]]; then
            print_status "Still waiting... (${wait_time}s elapsed)"
            print_status "Checking mounted devices:"
            mount | grep -i "adv360\|bootloader" || print_status "  No ADV360 devices found in mount table"
            lsblk | grep -i "adv360\|bootloader" || print_status "  No ADV360 devices found in block devices"
        fi
        
        # Show a progress indicator every 5 seconds
        if (( wait_time % 5 == 0 )); then
            echo -n "."
        fi
        
        sleep 1
        ((wait_time++))
    done
    
    echo # New line after progress dots
    print_error "Timeout waiting for ADV360PRO to be attached"
    print_error "Make sure the keyboard is in bootloader mode and try again"
    exit 1
}

# Copy firmware to device
deploy_firmware() {
    print_status "Copying firmware to ADV360PRO..."
    
    # Verify mount point is writable
    if [[ ! -w "$MOUNT_POINT" ]]; then
        print_error "Cannot write to $MOUNT_POINT - check permissions"
        exit 1
    fi
    
    # Copy firmware file
    if cp "$FIRMWARE_FILE" "$MOUNT_POINT/"; then
        print_success "Firmware copied successfully!"
        print_status "The keyboard should automatically restart and apply the new firmware"
    else
        print_error "Failed to copy firmware file"
        exit 1
    fi
}

# Wait for device to unmount (indicating successful flash)
wait_for_unmount() {
    print_status "Waiting for device to unmount (indicating successful flash)..."
    local wait_time=0
    
    while [[ $wait_time -lt 30 ]] && is_device_mounted; do
        sleep 1
        ((wait_time++))
    done
    
    if ! is_device_mounted; then
        print_success "Device unmounted - firmware flash completed!"
    else
        print_warning "Device still mounted after 30 seconds - this may be normal"
    fi
}

# Main execution
main() {
    echo "=== ADV360 Firmware Deploy Script ==="
    echo
    
    # Check prerequisites
    check_firmware_file
    
    # If device is already mounted, skip waiting
    if is_device_mounted; then
        print_success "ADV360PRO already detected at $MOUNT_POINT"
    else
        wait_for_device
    fi
    
    # Deploy firmware
    deploy_firmware
    
    # Wait for completion
    wait_for_unmount
    
    echo
    print_success "Deployment complete! Your ADV360 should now be running the new firmware."
    echo
}

# Handle Ctrl+C gracefully
trap 'echo; print_warning "Script interrupted by user"; exit 1' INT

# Run main function
main "$@"
