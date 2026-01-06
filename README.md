# void-ez 🚀
**Fast & Automated Void Linux Installer**

`void-ez` is a streamlined, minimal-prompt installation script for Void Linux (glibc/x86_64). Inspired by the simplicity of [arch-ez](https://github.com/haider-IQZ/arch-ez), this script automates the manual chroot installation process while following the official [Void Linux Handbook](https://docs.voidlinux.org/installation/guides/chroot.html).

---

## ✨ Features
- **UEFI Only**: Modern, clean setup.
- **Minimal Prompts**: Only asks for the essentials (Username, Password, Hostname, Disk, Filesystem).
- **Filesystem Choice**: Supports `ext4` and `btrfs`.
- **Automatic Repos**: Enables `non-free`, `multilib`, and `multilib-nonfree` repositories.
- **Nvidia Ready**: Pre-installs Nvidia drivers and DKMS.
- **Modern Audio**: Includes Pipewire and Wireplumber setup.
- **Official Chroot Method**: Uses the official XBPS bootstrap method for a clean system.

---

## 🛠️ Usage

### 1. Boot the Live ISO
Boot into the official [Void Linux Live Image](https://voidlinux.org/download/) (UEFI mode).

### 2. Download and Run
Connect to the internet, then run:

```bash
# Clone the repo (or just download the script)
git clone https://github.com/haider-IQZ/void-ez
cd void-ez

# Make it executable
chmod +x void-ez.sh

# Run the installer
sudo ./void-ez.sh
```

---

## 📦 What's Included?
By default, the script installs:
- **Base**: `base-system`, `base-devel`, `xtools`
- **Boot**: `grub-x86_64-efi`, `efibootmgr`
- **Networking**: `NetworkManager`
- **Drivers**: `nvidia`, `nvidia-libs`, `nvidia-dkms` (with `linux-headers`)
- **Audio**: `pipewire`, `libpulseaudio`
- **Tools**: `vim`, `git`, `curl`, `wget`, `bash-completion`

---

## 🖥️ Wayland on NVIDIA
If you are using a Wayland compositor (Niri, KDE Wayland, Hyprland), the script automatically enables `nvidia-drm.modeset=1`.

However, you should add these environment variables to your `~/.bash_profile` or `~/.zprofile` to fix common issues:

```bash
export LIBVA_DRIVER_NAME=nvidia
export XDG_SESSION_TYPE=wayland
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export WLR_NO_HARDWARE_CURSORS=1
```

---

## ⚠️ Warning
**This script will ERASE ALL DATA on the selected disk.** Use it at your own risk. It is designed for UEFI systems only.

---

## 🤝 Credits
- Inspired by [arch-ez](https://github.com/haider-IQZ/arch-ez).
- Based on the [Void Linux Wiki](https://docs.voidlinux.org/).

---

## 📄 License
MIT
