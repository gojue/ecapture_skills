#!/usr/bin/env bash
# List candidates; --pid uses actual process mappings instead of the host cache.
set -euo pipefail
[ "$(uname -s)" = Linux ] || { printf 'Run library discovery on the target Linux/Android host.\n' >&2; exit 1; }
pid=
if [ "$#" -gt 0 ]; then
  if [ "$#" -ne 2 ] || [ "$1" != --pid ] || ! [[ "$2" =~ ^[1-9][0-9]*$ ]]; then
    printf 'Usage: %s [--pid PID]\n' "$0" >&2; exit 1
  fi
  pid=$2
fi
show_library() {
  local path=$1 flag
  case "${path##*/}" in
    libssl.so*) flag=--libssl ;;
    libgnutls.so*) flag=--gnutls ;;
    libnspr4.so*) flag=--nspr ;;
    libreadline.so*) flag=--readlineso ;;
    *) return 0 ;;
  esac
  printf '  %s=%q\n' "$flag" "$path"
}
if [ -n "$pid" ]; then
  [ -r "/proc/$pid/maps" ] || { printf 'Cannot read /proc/%s/maps; check PID/permissions.\n' "$pid" >&2; exit 1; }
  printf 'Process %s executable: ' "$pid"
  readlink "/proc/$pid/exe" || true
  printf 'Mapped library candidates (paths belong to the process mount namespace):\n'
  while IFS= read -r path; do
    show_library "$path"
  done < <(awk '$6 ~ /^\// {print substr($0, index($0, $6))}' "/proc/$pid/maps" | sort -u)
  printf 'Verify host visibility/inode; container paths may require /proc/%s/root. Deleted mappings need separate investigation.\n' "$pid"
else
  printf 'Host library candidates (not proof of which library the target uses):\n'
  if command -v ldconfig >/dev/null 2>&1; then
    while IFS= read -r path; do
      show_library "$path"
    done < <(ldconfig -p 2>/dev/null | awk '/=>/ {print $NF}' | sort -u)
  fi
  for path in /apex/com.android.conscrypt/lib64/libssl.so /system/lib64/libssl.so; do
    [ ! -f "$path" ] || show_library "$path"
  done
fi
printf 'Host executable candidates:\n'
for name in bash zsh mysqld mariadbd postgres; do
  path=$(command -v "$name" || true)
  [ -n "$path" ] || continue
  flag=$name
  [ "$name" != mariadbd ] || flag=mysqld
  printf '  --%s=%q\n' "$flag" "$path"
done
for path in /usr/sbin/mysqld /usr/sbin/mariadbd /usr/libexec/mysqld /usr/lib/postgresql/*/bin/postgres; do
  [ -x "$path" ] || continue
  flag=mysqld
  [ "${path##*/}" != postgres ] || flag=postgres
  printf '  --%s=%q\n' "$flag" "$path"
done
printf 'Confirm actual library version/symbols; a system openssl CLI may use another library.\n'
