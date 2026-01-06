#!/bin/bash
# Fast Void Linux Installer
# Automated installation with minimal prompts
# Inspired by arch-ez (https://github.com/haider-IQZ/arch-ez)

set -e

echo "======================================"
echo "Fast Void Linux Installer"
echo "======================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: This script must be run as root!"
    echo "Run: sudo bash void-ez.sh"
    exit 1
fi

# Check if running in UEFI mode
if [ ! -d /sys/firmware/efi ]; then
    echo "ERROR: This script only supports UEFI systems!"
    exit 1
fi

# Check and install host dependencies (needed for partitioning/formatting)
echo "Checking for host dependencies..."
MISSING_DEPS=""
command -v sgdisk >/dev/null || MISSING_DEPS="$MISSING_DEPS gptfdisk"
command -v partprobe >/dev/null || MISSING_DEPS="$MISSING_DEPS parted"
command -v mkfs.fat >/dev/null || MISSING_DEPS="$MISSING_DEPS dosfstools"
command -v mkfs.ext4 >/dev/null || MISSING_DEPS="$MISSING_DEPS e2fsprogs"
command -v mkfs.btrfs >/dev/null || MISSING_DEPS="$MISSING_DEPS btrfs-progs"

if [ -n "$MISSING_DEPS" ]; then
    echo "Installing missing tools on live system:$MISSING_DEPS"
    xbps-install -Sy $MISSING_DEPS
fi

echo "======================================"
echo "System Configuration"
echo "======================================"
echo ""

# Get username
read -p "Enter username for your account: " USERNAME
while [ -z "$USERNAME" ]; do
    echo "Username cannot be empty!"
    read -p "Enter username for your account: " USERNAME
done

# Get password
while true; do
    read -sp "Enter password for $USERNAME: " PASSWORD
    echo ""
    read -sp "Confirm password: " PASSWORD2
    echo ""
    if [ "$PASSWORD" = "$PASSWORD2" ]; then
        break
    else
        echo "Passwords don't match! Try again."
    fi
done

# Get hostname (machine name)
read -p "Enter hostname (machine name): " HOSTNAME
while [ -z "$HOSTNAME" ]; do
    echo "Hostname cannot be empty!"
    read -p "Enter hostname (machine name): " HOSTNAME
done

echo ""
echo "Configuration:"
echo "  Username: $USERNAME"
echo "  Hostname: $HOSTNAME"
echo ""

echo "======================================"
echo "Disk Selection"
echo "======================================"
echo ""
echo "WARNING: This will ERASE ALL DATA on the selected disk!"
echo ""

# List available disks
echo "Available disks:"
lsblk -d -n -o NAME,SIZE,TYPE | grep disk | nl
echo ""

# Select disk
read -p "Enter disk number to install on (e.g., 1 for first disk): " disk_num
DISK=$(lsblk -d -n -o NAME,TYPE | grep disk | sed -n "${disk_num}p" | awk '{print $1}')

if [ -z "$DISK" ]; then
    echo "ERROR: Invalid disk selection!"
    exit 1
fi

DISK="/dev/$DISK"
echo "Selected disk: $DISK"
echo ""

# Choose filesystem
echo "Choose filesystem:"
echo "1) ext4 (stable, fast)"
echo "2) btrfs (snapshots, compression)"
read -p "Enter choice (1-2): " fs_choice

case $fs_choice in
    1)
        FILESYSTEM="ext4"
        ;;
    2)
        FILESYSTEM="btrfs"
        ;;
    *)
        echo "Invalid choice, using ext4"
        FILESYSTEM="ext4"
        ;;
esac

echo "Using filesystem: $FILESYSTEM"
echo ""

# Final confirmation
read -p "This will ERASE $DISK and install Void Linux. Continue? (yes/NO): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Installation cancelled."
    exit 0
fi

echo ""
echo "======================================"
echo "Step 1: Partitioning Disk"
echo "======================================"
echo ""

# Unmount if mounted
umount -R /mnt 2>/dev/null || true
swapoff -a 2>/dev/null || true

# Wipe disk
wipefs -af "$DISK"
sgdisk --zap-all "$DISK"

# Create partitions
echo "Creating partitions..."
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI" "$DISK"      # EFI partition (512MB)
sgdisk -n 2:0:+4G -t 2:8200 -c 2:"SWAP" "$DISK"       # SWAP partition (4GB)
sgdisk -n 3:0:0 -t 3:8300 -c 3:"ROOT" "$DISK"         # ROOT partition (rest)

# Reload partition table
partprobe "$DISK"
sleep 2

# Set partition variables
if [[ "$DISK" == *"nvme"* ]] || [[ "$DISK" == *"mmcblk"* ]]; then
    EFI_PART="${DISK}p1"
    SWAP_PART="${DISK}p2"
    ROOT_PART="${DISK}p3"
else
    EFI_PART="${DISK}1"
    SWAP_PART="${DISK}2"
    ROOT_PART="${DISK}3"
fi

echo "Partitions created:"
echo "  EFI:  $EFI_PART (512MB)"
echo "  SWAP: $SWAP_PART (4GB)"
echo "  ROOT: $ROOT_PART (remaining)"
echo ""

# Format partitions
echo "Formatting partitions..."
mkfs.fat -F32 "$EFI_PART"
mkswap "$SWAP_PART"

if [ "$FILESYSTEM" = "btrfs" ]; then
    mkfs.btrfs -f "$ROOT_PART"
else
    mkfs.ext4 -F "$ROOT_PART"
fi

echo "✓ Partitions formatted"
echo ""

# Mount partitions
echo "Mounting partitions..."
mount "$ROOT_PART" /mnt

# Create EFI mount point
mkdir -p /mnt/boot/efi
mount "$EFI_PART" /mnt/boot/efi

# Enable swap
swapon "$SWAP_PART"

echo "✓ Partitions mounted:"
echo "  $ROOT_PART -> /mnt"
echo "  $EFI_PART -> /mnt/boot/efi"
echo "  $SWAP_PART -> swap enabled"
echo ""

lsblk "$DISK"
echo ""

echo "======================================"
echo "Step 2: Installing Base System"
echo "======================================"
echo ""

# Void Linux base installation
echo "Installing base system (this will take a few minutes)..."

# Set repository and architecture (following official chroot guide)
REPO="https://repo-default.voidlinux.org/current"
ARCH="x86_64"

# Copy keys for XBPS
mkdir -p /mnt/var/db/xbps/keys
cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/

# Install base system first
echo "Installing base-system via XBPS method..."
XBPS_ARCH=$ARCH xbps-install -S -y -r /mnt -R "$REPO" base-system

# Install repositories for non-free and multilib
echo "Enabling non-free and multilib repositories..."
XBPS_ARCH=$ARCH xbps-install -S -y -r /mnt -R "$REPO" void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree

# Install additional packages
echo "Installing additional packages..."
XBPS_ARCH=$ARCH xbps-install -S -y -r /mnt -R "$REPO" \
    grub-x86_64-efi \
    efibootmgr \
    git \
    vim \
    sudo \
    NetworkManager \
    dbus \
    elogind \
    polkit \
    pipewire \
    libpulseaudio \
    nvidia \
    nvidia-libs \
    nvidia-dkms \
    linux-headers \
    base-devel \
    bash-completion \
    curl \
    wget \
    xtools

echo "✓ Base system and packages installed"
echo ""

# Generate fstab (following official guide using xgenfstab if possible, fallback to manual)
echo "Generating fstab..."
if command -v xgenfstab >/dev/null; then
    xgenfstab -U /mnt > /mnt/etc/fstab
else
    ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
    EFI_UUID=$(blkid -s UUID -o value "$EFI_PART")
    SWAP_UUID=$(blkid -s UUID -o value "$SWAP_PART")

    cat > /mnt/etc/fstab << EOF
# <file system> <mount point> <type> <options> <dump> <pass>
UUID=$ROOT_UUID / $FILESYSTEM defaults 0 1
UUID=$EFI_UUID /boot/efi vfat defaults 0 2
UUID=$SWAP_UUID none swap sw 0 0
tmpfs /tmp tmpfs defaults,nosuid,nodev 0 0
EOF
fi
echo "✓ fstab generated"
echo ""

echo "======================================"
echo "Step 3: System Configuration"
echo "======================================"
echo ""

# Create chroot configuration script
# We use xchroot if available, or manual mount
cat > /mnt/root/configure.sh << 'CHROOT_EOF'
#!/bin/bash
set -e

echo "Setting timezone to Asia/Baghdad..."
ln -sf /usr/share/zoneinfo/Asia/Baghdad /etc/localtime
# hwclock not always available in base, but common
hwclock --systohc 2>/dev/null || true
echo "✓ Timezone set"

echo "Setting locale to en_US.UTF-8..."
echo "en_US.UTF-8 UTF-8" > /etc/default/libc-locales
xbps-reconfigure -f glibc-locales
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "✓ Locale set"

echo "Setting hostname..."
echo "HOSTNAME_PLACEHOLDER" > /etc/hostname
echo "✓ Hostname set"

echo "Creating user USERNAME_PLACEHOLDER..."
useradd -m -G wheel,audio,video,storage -s /bin/bash USERNAME_PLACEHOLDER
# Use a more robust pipe for password setting
echo -e "PASSWORD_PLACEHOLDER\nPASSWORD_PLACEHOLDER" | passwd USERNAME_PLACEHOLDER
echo "✓ User created"

echo "Setting root password..."
echo -e "PASSWORD_PLACEHOLDER\nPASSWORD_PLACEHOLDER" | passwd root
echo "✓ Root password set"

echo "Enabling sudo for wheel group..."
# In Void, sudo is usually pre-installed but check anyway
if command -v sudo >/dev/null; then
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
fi
echo "✓ Sudo enabled"

echo "Installing GRUB bootloader..."
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="Void"
echo "✓ GRUB installed"

echo "Generating GRUB configuration..."
# Enable NVIDIA modesetting for Wayland
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia-drm.modeset=1 /' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
echo "✓ GRUB configured"

echo "Configuring services (runit)..."
# Enable dbus first (essential for many services)
ln -sf /etc/sv/dbus /etc/runit/runsvdir/default/
# Enable NetworkManager
ln -sf /etc/sv/NetworkManager /etc/runit/runsvdir/default/
# Enable nanokernel/udev etc if needed, but they are usually automatic
echo "✓ Services configured"

echo "Reconfiguring base system and generating initramfs..."
# This will run dracut and other hooks
xbps-reconfigure -fa
echo "✓ System reconfigured"

echo "Configuration complete!"
CHROOT_EOF

# Replace placeholders with actual values
sed -i "s/HOSTNAME_PLACEHOLDER/$HOSTNAME/g" /mnt/root/configure.sh
sed -i "s/USERNAME_PLACEHOLDER/$USERNAME/g" /mnt/root/configure.sh
sed -i "s/PASSWORD_PLACEHOLDER/$PASSWORD/g" /mnt/root/configure.sh

# Make script executable
chmod +x /mnt/root/configure.sh

# Run configuration in chroot
echo "Running system configuration..."
# Use xchroot if available (standard on Void ISO), otherwise manual mount
if command -v xchroot >/dev/null; then
    xchroot /mnt /root/configure.sh
else
    mount -t proc proc /mnt/proc
    mount -t sysfs sys /mnt/sys
    mount -B /dev /mnt/dev
    mount -t devpts pts /mnt/dev/pts
    mount -t efivarfs none /mnt/sys/firmware/efi/efivars 2>/dev/null || true
    cp /etc/resolv.conf /mnt/etc/
    chroot /mnt /root/configure.sh
    umount /mnt/proc /mnt/sys /mnt/dev/pts /mnt/dev
fi

# Clean up
rm /mnt/root/configure.sh

echo ""
echo "======================================"
echo "System configuration complete!"
echo "======================================"
echo ""
echo "Installation finished!"
echo ""
echo "System details:"
echo "  Username: $USERNAME"
echo "  Hostname: $HOSTNAME"
echo "  Timezone: Asia/Baghdad"
echo "  Locale: en_US.UTF-8"
echo ""
echo "You can now reboot into your new Void Linux system!"
echo ""
read -p "Reboot now? (y/N): " reboot_choice
if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
    umount -R /mnt
    reboot
else
    echo "Remember to unmount /mnt and reboot manually:"
    echo "  umount -R /mnt"
    echo "  reboot"
fi
