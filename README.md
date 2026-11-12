<p align="center">
  <img src="./images/ecapture-skill-logo.png" alt="eCapture logo" width="180" />
</p>

# eCapture AI Agent Skill

[中文](README-zh_Hans.md) · [eCapture](https://github.com/gojue/ecapture) · [Releases](https://github.com/gojue/ecapture/releases)

An agent skill for using eCapture to capture TLS plaintext, reconstruct HTTP,
export keys/pcapng, and inspect shell commands or SQL on Linux/Android without
a CA certificate. The skill is intended for agent harnesses that load
`SKILL.md` and its relative resources.

Updated on **2026-10-31**, against eCapture **v2.9.1**, local source commit
`5b664c9`. Skill package version: **2.0.0**. The installed binary's help and
behavior take precedence when using another version.

## What changed

- Live HTTP/1.1 and HTTP/2 reconstruction with `--text-source pcapng` for TLS,
  GoTLS, and GnuTLS, plus optional raw packet/key artifacts.
- Separate operational `--logaddr` and captured `--eventaddr`; raw TCP/WS
  output formats and typed eCaptureQ Protobuf integration.
- Linux LoongArch64, current OpenSSL/GnuTLS mappings, Android 16/17 updates,
  cgroup filtering, perf reordering, and actual HTTP reload semantics.
- Corrected Bash exit-code advice, Android module availability, default
  listener state, output examples, buffer units, and unsupported claims.
- Release-metadata-based Linux installation with required SHA256 validation,
  including Loong64 checksums; root-free dry run and prerequisite checks.

## Contents

| Resource | Purpose |
| --- | --- |
| [SKILL.md](SKILL.md) | Discovery metadata and core agent workflow |
| [Quick reference](references/quick-reference.md) | Modules, flags, version mappings, diagnostics |
| [Platform constraints](references/platform-constraints.md) | Kernels, privileges, namespaces, release artifacts |
| [Output and streaming](references/output-streaming.md) | Artifact formats, destinations, rotation, eCaptureQ |
| [Runtime configuration](references/runtime-config.md) | Routes, JSON fields, reload limits |
| [Source baseline](references/source-baseline.md) | Upstream changes and maintenance evidence |
| [Command templates](assets/command-templates.md) | Adaptable capture recipes |
| `scripts/` | Installer, preflight, library discovery, shared helpers |
| `tests/` | Offline helper regression tests with synthetic releases/hosts |

Keep the **whole directory** together when installing this skill in a harness;
references and helper files are required. Follow that harness's skill-directory
or package-import mechanism. Loading only the main file as a prompt omits its
referenced procedures and does not provide executable tools or target access.

## Target requirements

Linux x86_64 >= 4.18, aarch64 >= 5.5, or loongarch64 >= 6.6; Android
x86_64/aarch64 only. Root or sufficient capabilities are needed for capture.
Android builds provide `tls`, `gotls`, and `bash`; other modules are Linux-only.
macOS/Windows can author this skill and inspect outputs; run eCapture on a
supported target. PID/UID/cgroup filters may be ignored below kernel 5.2.

```bash
# On Linux, from the skill directory. Requires Bash, Python 3, curl or wget.
bash scripts/install-ecapture.sh --dry-run
sudo bash scripts/install-ecapture.sh v2.9.1
bash scripts/preflight-check.sh
bash scripts/detect-libs.sh --pid 1234

# Replace interface and executable with actual target values.
sudo ecapture tls -m text --text-source pcapng -i eth0 --eventaddr /tmp/http.txt
sudo ecapture gotls -e /usr/local/bin/caddy -m keylog --eventaddr /tmp/go.keys
```

Dry run fetches metadata only. Missing assets or SHA256 entries stop installation;
no unverified fallback is used. `--install-dir` supports a writable user directory.
Preflight exits 0 for basic prerequisites, 1 for a blocking issue, or 2 when
non-root capabilities still need validation. It does not attach probes.

## Validation

```bash
python3 -m unittest discover -s tests -v
for script in scripts/*.sh scripts/lib/*.sh; do bash -n "$script" || exit; done
```

Tests validate the skill helpers without network access, installation into
system directories, or BPF. Real capture, eCapture builds/tests, and E2E require
a supported Linux/Android environment. Captured data may contain secrets;
keep it in the authorized destination and redact it in reports.

## License

Apache-2.0, matching [eCapture's license](https://github.com/gojue/ecapture/blob/v2.9.1/LICENSE).
