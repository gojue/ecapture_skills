# eCapture AI Agent Skill

[English](README.md) · [eCapture 项目](https://github.com/gojue/ecapture) · [版本发布](https://github.com/gojue/ecapture/releases)

用于指导 AI Agent 使用 eCapture：在 Linux/Android 上捕获 TLS 明文、重组 HTTP、
导出密钥和 pcapng，以及检查 Shell 命令与 SQL，无需 CA 证书。
适用于支持加载 `SKILL.md` 及其相对路径资源的 Agent harness。

本次更新日期为 **2026-10-31**，依据 eCapture **v2.9.1** 及本地源码提交
`5b664c9`，Skill 包版本为 **2.0.0**。用于其他版本时，以目标机器实际二进制的
帮助信息和行为为准。

## 本次更新

- 补充 TLS、GoTLS、GnuTLS 的 `--text-source pcapng`，实时重组 HTTP/1.1 和
  HTTP/2，并按需保存原始数据包和密钥。
- 区分运行日志 `--logaddr` 与捕获数据 `--eventaddr`，说明 TCP/WebSocket
  原始流格式及 eCaptureQ 的 Protobuf 类型化事件协议。
- 同步 Linux LoongArch64、OpenSSL/GnuTLS 版本映射、Android 16/17、cgroup
  过滤、perf 事件重排和 HTTP 配置重载的实际语义。
- 修正 Bash 退出码、Android 模块、默认监听状态、输出示例、缓冲区单位及
  缺乏源码依据的兼容性说明。
- 安装脚本按真实发布元数据选择 Linux 产物，强制 SHA256 校验，兼容 Loong64
  独立校验清单；预览无需 root，并修复环境预检的误报。

## 目录与使用方式

| 资源 | 用途 |
| --- | --- |
| [SKILL.md](SKILL.md) | 技能发现元数据与核心工作流程 |
| [命令速查](references/quick-reference.md) | 模块、参数、版本映射和故障定位 |
| [平台约束](references/platform-constraints.md) | 内核、权限、命名空间和发布产物 |
| [输出与事件流](references/output-streaming.md) | 输出格式、目标、轮转和 eCaptureQ |
| [运行时配置](references/runtime-config.md) | HTTP 路由、JSON 字段及重载限制 |
| [源码基线](references/source-baseline.md) | 上游迭代与后续维护依据 |
| [命令模板](assets/command-templates.md) | 可替换参数的捕获示例 |
| `scripts/` | 安装、预检、库发现脚本及共享辅助文件 |
| `tests/` | 基于模拟发布包和主机环境的离线回归测试 |

按所用 harness 的技能目录或导入机制安装，保留**完整目录**。
参考文件与脚本辅助文件均为技能的一部分。只把 `SKILL.md` 文本放入 prompt，
不会自动提供其引用内容、工具执行能力或目标主机访问权限。

## 运行要求

支持 Linux x86_64 ≥ 4.18、aarch64 ≥ 5.5、loongarch64 ≥ 6.6；
Android 仅支持 x86_64/aarch64。加载探针需要 root 或充分的 Linux capabilities。
Android 构建提供 `tls`、`gotls`、`bash`，其他模块仅限 Linux。
macOS/Windows 可编辑技能和检查产物，eCapture 应在受支持的目标环境执行。
内核低于 5.2 时 PID/UID/cgroup 过滤可能被忽略。

```bash
# 在 Linux 目标主机的技能目录执行；依赖 Bash、Python 3、curl 或 wget。
bash scripts/install-ecapture.sh --dry-run
sudo bash scripts/install-ecapture.sh v2.9.1
bash scripts/preflight-check.sh
bash scripts/detect-libs.sh --pid 1234

# 替换为实际网卡与目标 ELF 路径。
sudo ecapture tls -m text --text-source pcapng -i eth0 --eventaddr /tmp/http.txt
sudo ecapture gotls -e /usr/local/bin/caddy -m keylog --eventaddr /tmp/go.keys
```

预览只获取发布元数据，不下载发布产物或安装。缺少产物或校验项时安装会失败，
不会跳过完整性校验。`--install-dir` 可指定用户可写目录。
预检退出码 0 表示基础条件通过，1 表示存在阻断问题，2 表示非 root 权限路径
仍需验证；预检不会加载探针，也不能证明实际捕获成功。

## 验证

```bash
python3 -m unittest discover -s tests -v
for script in scripts/*.sh scripts/lib/*.sh; do bash -n "$script" || exit; done
```

这些测试仅验证 Skill 辅助脚本，不访问网络、不写入系统安装目录，也不加载 BPF。
eCapture 本身的编译、测试与真实抓取需要受支持的 Linux/Android 环境。
捕获内容可能含敏感信息，应保存在授权位置，并在报告中脱敏。

## 协议

Apache-2.0，与 [eCapture 项目协议](https://github.com/gojue/ecapture/blob/v2.9.1/LICENSE) 一致。
