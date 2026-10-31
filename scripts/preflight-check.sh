#!/usr/bin/env bash
# No BPF side effects. Exit 0: basic checks pass; 1: blocked; 2: capabilities unverified.
set -euo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/environment.sh
source "$SCRIPT_DIR/lib/environment.sh"
ec_detect_target
printf '[PASS] %s %s, kernel %s\n' "$EC_PLATFORM" "$EC_ARCH" "$EC_KERNEL"
if (( EC_KERNEL_MAJOR < 5 || (EC_KERNEL_MAJOR == 5 && EC_KERNEL_MINOR < 2) )); then
  printf '[WARN] Kernel < 5.2: PID/UID/cgroup filters may be ignored. Resolve capture scope before proceeding.\n'
fi
binary=$(command -v ecapture) || { ec_fail 'ecapture is missing from PATH; install it before capture.'; exit 1; }
version=$("$binary" --version 2>&1) || { ec_fail "Cannot execute $binary --version: $version"; exit 1; }
printf '[PASS] %s\n' "$version"
if [ -r /sys/kernel/btf/vmlinux ]; then
  printf '[INFO] Kernel BTF visible. Keep --btf 0 unless a specific embedded mode is required.\n'
else
  printf '[INFO] No readable /sys/kernel/btf/vmlinux. Runtime also checks other BTF sources and embedded assets.\n'
fi
if [ "$(id -u)" -ne 0 ]; then
  printf '[CHECK] Non-root: validate effective/file capabilities for the selected mode, or run capture with sudo.\n'
  if command -v getcap >/dev/null 2>&1; then
    getcap "$binary" || true
  fi
  printf '[CHECK] No probe loaded; capability-based execution is not verified by this script.\n'
  exit 2
fi
printf '[PASS] Basic prerequisites checked. Container capabilities, attachment, interface, and capture still require runtime validation.\n'
