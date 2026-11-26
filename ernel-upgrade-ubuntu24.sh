
#!/usr/bin/env bash

# ============================================================
# AWS EC2 Kernel Upgrade
# Platform : Ubuntu 24.04 LTS (Noble)
# Kernel   : AWS Kernel (linux-aws)
# Purpose  : Upgrade kernel and generate STDOUT report
# ============================================================

set -Eeuo pipefail

SCRIPT_NAME="AWS EC2 Kernel Upgrade"
PACKAGE="linux-aws"
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
CURRENT_KERNEL=$(uname -r)
OS_NAME="Unknown"
OS_VERSION="Unknown"
OS_CODENAME="Unknown"
ARCH=$(dpkg --print-architecture)

# Colors
if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    GREEN='' YELLOW='' RED='' BLUE='' CYAN='' NC=''
fi

PASS=0
WARN=0
FAIL=0

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $*"
}

success() {
    echo -e "${GREEN}[PASS]${NC} $*"
    ((PASS+=1))
}

warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
    ((WARN+=1))
}

error() {
    echo -e "${RED}[FAIL]${NC} $*"
    ((FAIL+=1))
}

section() {
    echo
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN} $*${NC}"
    echo -e "${CYAN}============================================================${NC}"
}

finish() {
    local exit_code=$?

    echo
    section "UPGRADE SUMMARY"

    printf "Hostname          : %s\n" "$(hostname)"
    printf "Operating System  : %s %s\n" "$OS_NAME" "$OS_VERSION"
    printf "Architecture      : %s\n" "$ARCH"
    printf "Previous Kernel   : %s\n" "$CURRENT_KERNEL"
    printf "Current Kernel    : %s\n" "$(uname -r)"
    printf "Kernel Package    : %s\n" "$PACKAGE"
    printf "Started           : %s\n" "$START_TIME"
    printf "Finished          : %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"

    echo
    echo -e "Checks passed     : ${GREEN}${PASS}${NC}"
    echo -e "Warnings          : ${YELLOW}${WARN}${NC}"
    echo -e "Errors            : ${RED}${FAIL}${NC}"

    if [[ -f /var/run/reboot-required ]]; then
        echo -e "Reboot Status     : ${YELLOW}REQUIRED${NC}"
        echo "Action            : Schedule reboot during maintenance window"
    else
        echo -e "Reboot Status     : ${GREEN}NOT REQUIRED${NC}"
    fi

    if [[ $exit_code -eq 0 ]]; then
        echo -e "\nOverall Status    : ${GREEN}COMPLETED${NC}"
    else
        echo -e "\nOverall Status    : ${RED}FAILED / INCOMPLETE${NC}"
    fi

    echo
    echo "Note: Installed kernel is not necessarily the running kernel."
    echo "Verify with uname -r after reboot."
    echo

    exit "$exit_code"
}

trap finish EXIT

# ------------------------------------------------------------
# 1. ROOT VALIDATION
# ------------------------------------------------------------

section "1. PRE-UPGRADE VALIDATION"

if [[ $EUID -ne 0 ]]; then
    error "Please execute this script using sudo or as root."
    exit 1
fi

success "Running with root privileges"

# ------------------------------------------------------------
# 2. OS VALIDATION
# ------------------------------------------------------------

source /etc/os-release

OS_NAME="${NAME:-Unknown}"
OS_VERSION="${VERSION_ID:-Unknown}"
OS_CODENAME="${VERSION_CODENAME:-Unknown}"

log "Operating System : $OS_NAME"
log "OS Version       : $OS_VERSION"
log "Codename         : $OS_CODENAME"
log "Architecture     : $ARCH"
log "Running Kernel   : $CURRENT_KERNEL"

if [[ "${ID:-}" != "ubuntu" ]] ||
   [[ "$OS_CODENAME" != "noble" ]] ||
   [[ "$OS_VERSION" != 24.04* ]]; then
    error "This script only supports Ubuntu 24.04 LTS (Noble)."
    exit 1
fi

success "Ubuntu 24.04 LTS validated"

if [[ "$ARCH" != "amd64" && "$ARCH" != "arm64" ]]; then
    error "Unsupported architecture: $ARCH"
    exit 1
fi

success "Architecture validated"

# ------------------------------------------------------------
# 3. DISK SPACE VALIDATION
# ------------------------------------------------------------

BOOT_FREE_KB=$(df -Pk /boot | awk 'NR==2 {print $4}')

if [[ "$BOOT_FREE_KB" -lt 300000 ]]; then
    warning "Less than 300 MB available in /boot."
    warning "Check available disk space before installing kernel."
else
    success "Available /boot space: $((BOOT_FREE_KB / 1024)) MB"
fi

# ------------------------------------------------------------
# 4. PACKAGE HOLD CHECK
# ------------------------------------------------------------

HELD_PACKAGES=$(apt-mark showhold)

if echo "$HELD_PACKAGES" | grep -Eq 'linux|aws'; then
    warning "Kernel-related packages are on hold:"
    echo "$HELD_PACKAGES"
    error "Resolve package holds before proceeding."
    exit 1
else
    success "No kernel-related package holds detected"
fi

# ------------------------------------------------------------
# 5. UPDATE REPOSITORY
# ------------------------------------------------------------

section "2. UPDATE APT REPOSITORY"

log "Updating package repository..."

if ! apt-get update; then
    error "APT repository update failed."
    exit 1
fi

success "APT repository updated"

# ------------------------------------------------------------
# 6. CHECK KERNEL CANDIDATE
# ------------------------------------------------------------

section "3. KERNEL PACKAGE VALIDATION"

KERNEL_POLICY=$(apt-cache policy "$PACKAGE")
CANDIDATE=$(awk '/Candidate:/ {print $2; exit}' <<< "$KERNEL_POLICY")

echo "$KERNEL_POLICY"

if [[ -z "$CANDIDATE" || "$CANDIDATE" == "(none)" ]]; then
    error "No linux-aws candidate available in APT repository."
    exit 1
fi

success "Kernel candidate available: $CANDIDATE"

# ------------------------------------------------------------
# 7. SIMULATE INSTALLATION
# ------------------------------------------------------------

section "4. SIMULATE KERNEL UPGRADE"

log "Simulating linux-aws installation..."

if ! apt-get -s install "$PACKAGE"; then
    error "Kernel upgrade simulation failed."
    exit 1
fi

success "Simulation completed"

# ------------------------------------------------------------
# 8. CONFIRMATION
# ------------------------------------------------------------

section "5. EXECUTION CONFIRMATION"

echo "The following operation will be performed:"
echo "  - Install/upgrade AWS kernel metapackage"
echo "  - Install required kernel dependencies"
echo "  - No automatic reboot"
echo

read -r -p "Continue kernel upgrade? [y/N]: " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    warning "Upgrade cancelled by user."
    exit 0
fi

# ------------------------------------------------------------
# 9. INSTALL KERNEL
# ------------------------------------------------------------

section "6. KERNEL INSTALLATION"

log "Installing AWS kernel: $PACKAGE"

if ! DEBIAN_FRONTEND=noninteractive \
    apt-get install -y "$PACKAGE"; then
    error "Kernel installation failed."
    exit 1
fi

success "AWS kernel package installation completed"

# ------------------------------------------------------------
# 10. VERIFY INSTALLED KERNEL
# ------------------------------------------------------------

section "7. INSTALLED KERNEL VERIFICATION"

echo
echo "Installed AWS kernel packages:"
echo

dpkg-query -W \
    -f='${db:Status-Abbrev} ${binary:Package} ${Version}\n' \
    'linux-image-*-aws' 2>/dev/null || true

echo

NEW_KERNELS=$(dpkg-query -W \
    -f='${db:Status-Abbrev} ${binary:Package} ${Version}\n' \
    'linux-image-*-aws' 2>/dev/null |
    awk '$1 ~ /^ii/')

if [[ -n "$NEW_KERNELS" ]]; then
    success "Installed kernel images detected"
else
    error "No installed AWS kernel images detected"
    exit 1
fi

# ------------------------------------------------------------
# 11. REBOOT CHECK
# ------------------------------------------------------------

section "8. REBOOT REQUIREMENT"

if [[ -f /var/run/reboot-required ]]; then
    warning "System reboot is required."
    echo
    cat /var/run/reboot-required
else
    success "No reboot flag detected"
fi

# ------------------------------------------------------------
# 12. FINAL STATUS
# ------------------------------------------------------------

section "9. FINAL RESULT"

INSTALLED_KERNELS=$(dpkg-query -W \
    -f='${Version}\n' \
    'linux-image-*-aws' 2>/dev/null || true)

echo "Running kernel   : $(uname -r)"
echo "Kernel candidate : $CANDIDATE"
echo "Installed images :"
echo "$INSTALLED_KERNELS"

if [[ -f /var/run/reboot-required ]]; then
    warning "Kernel installed but not necessarily active."
    echo "Next action: Schedule reboot and verify uname -r."
else
    success "No reboot currently required."
fi

exit 0
