# AGENTS.md — AI 助手操作手册

本文件面向 **AI 编码助手**（Claude Code、Codex、Cursor、Copilot CLI、Gemini CLI、Qwen Code、Aider 等）。

目标：让 AI 在不读源码的情况下，也能正确判断这台 Mac 装了什么、该跑什么命令、哪些操作危险。

> 项目主页与人类阅读文档见 [`README.md`](README.md)。

---

## 0. 一句话上手

```bash
./ai-stack.sh            # 装/更新全部（含推荐项）
./ai-stack.sh --status   # 读取机器可读状态（JSON）
```

**先 `--status`，再决定动作。**

---

## 1. 核心契约

| 项目 | 值 |
|---|---|
| 入口脚本 | `ai-stack.sh`（Bash 3.2 兼容，macOS 自带 bash 可跑） |
| 交互入口 | `一键安装更新AI工具.command`（双击；等价于无参数运行） |
| 状态命令 | `./ai-stack.sh --status` → **纯 JSON 输出到 stdout** |
| 清单命令 | `./ai-stack.sh --list` → 表格（人类看） |
| 预览命令 | `./ai-stack.sh --dry-run` → 不改系统 |
| 日志 | `~/Library/Logs/ai-stack/latest.log`（每次另有 `run-*.log`） |

退出码：

| 码 | 含义 | AI 应对 |
|---|---|---|
| `0` | 全部成功 | 继续 |
| `1` | 有失败项 | 读日志 → 修 → 只重跑失败项 |
| `2` | 参数错误 | 修命令，不要重试原样命令 |
| `130` | 用户中断 | 不自动重试 |

---

## 2. `--status` JSON Schema

顶层：

```json
{
  "script": "ai-stack",
  "version": "1.4.0",
  "macos": "26.6.2",
  "arch": "arm64",
  "host": "MacBook-Air.local",
  "homebrew_installed": true,
  "filters": { "only": "", "skip": "", "no_recommend": 0, "no_claude": 0 },
  "items": [ ... ]
}
```

`items[]`（每项一个工具）：

| 字段 | 类型 | 说明 |
|---|---|---|
| `key` | string | **唯一标识，用于 `--only` / `--skip`** |
| `group` | string | `base` \| `apps` \| `cli` \| `recommend` |
| `label` | string | 中文名称（仅展示，勿用于匹配） |
| `type` | string | `formula` \| `cask` \| `npm` |
| `id` | string | Homebrew token 或 npm 包名 |
| `fallback` | string | 备用来源，当前仅 `npm:<包名>` 或空 |
| `note` | string | 备注（有时含「替代方案」） |
| `selected` | boolean | 本次参数下是否会被处理 |
| `installed` | boolean | 是否已安装（含 fallback 与 /Applications 手动安装） |
| `via` | string | 实际来源：`formula` / `cask` / `npm` / `app`（手动装的 App）/ `bin`（手动装的 CLI）/ `""` |
| `version` | string | 已装版本；未装为 `""` |

**判定规则（重要）：**

- 想知道「还缺什么」→ 过滤 `installed == false`。
- 想知道「哪些会被这次运行处理」→ 过滤 `selected == true`。
- `installed == true && via` 为 `"app"` 或 `"bin"` 时，表示是手动安装（brew 不认识）：AI 不应直接删除或重装；需要统一管理时先征得用户同意，再用 `--adopt`。
- `installed == true && via == "npm"` 说明该 CLI 走的是备用来源，**不要再让它走 cask**，否则会重复超时。
- 不要根据 `label` 或 `note` 做逻辑判断，只认 `key` / `id`。

---

## 3. 命令参考（AI 只该用这些）

```bash
# 只读（安全，随时可跑）
./ai-stack.sh --status
./ai-stack.sh --list
./ai-stack.sh --dry-run
./ai-stack.sh --version

# 安装 / 更新
./ai-stack.sh                       # 全部 + 推荐项
./ai-stack.sh --no-recommend        # 不处理 recommend，只装核心 32 项
./ai-stack.sh --only <keys>         # 逗号分隔，支持分组名
./ai-stack.sh --skip <keys>         # 逗号分隔，支持分组名
./ai-stack.sh --only apps           # 只处理 GUI
./ai-stack.sh --only cli            # 只处理命令行
./ai-stack.sh --only base           # 只处理基础工具链

# 网络相关
./ai-stack.sh --cn                  # Homebrew 走清华 TUNA 镜像
./ai-stack.sh --proxy http://127.0.0.1:7890
./ai-stack.sh --no-claude           # 跳过 Claude 桌面版 + Claude Code（不卸载）
./ai-stack.sh --adopt               # 接管 /Applications 里手动安装的同名 App
./ai-stack.sh --no-update           # 跳过 brew update，更快
./ai-stack.sh --no-greedy           # 不强制升级自带自动更新的 App

# 维护
./ai-stack.sh --cleanup             # 结束后 brew cleanup --prune=7
```

`--only` / `--skip` 接受 **key 或 group 名**，可混用：`--only cli,cherry-studio`。

默认不传筛选参数时会处理全部清单（当前 46 项）。
`--only` 是白名单：只处理指定 key/分组；`--skip` 是黑名单：处理全部但排除指定 key/分组。
如果同时使用，先按 `--only` 选中，再按 `--skip` 排除。

---

## 4. 标准工作流

### A. 「这台机器现在是什么状态？」

```bash
./ai-stack.sh --status > /tmp/ai-stack-status.json
python3 - <<'PY'
import json
d = json.load(open('/tmp/ai-stack-status.json'))
missing = [i['key'] for i in d['items'] if not i['installed']]
print('已装:', sum(i['installed'] for i in d['items']), '/', len(d['items']))
print('缺失:', missing)
PY
```

### B. 「把缺的补齐」

```bash
# 1. 查缺失
./ai-stack.sh --status | python3 -c 'import json,sys; d=json.load(sys.stdin); print(",".join(i["key"] for i in d["items"] if not i["installed"] and i["selected"]))'
# 2. 只装这些（把上一步输出粘进去）
./ai-stack.sh --only k1,k2,k3
# 3. 复核
./ai-stack.sh --status
```

若缺失列表含 `claude` 且网络受限，先加 `--no-claude` 或 `--proxy`。

### C. 「全部升级到最新」

```bash
./ai-stack.sh --no-recommend      # 或去掉 --no-recommend 连推荐项一起
```

### C2. 更新判定（回答「会不会重复装」）

每项都会先判断，再决定动作：

| 状态 | 动作 |
|---|---|
| brew 里查不到 | 安装 |
| 已装且 `brew outdated` 名单里有它 | `brew upgrade` |
| 已装且不在名单里 | **跳过**（`已是最新`） |
| npm 类条目 | 先 `npm view <pkg> version`，相同则跳过 |

因此重复运行是安全的、幂等的：只有「缺的」和「旧的」会被改动。

两个会让判断失准的开关：`--no-update`（不刷新索引）和 `--no-greedy`（自带自动更新的 App 不参与判断）。

### D. 「新机器初始化」

```bash
./ai-stack.sh --cn --no-claude
```

需要 TTY 输密码：**不要让用户用 `curl ... | bash`**，先下载再执行。

### E. 「某个 App 升级失败」

```bash
tail -n 80 ~/Library/Logs/ai-stack/latest.log     # 看真实报错
pgrep -fl "<AppName>"                             # 是否正在运行
./ai-stack.sh --only <key>                        # 单点重试
```

常见原因与处置：

| 报错关键词 | 原因 | 处置 |
|---|---|---|
| `is still running` / `did not quit` | App 在运行 | 让用户退出 App，再单点重跑 |
| `timed out` / `Could not resolve host` | 网络 | `--proxy` 或稍后重试 |
| `Cask ... is unavailable` | cask 下架/改名 | 查 `brew search`，改脚本里的 `id` |
| `Permission denied` / `Operation not permitted` | TCC 权限 | 让用户在「系统设置 → 隐私与安全性」授权终端 |

---

## 5. 安全边界（AI 必须遵守）

### 可以自动做

- 运行 `--status` / `--list` / `--dry-run`
- 运行 `--only` / `--skip` 指定的安装
- 读 `~/Library/Logs/ai-stack/`
- 为诊断运行只读命令：`brew list`、`brew info`、`pgrep`、`xattr -l`、`codesign -dv`

### 必须先问用户

- 运行**全量** `./ai-stack.sh`（会改动几十个 App）
- 用 `--adopt` 接管/覆盖用户手动安装的 App
- `brew uninstall` / `npm uninstall -g` / 删除 `~/Library` 下的数据
- 修改 `/etc/hosts`、系统代理、DNS
- `sudo` 开头的一切
- `rm -rf`、`--force` 覆盖用户已有数据
- 修改 `ai-stack.sh` 的清单（增删条目）

### 绝对不要做

- `curl ... | bash`（首次装 Homebrew 需要 TTY，会失败且难以诊断）
- 为了让命令「通过」而删掉用户的文件或配置
- 把用户的 token / 密码 / 私钥写进仓库、日志、提交
- 在 `--status` 输出里塞额外文本（会破坏 JSON）

---

## 6. 常见判断

**Q: `installed: false` 但用户说「我装过」？**
A: 先看 `via`。若为 `"app"`，说明脚本已在 `/Applications` 或 `~/Applications` 里找到同名 App（手动安装、未被 brew 管理），这是正常状态，执行安装时会**跳过并提示**。若 `installed` 仍是 `false`，可能装在非标准路径或其他用户目录，此时 `--only <key>` 会用 `--force` 安装一份到 `/Applications`。

**Q: 手动安装的 App 怎么让它自动更新？**
A: 默认不接管（避免覆盖用户手动装的版本）。征得用户同意后执行 `./ai-stack.sh --adopt --only <key>`，接管一次后 `via` 会变成 `cask`，以后正常跟随升级。

**Q: `via: "npm"` 是什么？**
A: 该 CLI 的主来源（cask）不可达，脚本走了 `fallback`。这是**正常状态**，不要「修」它。强行改回 cask 只会再次超时。

**Q: `homebrew_installed: false` 但想跑 `--status`？**
A: 可以。此时所有 `installed` 都是 `false`，`via`/`version` 为空 —— 因为无法检测。先跑一次安装让 Homebrew 就位。

**Q: 用户问「Clash Verge 提示临时目录运行」？**
A: macOS App Translocation。不是装错位置。处置：`brew reinstall --cask --force clash-verge-rev`，然后确认进程路径不含 `AppTranslocation`。

**Q: 用户在中国大陆、Google 服务全超时？**
A: Google IP 段被 TCP 封锁，改 hosts 无效，只能代理。GitHub 是间歇性：`api.github.com` / `raw.githubusercontent.com` 通常可达，`github.com` 可能需要 hosts 固定 IP。

---

## 7. 给 AI 的现成提示词

用户可以直接对 AI 说：

```
按 AGENTS.md 操作：先跑 ./ai-stack.sh --status，列出缺失项，
只安装缺失的（网络受限加 --cn --no-claude），装完再跑一次 --status 复核。
不要卸载任何东西，失败就只重试失败项。
```

```
读 AGENTS.md，把 ai-stack.sh 里的 cherry-studio 和 zed 更新到最新，
其他条目不要动，完成后报告版本变化。
```

---

## 8. 修改脚本时

```bash
bash -n ai-stack.sh                              # 必须通过
./ai-stack.sh --list                             # 新条目应出现
./ai-stack.sh --status | python3 -m json.tool    # JSON 必须合法
./ai-stack.sh --dry-run                          # 全量预演
```

约定：

- 只用 **Bash 3.2** 语法（macOS 自带），不依赖 bash 4+
- 中文字符紧邻变量时写 `${var}`，不要写 `$var`
- 新增条目用 `add_item <group> <key> <label> <type> <id> [note] [fallback]`
- 新增条目后确认 `--list` 显示、`--status` 的 `installed` 判定正确

---

## 9. 仓库结构

```
ai-stack.sh                     主脚本（唯一逻辑源）
一键安装更新AI工具.command        双击入口，透传所有参数
README.md                       人类文档
AGENTS.md                       本文件（AI 操作手册）
GEMINI.md                       指向 AGENTS.md
LICENSE                         MIT
```

`ai-stack.sh` 是**唯一事实来源**。不要在别处复制逻辑；改就改这一份。
