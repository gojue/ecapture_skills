# eCapture command templates

Replace brace-delimited values with verified, shell-quoted target values before
running. Commands use v2.9.1 behavior. Resolve the module/namespace/interface
first; remove optional flags rather than leaving placeholders in a command.

## TLS and HTTP

```bash
# Hook plaintext from one process; separate operational log.
sudo ecapture tls -p {PID} --libssl '{LIBSSL_PATH}' \
  --eventaddr '{TEXT_FILE}' --logaddr '{OPERATIONAL_LOG}'

# Live complete HTTP/1.1 or HTTP/2; optional raw capture copy.
sudo ecapture tls -m text --text-source pcapng -i '{INTERFACE}' \
  --eventaddr '{HTTP_FILE}' -w '{PCAPNG_FILE}' '{PACKET_BPF_FILTER}'

# Packet capture with embedded TLS keys (no separate -w with --eventaddr).
sudo ecapture tls -m pcapng -i '{INTERFACE}' \
  --eventaddr '{PCAPNG_FILE}' '{PACKET_BPF_FILTER}'

# NSS key lines for a separate packet capture (no separate -k).
sudo ecapture tls -m keylog --eventaddr '{KEYLOG_FILE}'

# Linux cgroup v2 scope; confirm the startup log did not disable the filter.
sudo ecapture tls --cgroup_path '{CGROUP_V2_DIRECTORY}' --eventaddr '{TEXT_FILE}'
```

## GoTLS and GnuTLS

```bash
sudo ecapture gotls -e '{GO_ELF_PATH}' -p {PID} --eventaddr '{TEXT_FILE}'
sudo ecapture gotls -e '{GO_ELF_PATH}' -m text --text-source pcapng \
  -i '{INTERFACE}' --eventaddr '{HTTP_FILE}' '{PACKET_BPF_FILTER}'
sudo ecapture gotls -e '{GO_ELF_PATH}' -m keylog --eventaddr '{KEYLOG_FILE}'
sudo ecapture gnutls --gnutls '{GNUTLS_PATH}' --eventaddr '{TEXT_FILE}'
sudo ecapture gnutls --gnutls '{GNUTLS_PATH}' -m pcapng \
  -i '{INTERFACE}' --eventaddr '{PCAPNG_FILE}' '{PACKET_BPF_FILTER}'
```

## NSPR, shell, and SQL

```bash
sudo ecapture nspr --nspr '{NSPR_PATH}' -p {PID} --eventaddr '{TEXT_FILE}'
# Omit --errnumber for general Bash capture (default sentinel 128).
sudo ecapture bash --bash '{BASH_PATH}' -u {TARGET_UID} --eventaddr '{TEXT_FILE}'
# Zsh captures input; do not promise exit-code filtering.
sudo ecapture zsh --zsh '{ZSH_PATH}' -u {TARGET_UID} --eventaddr '{TEXT_FILE}'
sudo ecapture mysqld --mysqld '{MYSQLD_PATH}' --eventaddr '{TEXT_FILE}'
sudo ecapture postgres --postgres '{POSTGRES_PATH}' --eventaddr '{TEXT_FILE}'
```

## Streaming and bounded remote capture

```bash
# Start an appropriate receiver first; raw bytes, not NDJSON.
sudo ecapture tls --eventaddr 'tcp://{RECEIVER_HOST}:{PORT}'
sudo ecapture tls --eventaddr 'wss://{RECEIVER_HOST}:{PORT}/events'
# Typed binary Protobuf live events, additive to the primary artifact.
sudo ecapture tls --eventaddr '{TEXT_FILE}' --ecaptureq '127.0.0.1:{PORT}'
# File-backed text/keylog rotation only; preserve the CLI's spelling.
sudo ecapture tls --eventaddr '{TEXT_FILE}' --eventroratesize 100 --eventroratetime 3600

# Example SSH flow using known target values; Linux timeout sends SIGINT.
ssh user@linux-host 'sudo timeout --signal=INT 30s ecapture tls -m pcapng -i eth0 --eventaddr /tmp/traffic.pcapng'
# Transfer using an account/path with permission to read the sensitive artifact.
scp user@linux-host:/tmp/traffic.pcapng ./traffic.pcapng
```

Timeout 124 can be an expected timed stop; inspect probe logs and artifact
content. For newly created root-owned sensitive files, arrange an authorized
read/transfer path without making the file world-readable. Do not assume scp
can read a root-owned 0600 capture.

For HTTP reload use [runtime configuration](../references/runtime-config.md);
start with `--listen 127.0.0.1:28256` and send the actual JSON schema.
