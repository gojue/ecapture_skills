# eCapture Skill for Claude AI

> **An AI Agent Skill for [eCapture (旁观者)](https://ecapture.cc)** — capture SSL/TLS plaintext, shell commands, and database queries on Linux/Android without a CA certificate, powered by eBPF.

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](https://github.com/gojue/ecapture/blob/master/LICENSE)
[![eCapture](https://img.shields.io/badge/eCapture-v1.x-green.svg)](https://github.com/gojue/ecapture/releases)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Android-orange.svg)](https://ecapture.cc)
[![Claude Skills](https://img.shields.io/badge/Claude-Custom%20Skill-blueviolet.svg)](https://support.claude.com/en/articles/12512198-how-to-create-custom-skills)

---

## What is this?

This repository contains a **Claude Custom Skill** that teaches Claude AI how to use [eCapture](https://github.com/gojue/ecapture) — an eBPF-based security tool for Linux and Android.

Once uploaded to Claude, the AI agent will be able to:

- 🔐 **Capture TLS/SSL plaintext** from OpenSSL, BoringSSL, GnuTLS, NSS/NSPR, and Go `crypto/tls` — without a CA certificate
- 🐚 **Audit shell commands** from bash and zsh sessions in real time
- 🗄️ **Capture database queries** from MySQL, MariaDB, and PostgreSQL without enabling query logs
- 🔍 **Run environment checks** before executing, verifying OS, kernel version, and required privileges
- 🔄 **Hot-reload configuration** of a running eCapture instance via its HTTP API
- 📡 **Stream captured events** to external log servers or AI agent endpoints over TCP/WebSocket

---

## Repository Structure

```
ecapture-skill/
├── SKILL.md                          # Core skill definition (instructions + metadata)
├── scripts/
│   ├── preflight-check.sh            # Verify OS, kernel, root, BTF support
│   └── detect-libs.sh                # Auto-discover SSL/TLS lib and binary paths
├── references/
│   ├── quick-reference.md            # Command cheatsheet for all modules
│   └── platform-constraints.md      # OS/kernel/arch support matrix
└── assets/
    └── command-templates.md          # Parameterized command templates
```

---

## Supported eCapture Modules

| Module | Captures | Linux | Android |
|--------|----------|-------|---------|
| `tls` | OpenSSL / BoringSSL / LibreSSL plaintext | ✅ | ✅ |
| `gotls` | Go `crypto/tls` plaintext | ✅ | ✅ |
| `gnutls` | GnuTLS plaintext | ✅ | ⚠️ Termux only |
| `nspr` | Firefox / NSS / NSPR plaintext | ✅ | ❌ |
| `bash` | bash commands + exit codes | ✅ | ✅ |
| `zsh` | zsh commands + exit codes | ✅ | ❌ |
| `mysqld` | MySQL / MariaDB SQL queries | ✅ | ❌ |
| `postgres` | PostgreSQL SQL queries | ✅ | ❌ |

---

## Platform Requirements

> ⚠️ **eCapture only runs on Linux or Android. It does NOT work on macOS or Windows.**

| Architecture | Minimum Kernel |
|---|---|
| x86_64 | 4.18 |
| aarch64 | 5.5 |

Root (`sudo`) is required for all modules.

---

## How to Upload to Claude

### Method 1 — Claude.ai Web UI

1. Go to [claude.ai](https://claude.ai) → **Settings** → **Integrations** → **Custom Skills**
2. Click **"Add Skill"**
3. Upload `SKILL.md` as the primary skill file
4. Optionally upload files from `scripts/`, `references/`, and `assets/` as supplementary context

### Method 2 — Anthropic API

```python
import anthropic

client = anthropic.Anthropic()

with open("SKILL.md") as f:
    skill_content = f.read()

response = client.messages.create(
    model="claude-opus-4-5",
    max_tokens=2048,
    system=skill_content,          # inject SKILL.md as system context
    messages=[{
        "role": "user",
        "content": "Capture HTTPS traffic on eth0 and save to /tmp/capture.pcapng"
    }]
)
print(response.content[0].text)
```

---

## Example Interactions

After uploading, you can ask Claude naturally:

```
"Capture all HTTPS traffic on my Linux server and save it as a pcapng file"
→ sudo ecapture tls -m pcap -i eth0 -w /tmp/capture.pcapng

"Monitor all bash commands run by uid 1000"
→ sudo ecapture bash -u 1000 -e 0 -l /tmp/bash_audit.log

"Audit MySQL queries without restarting the database"
→ sudo ecapture mysqld -l /tmp/mysql_queries.log

"Capture Go TLS traffic from my Caddy server"
→ sudo ecapture gotls -e /usr/local/bin/caddy

"Export TLS session keys so I can decrypt traffic in Wireshark"
→ sudo ecapture tls -m keylog -k /tmp/keys.log
```

---

## Helper Scripts

### `scripts/install-ecapture.sh` — Automated Installation

Run on the target Linux host to download, verify, and install eCapture automatically:

```bash
# Install latest stable release (requires root)
sudo bash scripts/install-ecapture.sh

# Install a specific version
sudo bash scripts/install-ecapture.sh v1.5.2

# Preview without installing
bash scripts/install-ecapture.sh --dry-run
```

The script:
1. Verifies OS (Linux only) and architecture (x86_64 / aarch64)
2. Checks kernel version meets minimum requirements
3. Detects BTF support → selects CO-RE or non-CO-RE build automatically
4. Fetches the latest version from GitHub API (or uses specified version)
5. Downloads the correct release tarball
6. Verifies SHA256 checksum
7. Installs binary to `/usr/local/bin/ecapture`

### `scripts/preflight-check.sh` — Environment Verification

Run on the target Linux host before any eCapture command. Verifies:
- OS is Linux
- Architecture is x86_64 or aarch64
- Kernel version meets the minimum requirement
- Running as root
- `ecapture` binary is installed
- BTF support availability

```bash
ssh user@linux-host 'bash preflight-check.sh'
```

### `scripts/detect-libs.sh`

Automatically discovers SSL/TLS library paths and database binary paths on the target host. Outputs ready-to-use flag values for eCapture.

```bash
ssh user@linux-host 'bash detect-libs.sh'
# Output example:
#   libssl:  --libssl=/lib/x86_64-linux-gnu/libssl.so.3
#   gnutls:  --gnutls=/lib/x86_64-linux-gnu/libgnutls.so.30
#   mysqld:  --mysqld=/usr/sbin/mysqld
```

---

## About eCapture

[eCapture (旁观者)](https://ecapture.cc) is an open-source eBPF-based tool developed by [@cfc4n](https://github.com/cfc4n). It captures encrypted traffic and system activity at the userspace hook level — no CA certificate, no proxy, no application modification required.

- **GitHub**: https://github.com/gojue/ecapture
- **Homepage**: https://ecapture.cc
- **License**: Apache-2.0

---

## License

This skill definition is licensed under [Apache-2.0](https://github.com/gojue/ecapture/blob/master/LICENSE), the same as the eCapture project.

