---
name: ecapture
description: >-
  Use eCapture to capture TLS plaintext, reconstruct HTTP traffic, export TLS
  keys or pcapng, and inspect shell commands or SQL on Linux/Android. Use for
  eCapture installation, capture planning, troubleshooting, event streaming,
  and runtime configuration; requires access to a supported target host.
license: Apache-2.0
metadata:
  display_name: eCapture (旁观者)
  version: "2.0.0"
  author: CFC4N <cfc4n.cs@gmail.com>
  homepage: https://ecapture.cc
  repository: https://github.com/gojue/ecapture
  upstream_baseline: "v2.9.1 / 5b664c9"
  verified_on: "2026-10-31"
---

# eCapture (旁观者)

Use eCapture's eBPF probes without a CA certificate or application changes.
Prioritize TLS capture and choose the module, representation, and destination
separately. This skill targets the v2.9.1 source baseline; inspect the installed
binary's version and help before using newer flags on an older host.

## Establish the target

- Identify the authorized host, process/container, capture objective, duration,
  and output location from the request and available context. Ask only for
  missing information that blocks execution; do not infer a remote host.
- Run `uname -srm`, `ecapture --version`, and `ecapture <module> --help` on
  that host. [preflight-check.sh](scripts/preflight-check.sh) checks the basic
  prerequisites without loading a probe. Resolve script paths relative to this
  skill; copy its helper directory too when transferring scripts.
- Runtime targets: Linux x86_64 >= 4.18, aarch64 >= 5.5, loongarch64 >= 6.6;
  Android x86_64/aarch64 only. macOS/Windows can edit the skill and inspect
  artifacts, but capture and eCapture builds/tests require Linux/Android.
- Use root or an established capability-based setup. Check
  [platform constraints](references/platform-constraints.md) for capabilities,
  Android modules, BTF, containers, and old-kernel filter limitations.
- If installation is needed, use [install-ecapture.sh](scripts/install-ecapture.sh)
  on Linux. `--dry-run` resolves release metadata without root or artifact
  downloads. Install only when required by the task, preserving a user-selected
  version. Android uses its own release artifact and deployment procedure.

## Choose capture behavior

| Need | Module / options |
| --- | --- |
| OpenSSL/BoringSSL plaintext, including non-HTTP TLS | `tls -m text` (default source: `hook`) |
| Complete HTTP/1.1 or HTTP/2 requests/responses | `tls -m text --text-source pcapng -i <interface>` |
| Go `crypto/tls` | `gotls -e /absolute/path/to/elf`; same modes/text sources as `tls` |
| GnuTLS | `gnutls`; same modes/text sources as `tls`, Linux only |
| Wireshark packet artifact with embedded TLS secrets | `-m pcapng -i <interface> --eventaddr <file.pcapng>` |
| NSS-format keys for a separate packet capture | `-m keylog --eventaddr <keys.log>` |
| NSS/NSPR applications | `nspr` (alias `nss`), text only |
| Shell / SQL inspection | `bash`, `zsh`, `mysqld`, `postgres`; see quick reference |

For packet capture or pcapng-sourced text, identify the actual interface from
`ip route get <destination-IP>` in the target network namespace. A real interface
is required, not tcpdump's `any`. Capture a new TLS connection/handshake when
keys are needed; already-established connections may not yield usable secrets.
The pcapng text source reconstructs HTTP over TLS/TCP, not every TLS application
protocol or HTTP/3/QUIC. It requires both packets and keys.

Prefer the target process's mapped library over a host-wide guess:
[scripts/detect-libs.sh](scripts/detect-libs.sh) accepts `--pid <PID>`.
For Go, use the actual running ELF, including a stripped Go executable; do not
reject it solely because `file` omits a Go BuildID. Consult
[quick reference](references/quick-reference.md) for supported flags, library
versions, cgroup filtering, and diagnostic decisions.

## Route output correctly

- `--logaddr` / `-l` contains operational logs only (also sent to stderr).
- `--eventaddr` selects captured output: `stdout`, a path, `file://`, `tcp://`,
  `ws://`, or `wss://`. Text defaults to stdout. Representation is selected by
  mode: event text, NSS key lines, or binary pcapng; it is not generic NDJSON.
- In keylog mode, `-k` is a legacy primary-file alias; in pcapng mode, `-w` is
  a legacy primary-file alias. Do not also set `--eventaddr` with the alias
  selecting that same primary destination.
- In `-m text --text-source pcapng`, `--eventaddr` carries reconstructed HTTP;
  explicit `-w` and `-k` optionally save separate packet/key artifacts.
- `--ecaptureq` adds a WebSocket/Protobuf event server. It does not replace the
  primary output and is not a durable pull queue. Read
  [output and streaming](references/output-streaming.md) before implementing a
  receiver, rotation, or network forwarding.

```bash
# On the target Linux host; replace PID and interface with verified values.
sudo ecapture tls -p 1234 --eventaddr /tmp/tls.txt
sudo ecapture tls -m text --text-source pcapng -i eth0 \
  --eventaddr /tmp/http.txt -w /tmp/traffic.pcapng 'tcp port 443'
sudo ecapture gotls -e /usr/local/bin/caddy -m keylog --eventaddr /tmp/go.keys
```

Use [command templates](assets/command-templates.md) when composing a concrete
command. Keep captured plaintext, SQL, commands, keys, and packet artifacts in
the requested destination; redact secrets from chat and repository changes.

## Run, inspect, and finish

Start the scoped capture, generate or await the intended traffic, and stop with
SIGINT/SIGTERM so buffered packets and secrets can drain. On Linux, a bounded
run can use `sudo timeout --signal=INT 30s ecapture ...`; timeout exit 124 by
itself is not proof of a probe failure. Inspect startup/termination logs and
the expected artifact before declaring success.

For pcapng, verify packet records, embedded secrets when expected, and actual
decryption of the intended traffic; a non-empty file is insufficient. For
HTTP reconstruction, check a recognizable request and response. For keylog,
check NSS lines and matching packet/handshake coverage. Do not report payloads
or performance results that were not observed.

Runtime HTTP configuration is disabled by default. Read
[runtime configuration](references/runtime-config.md) before enabling
`--listen`, posting configuration, or writing a controller: reload restarts
the same probe, omitted fields are not a general patch, and there is no `/zsh`
endpoint.

If no supported execution environment is available, finish the command/config
preparation and explicitly report the runtime validation still needed. For
future maintenance, [source baseline](references/source-baseline.md) maps these
instructions to upstream code and the changes since March 2026.
