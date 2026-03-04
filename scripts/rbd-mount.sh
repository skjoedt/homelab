#!/bin/bash

# Usage: ./rbd-mount.sh [mount|unmount] [image_name]
# Example: ./rbd-mount.sh mount radarr-config

ACTION=$1
IMAGE=$2
POOL="kubernetes" # Adjust if your pool name is different
MNT_PATH="/mnt/rbd/${IMAGE}"

do_mount() {
    echo "--- Mapping and Mounting ${IMAGE} ---"
    
    # Map the RBD image (returns the /dev/rbdX path)
    DEVICE=$(sudo rbd map "${POOL}/${IMAGE}")
    echo "Mapped: ${IMAGE} -> ${DEVICE}"
    # Create deterministic mount point
    sudo mkdir -p "$MNT_PATH"
    
    # Mount the device
    sudo mount "$DEVICE" "$MNT_PATH"
    
    echo "Mounted: ${IMAGE} -> ${MNT_PATH}"
}

do_unmount() {
    echo "--- Unmounting and Unmapping ${IMAGE} ---"
    
    # Unmount the path
    sudo umount "$MNT_PATH" 2>/dev/null || echo "Not mounted."
    
    # Unmap by the pool/image name to avoid tracking /dev/rbdX numbers
    sudo rbd unmap "${POOL}/${IMAGE}" 2>/dev/null || echo "Not mapped."
    
    # Clean up the directory
    sudo rmdir "$MNT_PATH" 2>/dev/null
    
    echo "Cleanup complete for ${IMAGE}."
}

case "$ACTION" in
    mount)   do_mount ;;
    unmount) do_unmount ;;
    *) echo "Usage: $0 {mount|unmount} image_name"; exit 1 ;;
esac