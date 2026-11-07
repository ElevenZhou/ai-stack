# GEMINI.md

本项目的 AI 助手操作说明统一维护在 [`AGENTS.md`](AGENTS.md)。

请直接阅读并遵循 `AGENTS.md`，其中包含：

- `ai-stack.sh` 的命令契约与退出码
- `--status` JSON Schema 与字段判定规则
- 标准工作流（查状态 → 补缺失 → 复核）
- 安全边界（哪些能自动做，哪些必须先问用户）
- 常见故障判断

速查：

```bash
./ai-stack.sh --status    # 机器可读状态（JSON）
./ai-stack.sh --list      # 清单
./ai-stack.sh --dry-run   # 预览，不改系统
./ai-stack.sh --only <keys>
./ai-stack.sh --cn --no-claude
```

人类阅读文档见 [`README.md`](README.md)。
