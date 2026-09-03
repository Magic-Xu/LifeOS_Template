#!/bin/zsh
set -euo pipefail

LIFEOS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIFEOS_TEMPLATE_DIR="$LIFEOS_ROOT/99-系统/模板"
LIFEOS_TODAY="$(date '+%Y-%m-%d')"
LIFEOS_CODEX_SKILLS_DIR="${CODEX_HOME:-$HOME/.codex}/skills"
LIFEOS_CODEX_SKILL_TARGET="$LIFEOS_CODEX_SKILLS_DIR/lifeos"
LIFEOS_CODEX_SKILL_SOURCE="$LIFEOS_ROOT/.agents/skills/lifeos"

if ! git -C "$LIFEOS_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  print -u2 "当前目录不是 Git 仓库：$LIFEOS_ROOT"
  exit 1
fi

copy_if_missing() {
  local LIFEOS_SOURCE="$1"
  local LIFEOS_TARGET="$2"

  mkdir -p "$(dirname "$LIFEOS_TARGET")"
  if [[ -e "$LIFEOS_TARGET" ]]; then
    print "已存在，跳过：$LIFEOS_TARGET"
  else
    sed "s/{{date}}/$LIFEOS_TODAY/g" "$LIFEOS_SOURCE" > "$LIFEOS_TARGET"
    print "已创建：$LIFEOS_TARGET"
  fi
}

git -C "$LIFEOS_ROOT" config core.hooksPath .githooks

copy_if_missing "$LIFEOS_TEMPLATE_DIR/我的概况模板.md" "$LIFEOS_ROOT/99-系统/AI上下文/我的概况.md"
copy_if_missing "$LIFEOS_TEMPLATE_DIR/当前目标模板.md" "$LIFEOS_ROOT/99-系统/AI上下文/当前目标.md"
copy_if_missing "$LIFEOS_TEMPLATE_DIR/重要偏好与边界模板.md" "$LIFEOS_ROOT/99-系统/AI上下文/重要偏好与边界.md"
copy_if_missing "$LIFEOS_TEMPLATE_DIR/待确认与冲突模板.md" "$LIFEOS_ROOT/99-系统/AI上下文/待确认与冲突.md"
copy_if_missing "$LIFEOS_TEMPLATE_DIR/系统状态模板.md" "$LIFEOS_ROOT/99-系统/AI上下文/系统状态.md"
copy_if_missing "$LIFEOS_TEMPLATE_DIR/经历索引模板.md" "$LIFEOS_ROOT/10-人生经历/经历索引.md"
copy_if_missing "$LIFEOS_TEMPLATE_DIR/人物索引模板.md" "$LIFEOS_ROOT/20-人物关系/人物索引.md"
copy_if_missing "$LIFEOS_TEMPLATE_DIR/健康总览模板.md" "$LIFEOS_ROOT/30-健康/健康总览.md"
copy_if_missing "$LIFEOS_TEMPLATE_DIR/财务总览模板.md" "$LIFEOS_ROOT/40-财务/财务总览.md"
copy_if_missing "$LIFEOS_TEMPLATE_DIR/兴趣偏好模板.md" "$LIFEOS_ROOT/50-兴趣与生活/兴趣偏好.md"

mkdir -p "$LIFEOS_CODEX_SKILLS_DIR"
if [[ -L "$LIFEOS_CODEX_SKILL_TARGET" && "$(readlink "$LIFEOS_CODEX_SKILL_TARGET")" == "$LIFEOS_CODEX_SKILL_SOURCE" ]]; then
  print "Codex Skill 已安装：$LIFEOS_CODEX_SKILL_TARGET"
elif [[ -e "$LIFEOS_CODEX_SKILL_TARGET" || -L "$LIFEOS_CODEX_SKILL_TARGET" ]]; then
  print -u2 "Codex Skill 目标已存在，未覆盖：$LIFEOS_CODEX_SKILL_TARGET"
  print -u2 "如需切换，请先自行备份或移除现有目录。"
else
  ln -s "$LIFEOS_CODEX_SKILL_SOURCE" "$LIFEOS_CODEX_SKILL_TARGET"
  print "Codex Skill 已安装：$LIFEOS_CODEX_SKILL_TARGET"
fi

print "LifeOS 初始化完成。"
print "下一步：用 Obsidian 打开 $LIFEOS_ROOT，并把新笔记位置设为 00-收件箱。"
