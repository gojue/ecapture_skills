#!/usr/bin/env bash
# Resolve a published Linux release, require SHA256 verification, install one binary.
# --dry-run reads GitHub metadata only; it needs neither root nor writable install dir.
set -euo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/environment.sh
source "$SCRIPT_DIR/lib/environment.sh"
usage() {
  printf 'Usage: %s [vX.Y.Z] [--dry-run] [--install-dir DIR]\n' "$0"
}
version=latest
dry_run=false
install_dir=/usr/local/bin
while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --dry-run) dry_run=true; shift ;;
    --install-dir)
      [ "$#" -ge 2 ] || { usage >&2; exit 1; }
      install_dir=$2; shift 2 ;;
    v*)
      [ "$version" = latest ] || { ec_fail 'Only one version may be selected.'; exit 1; }
      [[ "$1" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([-+][A-Za-z0-9.-]+)?$ ]] || { ec_fail 'Invalid version tag.'; exit 1; }
      version=$1; shift ;;
    *) usage >&2; exit 1 ;;
  esac
done
[ -n "$install_dir" ] || { ec_fail 'Installation directory is empty.'; exit 1; }
ec_detect_target
[ "$EC_PLATFORM" = linux ] || { ec_fail 'Use an Android release and device deployment; this installer is Linux-only.'; exit 1; }
command -v python3 >/dev/null || { ec_fail 'Python 3 is required for release metadata and checksum verification.'; exit 1; }
if command -v curl >/dev/null; then
  downloader=curl
elif command -v wget >/dev/null; then
  downloader=wget
else
  ec_fail 'curl or wget is required.'; exit 1
fi
http_get() {
  if [ "$downloader" = curl ]; then
    curl --fail --silent --show-error --location --retry 2 \
      --connect-timeout 15 --max-time 300 --proto '=https' --proto-redir '=https' \
      --output "$2" "$1"
  else
    wget --quiet --https-only --tries=3 --timeout=30 --output-document="$2" "$1"
  fi
}
if ! $dry_run; then
  if [ -d "$install_dir" ]; then
    [ -w "$install_dir" ] || { ec_fail "Cannot write $install_dir; use sudo or --install-dir."; exit 1; }
  else
    [ -w "$(dirname -- "$install_dir")" ] || { ec_fail 'Create a writable parent directory or use sudo.'; exit 1; }
  fi
fi
task_tmp=$(mktemp -d "${TMPDIR:-/tmp}/ecapture-install.XXXXXX")
trap 'rm -rf -- "$task_tmp"' EXIT
api=https://api.github.com/repos/gojue/ecapture/releases
if [ "$version" = latest ]; then
  metadata_url="$api/latest"
else
  metadata_url="$api/tags/$version"
fi
http_get "$metadata_url" "$task_tmp/release.json"
python3 "$SCRIPT_DIR/release-artifact.py" select "$task_tmp/release.json" \
  "$EC_GOARCH" "$version" > "$task_tmp/selection"
{
  IFS= read -r selected_version
  IFS= read -r asset_name
  IFS= read -r asset_url
  IFS= read -r checksum_url
} < "$task_tmp/selection"
printf 'Version: %s\nTarget: Linux %s (%s), kernel %s\nAsset: %s\nChecksum: %s\nInstall: %s/ecapture\n' \
  "$selected_version" "$EC_ARCH" "$EC_GOARCH" "$EC_KERNEL" "$asset_url" "$checksum_url" "$install_dir"
if $dry_run; then
  printf 'Dry run: release metadata fetched; no release artifacts downloaded or installation performed.\n'
  exit 0
fi
http_get "$asset_url" "$task_tmp/$asset_name"
http_get "$checksum_url" "$task_tmp/checksums.txt"
python3 "$SCRIPT_DIR/release-artifact.py" verify-extract \
  "$task_tmp/$asset_name" "$task_tmp/checksums.txt" "$task_tmp/ecapture"
mkdir -p -- "$install_dir"
install -m 0755 "$task_tmp/ecapture" "$install_dir/ecapture"
"$install_dir/ecapture" --version
printf 'Installed and verified: %s/ecapture\nDefault --btf 0 selects from embedded assets at runtime.\n' "$install_dir"
