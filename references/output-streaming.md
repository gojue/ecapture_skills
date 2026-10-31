# Output and agent integration

Baseline: v2.9.1; the output split and typed publisher changed in v2.8.0.

## Raw output vs typed events

`--logaddr` is operational logging only, also sent to stderr. `--eventaddr`
is captured output; it does not default to the log destination. Supported
primary destinations are `stdout`, a file path, `file://`, `tcp://`, `ws://`,
and `wss://`. The TLS mode determines bytes on the stream:

| Mode / source | Primary representation | Legacy / optional files |
| --- | --- | --- |
| text / hook | Human-readable event text; may contain multiple lines | Defaults to stdout |
| text / pcapng | Reconstructed HTTP/1.1 or HTTP/2 messages with metadata | Explicit `-w` saves packets, `-k` saves keys; neither is created by default |
| keylog | NSS Key Log lines | `-k` aliases primary file |
| pcapng | Binary packets with embedded TLS DSB | `-w` aliases primary file; `-k` is an optional additional keylog |

TLS/GoTLS/GnuTLS keep legacy CLI defaults: `ecapture_openssl_key.log`,
`ecapture_gotls_key.log`, `ecapture_gnutls_key.log`; packet defaults are
`save.pcapng` for TLS/GnuTLS and `ecapture_gotls.pcapng` for GoTLS. Prefer an
explicit destination in an agent workflow. HTTP-created configurations do
not necessarily have the same filename defaults as Cobra.

Setting `--eventaddr` together with an explicit `-k` in keylog mode, or `-w`
in pcapng mode, fails: both would select the primary destination. Pcapng text
source permits `--eventaddr /tmp/http.txt -w /tmp/raw.pcapng -k /tmp/keys.log`.

TCP is an ordered byte stream. Raw WebSocket output uses binary frames whose
payloads must be concatenated in arrival order; frames need not align to
records. It is not a JSON protocol. Broken streams terminate; do not append a
reconnected stream blindly to an existing pcapng artifact.

```bash
# These destinations carry the selected representation, not Protobuf.
sudo ecapture tls -m text --eventaddr tcp://127.0.0.1:9090
sudo ecapture tls -m keylog --eventaddr ws://127.0.0.1:8090/keys
sudo ecapture tls -m pcapng -i eth0 --eventaddr /tmp/traffic.pcapng
# Pure binary stdout; operational logs stay on stderr.
sudo ecapture tls -m pcapng -i eth0 --eventaddr stdout > /tmp/traffic.pcapng
```

Do not redirect stderr into a binary artifact. Explicit `--logaddr stdout`
conflicts with pcapng on stdout. Start receivers before a network capture and
verify their output; successful startup alone is not proof of delivery.

## Rotation and file lifecycle

The intentionally misspelled CLI flags are `--eventroratesize` (MiB) and
`--eventroratetime` (seconds), each 0 to disable or 1–65535. Rotation is supported
for file-backed text/keylog streams, not network sinks or pcapng. Do not rotate
an optional pcapng side artifact as if it were text.

```bash
sudo ecapture tls --eventaddr /tmp/tls.txt \
  --eventroratesize 100 --eventroratetime 3600
```

Keylog/pcapng files are truncated at capture start, including a reopened file
on reload. Use a new filename to preserve earlier artifacts. New sensitive
keylog, pcapng, and reconstructed-HTTP files use restrictive permissions;
inspect permissions when reusing an existing file. Stop gracefully to flush
packets and queued secrets. Raw captures and typed events can both be sensitive.

## eCaptureQ

```bash
sudo ecapture tls --eventaddr /tmp/tls.txt --ecaptureq 127.0.0.1:8091
# Client connects to ws://127.0.0.1:8091/
```

This is an additive live WebSocket server. It sends one binary Protobuf
`LogEntry` per message, using upstream
[`protobuf/proto/v1/ecaptureq.proto`](https://github.com/gojue/ecapture/blob/v2.9.1/protobuf/proto/v1/ecaptureq.proto).
Generate/import bindings matching that schema when building an agent receiver.

- `LOG_TYPE_HEARTBEAT`: transport health, not captured traffic.
- `LOG_TYPE_PROCESS_LOG`: operational `run_log`; keep in the status area.
- `LOG_TYPE_EVENT`: `event_payload` with `capture_format`, `sensitivity`,
  timestamp, UUID, PID/process, available network tuple/direction, payload,
  `original_length`, and optional `stream_id`/`sequence`.

For pcapng, EVENTs are packet rows rather than raw pcapng chunks; DSB-only
secret events do not become table rows. For pcapng text source, EVENTs carry
reconstructed sensitive text, not raw packets. Display/route by log type and
format instead of parsing rendered log strings.

New clients get at most 128 recent operational records, followed by live
traffic. Captured events are not replayed from startup history. Connect the
receiver before generating traffic; monitor drops/backpressure. eCaptureQ is
not a durable queue and does not replace an artifact sink. Keep listeners on
loopback or an established protected channel; use SSH forwarding for remote
access rather than opening an unauthenticated management/event port by default.
