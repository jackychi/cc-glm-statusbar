# cc-glm-statusbar

给 **z.ai / 智谱 GLM Coding Plan** 用户的 Claude Code 状态栏。把模型、目录、context 用量和 GLM 套餐余量放在同一屏，不用切到控制台查额度。

## 安装完之后长这样

状态栏两行，第一行是 Claude Code 会话信息，任何用户都通用；第二行是 GLM 用量。

```
[claude-sonnet-4-6] 📁 cc-glm-statusbar 🌿 main* | ████░░░░░░ 35% ctx | 💾 r15.2k w2.1k
🤖 GLM Pro | 5h ██░░░ 35% · W █░░░░ 7% · MCP 8/1000
```

| 区块 | 含义 |
|------|------|
| `[模型] 📁 目录` | 当前模型与工作目录名 |
| 🌿 `分支*` | Git 分支，`*` 表示有未提交改动（按会话缓存 5 秒） |
| `█░ 35% ctx` | Context 窗口已用比例，绿/黄/红 三档 |
| 💾 `r15.2k w2.1k` | 最近一次调用的 cache 读取 / 写入 token（首次调用前不显示） |
| 🤖 `GLM Pro` | 套餐等级，来自 z.ai 用量接口 |
| `5h ██░░░ 35%` | 5 小时滑动窗口 Token 额度 |
| `W █░░░░ 7%` | 每周 Token 额度 |
| `MCP 8/1000` | 本月 MCP 工具调用 / 总额度 |

> 5 小时窗口按滑动窗口重置，每周额度按自然周（周一起算），MCP 按自然月重置。

## 谁可以用

直连 z.ai 或 open.bigmodel.cn 使用 Claude Code 的朋友——也就是把 `ANTHROPIC_BASE_URL` 指向智谱、用 GLM Coding Plan 的那种用法。状态栏复用 Claude Code 本身的鉴权（`ANTHROPIC_AUTH_TOKEN`），不依赖任何第三方服务的密钥。

## 前置条件

- Claude Code CLI
- `curl`、`jq`（macOS 用 `brew install jq`）
- 已配置好 z.ai 作为 Claude Code 后端，能正常对话（说明环境变量已就位）

## 安装

一键安装：

```bash
git clone https://github.com/jackychi/cc-glm-statusbar.git
cd cc-glm-statusbar
cd cc-glm-statusbar
bash install.sh
```

脚本会做三件事：把 `SKILL.md` 放到 `~/.claude/skills/zai-usage/`、把状态栏脚本放到 `~/.claude/cc-glm-statusbar.sh`、并在 `~/.claude/settings.json` 写入 `statusLine` 配置。重启 Claude Code 即可生效。

手动安装（不想跑脚本）：把两个文件复制到 `~/.claude/` 下对应位置，再在 `settings.json` 里加：

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/cc-glm-statusbar.sh",
    "refreshInterval": 120
  }
}
```

## 环境变量

写进 `~/.zshrc`，`source` 后生效。

```bash
# 国际版
export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
# 国内版
# export ANTHROPIC_BASE_URL="https://open.bigmodel.cn/api/anthropic"

export ANTHROPIC_AUTH_TOKEN="<你的智谱 API Key>"   # https://z.ai/manage-apikey 获取
```

脚本从 `ANTHROPIC_BASE_URL` 推断走国际版还是国内版，用 `ANTHROPIC_AUTH_TOKEN`（或 `ANTHROPIC_API_KEY`）调用用量接口。两者都没有时，第二行会提示去配置，不会影响第一行。

## 模型用量查询 skill

`SKILL.md` 注册的是 `/zai-usage` 这个 skill——在对话里输入 `/zai-usage`，会调同一个用量接口，返回一张带进度条的完整用量表（5 小时 / 每周 / MCP 明细）。状态栏看个大概，想看细节就用 skill。

## 项目文件

```
cc-glm-statusbar/
├── cc-glm-statusbar.sh   # 状态栏脚本（核心）
├── SKILL.md              # /zai-usage 用量查询 skill
├── install.sh            # 一键安装
└── README.md
```

