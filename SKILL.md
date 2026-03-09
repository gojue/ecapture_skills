---
name: ecapture
display_name: eCapture (旁观者)
description: >
  eBPF-based CLI tool to capture SSL/TLS plaintext, shell commands, and database
  queries on Linux/Android without a CA certificate. Supports OpenSSL, BoringSSL,
  GnuTLS, NSS/NSPR, Go TLS, bash, zsh, MySQL/MariaDB, and PostgreSQL.
version: "1.0.0"
author: CFC4N <cfc4n.cs@gmail.com>
homepage: https://ecapture.cc
repository: https://github.com/gojue/ecapture
license: Apache-2.0
tags: [ebpf, tls, ssl, openssl, boringssl, gnutls, nss, golang, mysql, postgresql, bash, security, linux, android]
---

# eCapture (旁观者)

eCapture is an eBPF-based CLI tool that captures **SSL/TLS plaintext**, **shell commands**, and **database SQL queries** on Linux/Android **without a CA certificate** and without modifying any application.

---

## ⚠️ Critical Platform Constraints

> **eCapture ONLY runs on Linux or Android. It NEVER works on macOS or Windows.**

| Architecture | Minimum Linux Kernel |
|---|---|
| x86_64 | 4.18 |
| aarch64 | 5.5 |

**Root (`sudo`) is always required.**

### Pre-flight check — ALWAYS run this first on the target host

```bash
uname -s && uname -r && uname -m
```

- If output does not start with `Linux` → **abort, inform the user**
- If kernel version is below the minimum → **abort, inform the user**
- If running on the user's local macOS machine → **use SSH to execute on the remote Linux host**

---

## Installation

```bash
# Download the latest release (Linux x86_64)
curl -LO https://github.com/gojue/ecapture/releases/latest/download/ecapture_linux_x86_64.tar.gz
tar -xf ecapture_linux_x86_64.tar.gz
sudo mv ecapture /usr/local/bin/

# Verify
ecapture --version
```

---

## Modules Overview

| Module | What it captures | Platform |
|--------|-----------------|----------|
| `tls` | OpenSSL / BoringSSL / LibreSSL plaintext | Linux, Android |
| `gotls` | Go `crypto/tls` plaintext | Linux, Android |
| `gnutls` | GnuTLS plaintext | Linux |
| `nspr` | Firefox / NSS / NSPR plaintext | Linux |
| `bash` | bash shell commands + exit codes | Linux, Android |
| `zsh` | zsh shell commands + exit codes | Linux |
| `mysqld` | MySQL / MariaDB SQL queries | Linux |
| `postgres` | PostgreSQL SQL queries | Linux |

---

## Module: `tls` — Capture OpenSSL / BoringSSL / LibreSSL

Hooks into `libssl.so` via eBPF uprobes to capture TLS plaintext before encryption / after decryption.

### Syntax
```bash
sudo ecapture tls [flags] [pcap_bpf_filter]
```

### Key flags
| Flag | Short | Default | Description |
|------|-------|---------|-------------|
| `--model` | `-m` | `text` | Capture mode: `text` \| `pcap`/`pcapng` \| `keylog`/`key` |
| `--libssl` | | auto | Absolute path to `libssl.so` |
| `--ssl_version` | | auto | Override version string, e.g. `openssl 3.0.5` |
| `--keylogfile` | `-k` | `ecapture_openssl_key.log` | TLS key output file (mode=keylog) |
| `--pcapfile` | `-w` | `save.pcapng` | Packet capture output (mode=pcap) |
| `--ifname` | `-i` | | Network interface for pcap mode, e.g. `eth0` |
| `--pid` | `-p` | `0` | Target PID (0=all) |
| `--uid` | `-u` | `0` | Target UID (0=all) |
| `--logaddr` | `-l` | | Output: file path / `tcp://host:port` / `ws://host:port/path` |
| `--debug` | `-d` | false | Verbose debug logging |
| `--hex` | | false | Print payload as hex |
| `--btf` | | `0` | BTF mode: 0=auto, 1=CO-RE, 2=non-CO-RE |
| `--listen` | | `localhost:28256` | HTTP hot-reload config server |

### Examples
```bash
# Print all decrypted HTTPS traffic
sudo ecapture tls

# Target a specific process
sudo ecapture tls -p 1234

# Save packets to pcapng (open with Wireshark)
sudo ecapture tls -m pcap -i eth0 -w /tmp/capture.pcapng tcp port 443

# Export TLS session keys for Wireshark offline decryption
sudo ecapture tls -m keylog -k /tmp/keys.log

# Specify libssl.so path manually
sudo ecapture tls --libssl=/lib/x86_64-linux-gnu/libssl.so.3

# Write output to file
sudo ecapture tls -l /tmp/tls.log
```

---

## Module: `gotls` — Capture Go `crypto/tls`

Hooks directly into a Go ELF binary to capture Go TLS plaintext. Requires the path to the Go binary.

### Syntax
```bash
sudo ecapture gotls [flags] [pcap_bpf_filter]
```

### Key flags
| Flag | Short | Default | Description |
|------|-------|---------|-------------|
| `--elfpath` | `-e` | | **Required**: absolute path to the Go binary, e.g. `/usr/local/bin/caddy` |
| `--model` | `-m` | `text` | Capture mode: `text` \| `pcap`/`pcapng` \| `keylog`/`key` |
| `--keylogfile` | `-k` | `ecapture_gotls_key.log` | TLS key output file (mode=keylog) |
| `--pcapfile` | `-w` | `ecapture_gotls.pcapng` | Packet capture output (mode=pcap) |
| `--ifname` | `-i` | | Network interface for pcap mode |
| `--pid` | `-p` | `0` | Target PID (0=all) |
| `--uid` | `-u` | `0` | Target UID (0=all) |
| `--logaddr` | `-l` | | Output destination |
| `--debug` | `-d` | false | Verbose debug logging |

### Examples
```bash
# Capture Go TLS from Caddy
sudo ecapture gotls -e /usr/local/bin/caddy

# Save to pcapng
sudo ecapture gotls -e /usr/local/bin/caddy -m pcap -i eth0 -w /tmp/gotls.pcapng

# Export TLS session keys
sudo ecapture gotls -e /usr/local/bin/caddy -m keylog -k /tmp/gotls_keys.log
```

> To verify a binary uses Go TLS: `file /path/to/binary | grep 'Go BuildID'`

---

## Module: `gnutls` — Capture GnuTLS

Hooks into `libgnutls.so` via eBPF uprobes. Linux only.

### Syntax
```bash
sudo ecapture gnutls [flags] [pcap_bpf_filter]
```

### Key flags
| Flag | Default | Description |
|------|---------|-------------|
| `--gnutls` | auto | Absolute path to `libgnutls.so` |
| `--ssl_version` | auto | GnuTLS version, e.g. `3.8.4` |
| `--model` / `-m` | `text` | `text` \| `pcap`/`pcapng` \| `keylog`/`key` |
| `--keylogfile` / `-k` | `ecapture_gnutls_key.log` | TLS key output file |
| `--pcapfile` / `-w` | `save.pcapng` | Packet capture output |
| `--ifname` / `-i` | | Network interface |
| `--pid` / `-p` | `0` | Target PID |
| `--logaddr` / `-l` | | Output destination |

### Examples
```bash
sudo ecapture gnutls
sudo ecapture gnutls --ssl_version="3.8.4" -m keylog -k /tmp/gnutls_keys.log
```

Supported GnuTLS versions: `3.6.12`, `3.6.13`, `3.7.0`, `3.7.3`, `3.7.7`, `3.8.4`, `3.8.7`

---

## Module: `nspr` — Capture Firefox / NSS / NSPR

Hooks into `libnspr4.so` to capture TLS plaintext from Firefox, Thunderbird, and other Mozilla-based applications. Linux only.

### Syntax
```bash
sudo ecapture nspr [flags]
```

### Key flags
| Flag | Default | Description |
|------|---------|-------------|
| `--nspr` | auto | Absolute path to `libnspr4.so` |
| `--pid` / `-p` | `0` | Target PID (0=all Firefox instances) |
| `--uid` / `-u` | `0` | Target UID |
| `--logaddr` / `-l` | | Output destination |
| `--debug` / `-d` | false | Verbose debug |

### Examples
```bash
sudo ecapture nspr
sudo ecapture nspr -p $(pgrep -x firefox | head -1) -l /tmp/firefox_tls.log
```

---

## Module: `bash` — Audit bash Commands

Hooks into bash's readline library via eBPF uprobes to capture every command typed and its exit code. Linux and Android.

### Syntax
```bash
sudo ecapture bash [flags]
```

### Key flags
| Flag | Default | Description |
|------|---------|-------------|
| `--bash` | auto | Absolute path to bash binary |
| `--readlineso` | auto | Absolute path to `libreadline.so` |
| `--errnumber` / `-e` | `128` | Report commands matching this exit code. Use `0` for all commands |
| `--pid` / `-p` | `0` | Target PID |
| `--uid` / `-u` | `0` | Target UID |
| `--logaddr` / `-l` | | Output destination |

### Examples
```bash
# Capture all bash commands from all users
sudo ecapture bash -e 0

# Capture only failed commands (exit code ≥ 128)
sudo ecapture bash

# Monitor a specific user's bash sessions
sudo ecapture bash -u 1000 -e 0 -l /tmp/bash_audit.log
```

---

## Module: `zsh` — Audit zsh Commands

Same as bash module but for zsh. Linux only.

### Syntax
```bash
sudo ecapture zsh [flags]
```

### Key flags
| Flag | Default | Description |
|------|---------|-------------|
| `--zsh` | auto | Absolute path to zsh binary |
| `--errnumber` / `-e` | `128` | Exit code filter (0=all) |
| `--pid` / `-p` | `0` | Target PID |
| `--uid` / `-u` | `0` | Target UID |
| `--logaddr` / `-l` | | Output destination |

### Examples
```bash
sudo ecapture zsh -e 0
sudo ecapture zsh -u 1000 -e 0 -l /tmp/zsh_audit.log
```

---

## Module: `mysqld` — Audit MySQL / MariaDB Queries

Hooks into the `mysqld`/`mariadbd` binary via eBPF uprobes to capture all SQL queries without enabling query logs. Linux only.

### Syntax
```bash
sudo ecapture mysqld [flags]
```

### Key flags
| Flag | Default | Description |
|------|---------|-------------|
| `--mysqld` / `-m` | `/usr/sbin/mariadbd` | Path to mysqld or mariadbd binary |
| `--funcname` / `-f` | auto | Internal function name to hook (advanced) |
| `--offset` | `0` | Manual ELF symbol offset (advanced, hex) |
| `--pid` / `-p` | `0` | Target PID |
| `--logaddr` / `-l` | | Output destination |

### Examples
```bash
sudo ecapture mysqld
sudo ecapture mysqld -m /usr/sbin/mysqld -l /tmp/mysql_queries.log
```

---

## Module: `postgres` — Audit PostgreSQL Queries

Hooks into the `postgres` binary via eBPF uprobes to capture all SQL queries without modifying `postgresql.conf`. Linux only.

### Syntax
```bash
sudo ecapture postgres [flags]
```

### Key flags
| Flag | Default | Description |
|------|---------|-------------|
| `--postgres` / `-m` | `/usr/bin/postgres` | Path to postgres binary |
| `--funcname` / `-f` | auto | Internal function to hook (advanced) |
| `--pid` / `-p` | `0` | Target PID |
| `--logaddr` / `-l` | | Output destination |

### Examples
```bash
sudo ecapture postgres
sudo ecapture postgres -m /usr/lib/postgresql/15/bin/postgres -l /tmp/pg_queries.log
```

---

## Common Flags (All Modules)

| Flag | Short | Default | Description |
|------|-------|---------|-------------|
| `--pid` | `-p` | `0` | Target process ID (0=all) |
| `--uid` | `-u` | `0` | Target user ID (0=all) |
| `--debug` | `-d` | false | Verbose debug logging |
| `--hex` | | false | Print payload as hex |
| `--btf` | | `0` | BTF mode: 0=auto, 1=CO-RE, 2=non-CO-RE |
| `--mapsize` | | `1024` | eBPF ring buffer per CPU (KB) |
| `--tsize` | | `0` | Payload truncation bytes (0=none) |
| `--logaddr` | `-l` | | Log output: file / `tcp://host:port` / `ws://host:port/path` |
| `--eventaddr` | | | Event data output (defaults to logaddr) |
| `--listen` | | `localhost:28256` | HTTP hot-reload config API address |

---

## Runtime Config Hot-Reload

All modules expose an HTTP API for updating config without restarting.

```bash
# If eCapture runs remotely, create SSH tunnel first
ssh -L 28256:localhost:28256 user@linux-host

# Update TLS capture to target a new PID
curl -X POST http://localhost:28256/tls \
  -H 'Content-Type: application/json' \
  -d '{"pid": 5678}'

# Switch bash audit to capture all commands
curl -X POST http://localhost:28256/bash \
  -H 'Content-Type: application/json' \
  -d '{"errnumber": 0}'
```

Supported endpoints: `/tls`, `/gotls`, `/gnutls`, `/nspr`, `/bash`, `/zsh`, `/mysqld`, `/postgres`

---

## Real-Time Event Streaming

eCapture can push captured events to an agent or log server in real time.

```bash
# Push mode: eCapture sends events to a remote TCP/WebSocket server
sudo ecapture tls --eventaddr tcp://agent-host:9090
sudo ecapture tls --eventaddr ws://agent-host:8090/events

# Pull mode: eCapture acts as a queue, agent connects to pull
sudo ecapture tls --ecaptureq 0.0.0.0:8091

# File output with rotation (max 100 MB or 3600 s)
sudo ecapture tls --eventaddr /tmp/tls_events.log \
  --eventroratesize 100 --eventroratetime 3600
```

Events are emitted as **newline-delimited JSON (NDJSON)**:
```json
{"ts":"2026-03-09T10:00:00Z","module":"EBPFProbeOPENSSL","type":"TLSEvent","payload":"GET / HTTP/1.1\r\nHost: example.com"}
{"ts":"2026-03-09T10:00:01Z","module":"EBPFProbeBash","type":"BashEvent","payload":"ls -la /etc"}
{"ts":"2026-03-09T10:00:02Z","module":"EBPFProbeMysqld","type":"MysqlEvent","payload":"SELECT * FROM users"}
```

---

## Scripts

Two helper scripts are provided in `scripts/` for use by the agent on the target Linux host.

### `scripts/install-ecapture.sh` — Automated Installation

Run **before the first use** to download, verify, and install eCapture on the target Linux host:

```bash
# Install latest stable release (requires root)
sudo bash scripts/install-ecapture.sh

# Install a specific version
sudo bash scripts/install-ecapture.sh v1.5.2

# Preview what would be done (no download, no install)
bash scripts/install-ecapture.sh --dry-run
```

The script automatically:
1. Verifies OS is Linux and architecture is x86_64 or aarch64
2. Checks kernel version meets the minimum requirement (4.18 / 5.5)
3. Detects BTF support (`/sys/kernel/btf/vmlinux`) and selects CO-RE or non-CO-RE build accordingly
4. Fetches the latest version from the GitHub API (or uses the version you specify)
5. Downloads the correct release tarball from GitHub
6. Verifies SHA256 checksum integrity
7. Extracts and installs the binary to `/usr/local/bin/ecapture`

### `scripts/preflight-check.sh` — Environment Verification

Run **before any ecapture command** to verify the host is ready:

```bash
# On the target Linux host
bash scripts/preflight-check.sh
```

Checks: OS=Linux, architecture (x86_64/aarch64), kernel version ≥ minimum, root privileges, ecapture binary presence, BTF availability.

### `scripts/detect-libs.sh` — Library Path Discovery

Run to automatically discover SSL/TLS library paths and database binary paths:

```bash
# On the target Linux host
bash scripts/detect-libs.sh
```

Outputs the exact `--libssl`, `--gnutls`, `--nspr`, `--bash`, `--mysqld`, `--postgres` flag values ready to paste into ecapture commands.

---

## Remote Execution (macOS / Windows dev machine)

Since eCapture only runs on Linux, always execute via SSH when the local machine is not Linux:

```bash
# Run on remote Linux host
ssh user@linux-host 'sudo ecapture tls -m pcap -i eth0 -w /tmp/capture.pcapng'

# Fetch the pcapng file back to local machine
scp user@linux-host:/tmp/capture.pcapng ~/Desktop/
```

---

## Agent Decision Guide

| User intent | Module to use | Key flag to set |
|-------------|--------------|-----------------|
| Capture HTTPS traffic (curl, nginx, etc.) | `tls` | `-m text` or `-m pcap -i eth0` |
| Capture Go HTTPS server traffic | `gotls` | `-e /path/to/go/binary` |
| Capture Firefox HTTPS | `nspr` | auto-detect |
| Capture app using GnuTLS | `gnutls` | auto-detect |
| Monitor shell commands | `bash` or `zsh` | `-e 0` to capture all |
| Audit MySQL/MariaDB queries | `mysqld` | `-m /path/to/mysqld` |
| Audit PostgreSQL queries | `postgres` | `-m /path/to/postgres` |
| Wireshark offline decryption | `tls` or `gotls` | `-m keylog -k /tmp/keys.log` |
| Save raw packets for analysis | `tls` or `gotls` | `-m pcap -i eth0 -w /tmp/out.pcapng` |

---

## References

- Homepage: https://ecapture.cc
- GitHub: https://github.com/gojue/ecapture
- Releases: https://github.com/gojue/ecapture/releases
- Wireshark TLS key log: https://wiki.wireshark.org/TLS#using-the-pre-master-secret
- Protobuf event schema: `protobuf/`

