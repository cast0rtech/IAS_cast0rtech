#!/usr/bin/env bash
# ==============================================================================
# EMA Industrial Appliance - Automated Provisioning Script for Raspberry Pi OS
# Supported OS: Raspberry Pi OS Lite (64-bit / Debian Bookworm)
# Hardware: Raspberry Pi 3B+, 4, 5, CM4, CM5
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

INSTALL_DIR="/opt/ema"
REPO_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# 1. Root check
if [ "$EUID" -ne 0 ]; then
    error "Please execute this script with sudo: sudo ./setup.sh"
fi

echo -e "${GREEN}"
cat << "EOF"
  ______ __  __          
 |  ____|  \/  |   /\    
 | |__  | \  / |  /  \   
 |  __| | |\/| | / /\ \  
 | |____| |  | |/ ____ \ 
 |______|_|  |_/_/    \_\
 Alarm Management & Telemetry - Raspberry Pi OS Provisioner
EOF
echo -e "${NC}"

# 2. Architecture and OS check
ARCH=$(uname -m)
info "Checking hardware architecture: $ARCH"
case "$ARCH" in
    aarch64|arm64)
        info "64-bit ARM architecture confirmed."
        ;;
    armv7l)
        warn "32-bit ARM detected. 64-bit Raspberry Pi OS is strongly recommended for production."
        ;;
    *)
        warn "Non-standard ARM architecture ($ARCH). Continuing under assumption of container compatibility."
        ;;
esac

# 3. System update & prerequisite packages
info "Updating APT repositories and installing prerequisites..."
apt-get update -y
apt-get install -y --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    chrony \
    ufw \
    tar \
    git

# Configure Chrony for reliable timekeeping (critical for alarm logs)
systemctl enable chrony
systemctl restart chrony
info "NTP time synchronization configured via chrony."

# 4. Hardware Watchdog Configuration
info "Configuring hardware watchdog (BCM2835 WDT)..."
if ! grep -q "bcm2835_wdt" /etc/modules 2>/dev/null; then
    echo "bcm2835_wdt" >> /etc/modules
fi

# Enable systemd runtime watchdog to trigger reboot on system freeze
if grep -q "^#RuntimeWatchdogSec=" /etc/systemd/system.conf; then
    sed -i 's/^#RuntimeWatchdogSec=.*/RuntimeWatchdogSec=15s/' /etc/systemd/system.conf
elif ! grep -q "^RuntimeWatchdogSec=" /etc/systemd/system.conf; then
    echo "RuntimeWatchdogSec=15s" >> /etc/systemd/system.conf
fi
systemctl daemon-reload

# 5. Prevent SD card wear: tune journald and swappiness
info "Optimizing storage for SD card longevity..."
mkdir -p /etc/systemd/journald.conf.d/
cat << 'EOF' > /etc/systemd/journald.conf.d/00-rpi-storage.conf
[Journal]
Storage=persistent
SystemMaxUse=50M
RuntimeMaxUse=20M
MaxRetentionSec=1month
EOF
systemctl restart systemd-journald

# Lower swap write frequency
if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
    echo "vm.swappiness=10" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1 || true
fi

# 6. Install Docker Engine & Compose from official repository
if ! command -v docker &> /dev/null; then
    info "Installing Docker Engine from official Docker repository..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    VERSION_CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $VERSION_CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    success "Docker Engine installed successfully."
else
    info "Docker is already installed ($(docker --version))."
fi

systemctl enable docker
systemctl start docker

# Add non-root user (e.g. pi or current sudoer) to docker group
TARGET_USER="${SUDO_USER:-pi}"
if id "$TARGET_USER" &>/dev/null; then
    usermod -aG docker "$TARGET_USER"
    info "Added user '$TARGET_USER' to docker group."
fi

# 7. Configure Application in /opt/ema
info "Deploying EMA codebase to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
cp -r "$REPO_SOURCE"/* "$INSTALL_DIR/"

cd "$INSTALL_DIR"

if [ ! -f .env ]; then
    info "Creating default .env from .env.example..."
    cp .env.example .env
fi

# Set proper permissions for scripts
chmod +x "$INSTALL_DIR/rpi/scripts/"*.sh 2>/dev/null || true

# 8. Firewall Configuration (UFW)
info "Configuring UFW firewall rules..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment "SSH Remote Management"
ufw allow 8080/tcp comment "EMA Dashboard UI"
# Modbus (502) and Asterisk SIP (5060/UDP) can be enabled if required
if grep -q "EMA_MODBUS_ENABLED=true" .env; then
    ufw allow 502/tcp comment "Modbus TCP"
fi
if grep -q "EMA_CALLS_ENABLED=true" .env; then
    ufw allow 5060/udp comment "Asterisk SIP"
    ufw allow 10000:10100/udp comment "Asterisk RTP Audio"
fi
ufw --force enable
info "Firewall enabled (SSH: 22, Web UI: 8080)."

# 9. Install and Enable Systemd Services
info "Configuring systemd service units..."
cp "$INSTALL_DIR/rpi/systemd/ema.service" /etc/systemd/system/
cp "$INSTALL_DIR/rpi/systemd/ema-watchdog.service" /etc/systemd/system/

systemctl daemon-reload
systemctl enable ema.service
systemctl enable ema-watchdog.service

info "Starting EMA stack via systemd..."
systemctl restart ema.service
systemctl restart ema-watchdog.service

# 10. Optional Kiosk Mode Setup
if [ "${1:-}" = "--kiosk" ]; then
    info "Configuring HDMI Touchscreen Kiosk Mode..."
    apt-get install -y --no-install-recommends \
        xserver-xorg \
        x11-xserver-utils \
        xinit \
        openbox \
        chromium-browser \
        unclutter
    cp "$INSTALL_DIR/rpi/systemd/ema-kiosk.service" /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable ema-kiosk.service
    success "Kiosk service enabled on graphical.target."
fi

# Final status verification
success "====================================================================="
success "EMA Appliance successfully configured on this Raspberry Pi!"
success "Web Dashboard URL: http://$(hostname -I | awk '{print $1}'):8080"
success "API Documentation: http://$(hostname -I | awk '{print $1}'):8000/docs"
success "Systemd Service:   sudo systemctl status ema.service"
success "Watchdog Service:  sudo systemctl status ema-watchdog.service"
success "====================================================================="
