#!/usr/bin/env bash
# Shared target validation. Sourced by install/preflight; does not load BPF.
ec_fail() { printf '[ERROR] %s\n' "$*" >&2; return 1; }

ec_detect_target() {
  local os major minor
  os=$(uname -s)
  [ "$os" = Linux ] || { ec_fail "eCapture requires Linux/Android; detected $os."; return 1; }
  EC_PLATFORM=linux
  if [ -n "${ANDROID_ROOT:-}" ] || [ -d /system/framework ] || command -v getprop >/dev/null 2>&1; then
    EC_PLATFORM=android
  fi
  EC_ARCH=$(uname -m)
  case "$EC_ARCH" in
    x86_64) EC_GOARCH=amd64; EC_MIN_MAJOR=4; EC_MIN_MINOR=18 ;;
    aarch64|arm64) EC_GOARCH=arm64; EC_MIN_MAJOR=5; EC_MIN_MINOR=5 ;;
    loongarch64)
      [ "$EC_PLATFORM" = linux ] || { ec_fail 'Android LoongArch64 is unsupported.'; return 1; }
      EC_GOARCH=loong64; EC_MIN_MAJOR=6; EC_MIN_MINOR=6 ;;
    *) ec_fail "Unsupported architecture: $EC_ARCH"; return 1 ;;
  esac
  EC_KERNEL=$(uname -r)
  if [[ "$EC_KERNEL" =~ ^([0-9]+)\.([0-9]+) ]]; then
    major=$((10#${BASH_REMATCH[1]}))
    minor=$((10#${BASH_REMATCH[2]}))
  else
    ec_fail "Cannot parse kernel version: $EC_KERNEL"; return 1
  fi
  if (( major < EC_MIN_MAJOR || (major == EC_MIN_MAJOR && minor < EC_MIN_MINOR) )); then
    ec_fail "Kernel $EC_KERNEL is too old for $EC_ARCH; need $EC_MIN_MAJOR.$EC_MIN_MINOR+."
    return 1
  fi
  EC_KERNEL_MAJOR=$major
  EC_KERNEL_MINOR=$minor
}
