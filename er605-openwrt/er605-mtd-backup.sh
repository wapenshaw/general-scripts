#!/bin/sh

# script to do mtd backup for er605 v2.1.2 to usb
# NTFS Formatted USB Disk for default operation
# mkdir -p /mnt/usb
# Find usb disk name using `fdisk -l`
# Mine was sda5
# mount using `mount /dev/sda5 /mnt/usb`


# change back to 192.168.1.1/24

## Adjust UBI Layout
set -e

OUTPUT_FILE="mtd_backup.tgz"
BACKUP_DIR="/mnt/usb/mtd_backup" # Replace with actual mount location
mkdir -p "${BACKUP_DIR}"

die() {
    echo 'failed, aborting...'
    exit 2
}

cat /proc/mtd | tail -n+2 | while read; do
    MTD_DEV=$(echo ${REPLY} | cut -f1 -d:)
    MTD_NAME=$(echo ${REPLY} | cut -f2 -d\")
    echo "Backing up ${MTD_DEV} (${MTD_NAME})"
    # It's important that the remote command only prints the actual file
    # contents to stdout, otherwise our backup files will be corrupted. Other
    # info must be printed to stderr instead. Luckily, this is how the dd
    # command already behaves by default, so no additional flags are needed.
    dd if="/dev/${MTD_DEV}ro" >"${BACKUP_DIR}/${MTD_DEV}_${MTD_NAME}.backup" || die
done

# Use gzip and tar to compress the backup files
echo "Compressing backup files to \"${OUTPUT_FILE}\""
(cd /mnt/usb && tar czf - "$(basename "${BACKUP_DIR}")") >"${OUTPUT_FILE}" || die

# Clean up a little earlier, so the completion message is the last thing the user sees
set +e

echo -e "\nMTD backup complete. Extract the files using:\ntar xzf \"${OUTPUT_FILE}\""
