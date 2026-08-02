#!/bin/zsh
set -euo pipefail

LIFEOS_TEMPLATE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIFEOS_TARGET_ROOT="${1:-}"
LIFEOS_SYNC_MODE="${2:---check}"
LIFEOS_SYNC_MANIFEST="$LIFEOS_TEMPLATE_ROOT/99-系统/配置/模板同步清单.txt"

if [[ -z "$LIFEOS_TARGET_ROOT" ]]; then
  print -u2 "用法：$0 /路径/个人LifeOS --check|--apply"
  exit 1
fi

LIFEOS_TARGET_ROOT="$(cd "$LIFEOS_TARGET_ROOT" 2>/dev/null && pwd)" || {
  print -u2 "目标目录不存在：$1"
  exit 1
}

if [[ "$LIFEOS_TARGET_ROOT" == "$LIFEOS_TEMPLATE_ROOT" ]]; then
  print -u2 "目标不能是模板仓库自身。"
  exit 1
fi

for LIFEOS_REQUIRED in AGENTS.md 00-收件箱 99-系统; do
  if [[ ! -e "$LIFEOS_TARGET_ROOT/$LIFEOS_REQUIRED" ]]; then
    print -u2 "目标不是有效 LifeOS，缺少：$LIFEOS_REQUIRED"
    exit 1
  fi
done

if [[ "$LIFEOS_SYNC_MODE" != "--check" && "$LIFEOS_SYNC_MODE" != "--apply" ]]; then
  print -u2 "模式必须是 --check 或 --apply。"
  exit 1
fi

while IFS= read -r LIFEOS_RELATIVE_PATH; do
  [[ -z "$LIFEOS_RELATIVE_PATH" || "$LIFEOS_RELATIVE_PATH" == \#* ]] && continue

  LIFEOS_SOURCE="$LIFEOS_TEMPLATE_ROOT/$LIFEOS_RELATIVE_PATH"
  LIFEOS_TARGET="$LIFEOS_TARGET_ROOT/$LIFEOS_RELATIVE_PATH"

  if [[ ! -e "$LIFEOS_SOURCE" ]]; then
    print -u2 "同步清单中的来源不存在：$LIFEOS_RELATIVE_PATH"
    exit 1
  fi

  if [[ "$LIFEOS_SYNC_MODE" == "--check" ]]; then
    if [[ -d "$LIFEOS_SOURCE" ]]; then
      diff -qr "$LIFEOS_SOURCE" "$LIFEOS_TARGET" 2>/dev/null || true
    elif [[ ! -f "$LIFEOS_TARGET" ]] || ! cmp -s "$LIFEOS_SOURCE" "$LIFEOS_TARGET"; then
      print "需要更新：$LIFEOS_RELATIVE_PATH"
    fi
    continue
  fi

  mkdir -p "$(dirname "$LIFEOS_TARGET")"
  if [[ -d "$LIFEOS_SOURCE" ]]; then
    mkdir -p "$LIFEOS_TARGET"
    cp -R "$LIFEOS_SOURCE"/. "$LIFEOS_TARGET"/
  else
    cp "$LIFEOS_SOURCE" "$LIFEOS_TARGET"
  fi
  print "已同步：$LIFEOS_RELATIVE_PATH"
done < "$LIFEOS_SYNC_MANIFEST"

if [[ "$LIFEOS_SYNC_MODE" == "--check" ]]; then
  print "检查完成；未修改个人 LifeOS。"
  exit 0
fi

git -C "$LIFEOS_TARGET_ROOT" config core.hooksPath .githooks
"$LIFEOS_TARGET_ROOT/脚本/检查可提交内容.sh"
print "同步完成。请检查个人 LifeOS 的 Git diff 后再提交通用文件。"
