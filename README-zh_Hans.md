# eCapture Claude AI Skill（AI Agent 技能包）

> **[eCapture (旁观者)](https://ecapture.cc) 的 Claude AI Agent 技能包** —— 基于 eBPF，无需 CA 证书即可在 Linux/Android 上捕获 SSL/TLS 明文、Shell 命令和数据库查询。

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](https://github.com/gojue/ecapture/blob/master/LICENSE)
[![eCapture](https://img.shields.io/badge/eCapture-v1.x-green.svg)](https://github.com/gojue/ecapture/releases)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Android-orange.svg)](https://ecapture.cc)
[![Claude Skills](https://img.shields.io/badge/Claude-Custom%20Skill-blueviolet.svg)](https://support.claude.com/en/articles/12512198-how-to-create-custom-skills)

---

## 这是什么？

本仓库是 [eCapture](https://github.com/gojue/ecapture) 的 **Claude Custom Skill（自定义技能包）**，用于告诉 Claude AI 如何正确使用 eCapture 这款 eBPF 安全工具。

上传到 Claude 后，AI Agent 将能够：

- 🔐 **捕获 TLS/SSL 明文** —— 支持 OpenSSL、BoringSSL、GnuTLS、NSS/NSPR 以及 Go `crypto/tls`，无需安装 CA 证书
- 🐚 **实时审计 Shell 命令** —— 监控 bash / zsh 会话中的每一条命令及其退出码
- 🗄️ **捕获数据库查询** —— 无需开启查询日志，直接捕获 MySQL、MariaDB、PostgreSQL 的 SQL 语句
- 🔍 **执行前环境检查** —— 自动核验操作系统、内核版本、运行权限
- 🔄 **运行时热更新配置** —— 通过 HTTP API 在不重启的情况下更新 eCapture 的抓包参数
- 📡 **实时事件流推送** —— 将捕获数据通过 TCP/WebSocket 推送至外部日志服务器或 AI Agent 端点

---

## 仓库结构

```
ecapture-skill/
├── SKILL.md                          # 核心技能文件（说明 + 元数据）
├── scripts/
│   ├── preflight-check.sh            # 检查 OS、内核版本、root 权限、BTF 支持
│   └── detect-libs.sh                # 自动发现 SSL/TLS 库路径和数据库二进制路径
├── references/
│   ├── quick-reference.md            # 所有模块的命令速查表
│   └── platform-constraints.md      # 操作系统/内核/架构支持矩阵
└── assets/
    └── command-templates.md          # 参数化命令模板
```

---

## 支持的 eCapture 模块

| 模块 | 捕获内容 | Linux | Android |
|------|---------|-------|---------|
| `tls` | OpenSSL / BoringSSL / LibreSSL 明文 | ✅ | ✅ |
| `gotls` | Go `crypto/tls` 明文 | ✅ | ✅ |
| `gnutls` | GnuTLS 明文 | ✅ | ⚠️ 仅 Termux |
| `nspr` | Firefox / NSS / NSPR 明文 | ✅ | ❌ |
| `bash` | bash 命令 + 退出码 | ✅ | ✅ |
| `zsh` | zsh 命令 + 退出码 | ✅ | ❌ |
| `mysqld` | MySQL / MariaDB SQL 查询 | ✅ | ❌ |
| `postgres` | PostgreSQL SQL 查询 | ✅ | ❌ |

---

## 平台要求

> ⚠️ **eCapture 仅支持 Linux 或 Android，不支持 macOS 和 Windows。**

| 架构 | 最低内核版本 |
|---|---|
| x86_64 | 4.18 |
| aarch64 | 5.5 |

所有模块均需要 root（`sudo`）权限。

---

## 如何上传到 Claude

### 方式一 —— Claude.ai 网页端

1. 进入 [claude.ai](https://claude.ai) → **设置（Settings）** → **集成（Integrations）** → **自定义技能（Custom Skills）**
2. 点击 **"添加技能（Add Skill）"**
3. 上传 `SKILL.md` 作为主技能文件
4. 可选：将 `scripts/`、`references/`、`assets/` 目录下的文件作为补充上下文一并上传

### 方式二 —— Anthropic API

```python
import anthropic

client = anthropic.Anthropic()

with open("SKILL.md") as f:
    skill_content = f.read()

response = client.messages.create(
    model="claude-opus-4-5",
    max_tokens=2048,
    system=skill_content,          # 将 SKILL.md 注入为系统提示
    messages=[{
        "role": "user",
        "content": "帮我在 eth0 网卡上抓取 HTTPS 流量，保存为 pcapng 文件"
    }]
)
print(response.content[0].text)
```

---

## 使用示例

上传后，你可以用自然语言向 Claude 提问：

```
"帮我在 Linux 服务器上抓取所有 HTTPS 流量，保存为 pcapng 文件"
→ sudo ecapture tls -m pcap -i eth0 -w /tmp/capture.pcapng

"监控 uid 1000 用户运行的所有 bash 命令"
→ sudo ecapture bash -u 1000 -e 0 -l /tmp/bash_audit.log

"在不重启数据库的情况下审计 MySQL 查询"
→ sudo ecapture mysqld -l /tmp/mysql_queries.log

"捕获 Caddy 服务器的 Go TLS 流量"
→ sudo ecapture gotls -e /usr/local/bin/caddy

"导出 TLS 会话密钥，以便用 Wireshark 解密流量"
→ sudo ecapture tls -m keylog -k /tmp/keys.log
```

---

## 辅助脚本说明

### `scripts/install-ecapture.sh` —— 自动安装

在目标 Linux 主机上运行，自动完成下载、校验、安装全流程：

```bash
# 安装最新稳定版（需要 root）
sudo bash scripts/install-ecapture.sh

# 安装指定版本
sudo bash scripts/install-ecapture.sh v1.5.2

# 仅预览，不实际安装
bash scripts/install-ecapture.sh --dry-run
```

脚本执行步骤：
1. 验证 OS 为 Linux，架构为 x86_64 或 aarch64
2. 检查内核版本是否满足最低要求（x86_64 ≥ 4.18 / aarch64 ≥ 5.5）
3. 检测 BTF 支持（`/sys/kernel/btf/vmlinux`）→ 自动选择 CO-RE 或 non-CO-RE 构建版本
4. 从 GitHub API 获取最新版本号（或使用指定版本）
5. 下载对应架构的 release 压缩包
6. 验证 SHA256 校验和，确保文件完整性
7. 解压并安装二进制文件至 `/usr/local/bin/ecapture`

### `scripts/preflight-check.sh` —— 环境预检

在执行任何 eCapture 命令前，在目标 Linux 主机上运行此脚本，检查以下内容：
- 操作系统是否为 Linux
- 架构是否为 x86_64 或 aarch64
- 内核版本是否满足最低要求
- 是否以 root 身份运行
- `ecapture` 二进制文件是否已安装
- 是否支持 BTF（BPF Type Format）

```bash
ssh user@linux-host 'bash preflight-check.sh'
```

### `scripts/detect-libs.sh` —— 库路径自动探测

在目标主机上自动发现 SSL/TLS 共享库路径及数据库二进制路径，输出可直接使用的 eCapture flag 参数。

```bash
ssh user@linux-host 'bash detect-libs.sh'
# 输出示例：
#   libssl:  --libssl=/lib/x86_64-linux-gnu/libssl.so.3
#   gnutls:  --gnutls=/lib/x86_64-linux-gnu/libgnutls.so.30
#   mysqld:  --mysqld=/usr/sbin/mysqld
```

---

## 关于 eCapture

[eCapture (旁观者)](https://ecapture.cc) 是由 [@cfc4n](https://github.com/cfc4n) 开发的开源 eBPF 工具，通过 Hook 用户态函数捕获加密流量和系统行为——无需 CA 证书、无需代理、无需修改任何应用程序。

- **GitHub**：https://github.com/gojue/ecapture
- **官网**：https://ecapture.cc
- **开源协议**：Apache-2.0

---

## 开源协议

本技能包遵循与 eCapture 项目相同的 [Apache-2.0](https://github.com/gojue/ecapture/blob/master/LICENSE) 协议。

