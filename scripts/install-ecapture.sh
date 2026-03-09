#!/usr/bin/env bash
# install-ecapture.sh
# Automatically download, verify, and install eCapture on Linux.
# Detects OS, kernel version, CPU architecture, and selects the correct release asset.
#
# Usage:
#   sudo bash install-ecapture.sh               # install latest stable release
#   sudo bash install-ecapture.sh v1.5.2        # install a specific version
#   sudo bash install-ecapture.sh --dry-run      # show what would be done, no install
#
# Requirements: curl (or wget), tar, sha256sum
# Target platform: Linux x86_64 (kernel ≥ 4.18) or aarch64 (kernel ≥ 5.5)

set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
REPO="gojue/ecapture"
INSTALL_DIR="/usr/local/bin"
GITHUB_API="https://api.github.com/repos/${REPO}/releases"
GITHUB_DOWNLOAD="https://github.com/${REPO}/releases/download"
TMP_DIR="$(mktemp -d /tmp/ecapture-install.XXXXXX)"
MIN_KERNEL_X86=418   # 4.18 → major*100 + minor
MIN_KERNEL_ARM=505   # 5.5  → 505

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()     { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
VERSION_ARG=""
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    v*.*) VERSION_ARG="$arg" ;;
    *) die "Unknown argument: $arg  (usage: $0 [vX.Y.Z] [--dry-run])" ;;
  esac
done

# ---------------------------------------------------------------------------
# Cleanup on exit
# ---------------------------------------------------------------------------
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Step 1: OS check
# ---------------------------------------------------------------------------
info "Checking operating system..."
OS="$(uname -s)"
[ "$OS" = "Linux" ] || die "eCapture only supports Linux. Detected: $OS"
success "OS: Linux"

# ---------------------------------------------------------------------------
# Step 2: Architecture detection
# ---------------------------------------------------------------------------
info "Detecting CPU architecture..."
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64)
    GOARCH="amd64"
    MIN_KERNEL=$MIN_KERNEL_X86
    ;;
  aarch64 | arm64)
    ARCH="aarch64"
    GOARCH="arm64"
    MIN_KERNEL=$MIN_KERNEL_ARM
    ;;
  *)
    die "Unsupported architecture: $ARCH (eCapture supports x86_64 and aarch64 only)"
    ;;
esac
success "Architecture: $ARCH (GOARCH=$GOARCH)"

# ---------------------------------------------------------------------------
# Step 3: Kernel version check
# ---------------------------------------------------------------------------
info "Checking kernel version..."
KERNEL_RAW="$(uname -r)"
MAJOR="$(echo "$KERNEL_RAW" | cut -d. -f1)"
MINOR="$(echo "$KERNEL_RAW" | cut -d. -f2 | sed 's/[^0-9].*//')"
KERNEL_NUM=$(( MAJOR * 100 + MINOR ))

if [ "$KERNEL_NUM" -lt "$MIN_KERNEL" ]; then
  if [ "$ARCH" = "x86_64" ]; then
    die "Kernel $KERNEL_RAW is too old. eCapture requires ≥ 4.18 on x86_64."
  else
    die "Kernel $KERNEL_RAW is too old. eCapture requires ≥ 5.5 on aarch64."
  fi
fi
success "Kernel: $KERNEL_RAW"

# ---------------------------------------------------------------------------
# Step 4: Root check
# ---------------------------------------------------------------------------
info "Checking root privileges..."
[ "$(id -u)" -eq 0 ] || die "Installation requires root. Re-run with: sudo $0 $*"
success "Running as root"

# ---------------------------------------------------------------------------
# Step 5: Detect required tools
# ---------------------------------------------------------------------------
info "Checking required tools..."
HAS_CURL=false; HAS_WGET=false
command -v curl  &>/dev/null && HAS_CURL=true
command -v wget  &>/dev/null && HAS_WGET=true
command -v tar   &>/dev/null || die "'tar' is required but not found. Install it first."
command -v sha256sum &>/dev/null || die "'sha256sum' is required but not found. Install it first."
$HAS_CURL || $HAS_WGET || die "Either 'curl' or 'wget' is required but neither was found."
success "Required tools found"

# ---------------------------------------------------------------------------
# Helper: HTTP GET
# ---------------------------------------------------------------------------
http_get() {
  local url="$1" out="$2"
  if $HAS_CURL; then
    curl -fsSL --retry 3 --retry-delay 2 -o "$out" "$url"
  else
    wget -q --tries=3 --waitretry=2 -O "$out" "$url"
  fi
}

# ---------------------------------------------------------------------------
# Step 6: Resolve target version
# ---------------------------------------------------------------------------
info "Resolving eCapture version..."

if [ -n "$VERSION_ARG" ]; then
  VERSION="$VERSION_ARG"
  info "Using requested version: $VERSION"
else
  info "Fetching latest release from GitHub..."
  RELEASE_JSON="$TMP_DIR/release.json"
  http_get "${GITHUB_API}/latest" "$RELEASE_JSON" \
    || die "Failed to fetch release info from GitHub API. Check network connectivity."
  VERSION="$(grep -m1 '"tag_name"' "$RELEASE_JSON" | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')"
  [ -n "$VERSION" ] || die "Could not parse version from GitHub API response."
  info "Latest version: $VERSION"
fi

success "Target version: $VERSION"

# ---------------------------------------------------------------------------
# Step 7: Determine asset names
# ---------------------------------------------------------------------------
# Release asset naming convention (from functions.mk):
#   ecapture-{VERSION}-linux-{GOARCH}.tar.gz         (CO-RE, default)
#   ecapture-{VERSION}-linux-{GOARCH}-nocore.tar.gz  (non-CO-RE fallback)
#
# Checksum file: checksum-{VERSION}.txt

ASSET_CORE="${VERSION}/ecapture-${VERSION}-linux-${GOARCH}.tar.gz"
ASSET_NOCORE="${VERSION}/ecapture-${VERSION}-linux-${GOARCH}-nocore.tar.gz"
CHECKSUM_FILE="${VERSION}/checksum-${VERSION}.txt"

DOWNLOAD_URL_CORE="${GITHUB_DOWNLOAD}/${ASSET_CORE}"
DOWNLOAD_URL_NOCORE="${GITHUB_DOWNLOAD}/${ASSET_NOCORE}"
CHECKSUM_URL="${GITHUB_DOWNLOAD}/${CHECKSUM_FILE}"

# ---------------------------------------------------------------------------
# Step 8: Select CO-RE vs non-CO-RE based on BTF availability
# ---------------------------------------------------------------------------
info "Checking BTF (BPF Type Format) support..."
if [ -f /sys/kernel/btf/vmlinux ]; then
  USE_CORE=true
  ASSET_URL="$DOWNLOAD_URL_CORE"
  TARBALL_NAME="ecapture-${VERSION}-linux-${GOARCH}.tar.gz"
  success "BTF available → will install CO-RE build"
else
  USE_CORE=false
  ASSET_URL="$DOWNLOAD_URL_NOCORE"
  TARBALL_NAME="ecapture-${VERSION}-linux-${GOARCH}-nocore.tar.gz"
  warn "BTF not available → will install non-CO-RE (nocore) build"
fi

# ---------------------------------------------------------------------------
# Dry-run summary
# ---------------------------------------------------------------------------
if $DRY_RUN; then
  echo ""
  echo -e "${BOLD}=== DRY RUN — no files will be downloaded or installed ===${NC}"
  echo "  Version   : $VERSION"
  echo "  Arch      : $ARCH (GOARCH=$GOARCH)"
  echo "  Kernel    : $KERNEL_RAW"
  echo "  BTF       : $( $USE_CORE && echo 'yes (CO-RE)' || echo 'no (nocore)' )"
  echo "  Asset URL : $ASSET_URL"
  echo "  Checksum  : $CHECKSUM_URL"
  echo "  Install to: ${INSTALL_DIR}/ecapture"
  echo ""
  exit 0
fi

# ---------------------------------------------------------------------------
# Step 9: Download tarball and checksum
# ---------------------------------------------------------------------------
TARBALL_PATH="$TMP_DIR/$TARBALL_NAME"
CHECKSUM_PATH="$TMP_DIR/checksum.txt"

info "Downloading: $ASSET_URL"
http_get "$ASSET_URL" "$TARBALL_PATH" \
  || die "Download failed. URL: $ASSET_URL\nCheck version tag and network connectivity."
success "Downloaded: $TARBALL_NAME"

info "Downloading checksum file..."
if http_get "$CHECKSUM_URL" "$CHECKSUM_PATH" 2>/dev/null; then
  success "Downloaded checksum file"
  VERIFY_CHECKSUM=true
else
  warn "Checksum file not available — skipping integrity verification"
  VERIFY_CHECKSUM=false
fi

# ---------------------------------------------------------------------------
# Step 10: Verify SHA256 checksum
# ---------------------------------------------------------------------------
if $VERIFY_CHECKSUM; then
  info "Verifying SHA256 checksum..."
  EXPECTED_HASH="$(grep "$TARBALL_NAME" "$CHECKSUM_PATH" | awk '{print $1}')"
  if [ -z "$EXPECTED_HASH" ]; then
    warn "Could not find checksum entry for $TARBALL_NAME in checksum file — skipping"
  else
    ACTUAL_HASH="$(sha256sum "$TARBALL_PATH" | awk '{print $1}')"
    if [ "$ACTUAL_HASH" = "$EXPECTED_HASH" ]; then
      success "SHA256 checksum verified"
    else
      die "Checksum mismatch!\n  Expected: $EXPECTED_HASH\n  Actual:   $ACTUAL_HASH\nThe file may be corrupted or tampered with."
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Step 11: Extract and install
# ---------------------------------------------------------------------------
info "Extracting tarball..."
tar -xzf "$TARBALL_PATH" -C "$TMP_DIR"
success "Extracted successfully"

# Find the ecapture binary (may be inside a subdirectory)
BINARY_PATH="$(find "$TMP_DIR" -type f -name "ecapture" | head -1)"
[ -n "$BINARY_PATH" ] || die "Could not find 'ecapture' binary inside the archive."

info "Installing to ${INSTALL_DIR}/ecapture ..."
install -m 0755 "$BINARY_PATH" "${INSTALL_DIR}/ecapture"
success "Installed: ${INSTALL_DIR}/ecapture"

# ---------------------------------------------------------------------------
# Step 12: Verify installation
# ---------------------------------------------------------------------------
info "Verifying installation..."
if command -v ecapture &>/dev/null; then
  INSTALLED_VERSION="$(ecapture --version 2>&1 | head -1 || true)"
  success "ecapture is ready: $INSTALLED_VERSION"
else
  warn "ecapture was installed to ${INSTALL_DIR} but is not in \$PATH."
  warn "Add ${INSTALL_DIR} to your PATH or use the full path: ${INSTALL_DIR}/ecapture"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo -e "${GREEN}${BOLD}=== eCapture ${VERSION} installed successfully ===${NC}"
echo ""
echo "  Quick start:"
echo "    sudo ecapture tls                          # capture OpenSSL plaintext"
echo "    sudo ecapture tls -m pcap -i eth0 -w /tmp/capture.pcapng"
echo "    sudo ecapture bash -e 0                    # audit all bash commands"
echo "    sudo ecapture mysqld                       # audit MySQL queries"
echo ""
echo "  Docs: https://ecapture.cc"
echo "  Repo: https://github.com/gojue/ecapture"
echo ""

