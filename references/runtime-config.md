# Runtime HTTP configuration

Baseline: v2.9.1. Read this before issuing updates: configuration reload creates
a fresh probe generation of the original type. It is not a cross-module switch
or a zero-gap operation. The listener is disabled unless `--listen` is set.

```bash
sudo ecapture tls --libssl /usr/lib/x86_64-linux-gnu/libssl.so.3 \
  -p 1234 --eventaddr /tmp/tls.txt --listen 127.0.0.1:28256
# From a remote workstation, use an authorized SSH target:
ssh -N -L 28256:127.0.0.1:28256 user@linux-host
```

## Routes

POST JSON to `/tls` (aliases `/openssl`, `/boringssl`), `/gotls`, `/gnutls`,
`/nspr` (alias `/nss`), `/bash`, `/mysqld`, or `/postgres` (legacy `/postgress`).
There is **no `/zsh` endpoint**. Android supports TLS, GoTLS, and Bash updates;
other registered routes return unsupported errors in the Android build.
Use a route matching the running probe.

## Field names and replacement semantics

Configuration factories create a default config then decode JSON. Omitted
module fields and filters can therefore reset, rather than retaining the active
value. Keep a full known-good desired configuration and send its important
fields (paths, mode, text source, interface, filters, PID/UID) on every update.

Only captured-event destination and rotation fields have explicit inheritance:
if omitted they retain active values; explicit empty/zero values clear them
and are validated. Logger and eCaptureQ services remain process-lifetime
dependencies. Changing `logger_addr`, `ecapture_q`, or `listen` in a JSON body
does not reconfigure those services.

| CLI concept | Actual JSON field |
| --- | --- |
| `--pid`, `--uid`, `--debug` | `pid`, `uid`, `debug` |
| `--hex`, `--btf` | `is_hex`, `btf_mode` |
| `--mapsize` | `per_cpu_map_size` in **bytes**, not CLI pages |
| `--eventaddr` | `event_collector_addr` |
| rotation size/time | `event_rotate_size_mb`, `event_rotate_seconds` |
| mode / text source (TLS, GnuTLS) | `capturemode`, `text_source` |
| mode / text source (GoTLS) | `capture_mode`, `text_source` |
| TLS library/version | `opensslpath`, `sslversion` |
| Go executable | `elf_path` |
| GnuTLS library/version | `gnutlspath`, `gnuversion` |
| interface (all three TLS modules) | `ifname` |
| packet filter / artifact paths (TLS, GnuTLS) | `pcapfilter`, `pcapfile`, `keylogfile` |
| packet filter / artifact paths (GoTLS) | `pcap_filter`, `pcap_file`, `keylog_file` |
| cgroup / reorder | `cgroup_path`, `perf_reorder`, `perf_reorder_lag_ms` |
| Bash exit-code option | `errno` (not `errnumber`) |

Do not send CLI flag names as JSON keys. Inspect the matching
`internal/probe/<module>/config.go` and `internal/config/common.go` for fields
not listed here; older `user/config` documentation is obsolete.

```bash
# Example for the hook-text process above, preserving its intended path/mode.
# Substitute the actual mapped library; this example uses a new PID.
curl --fail-with-body -X POST http://127.0.0.1:28256/tls \
  -H 'Content-Type: application/json' \
  --data '{"opensslpath":"/usr/lib/x86_64-linux-gnu/libssl.so.3","capturemode":"text","text_source":"hook","pid":5678,"uid":0,"event_collector_addr":"/tmp/tls.txt"}'
```

GoTLS uses snake_case fields where TLS/GnuTLS use compact names. For example,
for a running GoTLS probe:

```bash
curl --fail-with-body -X POST http://127.0.0.1:28256/gotls \
  -H 'Content-Type: application/json' \
  --data '{"elf_path":"/usr/local/bin/caddy","capture_mode":"text","text_source":"pcapng","ifname":"eth0","pcap_filter":"tcp port 443","pid":5678,"uid":0,"event_collector_addr":"/tmp/go-http.txt"}'
```

For pcapng or pcapng-sourced text include `ifname` and the appropriate packet
filter field; for keylog/pcapng provide a valid destination.
Changing/reopening artifact files can truncate them; preserve the old capture
with a distinct new filename where needed.

HTTP 200 plus `code == 0` means the new generation started. HTTP 400 indicates
decode/validation/start failure; inspect `msg` and startup logs. HTTP 503 means
the update channel is busy. A failed start attempts to restore the previous
same-probe configuration; verify that recovery instead of assuming it. Retry
only transient busy failures with a bounded policy; do not loop on a malformed
configuration or assume a client timeout means the update was not applied.
