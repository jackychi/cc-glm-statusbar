#!/bin/bash
# cc-glm-statusbar installer — 把 z.ai / 智谱 GLM 用量状态栏 + 查询 skill 装进 Claude Code
# 用法: bash install.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🤖 cc-glm-statusbar — 安装到 Claude Code"
echo "=========================================="

# 1. 安装 skill（/zai-usage 用量查询）
SKILL_DIR="$HOME/.claude/skills/zai-usage"
mkdir -p "$SKILL_DIR"
cp "$SCRIPT_DIR/SKILL.md" "$SKILL_DIR/SKILL.md"
echo "✅ Skill → $SKILL_DIR/SKILL.md"

# 2. 安装状态栏脚本
cp "$SCRIPT_DIR/cc-glm-statusbar.sh" "$HOME/.claude/cc-glm-statusbar.sh"
chmod +x "$HOME/.claude/cc-glm-statusbar.sh"
echo "✅ 状态栏脚本 → ~/.claude/cc-glm-statusbar.sh"

# 3. 配置 settings.json 的 statusLine（保留其他设置不变）
SETTINGS="$HOME/.claude/settings.json"
if [ ! -f "$SETTINGS" ]; then
    echo '{}' > "$SETTINGS"
fi

python3 -c "
import json
with open('$SETTINGS') as f:
    d = json.load(f)
d['statusLine'] = {
    'type': 'command',
    'command': 'bash ~/.claude/cc-glm-statusbar.sh',
    'refreshInterval': 120
}
with open('$SETTINGS', 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.write('\n')
print('✅ settings.json 已更新 statusLine 配置')
"

echo ""
echo "📋 需要确认的环境变量（写入 ~/.zshrc 后 source 生效）:"
echo "   ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic"
echo "                       # 国内版用 https://open.bigmodel.cn/api/anthropic"
echo "   ANTHROPIC_AUTH_TOKEN=<你的智谱 API Key>   # https://z.ai/manage-apikey 获取"
echo ""
echo "🎉 安装完成！下次启动 Claude Code 即可看到状态栏，并可用 /zai-usage 查询用量"
