#!/bin/bash
# tools/remote/btrfs-snapshot.sh

set -euo pipefail

# Configuration
BTRFS_MOUNT="/mnt/state"            # Mount point of the btrfs volume itself
SUBVOLUMES=("@storage" "@database") # Subvolumes to snapshot
RETENTION_HOURS=24

# Ensure btrfs root is mounted
if ! mountpoint -q "$BTRFS_MOUNT"; then
    echo "Error: $BTRFS_MOUNT is not mounted"
    exit 1
fi

# Create timestamp for this snapshot batch
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Snapshot each subvolume
for subvol in "${SUBVOLUMES[@]}"; do
    SNAPSHOT_NAME="${subvol}-${TIMESTAMP}"
    SNAPSHOT_PATH="${BTRFS_MOUNT}/.snapshots/${SNAPSHOT_NAME}"

    # Create .snapshots directory if needed
    mkdir -p "${BTRFS_MOUNT}/.snapshots"

    echo "Creating snapshot: $SNAPSHOT_PATH"
    btrfs subvolume snapshot -r "${BTRFS_MOUNT}/${subvol}" "$SNAPSHOT_PATH"
done

# Cleanup old snapshots for each subvolume
echo "Cleaning up old snapshots..."
for subvol in "${SUBVOLUMES[@]}"; do
    find "${BTRFS_MOUNT}/.snapshots" -maxdepth 1 -type d -name "${subvol}-*" -mmin +$((RETENTION_HOURS * 60)) | while read -r old_snapshot; do
        echo "Deleting old snapshot: $old_snapshot"
        btrfs subvolume delete "$old_snapshot"
    done
done

echo "Snapshot operation completed successfully"
