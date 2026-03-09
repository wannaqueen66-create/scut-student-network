# SCUT Student Network Login Script Template / 华南理工校园网登录脚本模板

A lightweight shell-based template for automating campus portal login on Linux routers, SBCs, and similar devices.

这是一个基于 Shell 的轻量模板项目，用于在 Linux 路由器、开发板或类似设备上自动化处理校园网 Portal 登录。

> This repository is published as a template and reference project. Portal workflows vary across schools and vendors, so users should capture their own login requests and adapt the script accordingly.
>
> 本仓库以“模板 / 参考实现”为主。不同学校、校区和 Portal 厂商的接口差异很大，使用者应自行抓包并按本地环境调整参数。

## Table of Contents / 目录

- [Features / 特性](#features--特性)
- [Project Structure / 项目结构](#project-structure--项目结构)
- [Requirements / 依赖环境](#requirements--依赖环境)
- [Quick Start / 快速开始](#quick-start--快速开始)
- [Configuration / 配置说明](#configuration--配置说明)
- [How to Capture Portal Parameters / 如何抓取 Portal 参数](#how-to-capture-portal-parameters--如何抓取-portal-参数)
- [How It Works / 工作原理](#how-it-works--工作原理)
- [Scheduling / 定时执行](#scheduling--定时执行)
- [Security Notes / 安全说明](#security-notes--安全说明)
- [Limitations / 限制](#limitations--限制)
- [License / 许可证](#license--许可证)

## Features / 特性

**English**

- Simple POSIX shell script
- Local config file support
- IPv4 and MAC auto-detection from a specified interface
- Basic online check before login
- Retry and failure counter logic
- Optional interface reset after repeated failures
- Safer default logging behavior for public release

**中文**

- 基于 POSIX Shell，依赖简单
- 支持本地配置文件
- 自动读取指定网卡的 IPv4 和 MAC 地址
- 登录前自动检查是否已在线
- 内置重试与失败计数逻辑
- 连续失败后可选重置网卡
- 为公开发布做了默认脱敏与安全化处理

## Project Structure / 项目结构

```text
.
├── README.md
├── LICENSE
├── .gitignore
├── scut_portal_login.sh
├── scut_portal.conf.example
└── docs/
    └── 抓包与参数提取.md
```

## Requirements / 依赖环境

**English**

You should have:

- Linux system
- `sh`
- `curl`
- `ip` command from `iproute2`
- Optional: `ifup` / `ifdown` if you enable interface reset

**中文**

建议环境：

- Linux 系统
- `sh`
- `curl`
- `iproute2` 提供的 `ip` 命令
- 如果启用网卡重置，还需要 `ifup` / `ifdown`

## Quick Start / 快速开始

### 1) Copy the example config / 复制示例配置

```sh
cp scut_portal.conf.example scut_portal.conf
```

### 2) Edit your local config / 修改本地配置

Fill in your own portal account and network parameters.

填写你自己的账号、密码和 Portal 参数。

### 3) Make the script executable / 赋予执行权限

```sh
chmod +x scut_portal_login.sh
```

### 4) Run manually / 手动执行

```sh
CONFIG_FILE=./scut_portal.conf ./scut_portal_login.sh
```

## Configuration / 配置说明

Example config fields:

```sh
PORTAL_USER="your-student-id-or-portal-username"
PORTAL_PASS="your-portal-password"
IFACE="apclix0"
AC_NAME="example_ac"
HOST="portal.example.edu.cn"
HOST_IP="203.0.113.10"
PORT="802"
```

### Key fields / 关键字段

- `PORTAL_USER`: portal username / 门户账号
- `PORTAL_PASS`: portal password / 门户密码
- `IFACE`: network interface used for login / 登录所用网卡
- `AC_NAME`: access controller name if required / 接入点名称
- `HOST`: portal host / 门户域名
- `HOST_IP`: optional fixed IP for `--resolve` / 可选固定 IP
- `PORT`: portal port / 门户端口
- `DEBUG`: set to `1` only when debugging / 调试时可设为 `1`
- `ENABLE_IFACE_RESET`: whether to run `ifdown/ifup` after repeated failures / 是否在多次失败后重置网卡

## How to Capture Portal Parameters / 如何抓取 Portal 参数

**English**

Different schools use different login flows. In most cases, you should:

1. Open your portal login page
2. Press `F12`
3. Switch to `Network`
4. Enable `Preserve log`
5. Log out and log in again
6. Find the login request
7. Copy it as cURL
8. Extract required parameters into your config or script

See detailed guide:

- [docs/抓包与参数提取.md](docs/抓包与参数提取.md)

**中文**

不同学校的 Portal 登录接口差异很大。一般建议：

1. 打开登录页
2. 按 `F12`
3. 切到 `Network / 网络`
4. 勾选 `Preserve log / 保留日志`
5. 先注销再重新登录
6. 找到登录请求
7. 复制为 cURL
8. 把关键参数提取到配置文件或脚本中

详细说明见：

- [docs/抓包与参数提取.md](docs/抓包与参数提取.md)

## How It Works / 工作原理

**English**

This template script works roughly as follows:

1. Load a local config file
2. Check whether the specified interface already has working internet access
3. Read IPv4 and MAC from the interface
4. Send a portal login request with configured parameters
5. Retry several times if needed
6. Optionally reset the interface after repeated failures

**中文**

脚本的基本流程如下：

1. 读取本地配置文件
2. 检查目标网卡是否已经联网
3. 读取该网卡的 IPv4 和 MAC 地址
4. 按配置参数发起 Portal 登录请求
5. 失败时按策略重试
6. 连续失败时可选重置网卡

## Scheduling / 定时执行

### Cron example / Cron 示例

```cron
*/5 * * * * CONFIG_FILE=/path/to/scut_portal.conf /path/to/scut_portal_login.sh
```

This runs the script every 5 minutes.

这会每 5 分钟执行一次脚本。

## Security Notes / 安全说明

**English**

- Do not commit real credentials
- Do not publish raw cURL requests with passwords, cookies, or tokens
- Keep `DEBUG=0` by default in production
- Only use this in networks you are authorized to access

**中文**

- 不要提交真实账号密码
- 不要公开原始 cURL、Cookie、Token 等敏感信息
- 生产环境默认保持 `DEBUG=0`
- 仅在你有合法授权的网络环境中使用

## Limitations / 限制

**English**

This repository is not a universal campus login solution.

It may fail if your environment requires:

- JavaScript-generated signatures
- Temporary tokens or cookies
- Multi-step redirects or unified authentication
- Vendor-specific encryption or obfuscation

**中文**

本仓库不是“所有校园网都能直接用”的通用方案。

以下情况可能需要额外改造：

- 需要 JavaScript 动态签名
- 依赖一次性 Token 或 Cookie
- 需要多步跳转或统一认证
- 存在厂商特有加密或混淆逻辑

## License / 许可证

This project is licensed under **CC BY-NC 4.0**.

本项目采用 **CC BY-NC 4.0（署名-非商业性使用）** 许可协议。

That means:

- Attribution is required / 使用时需要保留署名
- Commercial use is not allowed without permission / 未经许可不得商用

## Disclaimer / 免责声明

**English**

This project is provided for educational, research, and lawful automation purposes only. The author does not guarantee compatibility with any specific campus network environment and is not responsible for account issues, policy violations, or service interruptions caused by misuse.

**中文**

本项目仅供学习、研究和合法授权场景下的自动化使用。作者不保证其适用于任何特定校园网环境，也不对因误用造成的账号问题、策略违规或服务中断负责。
