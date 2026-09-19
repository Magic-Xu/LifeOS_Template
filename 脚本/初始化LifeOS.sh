#!/bin/zsh
set -euo pipefail

LIFEOS_SKIP_GLOBAL_SKILL=0
case "${1:-}" in
  --skip-global-skill) LIFEOS_SKIP_GLOBAL_SKILL=1; shift ;;
  --help|-h)
    print "用法：$0 [--skip-global-skill]"
    print "--skip-global-skill：仅使用项目内 Skill，不安装全局链接。"
    exit 0
    ;;
esac
if (( $# > 0 )); then
  print -u2 "用法：$0 [--skip-global-skill]"
  exit 1
fi

# rg 用于后续知识库检查和 Git 提交保护，首次初始化时一并检查。
for LIFEOS_COMMAND in git rg date dirname mkdir sed readlink ln; do
  command -v "$LIFEOS_COMMAND" >/dev/null || {
    print -u2 "缺少依赖：$LIFEOS_COMMAND。请安装后重新初始化。"
    exit 1
  }
done

LIFEOS_ROOT="$(cd -P "$(dirname "$0")/.." && pwd -P)"
LIFEOS_TEMPLATE_DIR="$LIFEOS_ROOT/99-系统/模板"
LIFEOS_TODAY="$(date '+%Y-%m-%d')"
LIFEOS_CODEX_SKILLS_DIR="${CODEX_HOME:-$HOME/.codex}/skills"
LIFEOS_CODEX_SKILL_TARGET="$LIFEOS_CODEX_SKILLS_DIR/lifeos"
LIFEOS_CODEX_SKILL_SOURCE="$LIFEOS_ROOT/.agents/skills/lifeos"

if ! LIFEOS_GIT_ROOT="$(git -C "$LIFEOS_ROOT" rev-parse --show-toplevel 2>/dev/null)"; then
  print -u2 "当前目录不是 Git 仓库：$LIFEOS_ROOT"
  exit 1
fi
LIFEOS_GIT_ROOT="$(cd -P "$LIFEOS_GIT_ROOT" && pwd -P)"
if [[ "$LIFEOS_GIT_ROOT" != "$LIFEOS_ROOT" ]]; then
  print -u2 "LifeOS 必须有独立的 Git 根目录，拒绝修改上级仓库：$LIFEOS_GIT_ROOT"
  exit 1
fi

copy_if_missing() {
  local LIFEOS_SOURCE="$1"
  local LIFEOS_TARGET="$2"

  mkdir -p "$(dirname "$LIFEOS_TARGET")"
  if [[ -e "$LIFEOS_TARGET" || -L "$LIFEOS_TARGET" ]]; then
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

if (( LIFEOS_SKIP_GLOBAL_SKILL )); then
  print "已跳过全局 Skill 安装；请使用 $LIFEOS_CODEX_SKILL_SOURCE。"
else
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
fi

print "LifeOS 初始化完成。"
print "下一步：用 Obsidian 打开 $LIFEOS_ROOT，并把新笔记位置设为 00-收件箱。"
