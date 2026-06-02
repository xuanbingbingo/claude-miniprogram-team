#!/usr/bin/env bash
#
# 微信小程序开发团队 —— 一键安装脚本
#
# 自动检测你是否已经装过「标准开发团队」：
#   - 没装过 → 安装全部 16 个 agent（小程序团队自包含，开箱即用）
#   - 已装过 → 只补 3 个小程序专属 agent，共用 agent 不覆盖（保留你可能改过的版本）
#
# 用法：
#   bash install.sh            # 智能安装（推荐）
#   bash install.sh --force    # 强制覆盖所有同名 agent
#   bash install.sh --uninstall
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DST="$HOME/.claude/agents"
SKILL_DST="$HOME/.claude/skills/miniprogram-team"

# 小程序专属 agent（永远安装）
OWN_AGENTS=(
  miniprogram-orchestrator
  miniprogram-ui-designer
  miniprogram-developer
)

# 与标准团队共用的 agent（已存在则默认跳过，不覆盖）
SHARED_AGENTS=(
  product-manager software-architect database-optimizer backend-architect
  devops-automator testing-evidence-collector security-engineer
  code-reviewer reality-checker technical-writer
  app-deploy-agent infra-bootstrap-agent deploy-yaml-schema
)

c_green() { printf '\033[32m%s\033[0m\n' "$1"; }
c_yellow() { printf '\033[33m%s\033[0m\n' "$1"; }
c_blue() { printf '\033[36m%s\033[0m\n' "$1"; }

# ---------- 卸载 ----------
if [[ "${1:-}" == "--uninstall" ]]; then
  c_yellow "卸载小程序团队..."
  for a in "${OWN_AGENTS[@]}"; do
    rm -f "$AGENTS_DST/$a.md" && echo "  删除 $a.md"
  done
  rm -rf "$SKILL_DST" && echo "  删除 skill"
  c_yellow "注意：共用 agent（product-manager 等）未删除，可能仍被标准团队使用。"
  c_green "卸载完成。"
  exit 0
fi

FORCE=false
[[ "${1:-}" == "--force" ]] && FORCE=true

mkdir -p "$AGENTS_DST" "$SKILL_DST"

# ---------- 检测是否已有标准团队 ----------
HAS_STANDARD=false
if [[ -f "$AGENTS_DST/software-architect.md" && -f "$AGENTS_DST/product-manager.md" ]]; then
  HAS_STANDARD=true
fi

echo ""
c_blue "=== 微信小程序开发团队 安装程序 ==="
if $HAS_STANDARD; then
  c_yellow "检测到你已安装标准团队的共用 agent。"
  echo "→ 只安装 3 个小程序专属 agent，共用 agent 保持你现有版本不动。"
else
  echo "→ 未检测到标准团队，安装完整套件（16 个 agent，开箱即用）。"
fi
echo ""

installed=0; skipped=0; overwritten=0

install_one() {
  local name="$1" src="$SCRIPT_DIR/agents/$1.md" dst="$AGENTS_DST/$1.md"
  if [[ -f "$dst" && "$FORCE" == false ]]; then
    echo "  跳过（已存在）：$name"; ((skipped+=1)); return
  fi
  if [[ -f "$dst" ]]; then ((overwritten+=1)); else ((installed+=1)); fi
  cp "$src" "$dst"
  echo "  安装：$name"
}

echo "[ 小程序专属 agent ]"
for a in "${OWN_AGENTS[@]}"; do install_one "$a"; done

echo ""
echo "[ 共用 agent ]"
for a in "${SHARED_AGENTS[@]}"; do install_one "$a"; done

echo ""
echo "[ 总指挥剧本 skill ]"
cp "$SCRIPT_DIR/skills/miniprogram-team/SKILL.md" "$SKILL_DST/SKILL.md"
echo "  安装：miniprogram-team/SKILL.md"

echo ""
c_green "=== 安装完成 ==="
echo "  新增 $installed 个 / 跳过 $skipped 个 / 覆盖 $overwritten 个 agent + 1 个 skill"
echo ""
echo "验证："
echo "  ls $AGENTS_DST/ | grep miniprogram"
echo "  ls $SKILL_DST/SKILL.md"
echo ""
echo "重启 Claude Code 后，新开对话输入「用小程序团队开发一个 XXX」即可触发。"
