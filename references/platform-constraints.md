# eCapture Platform Constraints Reference

## Supported Operating Systems

- **Linux** (primary platform)
- **Android** (limited modules — see table below)

## NOT Supported

- ❌ macOS
- ❌ Windows
- ❌ BSD variants

## Kernel Version Requirements

| Architecture | Minimum Kernel Version |
|---|---|
| x86_64 (Intel/AMD 64-bit) | **4.18** |
| aarch64 (ARM 64-bit) | **5.5** |

## Module Platform Availability

| Module | Linux | Android |
|--------|-------|---------|
| `tls` (OpenSSL/BoringSSL) | ✅ | ✅ |
| `gotls` (Go crypto/tls) | ✅ | ✅ |
| `gnutls` | ✅ | ⚠️ Termux only |
| `nspr` (Firefox/NSS) | ✅ | ❌ |
| `bash` | ✅ | ✅ |
| `zsh` | ✅ | ❌ |
| `mysqld` | ✅ | ❌ |
| `postgres` | ✅ | ❌ |

## Required Privileges

Root (`sudo`) is required for all modules. eCapPture uses eBPF which requires `CAP_BPF` or full root.

## BTF / CO-RE Modes

| Mode | Flag | When to use |
|------|------|-------------|
| Auto-detect | `--btf 0` (default) | Let eCapture decide |
| CO-RE | `--btf 1` | Kernel has BTF (most kernels ≥5.8 with `CONFIG_DEBUG_INFO_BTF=y`) |
| Non-CO-RE | `--btf 2` | Older kernels without BTF support |

To check if the kernel has BTF:
```bash
ls /sys/kernel/btf/vmlinux
```

