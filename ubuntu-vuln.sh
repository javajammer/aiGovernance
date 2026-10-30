#!/bin/bash
# CVE-2026-98432 Mitigation Script
# Usage: ./ubuntu-vuln.sh [check|patch]
#   check  - only detect, no changes
#   patch  - apply sysctl hardening

set -e

MODE="${1:-check}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=========================================="
echo " CVE-2026-98432 Mitigation Script"
echo " Mode: $MODE"
echo "=========================================="
echo ""

# --- 1. SYSTEM INFO ---
log "[1/7] System Info"
echo "  OS:       $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
echo "  Kernel:   $(uname -r)"
echo "  Arch:     $(uname -m)"
echo ""

# --- 2. MPTCP CHECK ---
log "[2/7] MPTCP Status"
MPTCP_VAL=$(sysctl -n net.mptcp.enabled 2>/dev/null || echo "not_found")
echo "  net.mptcp.enabled = $MPTCP_VAL"
if [ "$MPTCP_VAL" = "1" ]; then
    warn "  MPTCP ENABLED - trigger path for CVE-2026-98432"
    warn "  Fix: sysctl -w net.mptcp.enabled=0"
else
    log "  MPTCP disabled or not available"
fi
echo ""

# --- 3. BPF CHECK ---
log "[3/7] BPF Hardening"
BPF_DIS=$(sysctl -n kernel.unprivileged_bpf_disabled 2>/dev/null || echo "not_found")
BPF_JIT=$(sysctl -n net.core.bpf_jit_harden 2>/dev/null || echo "not_found")
echo "  kernel.unprivileged_bpf_disabled = $BPF_DIS"
echo "  net.core.bpf_jit_harden = $BPF_JIT"
if [ "$BPF_DIS" != "2" ]; then
    warn "  BPF not fully locked (should be 2)"
    warn "  Fix: sysctl -w kernel.unprivileged_bpf_disabled=2"
fi
if [ "$BPF_JIT" != "2" ]; then
    warn "  BPF JIT not hardened (should be 2)"
    warn "  Fix: sysctl -w net.core.bpf_jit_harden=2"
fi
echo ""

# --- 4. KERNEL PATCH CHECK ---
log "[4/7] Kernel Patch Status"
if apt-get changelog linux-image-$(uname -r) 2>/dev/null | grep -qi "CVE-2026-98432"; then
    log "  Kernel has CVE-2026-98432 fix"
else
    warn "  Could not confirm fix in running kernel"
fi
echo "  Available updates:"
apt list --upgradable 2>/dev/null | grep -i linux | head -5 || echo "  (none)"
echo ""

# --- 5. OPEN PORTS ---
log "[5/7] Open Ports"
OPEN_PORTS=$(ss -tulnp 2>/dev/null | grep -E '0\.0\.0\.0|:::' || echo "")
if [ -z "$OPEN_PORTS" ]; then
    log "  No ports listening on 0.0.0.0"
else
    warn "  Ports listening on all interfaces:"
    echo "$OPEN_PORTS" | while read line; do echo "    $line"; done
fi
echo ""

# --- 6. KERNEL ERROR CHECK ---
log "[6/7] Recent Kernel Errors"
DMESG=$(sudo dmesg -T 2>/dev/null | grep -Ei 'KASAN|use-after-free|general protection|BUG:|Oops|segfault' | tail -10)
JOURNAL=$(sudo journalctl -k --since "24 hours ago" 2>/dev/null | grep -Ei 'KASAN|use-after-free|BUG:|Oops' | tail -10)
if [ -z "$DMESG" ] && [ -z "$JOURNAL" ]; then
    log "  No UAF/Oops/BUG detected in last 24h"
else
    warn "  Potential issues found:"
    [ -n "$DMESG" ] && echo "$DMESG" | while read line; do echo "    $line"; done
    [ -n "$JOURNAL" ] && echo "$JOURNAL" | while read line; do echo "    $line"; done
fi
echo ""

# --- 7. AWS / CLOUD CHECK ---
log "[7/7] Cloud Detection"
if [ -f /sys/class/dmi/sys_uuid ]; then
    UUID=$(cat /sys/class/dmi/sys_uuid 2>/dev/null || echo "")
    if echo "$UUID" | grep -qi "^EC2"; then
        log "  Platform: AWS EC2"
    else
        log "  Platform: Non-AWS"
    fi
else
    log "  Platform: Unknown"
fi
echo ""

# --- APPLY MODE ---
if [ "$MODE" = "patch" ]; then
    echo "=========================================="
    echo " APPLYING SYSCTL HARDENING"
    echo "=========================================="
    echo ""
    warn "  This will modify /etc/sysctl.d/99-cve-2026-98432.conf"
    warn "  Requires root."
    echo ""
    sudo tee /etc/sysctl.d/99-cve-2026-98432.conf > /dev/null <<'SYSCTLEOF'
# CVE-2026-98432 mitigation
net.mptcp.enabled = 0
kernel.unprivileged_bpf_disabled = 2
net.core.bpf_jit_harden = 2
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.perf_event_paranoid = 3
kernel.yama.ptrace_scope = 2
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
SYSCTLEOF
    sudo sysctl --system
    log "  Sysctl hardening applied"
    echo ""
fi

# --- SUMMARY ---
echo "=========================================="
echo " RECOMMENDED SYSCTL HARDENING"
echo "=========================================="
echo ""
echo "  # MPTCP - disable if not needed"
echo "  sudo sysctl -w net.mptcp.enabled=0"
echo ""
echo "  # BPF - lock unprivileged access"
echo "  sudo sysctl -w kernel.unprivileged_bpf_disabled=2"
echo "  sudo sysctl -w net.core.bpf_jit_harden=2"
echo ""
echo "  # Kernel info disclosure"
echo "  sudo sysctl -w kernel.kptr_restrict=2"
echo "  sudo sysctl -w kernel.dmesg_restrict=1"
echo ""
echo "  # TCP anti-spoofing"
echo "  sudo sysctl -w net.ipv4.tcp_syncookies=1"
echo "  sudo sysctl -w net.ipv4.conf.all.rp_filter=1"
echo ""
echo "  # Persist across reboot:"
echo "  sudo tee /etc/sysctl.d/99-cve-hardening.conf <<EOF"
echo "net.mptcp.enabled = 0"
echo "kernel.unprivileged_bpf_disabled = 2"
echo "net.core.bpf_jit_harden = 2"
echo "EOF"
echo "  sudo sysctl --system"
echo ""
echo "=========================================="
echo " REMAINING ACTIONS"
echo "=========================================="
echo ""
echo "  [AWS] Close unused ports in Security Group"
echo "  [AWS] Enable IMDSv2 (hop limit 1)"
echo "  [AWS] Use SSM Session Manager instead of SSH"
echo "  [OS]  Check: apt list --upgradable | grep linux"
echo "  [OS]  Consider Ubuntu Pro for ESM (20.04)"
echo "  [OS]  Plan migration to 22.04 or 24.04"
echo ""
echo "  Detection:"
echo "  sudo dmesg -T | grep -Ei 'KASAN|use-after-free|general protection'"
echo "  sudo journalctl -k | grep -Ei 'KASAN|use-after-free|BUG:|Oops'"
echo ""
echo "  Script complete."
