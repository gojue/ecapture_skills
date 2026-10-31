# Maintenance baseline and source map

Reviewed 2026-10-31 against local `gojue/ecapture` commit `5b664c9` (describe:
`v2.9.1-1-g5b664c9`; v2.9.1 tag at `143e771`). The subsequent commit changes
logo assets. These instructions describe that source baseline, not an assertion
that every installed binary or release mirror already contains it.

The [upstream releases](https://github.com/gojue/ecapture/releases) are useful
for discovery; inspect the target binary and versioned code when they differ.
Do not hard-code a maintainer's local checkout path into this skill.

## Changes since March 2026 that affect an agent

| Upstream release | Consequence for this skill |
| --- | --- |
| v2.0–v2.2 | v2 probe architecture, GoTLS network tuple work, cgroup/TC filtering fixes; stop referring to `user/config` as current code. |
| v2.3 | HTTP listener disabled by default; old-kernel ignored-filter warnings. |
| v2.4 | Android 16 BoringSSL, keylog fixes in 2.4.1/2.4.2, perf reorder generalized. |
| v2.5–v2.7 | OpenSSL 4.0/updated 3.x mappings; GoTLS large-event chunking, NSPR loading fixes; Android 17, tagged pointers, NSS key-length fixes; Go module path includes `/v2`. |
| v2.8 | LoongArch64 Linux >= 6.6; GnuTLS text/keylog/pcapng; separate operational/event output, typed eCaptureQ, consistent shared config and reload output inheritance; embedded-bytecode selection and packet/secret drain fixes. |
| v2.8.1–v2.8.2 | Private OpenSSL connection metadata; `TARGET_ARCH` build selector; Android release archive executable restored. |
| v2.9 | `--text-source pcapng` reconstructs HTTP/1.1 and HTTP/2 live for TLS/GoTLS/GnuTLS, with optional packet/key files. |
| v2.9.1 | Non-CO-RE builds fixed for Linux 6.19+/7.x headers; amd64/arm64 static PIE linking; smaller BPF objects retain BTF. These are build fixes, not new capture modes or lower kernel requirements. |

## Authoritative paths (in the eCapture checkout)

- `cli/cmd/root.go`, individual command files, `output_flags.go`: actual flags,
  defaults, aliases, units, destination conflicts, runtime lifecycle.
- `internal/probe/openssl/libs.go`, `config_linux.go`, `config_ecandroid.go`:
  supported layouts, library/version selection, Android behavior.
- `internal/probe/gnutls/config.go`: explicit supported patch mappings.
- `internal/probe/gotls/config*.go`: Go binary and symbol discovery.
- `kern/bash_kern.c`, `kern/zsh_kern.c`, corresponding probe/event Go files:
  shell event/filter limitations; do not infer behavior from flag help alone.
- `internal/config/common.go`, `base_config.go`, `cli/http/server.go`,
  `config_factory*.go`: JSON names, route availability, reload inheritance.
- `internal/output/writers/`, `internal/output/pcapng/`,
  `internal/output/decrypt/`, `docs/agent/output-pipeline.md`: raw formats,
  stream semantics, rotation, sensitive files, HTTP reconstruction.
- `protobuf/proto/v1/ecaptureq.proto`, `pkg/ecaptureq/`: typed events/history.
- `variables.mk`, `functions.mk`, `builder/Makefile.release`,
  `.github/workflows/release.yml`: artifact names, embedded modes, checksums.
- `AGENTS.md`, `docs/agent/`, `test/e2e/README.md`: upstream development and
  validation rules. Read those if asked to modify/build eCapture itself.

## Updating again

Compare installed help, code, tests, and release notes. Keep the SKILL entry
short and route conditional detail to these references. Update both README
languages and templates when the command contract changes. Test installer
selection/checksum failure paths with synthetic artifacts before any real
installation. The skill helper regression suite is host-independent:

```bash
python3 -m unittest discover -s tests -v
for script in scripts/*.sh scripts/lib/*.sh; do bash -n "$script" || exit; done
```

Those checks exercise the skill's helpers, not eCapture probes. Real capture,
Go builds/tests, BPF compilation, and E2E still need the supported Linux/Android
host; report them as unrun when unavailable.
