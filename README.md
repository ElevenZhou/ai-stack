# AI 工具栈 · macOS 一键安装 / 更新

一个 **单文件、可自举** 的 Shell 脚本：新 Mac 不用预先装 Homebrew、Node 或任何东西，跑一次就把 AI 工具装齐；以后重复跑就是检查并升级到最新版。

- 主脚本：`ai-stack.sh`（Bash 3.2 兼容，macOS 自带 bash 就能跑）
- 双击入口：`一键安装更新AI工具.command`
- AI 助手说明：[`AGENTS.md`](AGENTS.md)
- 日志：`~/Library/Logs/ai-stack/run-*.log`（`latest.log` 指向最近一次）

```bash
# 新 Mac 一条命令（国内网络）
curl -fsSL https://raw.githubusercontent.com/ElevenZhou/ai-stack/main/ai-stack.sh -o ~/ai-stack.sh \
  && bash ~/ai-stack.sh --cn --no-claude
```

---

## 目录

- [快速开始](#快速开始)
- [它会做什么](#它会做什么)
- [清单（44 项）](#清单44-项)
- [参数说明](#参数说明)
- [典型场景](#典型场景)
- [给 AI 助手用](#给-ai-助手用)
- [常见问题](#常见问题)
- [卸载 / 定制](#卸载--定制)
- [开发](#开发)

---

## 快速开始

### 方式一：新 Mac，一条命令

```bash
curl -fsSL https://raw.githubusercontent.com/ElevenZhou/ai-stack/main/ai-stack.sh -o ~/ai-stack.sh
bash ~/ai-stack.sh
```

如果 `raw.githubusercontent.com` 打不开，用 jsDelivr 镜像（国内一般可达）：

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/ElevenZhou/ai-stack@main/ai-stack.sh -o ~/ai-stack.sh
bash ~/ai-stack.sh
```

> jsDelivr 对 `@main` 有约 12 小时缓存，可能拿到旧版本。想立刻用最新版，改用 tag：`@v1.2.0`，或干脆用上面的 raw 地址。

国内网络建议加 `--cn`（Homebrew 走清华镜像）：

```bash
bash ~/ai-stack.sh --cn
```

> ⚠️ 不要用 `curl ... | bash` 管道执行。首次安装 Homebrew 要输入管理员密码，管道会让脚本拿不到终端输入。

### 方式二：拷贝整个文件夹

AirDrop / U 盘 / iCloud 把 `AI工具一键安装` 文件夹传过去，双击 `一键安装更新AI工具.command`。

### 方式三：Git clone

```bash
git clone https://github.com/ElevenZhou/ai-stack.git
cd ai-stack
./ai-stack.sh
```

### 首次运行会发生什么

1. 检查 Xcode Command Line Tools；缺了会弹出安装窗口，**装完再跑一次脚本**；
2. 自动安装 Homebrew（需要输入一次管理员密码，之后不再需要）；
3. 按清单安装/更新，失败项不会中断其他项，最后统一汇总。

想先看会装什么、不修改系统：

```bash
bash ai-stack.sh --dry-run
```

---

## 它会做什么

- **缺什么装什么**：已安装且最新 → 跳过；已安装但旧 → 升级；没装 → 安装。
- **重复运行安全**：随时可以再跑，不会重复安装。
- **失败不阻塞**：单项失败会记录，继续处理后面的，最后给出失败清单和日志路径。
- **自动兜底**：Claude Code 的 Homebrew 包下载失败时，自动改用 `npm install -g @anthropic-ai/claude-code@latest`；已用 npm 装过的下次直接走 npm，不再等待超时。
- **不改你的数据**：覆盖的只是 `/Applications` 里的 App 本体，登录状态、配置、聊天记录在 `~/Library`，不会被删。
- **关闭匿名统计**：`HOMEBREW_NO_ANALYTICS=1`。

### 逐项判定逻辑

每次运行，对清单里的每一项都按下面的顺序判断，**不会无脑重装**：

| 当前状态 | 动作 | 结果标记 |
|---|---|---|
| brew 已装 + 有新版 | `brew upgrade` | `已更新` |
| brew 已装 + 已是最新 | **跳过**，不做任何事 | `已是最新` |
| brew 已装 + App 文件被删了 | `brew install --cask --force` 补装 | `已安装` |
| **手动装过同名 App**（brew 不认识） | **默认跳过**，只提示；`--adopt` 才接管 | `手动安装` |
| brew 和 /Applications 都没有 | `brew install --cask --force` / `brew install` | `已安装` |
| npm 条目 | 先查线上版本，相同则跳过，不同才装 | `已是最新` / `已更新` |
| 主来源失败（如 Claude Code 的 cask） | 自动改用 fallback（npm） | `已安装` / `已更新` |

判定顺序（脚本实际执行的步骤）：

1. `brew update` 刷新本地索引（`--no-update` 或离线时跳过/失败则沿用旧索引）；
2. 一次性执行 `brew outdated --cask --greedy` / `--formula` 得到「可更新」名单；
3. 逐项比对名单：在名单里 → 升级，不在 → 视为已是最新并跳过；
4. 对 brew 里没有的 **GUI 条目**，再去 `/Applications` 和 `~/Applications` 里找同名 `.app`；
5. npm 类条目额外执行一次 `npm view <包> version` 对比，相同就跳过。

几个需要知道的边界：

- **判定依据是 Homebrew 本地索引**。如果 `brew update` 失败（断网、镜像不可达），索引是旧的，可能把「其实有新版」误报成 `已是最新`。日志里会有 `brew update 失败` 的提示，重跑一次即可。
- **自带自动更新的 App**（Chrome、VS Code、Cursor 等）默认靠 `--greedy` 判定；加了 `--no-greedy` 就会被当作已是最新而跳过，这是有意的省时选项。
- **手动装过的同名 App 默认不会被覆盖**：脚本在 `/Applications` 里找到它，就标为 `手动安装，已跳过`，并打印它的版本和 Homebrew 上的最新版本供你判断。想纳入统一管理时加 `--adopt`，它会用 `brew install --cask --force` 接管一次（只替换 App 本体，`~/Library` 里的数据和登录状态不动），之后自动跟随升级。
- **版本号不跨厂商可比**：例如飞书的 `CFBundleShortVersionString` 是 `147.0.7727.149`，而 cask 版本是 `8.4.7,...`。所以脚本不对手动安装的 App 自作主张判断新旧，只把两个版本号都显示出来。
- `--dry-run` 会走同一套判断，只打印「将安装 / 将升级 / 已是最新 / 手动安装」，不改系统。



---

## 清单（44 项）

### 基础工具链（8）

| Key | 工具 | 类型 |
|---|---|---|
| `node` | Node.js / npm / npx | formula |
| `git` | Git | formula |
| `gh` | GitHub CLI | formula |
| `uv` | uv / uvx（Python 工具链） | formula |
| `bun` | Bun / bunx | formula |
| `jq` | jq（JSON 处理） | formula |
| `ripgrep` | ripgrep（`rg`，代码搜索） | formula |
| `fd` | fd（快速文件查找） | formula |

### 桌面应用（16）

| Key | 工具 | 说明 |
|---|---|---|
| `chatgpt` | ChatGPT 桌面版 | |
| `claude` | Claude 桌面版 | 下载源被墙时需代理，见 FAQ |
| `antigravity` | Google Antigravity 2 | Agent 调度台 |
| `antigravity-ide` | Google Antigravity IDE | 只要一个可 `--skip antigravity-ide` |
| `workbuddy-cn` | WorkBuddy 国内版 | 国际版 id 为 `workbuddy-ai` |
| `trae-cn` | Trae CN 国内版 | 国际版 id 为 `trae` |
| `qoder` | Qoder 国际版 | 国内版 Qoder CN 用应用内更新，或 `--skip qoder` |
| `doubao` | 豆包 | |
| `clash-verge-rev` | Clash Verge Rev | |
| `cc-switch` | CC Switch | Claude / Codex 配置切换 |
| `feishu` | 飞书 | |
| `google-chrome` | Google Chrome | |
| `cherry-studio` | Cherry Studio | |
| `deepseek-harness` | DeepSeek Harness 桌面版 | |
| `github` | GitHub Desktop | |
| `hermes-desktop` | Hermes Agent 桌面版 | |

### 命令行工具（6）

| Key | 命令 | 工具 |
|---|---|---|
| `codex` | `codex` | OpenAI Codex CLI |
| `claude-code` | `claude` | Claude Code CLI（cask 失败自动转 npm） |
| `grok` | `grok` | xAI 官方 Grok Build |
| `agy` | `agy` | Antigravity CLI |
| `qwen` | `qwen` | Qwen Code CLI |
| `hermes-cli` | `hermes` | Hermes Agent CLI |

### 推荐补充（14，默认安装）

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
| `visual-studio-code` | VS Code | 通用编辑器 |
| `zed` | Zed | 高性能编辑器 |
| `ghostty` | Ghostty | 原生 GPU 终端 |
| `orbstack` | OrbStack | Docker 替代 |
| `chatbox` | Chatbox | 多模型聊天客户端 |

不要推荐项：加 `--no-recommend`，只装前 30 项。

---

## 参数说明

| 参数 | 作用 |
|---|---|
| `--only LIST` | 只处理指定条目或分组，逗号分隔：`--only codex,claude-code` / `--only apps,cli` |
| `--skip LIST` | 跳过指定条目或分组：`--skip qoder,antigravity-ide` |
| `--no-recommend` | 不安装 `recommend` 分组（推荐补充） |
| `--no-claude` | 跳过 Claude 桌面版 + Claude Code（网络受限时用，只影响安装/更新，不卸载） |
| `--adopt` | 接管 `/Applications` 里手动安装的同名 App，交给 Homebrew 管理（默认只检测、跳过） |
| `--no-adopt` | 显式保持「不接管」（默认行为） |
| `--dry-run`, `-n` | 只预览，不改系统 |
| `--list`, `-l` | 列出全部条目和 Key |
| `--status` | 以 **JSON** 输出全部条目的安装状态（给脚本 / AI 读取） |
| `--no-update` | 跳过 `brew update`，更快（可能不是最新索引） |
| `--no-greedy` | 不强制升级自带自动更新的 App，更快 |
| `--cleanup` | 结束后执行 `brew cleanup --prune=7` |
| `--cn` | Homebrew 使用清华 TUNA 镜像 |
| `--proxy URL` | 本次运行使用 HTTP/HTTPS 代理（Homebrew、curl、npm 都走） |
| `--help`, `-h` | 帮助 |
| `--version` | 版本号 |

退出码：`0` 全部成功；`1` 有失败项；`2` 参数错误；`130` 手动中断。

---

## 典型场景

```bash
# 全量安装 / 更新（含推荐项）
./ai-stack.sh

# 只装点名的，不要推荐补充
./ai-stack.sh --no-recommend

# 只更新某几个
./ai-stack.sh --only codex,claude-code,cherry-studio

# 按分组更新
./ai-stack.sh --only apps
./ai-stack.sh --only cli

# 跳过大件 / 某些 App
./ai-stack.sh --skip qoder,lm-studio

# 网络受限：跳过两个 Claude + 走镜像
./ai-stack.sh --cn --no-claude

# 只检查，不动系统
./ai-stack.sh --dry-run

# 看某台机器现在装了什么（JSON）
./ai-stack.sh --status

# 有代理时补装 Claude 桌面版
./ai-stack.sh --only claude --proxy http://127.0.0.1:7890
```

### 定时自动更新（可选）

`~/Library/LaunchAgents/com.local.ai-stack.plist`：

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
# 停止：launchctl unload ~/Library/LaunchAgents/com.local.ai-stack.plist
```

---

## 给 AI 助手用

这个仓库是给 AI 直接操作设计的，不只是给人看。

### 1. `AGENTS.md`

仓库根目录的 [`AGENTS.md`](AGENTS.md) 是给 AI 编码助手的操作手册（Claude Code、Codex、Cursor、Gemini CLI 等都能读）。里面写了命令契约、典型任务、安全边界。新机器上把仓库 clone 下来，AI 就能按说明直接干活。

### 2. 机器可读状态：`--status`

AI 不需要解析中文表格，直接读 JSON：

```bash
./ai-stack.sh --status
```

```json
{
  "script": "ai-stack",
  "version": "1.2.0",
  "macos": "26.6.2",
  "arch": "arm64",
  "host": "MacBook-Air.local",
  "homebrew_installed": true,
  "filters": { "only": "", "skip": "", "no_recommend": 0, "no_claude": 0 },
  "items": [
    {
      "key": "claude-code",
      "group": "cli",
      "label": "Claude Code CLI（claude）",
      "type": "cask",
      "id": "claude-code",
      "fallback": "npm:@anthropic-ai/claude-code",
      "note": "",
      "selected": true,
      "installed": true,
      "via": "npm",
      "version": "2.1.318"
    }
  ]
}
```

字段说明：

| 字段 | 含义 |
|---|---|
| `key` | 条目标识，用于 `--only` / `--skip` |
| `group` | `base` / `apps` / `cli` / `recommend` |
| `type` / `id` | 安装方式与 Homebrew/npm 标识 |
| `fallback` | 主来源失败时的备用来源，如 `npm:@anthropic-ai/claude-code` |
| `selected` | 本次参数下是否会被处理 |
| `installed` | 是否已安装（brew / npm 兜底 / 手动安装的 App 都算） |
| `via` | 实际来源：`cask` / `formula` / `npm` / `app`（手动安装，未被 brew 管理） |
| `version` | 已安装版本，未装为空 |

### 3. 直接对 AI 说的话

```
先运行 ./ai-stack.sh --status 看现状，然后只安装缺少的项，最后再跑一次 --status 确认。
```

```
把 ai-stack.sh 里 cherry-studio 和 zed 更新到最新，其他不要动。
```

```
按 AGENTS.md 的说明，在这台新 Mac 上初始化整套 AI 工具，跳过 Claude。
```

### 4. 写入你的 AI 配置

- Claude Code / Codex：直接把仓库 `clone` 到工作目录，它们会自动读 `AGENTS.md`。
- Gemini CLI：仓库里另有 `GEMINI.md` 指向同一份说明。
- 其他工具：把 `AGENTS.md` 内容贴进系统提示词即可。

---

## 常见问题

### 1. 某个 App 升级失败？

按顺序排查：

1. **App 正在运行** → 退出后再跑 `./ai-stack.sh --only <key>`；
2. **网络超时** → 加 `--proxy` 或换时间重试；
3. **cask 改名/下架** → 看日志里的 brew 报错。

脚本不会因为一项失败中断，日志在 `~/Library/Logs/ai-stack/latest.log`。

### 2. Clash Verge 提示「正在临时目录运行 / 配置无法保存」

这是 macOS 的 **App Translocation（应用转译）**：带隔离属性的 App 启动时会被系统放到 `/private/var/folders/.../AppTranslocation/...` 只读路径运行。不是脚本装错了位置，软件本体在 `/Applications`。

Clash Verge 自带的 launchGuard 检测到只读路径就会弹提醒并拒绝写配置。两种修法：

```bash
# 修法 A：重新安装（推荐，会拿到最新版并换掉带隔离属性的包）
brew reinstall --cask --force clash-verge-rev

# 修法 B：只去掉隔离属性（在「终端」里执行；系统可能要求授予 App 管理权限）
xattr -dr com.apple.quarantine "/Applications/Clash Verge.app"
open "/Applications/Clash Verge.app"
```

修好后确认进程路径是 `/Applications/Clash Verge.app/...`，而不是 `AppTranslocation`：

```bash
ps -Ao pid,command | grep "Clash Verge.app/Contents/MacOS"
```

### 3. Claude 下载一直超时？

`downloads.claude.ai`（35.190.46.17）在部分网络下直接 TCP 超时，属于网络层封锁：

- **Claude Code CLI**：脚本会自动改用 npm，无需代理；
- **Claude 桌面版**：开代理后 `./ai-stack.sh --only claude --proxy http://127.0.0.1:7890`，或用 Mac App Store 版；
- 自检：`curl -I --connect-timeout 8 https://downloads.claude.ai/`，超时就是网络问题。

### 4. 我已经手动装过某个 App，会被覆盖吗？

**不会。** 脚本会先查 `/Applications` 和 `~/Applications`：如果找到同名 `.app`、但它不是 Homebrew 装的，就标为 `手动安装，已跳过`，并打印：

```
已手动安装：/Applications/Qoder.app（版本 0.5.2）
Homebrew 最新：0.5.6
未被 Homebrew 管理，本次跳过；想让它自动更新请加 --adopt。
```

想让它以后自动跟随升级，加 `--adopt` 接管一次：

```bash
./ai-stack.sh --adopt --only qoder
```

接管时用 `brew install --cask --force`，替换的是 `/Applications` 里的 App 本体；登录状态、配置、聊天记录在 `~/Library`，不受影响。

注意：手动安装的 App 版本号格式不一定和 cask 一致（飞书 cask 是 `8.4.7,...`，App 内是 `147.0.7727.149`），所以脚本只**展示**两个版本号，不自动判断新旧。


### 5. Qoder / Trae / WorkBuddy 国际版和国内版

- 默认国内版：`trae-cn`、`workbuddy-cn`；Qoder 的官方 cask 是国际版。
- 国内版 Qoder CN 一般由 App 自己更新，可 `--skip qoder`。
- 想换国际版：编辑 `ai-stack.sh` 里的 cask id（如 `trae-cn` → `trae`）。

### 6. 为什么 Claude Code 显示 `via: npm`？

它的 Homebrew 包和 npm 包是同一个 CLI。脚本优先用 cask，下载失败时自动转 npm；之后检测到已有 npm 版本就直接走 npm 更新，省掉每次 75 秒的下载超时。

### 7. 需要一直联网吗？

只有安装/升级时需要。已装好的工具离线可用。

### 8. 支持 Intel Mac 吗？

支持。脚本按 `/opt/homebrew`（Apple Silicon）和 `/usr/local`（Intel）自动选择 Homebrew 路径，清单里的 cask 都是双架构或官方 universal 包。

### 9. 日志在哪？

```bash
open ~/Library/Logs/ai-stack
```

`run-YYYYMMDD-HHMMSS.log` 每次一份，`latest.log` 指向最近一次。

---

## 卸载 / 定制

```bash
brew uninstall --cask <token>     # 卸载 GUI（如 cherry-studio）
brew uninstall <formula>          # 卸载 CLI（如 qwen-code）
npm uninstall -g @anthropic-ai/claude-code   # 卸载 npm 装的 Claude Code
```

加工具：编辑 `ai-stack.sh` 里的 `add_item` 段。

```bash
add_item apps my-app "我的工具" cask my-app
add_item cli  my-cli "我的 CLI" formula my-cli
add_item cli  my-npm "npm 版 CLI" npm @scope/my-cli
# 第 6 个参数是备注，第 7 个是备用来源（可选）
add_item cli  my-cli2 "带兜底的 CLI" cask my-cli2 "" npm:my-cli2
```

---

## 开发

```bash
bash -n ai-stack.sh                  # 语法检查
./ai-stack.sh --list                 # 清单
./ai-stack.sh --status | python3 -m json.tool   # JSON 合法性
./ai-stack.sh --dry-run              # 全量预演（不改系统）
```

约定：

- 只用 macOS 自带 **Bash 3.2** 的语法，不依赖 zsh / bash 4+；
- 中文与 `$变量` 相邻时一律写 `${变量}`，避免 3.2 的多字节解析 bug；
- 安装逻辑只依赖 Homebrew Cask / Formula / npm 三种来源；
- 新增条目要补 `--list` 能显示、`--status` 能正确报告 `installed`。

---

## License

[MIT](LICENSE)
