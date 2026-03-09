#!/usr/bin/env bash
# detect-libs.sh
# Detect SSL/TLS library paths on the current Linux host.
# Prints discovered paths so the Agent can pass them to ecapture flags.
# Run on the TARGET Linux host.

set -uo pipefail

echo "=== eCapture Library Detection ==="
echo ""

# Helper: find a library via ldconfig or locate
find_lib() {
  local name="$1"
  # Try ldconfig cache first (fastest)
  ldconfig -p 2>/dev/null | grep "$name" | awk '{print $NF}' | head -1
}

# 1. OpenSSL libssl
echo "--- OpenSSL (libssl) ---"
LIBSSL=$(find_lib "libssl.so")
if [ -n "$LIBSSL" ]; then
  echo "  Found: $LIBSSL"
  echo "  ecapture flag: --libssl=$LIBSSL"
  # Try to get version
  OPENSSL_VER=$(openssl version 2>/dev/null || echo "unknown")
  echo "  Version: $OPENSSL_VER"
else
  echo "  Not found via ldconfig. Try: find /usr/lib /lib -name 'libssl.so*' 2>/dev/null"
fi
echo ""

# 2. BoringSSL (Android-style, may appear as libssl.so too)
echo "--- BoringSSL ---"
BORINGSSL=$(find_lib "libssl.so" | grep -i boring || true)
if [ -n "$BORINGSSL" ]; then
  echo "  Found: $BORINGSSL"
else
  echo "  Not detected (BoringSSL typically found on Android systems)"
fi
echo ""

# 3. GnuTLS
echo "--- GnuTLS (libgnutls) ---"
LIBGNUTLS=$(find_lib "libgnutls.so")
if [ -n "$LIBGNUTLS" ]; then
  echo "  Found: $LIBGNUTLS"
  echo "  ecapture flag: --gnutls=$LIBGNUTLS"
  GNUTLS_VER=$(gnutls-cli --version 2>/dev/null | head -1 || echo "unknown")
  echo "  Version: $GNUTLS_VER"
else
  echo "  Not found"
fi
echo ""

# 4. NSS / NSPR (Firefox)
echo "--- NSS/NSPR (libnspr4) ---"
LIBNSPR=$(find_lib "libnspr4.so")
if [ -n "$LIBNSPR" ]; then
  echo "  Found: $LIBNSPR"
  echo "  ecapture flag: --nspr=$LIBNSPR"
else
  echo "  Not found (install Firefox to get libnspr4.so)"
fi
echo ""

# 5. bash + readline
echo "--- bash + readline ---"
BASH_PATH=$(command -v bash 2>/dev/null || echo "")
if [ -n "$BASH_PATH" ]; then
  echo "  bash: $BASH_PATH"
  echo "  ecapture flag: --bash=$BASH_PATH"
  READLINE=$(ldd "$BASH_PATH" 2>/dev/null | grep readline | awk '{print $3}' | head -1)
  if [ -n "$READLINE" ]; then
    echo "  readline: $READLINE"
    echo "  ecapture flag: --readlineso=$READLINE"
  fi
else
  echo "  bash not found"
fi
echo ""

# 6. zsh
echo "--- zsh ---"
ZSH_PATH=$(command -v zsh 2>/dev/null || echo "")
if [ -n "$ZSH_PATH" ]; then
  echo "  zsh: $ZSH_PATH"
  echo "  ecapture flag: --zsh=$ZSH_PATH"
else
  echo "  zsh not found"
fi
echo ""

# 7. MySQL / MariaDB
echo "--- MySQL / MariaDB ---"
for bin in /usr/sbin/mysqld /usr/sbin/mariadbd /usr/libexec/mysqld; do
  if [ -x "$bin" ]; then
    echo "  Found: $bin"
    echo "  ecapture flag: --mysqld=$bin"
  fi
done
echo ""

# 8. PostgreSQL
echo "--- PostgreSQL ---"
PG_BIN=$(command -v postgres 2>/dev/null || find /usr/lib/postgresql -name postgres -type f 2>/dev/null | head -1 || echo "")
if [ -n "$PG_BIN" ]; then
  echo "  Found: $PG_BIN"
  echo "  ecapture flag: --postgres=$PG_BIN"
else
  echo "  Not found"
fi
echo ""

echo "=== Detection complete ==="

