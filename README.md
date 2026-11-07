# AI 工具栈 · macOS 一键安装 / 更新

一个可重复运行的 Shell 脚本：**没装的自动装，装了的自动升级到最新版**。首次运行会自动安装 Homebrew；之后每次运行只做检查和升级。

- 主脚本：`ai-stack.sh`
- 双击入口：`一键安装更新AI工具.command`
- 日志：`~/Library/Logs/ai-stack/run-*.log`

## 快速开始

### 在新 Mac 上第一次安装

脚本是单文件、可自举的：**新电脑不需要先装 Homebrew、Node 或别的工具**，它会自己装。

三种拿到脚本的方式，任选一种：

1. **拷贝整个文件夹**（AirDrop / U 盘 / iCloud）→ 双击 `一键安装更新AI工具.command`。
2. **只拷 `ai-stack.sh` 一个文件**→ 放到任意目录，终端里 `bash ai-stack.sh`。
3. **有下载地址时**（自己的 GitHub / 内网服务器）：

```bash
curl -fsSL "<脚本地址>" -o ~/ai-stack.sh && bash ~/ai-stack.sh --cn --no-claude
```

> 不建议用 `curl ... | bash` 直接管道执行：首次安装 Homebrew 需要输入管理员密码，管道会让脚本拿不到终端输入。

首次运行会：

1. 检查 Xcode Command Line Tools（缺的话会弹出安装窗口，装完再跑一次脚本）；
2. 安装 Homebrew（需要输入一次管理员密码）；
3. 安装/更新全部工具。

### 方式一：双击

双击 `一键安装更新AI工具.command`。

### 方式二：终端

```bash
cd ~/Documents/本地管理/AI工具一键安装
chmod +x ai-stack.sh
./ai-stack.sh
```

> 第一次建议先预览，看看会装什么：
>
> ```bash
> ./ai-stack.sh --dry-run
> ```

## 清单

### 基础工具链

| Key | 工具 | 方式 |
|---|---|---|
| `node` | Node.js / npm / npx | formula |
| `git` | Git | formula |
| `gh` | GitHub CLI | formula |
| `uv` | uv / uvx（Python） | formula |
| `bun` | Bun / bunx | formula |
| `jq` | jq | formula |
| `ripgrep` | ripgrep（rg） | formula |
| `fd` | fd | formula |

### 你点名的桌面应用

| Key | 工具 | 说明 |
|---|---|---|
| `chatgpt` | ChatGPT 桌面版 | |
| `claude` | Claude 桌面版 | 下载源 `downloads.claude.ai` 被墙时需代理，或改用 App Store 版 |
| `antigravity` | Google Antigravity 2 | Agent 调度台 |
| `antigravity-ide` | Google Antigravity IDE | 如只要一个，可 `--skip antigravity-ide` |
| `workbuddy-cn` | WorkBuddy 国内版 | 国际版 id 为 `workbuddy-ai` |
| `trae-cn` | Trae CN 国内版 | 国际版 id 为 `trae` |
| `qoder` | Qoder 国际版 | 国内版 Qoder CN 请用应用内更新，或 `--skip qoder` |
| `doubao` | 豆包 | |
| `clash-verge-rev` | Clash Verge Rev | |
| `cc-switch` | CC Switch | Claude/Codex 配置切换 |
| `feishu` | 飞书 | |
| `google-chrome` | Google Chrome | |
| `cherry-studio` | Cherry Studio | |
| `deepseek-harness` | DeepSeek Harness 桌面版 | |
| `github` | GitHub Desktop | |
| `hermes-desktop` | Hermes Agent 桌面版 | |

### 你点名的命令行工具

| Key | 命令 | 工具 |
|---|---|---|
| `codex` | `codex` | OpenAI Codex CLI |
| `claude-code` | `claude` | Claude Code CLI（cask 下载失败会自动改用 npm 安装） |
| `grok` | `grok` | xAI 官方 Grok Build |
| `agy` | `agy` | Antigravity CLI |
| `qwen` | `qwen` | Qwen Code CLI |
| `hermes-cli` | `hermes` | Hermes Agent CLI |

### 推荐补充（默认安装，`--no-recommend` 可跳过）

| Key | 工具 | 用途 |
|---|---|---|
| `gemini-cli` | Gemini CLI | Google 官方命令行 Agent |
| `copilot-cli` | GitHub Copilot CLI | GitHub 官方命令行 Agent |
| `opencode` | OpenCode | 开源终端 Agent |
| `aider` | Aider | 老牌结对编程 CLI |
| `cursor-cli` | Cursor CLI（`cursor-agent`） | Cursor 的命令行 Agent |
| `kiro-cli` | Kiro CLI | AWS Kiro 的命令行 Agent |
| `ollama-app` | Ollama | 本地跑开源模型 |
| `lm-studio` | LM Studio | 本地模型 GUI / Server |
| `cursor` | Cursor | AI IDE |
| `visual-studio-code` | VS Code | 通用编辑器 + Copilot |
| `zed` | Zed | 高性能编辑器 |
| `ghostty` | Ghostty | 原生 GPU 终端 |
| `orbstack` | OrbStack | Docker 替代，跑 MCP/Open WebUI 很方便 |
| `chatbox` | Chatbox | 多模型聊天客户端 |

为什么是这些：AI 开发常用链路基本是 **终端 + 编辑器 + 本地模型 + Docker + 多模型客户端**。`uv`/`bun` 覆盖 Python 和 JS 的 MCP 工具，`ripgrep`/`fd`/`jq` 是 Agent 高频依赖，`gh` 直接带 Copilot 能力。

## 常用参数

```bash
./ai-stack.sh                      # 全部安装/更新（含推荐）
./ai-stack.sh --no-recommend       # 只装点名的，不装推荐补充
./ai-stack.sh --no-claude          # 跳过 Claude 桌面版 + Claude Code
./ai-stack.sh --dry-run            # 只预览，不改系统
./ai-stack.sh --list               # 列出全部 Key
./ai-stack.sh --only codex,claude-code
./ai-stack.sh --only apps,cli      # 按分组选择
./ai-stack.sh --skip trae-cn,antigravity-ide
./ai-stack.sh --no-update          # 跳过 brew update，更快
./ai-stack.sh --no-greedy          # 不强制升级自带自动更新的 App，更快
./ai-stack.sh --cleanup            # 结束后清理旧版本缓存
```

## 国内网络

```bash
./ai-stack.sh --cn
./ai-stack.sh --proxy http://127.0.0.1:7890
```

- `--cn`：Homebrew 使用清华 TUNA 镜像。
- `--proxy`：本次运行的 HTTP/HTTPS 代理，Homebrew、curl 都会走。
- 如果 `raw.githubusercontent.com` 被墙，Homebrew 安装脚本可能下载失败；先开代理，或用环境变量换安装脚本地址：

```bash
AI_STACK_BREW_INSTALL_URL="https://你的镜像/install.sh" ./ai-stack.sh --cn
```

### Claude 下载被墙怎么办

Claude 桌面版和 Claude Code 的官方 cask 都从 `downloads.claude.ai` 下载，国内网络经常直接超时。脚本已经内置了处理方式：

- **Claude Code CLI**：cask 下载失败会自动改用 `npm install -g @anthropic-ai/claude-code@latest`。
  一旦用 npm 装过，后续运行会直接走 npm 更新，不再等待 cask 超时。
- **Claude 桌面版**：没有可用的镜像。三种办法：
  1. 开代理后运行 `./ai-stack.sh --only claude --proxy http://127.0.0.1:7890`；
  2. 从 Mac App Store 安装（搜 “Claude”，需要对应区账号）；
  3. 手动下载安装包装好后，其他工具仍由脚本管理；Claude 桌面版本身会在每次运行时提示失败。

检查是否被墙：

```bash
curl -I --connect-timeout 8 https://downloads.claude.ai/
```

超时就是网络不通，不是脚本问题。

## 定时自动更新（可选）

如果想让 Mac 每周一自动跑一次，可以创建 LaunchAgent：

`~/Library/LaunchAgents/com.local.ai-stack.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.local.ai-stack</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>/Users/你的用户名/Documents/本地管理/AI工具一键安装/ai-stack.sh</string>
    <string>--no-recommend</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Weekday</key><integer>1</integer>
    <key>Hour</key><integer>10</integer>
    <key>Minute</key><integer>0</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>/Users/你的用户名/Library/Logs/ai-stack/launchd.log</string>
  <key>StandardErrorPath</key>
  <string>/Users/你的用户名/Library/Logs/ai-stack/launchd.err.log</string>
</dict>
</plist>
```

```bash
mkdir -p ~/Library/Logs/ai-stack
launchctl load ~/Library/LaunchAgents/com.local.ai-stack.plist
```

停止：

```bash
launchctl unload ~/Library/LaunchAgents/com.local.ai-stack.plist
```

## 常见问题

### 1. 为什么升级失败？

最常见的原因：

- 应用正在运行。先退出对应 App，再执行 `./ai-stack.sh --only <key>`。
- 网络超时。开代理后重试。
- 某个 cask 暂时下架或改名。看日志里的 brew 报错。

脚本会继续处理其他项目，最后汇总失败项，不会因为一个失败全部中断。

### 2. 我已经手动装过某个 App，会被覆盖吗？

会。脚本对未由 Homebrew 管理的同名 App 使用 `brew install --cask --force` 接管，覆盖的是 `/Applications` 里的 App 本体。你的配置、登录状态、聊天记录通常在 `~/Library`，不会被删除。

### 3. Qoder / Trae / WorkBuddy 国内版和国际版

- 脚本默认国内版：`trae-cn`、`workbuddy-cn`。
- Qoder 官方 cask 是国际版；国内版 Qoder CN 一般由 App 自己更新，不需要脚本处理，可 `--skip qoder`。
- 想换国际版：编辑 `ai-stack.sh` 清单里的 cask id（例如把 `trae-cn` 改成 `trae`），保存后重新运行即可。

### 4. 怎么只更新某个工具？

```bash
./ai-stack.sh --only codex
./ai-stack.sh --only chatgpt,claude
```

### 5. 日志在哪？

```bash
open ~/Library/Logs/ai-stack
```

`latest.log` 永远指向最近一次运行。

### 6. 怎么卸载？

```bash
brew uninstall --cask <token>
brew uninstall <formula>
```

例如：

```bash
brew uninstall --cask cherry-studio
brew uninstall qwen-code
```

### 7. 怎么往清单里加工具？

编辑 `ai-stack.sh` 里的 `add_item` 段：

```bash
add_item apps my-app "我的工具" cask my-app
add_item cli  my-cli "我的 CLI" formula my-cli
add_item cli  my-npm "我的 npm CLI" npm @scope/my-cli
```

类型支持 `cask`、`formula`、`npm`。

## 说明

- 所有软件来自 Homebrew 官方 cask/formula 及其上游官方下载地址。
- 脚本关闭了 Homebrew 匿名统计（`HOMEBREW_NO_ANALYTICS=1`）。
- `--dry-run` 不会安装 Homebrew，也不会改任何文件。
- 首次安装 Homebrew 需要管理员密码；之后的 App 安装通常不需要。
