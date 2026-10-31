# Commands and diagnostics

Baseline: v2.9.1. Use `ecapture <module> --help` on the target host when its
version differs. Concrete recipes are in [command templates](../assets/command-templates.md).

## Core TLS modules

| Module (alias) | Library / executable selector | Modes |
| --- | --- | --- |
| `tls` (`openssl`) | `--libssl /absolute/libssl.so`; auto discovery otherwise | text, keylog, pcapng |
| `gotls` (`tlsgo`) | `-e` / `--elfpath /absolute/Go-ELF` required | text, keylog, pcapng |
| `gnutls` (`gnu`) | `--gnutls /absolute/libgnutls.so`; auto discovery otherwise | text, keylog, pcapng |

All three accept `--model` / `-m`, `--text-source hook|pcapng`, `-i` / `--ifname`,
`-w` / `--pcapfile`, `-k` / `--keylogfile`, and trailing packet BPF expressions.
`pcap` aliases `pcapng`, and `key` aliases `keylog`. `--text-source pcapng` is
valid only with text mode and needs TC packet capture on a real interface.
A BPF expression filters packets in packet-backed modes, not plaintext strings
or generic hook events. In pcapng mode the artifact stores encrypted packets
plus Decryption Secrets Blocks; Wireshark decrypts them using those secrets.

`--ssl_version` overrides OpenSSL/BoringSSL or GnuTLS version detection.
Use the actual library version, not `openssl version` from an unrelated host
executable. A forced mismatched layout can prevent capture or corrupt decoding.

Current mapping highlights (not guarantees for arbitrary vendor builds):

- OpenSSL: 1.0.2 through `u`, 1.1.0 through `l`, 1.1.1 through `w`; 3.0.22,
  3.1.8, 3.2.6, 3.3.7, 3.4.7, 3.5.8, 3.6.4, and 4.0.2 upper patch mappings.
  Check `internal/probe/openssl/libs.go` for exact version-to-object mapping.
- Android BoringSSL: updates include Android 15/16 keylog fixes, Android 17
  (API 37) layouts, TLS 1.3 client/server secrets, and tagged-pointer handling.
  Prefer detection; any `boringssl_a_<release>` override must match that build.
- GnuTLS: explicit patch mappings for 3.6.12–3.6.16, 3.7.0–3.7.11, and
  3.8.0–3.8.9. Unsupported versions fail validation. Do not reduce this list to
  the seven BPF object filenames or imply all later 3.8 releases are supported.
- Do not promise general LibreSSL support from the `libssl.so` filename alone.
- GoTLS handles stripped Go ELF discovery and chunks large hook output; one
  event is not necessarily a complete request. Prefer pcapng-sourced text for
  HTTP reconstruction, and start before the TLS handshake when secrets matter.

## Filters and shared controls

| Flag | Semantics / availability |
| --- | --- |
| `-p`, `--pid` / `-u`, `--uid` | Target process/user; 0 = all. Old kernels may ignore filters. |
| `--cgroup_path` | Linux cgroup v2 directory on tls, gotls, gnutls. NSPR exposes the flag but currently writes target cgroup ID 0, so it does not enforce that filter. |
| `--perf-reorder` | Available on tls, gotls, mysqld, postgres; opt-in perf timestamp reordering. |
| `--perf-reorder-lag-ms` | Default 10; batching window for enabled reorder. It is per reader/map, not global TCP reconstruction. |
| `--mapsize` | Default 1024 **pages per CPU**; CLI multiplies by OS page size (4 MiB at 4 KiB pages). Help's KB wording is misleading. |
| `--btf`, `-b` | 0 auto, 1 CO-RE, 2 non-CO-RE; requires matching embedded assets. |
| `--debug`, `-d` / `--hex` | Diagnostics / byte-oriented text display. |
| `--tsize`, `-t` | Parsed but has no active production truncation consumer at this baseline. Do not rely on it to limit or redact data. |
| `--listen` | Empty/disabled by default; opt in for runtime HTTP configuration. |

Output controls and rotation are described in [output and streaming](output-streaming.md).

## Other modules

All use shared PID/UID and event-output controls; do not add TLS capture modes
to modules whose CLI does not expose them.

| Module | Module-specific flags / behavior |
| --- | --- |
| `nspr` (`nss`) | `--nspr /path/libnspr4.so`; text from NSS/NSPR calls, Linux only. |
| `bash` | `--bash /bin/bash`, `--readlineso /path/libreadline.so`, `-e` / `--errnumber` (default 128). |
| `zsh` | `--zsh /bin/zsh`; captures readline-style input. |
| `mysqld` | `-m` / `--mysqld` (default `/usr/sbin/mariadbd`), `-f` / `--funcname`, `--offset` (e.g. `0x710410`). |
| `postgres` | `-m` / `--postgres` (default `/usr/bin/postgres`), `-f` / `--funcname`. |

For general Bash capture, omit `-e`: 128 is the kernel's no-exit-code-filter
sentinel. `-e 0` selects exit status 0 at the kernel retval hook, not “all”.
Do not promise exact audit completeness/exit-code filtering without checking
observed readline/retval events. Zsh accepts `--errnumber` for compatibility,
but its current kernel event has no exit status and does not apply that filter.
Neither shell probe is a universal record of every script command or process
execution.

## Diagnose from the failure

- **No library/probe symbol:** inspect the process's actual mapped ELF, its
  namespace, symbols, and version. A helper's host library candidate may be
  unrelated. NSPR requires an application actually using NSPR APIs.
- **No packets or HTTP:** check route/interface, network namespace, BPF filter,
  TC privileges, new handshake, supported key layout, and startup warnings.
  Hook plaintext alone does not prove keylog capture works.
- **Missing/reordered text:** consider pcapng text source for HTTP; investigate
  perf losses and buffers before claiming completeness. Reorder and larger
  buffers do not guarantee zero loss.
- **Unsupported BTF/object:** inspect embedded asset mode and kernel BTF; do
  not force a mode absent from the binary.
- **Output destination conflict:** remove the duplicate primary alias, keeping
  optional side artifacts only in modes that support them.
- **Empty file or stdout:** distinguish operational stderr/`-l` from captured
  `--eventaddr`; stop gracefully, then verify content, not only file size.
