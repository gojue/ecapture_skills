# eCapture Quick Reference

## Platform Check
```bash
uname -s && uname -r && uname -m
# Must be: Linux x86_64 ≥4.18  OR  Linux aarch64 ≥5.5
```

## Module → Use Case Cheatsheet

```
TLS/HTTPS (OpenSSL/BoringSSL)  →  sudo ecapture tls
Go TLS (crypto/tls binary)     →  sudo ecapture gotls -e /path/to/binary
GnuTLS                         →  sudo ecapture gnutls
Firefox (NSS/NSPR)             →  sudo ecapture nspr
bash commands                  →  sudo ecapture bash -e 0
zsh commands                   →  sudo ecapture zsh -e 0
MySQL / MariaDB SQL            →  sudo ecapture mysqld
PostgreSQL SQL                 →  sudo ecapture postgres
```

## Capture Mode Cheatsheet

```
Print plaintext in terminal   →  -m text          (default)
Save packets for Wireshark    →  -m pcap -i eth0 -w /tmp/out.pcapng
Wireshark offline decryption  →  -m keylog -k /tmp/keys.log
```

## Common Filter Flags

```
Filter by PID   →  -p <pid>
Filter by UID   →  -u <uid>
Log to file     →  -l /tmp/output.log
Log to TCP      →  -l tcp://host:9090
Log to WS       →  -l ws://host:8090/path
Debug mode      →  -d
```

## Hot-Reload API

```bash
# Tunnel if remote
ssh -L 28256:localhost:28256 user@host

# Update config
curl -X POST http://localhost:28256/<module> \
  -H 'Content-Type: application/json' \
  -d '{"pid": 1234}'
```

## Supported SSL Libraries (tls module)

| Library      | Version range        |
|--------------|---------------------|
| OpenSSL      | 1.0.2a – 3.x        |
| BoringSSL    | Android 13 – 16     |
| LibreSSL     | auto-detected       |

## Supported GnuTLS Versions (gnutls module)

3.6.12 · 3.6.13 · 3.7.0 · 3.7.3 · 3.7.7 · 3.8.4 · 3.8.7

