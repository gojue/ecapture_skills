#!/usr/bin/env bash
# preflight-check.sh
# Run this script on the TARGET Linux host before invoking any eCapture module.
# Verifies OS, kernel version, architecture, and root privileges.
# Exit code 0 = ready; non-zero = cannot run eCapture.

set -euo pipefail

MIN_KERNEL_X86=418   # 4.18 → stripped dots
MIN_KERNEL_ARM=505   # 5.5  → padded to 505

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

echo "=== eCapture Pre-flight Check ==="

# 1. OS check
OS=$(uname -s)
[ "$OS" = "Linux" ] || fail "eCapture requires Linux. Detected: $OS"
pass "OS: $OS"

# 2. Architecture check
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  MIN_KERNEL=$MIN_KERNEL_X86 ;;
  aarch64) MIN_KERNEL=$MIN_KERNEL_ARM  ;;
  *) fail "Unsupported architecture: $ARCH (supported: x86_64, aarch64)" ;;
esac
pass "Architecture: $ARCH"

# 3. Kernel version check
KERNEL_RAW=$(uname -r)
# Extract major.minor (e.g. "5.15.0-113-generic" → "515")
MAJOR=$(echo "$KERNEL_RAW" | cut -d. -f1)
MINOR=$(echo "$KERNEL_RAW" | cut -d. -f2 | sed 's/[^0-9].*//')
KERNEL_NUM=$(printf "%d%02d" "$MAJOR" "$MINOR")

if [ "$KERNEL_NUM" -lt "$MIN_KERNEL" ]; then
  if [ "$ARCH" = "x86_64" ]; then
    fail "Kernel $KERNEL_RAW is too old. eCapture requires ≥4.18 on x86_64."
  else
    fail "Kernel $KERNEL_RAW is too old. eCapture requires ≥5.5 on aarch64."
  fi
fi
pass "Kernel: $KERNEL_RAW (requirement met)"

# 4. Root / sudo check
if [ "$(id -u)" -ne 0 ]; then
  fail "eCapture requires root privileges. Re-run with sudo."
fi
pass "Running as root"

# 5. ecapture binary check
if command -v ecapture &>/dev/null; then
  ECAPTURE_VERSION=$(ecapture --version 2>&1 | head -1)
  pass "ecapture binary found: $ECAPTURE_VERSION"
else
  warn "ecapture binary not found in PATH. Install it before proceeding."
  warn "Download: https://github.com/gojue/ecapture/releases"
fi

# 6. BTF support check
if [ -f /sys/kernel/btf/vmlinux ]; then
  pass "BTF available (/sys/kernel/btf/vmlinux) — CO-RE mode supported (--btf 1)"
else
  warn "BTF not available — use non-CO-RE mode (--btf 2) or let eCapture auto-detect (--btf 0)"
fi

echo ""
echo -e "${GREEN}=== Pre-flight check passed. eCapture is ready to run. ===${NC}"

