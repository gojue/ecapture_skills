# eCapture Command Templates

## TLS / SSL Capture (OpenSSL · BoringSSL · LibreSSL)

```bash
# Print plaintext (default)
sudo ecapture tls

# Save to pcapng file
sudo ecapture tls -m pcap -i {INTERFACE} -w {OUTPUT_FILE} {BPF_FILTER}

# Export TLS session keys
sudo ecapture tls -m keylog -k {KEYLOG_FILE}

# Filter by PID
sudo ecapture tls -p {PID}

# Specify libssl.so explicitly
sudo ecapture tls --libssl={LIBSSL_PATH}

# Write output to file
sudo ecapture tls -l {LOG_FILE}
```

## Go TLS Capture

```bash
# Print plaintext
sudo ecapture gotls -e {GO_BINARY_PATH}

# Save to pcapng
sudo ecapture gotls -e {GO_BINARY_PATH} -m pcap -i {INTERFACE} -w {OUTPUT_FILE}

# Export TLS keys
sudo ecapture gotls -e {GO_BINARY_PATH} -m keylog -k {KEYLOG_FILE}
```

## GnuTLS Capture

```bash
sudo ecapture gnutls
sudo ecapture gnutls --ssl_version={GNUTLS_VERSION}
sudo ecapture gnutls -m keylog -k {KEYLOG_FILE}
```

## NSS / NSPR (Firefox) Capture

```bash
sudo ecapture nspr
sudo ecapture nspr -p {FIREFOX_PID}
sudo ecapture nspr -l {LOG_FILE}
```

## Shell Command Auditing

```bash
# All bash commands (all users)
sudo ecapture bash -e 0

# All bash commands for a specific UID
sudo ecapture bash -e 0 -u {UID} -l {LOG_FILE}

# zsh commands
sudo ecapture zsh -e 0
```

## Database Query Auditing

```bash
# MySQL / MariaDB
sudo ecapture mysqld
sudo ecapture mysqld -m {MYSQLD_PATH} -l {LOG_FILE}

# PostgreSQL
sudo ecapture postgres
sudo ecapture postgres -m {POSTGRES_PATH} -l {LOG_FILE}
```

## Remote Execution via SSH

```bash
# Run on remote Linux host
ssh {SSH_USER}@{LINUX_HOST} 'sudo ecapture {MODULE} {FLAGS}'

# SSH tunnel for hot-reload API
ssh -L 28256:localhost:28256 {SSH_USER}@{LINUX_HOST}
```

## Real-Time Event Streaming

```bash
# Push to TCP server
sudo ecapture tls --eventaddr tcp://{AGENT_HOST}:{PORT}

# Push to WebSocket server
sudo ecapture tls --eventaddr ws://{AGENT_HOST}:{PORT}/events

# Queue server (agent connects to pull)
sudo ecapture tls --ecaptureq 0.0.0.0:{PORT}
```

