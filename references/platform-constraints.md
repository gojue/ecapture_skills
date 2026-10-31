# Platform and environment

Baseline: eCapture v2.9.1. Inspect the installed build's help and startup logs.

| Target | `uname -m` | Release architecture | Minimum kernel |
| --- | --- | --- | --- |
| Linux / Android | x86_64 | amd64 | 4.18 |
| Linux / Android | aarch64 (arm64 alias) | arm64 | 5.5 |
| Linux only | loongarch64 | loong64 | 6.6 |

Linux builds expose all eight modules. Android builds expose `tls`, `gotls`,
and `bash`; GnuTLS, NSPR, zsh, MySQL, and PostgreSQL are excluded. Termux does
not make an excluded module available in the official Android binary.
macOS, Windows, and BSD cannot load these probes. eCapture source compilation,
linking, Go tests/lint, and eBPF generation also belong on Linux.

## Privileges and namespaces

Root through `sudo` is the usual path. Existing capability-based deployments
are supported; non-root is not automatically a failure:

| Kernel | Hook text / keylog | Packet capture, including pcapng text source |
| --- | --- | --- |
| >= 5.8 | `CAP_BPF`, `CAP_PERFMON`, `CAP_SYS_PTRACE` | Also `CAP_NET_ADMIN` |
| < 5.8 | `CAP_SYS_ADMIN`; process access must also be permitted | Also `CAP_NET_ADMIN` |

See upstream [minimum privileges](https://github.com/gojue/ecapture/blob/v2.9.1/docs/minimum-privileges.md).
Capabilities, seccomp/LSM rules, tracefs access, and process/library visibility
still affect attachment. UID 0 in a container is not proof of sufficient
capabilities. Do not change persistent capabilities simply to run preflight.

Run probes in a context that sees the intended PID, library inode, cgroup, and
network interface. Host/container PID numbers and filesystem paths can differ.
`/proc/<host-pid>/root/...` may provide the mapped library from a container.
For `--cgroup_path`, use an existing cgroup v2 directory and confirm no startup
warning disabled filtering. Do not treat the Android flag as a supported
container-isolation mechanism.

**On kernels below 5.2, PID/UID/cgroup filtering can be ignored.** If the user
requires a narrow capture scope, resolve this limitation before capture rather
than silently collecting from the whole host. UID/PID value `0` means all,
not “root only”.

## BTF and release artifacts

`--btf 0` lets the binary choose once per process. `--btf 1` requires CO-RE;
`--btf 2` requires non-CO-RE. The selected object must be embedded in the binary.
Explicit modes fail if unavailable; a flag cannot supply a missing asset.
`/sys/kernel/btf/vmlinux` is a useful BTF signal, but absence alone does not
prove the kernel has no other usable BTF source.

Current standard Linux release archives embed both object variants. Do not
invent a `-nocore` download URL based on a single BTF file check. The installer
selects an actually published asset from the GitHub release API, including
`linux-loong64`, and requires its SHA256 entry. Loong64 releases may use the
separate `checksum-loong64-<tag>.txt` manifest.

```bash
# Linux; requires Bash, Python 3, and curl or wget.
bash scripts/install-ecapture.sh --dry-run
sudo bash scripts/install-ecapture.sh v2.9.1
# Non-root installation to a chosen writable directory is also supported.
bash scripts/install-ecapture.sh v2.9.1 --install-dir "$HOME/.local/bin"
bash scripts/preflight-check.sh
```

Preflight exits 1 for missing/unsupported prerequisites, 2 when non-root
capability validation remains, and 0 when basic checks pass. It never loads
BPF, so it cannot certify attachment or packet capture. The installer is Linux
only; deploy the matching Android artifact separately (for example via adb)
and run under the device's existing root setup. Android archives before
v2.8.2 had a packaging issue that could omit the executable.
