#!/bin/zsh
set -euo pipefail

LIFEOS_TARGET_ARGUMENT="${1:-}"
LIFEOS_SYNC_MODE="${2:---check}"
LIFEOS_SYNC_MANIFEST="99-系统/配置/模板同步清单.txt"

lifeos_fail() {
  print -u2 -- "$1"
  exit 1
}

# macOS 的系统目录别名可正常使用；用户创建的库根目录/祖先链接一律拒绝。
lifeos_check_root_path() {
  local LIFEOS_ARGUMENT="$1" LIFEOS_PART LIFEOS_CURRENT=""
  local -a LIFEOS_PARTS
  LIFEOS_ARGUMENT="${LIFEOS_ARGUMENT:a}"
  LIFEOS_PARTS=("${(@s:/:)LIFEOS_ARGUMENT}")
  for LIFEOS_PART in "${LIFEOS_PARTS[@]}"; do
    [[ -n "$LIFEOS_PART" ]] || continue
    LIFEOS_CURRENT="$LIFEOS_CURRENT/$LIFEOS_PART"
    if [[ -L "$LIFEOS_CURRENT" ]]; then
      case "$LIFEOS_CURRENT" in
        /tmp|/var|/etc)
          [[ "${LIFEOS_CURRENT:A}" == "/private$LIFEOS_CURRENT" ]] || lifeos_fail "库根目录的祖先不能是符号链接：$LIFEOS_CURRENT"
          ;;
        *) lifeos_fail "库根目录或其祖先不能是符号链接：$LIFEOS_CURRENT" ;;
      esac
    fi
  done
}

if [[ -z "$LIFEOS_TARGET_ARGUMENT" || $# -gt 2 ]]; then
  lifeos_fail "用法：$0 /路径/个人LifeOS --check|--apply"
fi
[[ "$LIFEOS_SYNC_MODE" == "--check" || "$LIFEOS_SYNC_MODE" == "--apply" ]] || lifeos_fail "模式必须是 --check 或 --apply。"
lifeos_check_root_path "$(dirname "$0")/.."
lifeos_check_root_path "$LIFEOS_TARGET_ARGUMENT"
LIFEOS_TEMPLATE_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
LIFEOS_TARGET_ROOT="$(cd "$LIFEOS_TARGET_ARGUMENT" 2>/dev/null && pwd -P)" || lifeos_fail "目标目录不存在：$LIFEOS_TARGET_ARGUMENT"
[[ "$LIFEOS_TARGET_ROOT" != "$LIFEOS_TEMPLATE_ROOT" ]] || lifeos_fail "目标不能是模板仓库自身。"
LIFEOS_GIT_ROOT="$(git -C "$LIFEOS_TARGET_ROOT" rev-parse --show-toplevel 2>/dev/null)" || lifeos_fail "目标必须是已初始化的 Git 仓库。"
[[ "$(cd "$LIFEOS_GIT_ROOT" && pwd -P)" == "$LIFEOS_TARGET_ROOT" ]] || lifeos_fail "目标必须是 Git 仓库根目录。"

# 逐层检查已有节点；缺失的目录可在全部预检通过后创建。
lifeos_check_path() {
  local LIFEOS_ROOT_PATH="$1" LIFEOS_RELATIVE="$2" LIFEOS_EXPECTED="$3"
  local LIFEOS_PART LIFEOS_CURRENT="$LIFEOS_ROOT_PATH"
  local -a LIFEOS_PARTS
  [[ -n "$LIFEOS_RELATIVE" && "$LIFEOS_RELATIVE" != /* && "$LIFEOS_RELATIVE" != */ && "$LIFEOS_RELATIVE" != *//* ]] || lifeos_fail "路径格式不安全：$LIFEOS_RELATIVE"
  LIFEOS_PARTS=("${(@s:/:)LIFEOS_RELATIVE}")
  for LIFEOS_PART in "${LIFEOS_PARTS[@]}"; do
    [[ "$LIFEOS_PART" != "." && "$LIFEOS_PART" != ".." ]] || lifeos_fail "路径不能包含 . 或 ..：$LIFEOS_RELATIVE"
    LIFEOS_CURRENT="$LIFEOS_CURRENT/$LIFEOS_PART"
    [[ ! -L "$LIFEOS_CURRENT" ]] || lifeos_fail "路径或其祖先不能是符号链接：$LIFEOS_CURRENT"
    if [[ -e "$LIFEOS_CURRENT" ]]; then
      if [[ "$LIFEOS_CURRENT" != "$LIFEOS_ROOT_PATH/$LIFEOS_RELATIVE" || "$LIFEOS_EXPECTED" == dir ]]; then
        [[ -d "$LIFEOS_CURRENT" ]] || lifeos_fail "预期目录，实际为其他文件：$LIFEOS_CURRENT"
      else
        [[ -f "$LIFEOS_CURRENT" ]] || lifeos_fail "预期普通文件：$LIFEOS_CURRENT"
      fi
    fi
  done
}

lifeos_path_is_syncable() {
  case "$1" in
    .agents/skills/lifeos/SKILL.md|\
    .agents/skills/lifeos/agents/openai.yaml|\
    .agents/skills/lifeos/references/archive-policy.md|\
    .agents/skills/lifeos/references/context-routing.md|\
    .agents/skills/lifeos/references/knowledge-schema.md|\
    .githooks/pre-commit|\
    .gitattributes|\
    .gitignore|\
    AGENTS.md|\
    README.md|\
    LICENSE|\
    99-系统/工作流/备份与恢复.md|\
    99-系统/工作流/整理收件箱.md|\
    99-系统/工作流/日常记录.md|\
    99-系统/模板/AI上下文模板.md|\
    99-系统/模板/人物模板.md|\
    99-系统/模板/人物索引模板.md|\
    99-系统/模板/人生事件模板.md|\
    99-系统/模板/健康总览模板.md|\
    99-系统/模板/健康记录模板.md|\
    99-系统/模板/兴趣偏好模板.md|\
    99-系统/模板/当前目标模板.md|\
    99-系统/模板/待确认与冲突模板.md|\
    99-系统/模板/我的概况模板.md|\
    99-系统/模板/日记模板.md|\
    99-系统/模板/系统状态模板.md|\
    99-系统/模板/经历索引模板.md|\
    99-系统/模板/计划模板.md|\
    99-系统/模板/财务总览模板.md|\
    99-系统/模板/财务记录模板.md|\
    99-系统/模板/重要偏好与边界模板.md|\
    99-系统/模板/随手记模板.md|\
    脚本/初始化LifeOS.sh|\
    脚本/初始化加密.sh|\
    脚本/同步到个人库.sh|\
    脚本/恢复加密备份.sh|\
    脚本/检查可提交内容.sh|\
    脚本/检查知识库质量.sh|\
    脚本/生成加密备份.sh|\
    脚本/验证备份.sh|\
    99-系统/配置/模板同步清单.txt|\
    00-收件箱/.gitkeep|\
    01-日记/.gitkeep|\
    10-人生经历/重要事件/.gitkeep|\
    10-人生经历/决定与结果/.gitkeep|\
    10-人生经历/目标与复盘/.gitkeep|\
    10-人生经历/职业经历/.gitkeep|\
    20-人物关系/.gitkeep|\
    30-健康/.gitkeep|\
    30-健康/亲友健康/.gitkeep|\
    40-财务/.gitkeep|\
    50-兴趣与生活/读书与电影/.gitkeep|\
    50-兴趣与生活/旅行/.gitkeep|\
    50-兴趣与生活/兴趣爱好/.gitkeep|\
    50-兴趣与生活/外貌与护肤/.gitkeep|\
    90-附件/.gitkeep|\
    99-系统/AI上下文/.gitkeep|\
    99-系统/AI整理报告/.gitkeep)
      return 0 ;;
    *) return 1 ;;
  esac
}

lifeos_check_path "$LIFEOS_TARGET_ROOT" AGENTS.md file
lifeos_check_path "$LIFEOS_TARGET_ROOT" 00-收件箱 dir
lifeos_check_path "$LIFEOS_TARGET_ROOT" 99-系统 dir
[[ -f "$LIFEOS_TARGET_ROOT/AGENTS.md" && -d "$LIFEOS_TARGET_ROOT/00-收件箱" && -d "$LIFEOS_TARGET_ROOT/99-系统" ]] || lifeos_fail "目标不是有效 LifeOS，需包含 AGENTS.md、00-收件箱和 99-系统。"
lifeos_check_path "$LIFEOS_TEMPLATE_ROOT" "$LIFEOS_SYNC_MANIFEST" file
[[ -f "$LIFEOS_TEMPLATE_ROOT/$LIFEOS_SYNC_MANIFEST" ]] || lifeos_fail "同步清单不存在。"
lifeos_check_path "$LIFEOS_TARGET_ROOT" .template-backups dir

# 一次性预检全部清单，避免遇到后续无效路径时已覆盖前面的文件。
typeset -A LIFEOS_SEEN
LIFEOS_CHANGED=()
LIFEOS_EXISTING=()
while IFS= read -r LIFEOS_RELATIVE_PATH || [[ -n "$LIFEOS_RELATIVE_PATH" ]]; do
  [[ -z "$LIFEOS_RELATIVE_PATH" || "$LIFEOS_RELATIVE_PATH" == \#* ]] && continue
  lifeos_path_is_syncable "$LIFEOS_RELATIVE_PATH" || lifeos_fail "同步清单包含非白名单文件：$LIFEOS_RELATIVE_PATH"
  [[ -z "${LIFEOS_SEEN[$LIFEOS_RELATIVE_PATH]:-}" ]] || lifeos_fail "同步清单包含重复路径：$LIFEOS_RELATIVE_PATH"
  LIFEOS_SEEN[$LIFEOS_RELATIVE_PATH]=1
  lifeos_check_path "$LIFEOS_TEMPLATE_ROOT" "$LIFEOS_RELATIVE_PATH" file
  lifeos_check_path "$LIFEOS_TARGET_ROOT" "$LIFEOS_RELATIVE_PATH" file
  LIFEOS_SOURCE="$LIFEOS_TEMPLATE_ROOT/$LIFEOS_RELATIVE_PATH"
  LIFEOS_TARGET="$LIFEOS_TARGET_ROOT/$LIFEOS_RELATIVE_PATH"
  [[ -f "$LIFEOS_SOURCE" ]] || lifeos_fail "同步清单中的来源不存在：$LIFEOS_RELATIVE_PATH"
  if [[ "$LIFEOS_RELATIVE_PATH" == */.gitkeep ]]; then
    [[ ! -s "$LIFEOS_SOURCE" ]] || lifeos_fail "来源占位文件必须为空：$LIFEOS_RELATIVE_PATH"
    [[ ! -s "$LIFEOS_TARGET" ]] || lifeos_fail "目标占位文件非空，拒绝覆盖：$LIFEOS_RELATIVE_PATH"
  fi
  if [[ ! -f "$LIFEOS_TARGET" ]]; then
    print -- "缺失，将新增：$LIFEOS_RELATIVE_PATH"
    LIFEOS_CHANGED+=("$LIFEOS_RELATIVE_PATH")
  elif ! cmp -s "$LIFEOS_SOURCE" "$LIFEOS_TARGET" || [[ -x "$LIFEOS_SOURCE" && ! -x "$LIFEOS_TARGET" ]] || [[ ! -x "$LIFEOS_SOURCE" && -x "$LIFEOS_TARGET" ]]; then
    print -- "内容或执行权限有差异，将更新：$LIFEOS_RELATIVE_PATH"
    LIFEOS_CHANGED+=("$LIFEOS_RELATIVE_PATH")
    LIFEOS_EXISTING+=("$LIFEOS_RELATIVE_PATH")
  fi
done < "$LIFEOS_TEMPLATE_ROOT/$LIFEOS_SYNC_MANIFEST"

if [[ "$LIFEOS_SYNC_MODE" == "--check" ]]; then
  print -- "检查完成：${#LIFEOS_CHANGED} 个文件需要同步；未修改个人 LifeOS。"
  exit 0
fi
if (( ${#LIFEOS_CHANGED} == 0 )); then
  print "无需同步，所有清单文件均已一致。"
  exit 0
fi

# 所有覆盖项备份成功后才写入；保留相对路径，可按需恢复本地定制。
if (( ${#LIFEOS_EXISTING} > 0 )); then
  mkdir -p "$LIFEOS_TARGET_ROOT/.template-backups"
  LIFEOS_BACKUP_ROOT="$(mktemp -d "$LIFEOS_TARGET_ROOT/.template-backups/$(date +%Y%m%d-%H%M%S)-XXXXXX")"
  for LIFEOS_RELATIVE_PATH in "${LIFEOS_EXISTING[@]}"; do
    mkdir -p "$(dirname "$LIFEOS_BACKUP_ROOT/$LIFEOS_RELATIVE_PATH")"
    cp -p "$LIFEOS_TARGET_ROOT/$LIFEOS_RELATIVE_PATH" "$LIFEOS_BACKUP_ROOT/$LIFEOS_RELATIVE_PATH"
  done
  print -- "原文件已备份：$LIFEOS_BACKUP_ROOT"
fi

LIFEOS_TEMP_FILE=""
trap '[[ -z "$LIFEOS_TEMP_FILE" ]] || rm -f -- "$LIFEOS_TEMP_FILE"' EXIT
for LIFEOS_RELATIVE_PATH in "${LIFEOS_CHANGED[@]}"; do
  LIFEOS_TARGET="$LIFEOS_TARGET_ROOT/$LIFEOS_RELATIVE_PATH"
  mkdir -p "$(dirname "$LIFEOS_TARGET")"
  LIFEOS_TEMP_FILE="$(mktemp "$(dirname "$LIFEOS_TARGET")/.lifeos-sync-XXXXXX")"
  cp -p "$LIFEOS_TEMPLATE_ROOT/$LIFEOS_RELATIVE_PATH" "$LIFEOS_TEMP_FILE"
  mv -f "$LIFEOS_TEMP_FILE" "$LIFEOS_TARGET"
  LIFEOS_TEMP_FILE=""
  print -- "已同步：$LIFEOS_RELATIVE_PATH"
done

git -C "$LIFEOS_TARGET_ROOT" config core.hooksPath .githooks
"$LIFEOS_TARGET_ROOT/脚本/检查可提交内容.sh"
print "同步完成。请核对 Git diff，将所需的个人定制从备份合回通用文件，再运行质量与提交检查。"
