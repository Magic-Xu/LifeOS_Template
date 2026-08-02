#!/bin/zsh
set -euo pipefail

LIFEOS_ARCHIVE="${1:-}"
LIFEOS_IDENTITY_PATH="${2:-}"
LIFEOS_RESTORE_DIR="${3:-}"

if [[ -z "$LIFEOS_ARCHIVE" || -z "$LIFEOS_IDENTITY_PATH" || -z "$LIFEOS_RESTORE_DIR" ]]; then
  print -u2 "用法：$0 LifeOS-日期.zip.age /路径/人生库解密密钥.txt /新的恢复目录"
  exit 1
fi

if [[ -e "$LIFEOS_RESTORE_DIR" && -n "$(ls -A "$LIFEOS_RESTORE_DIR" 2>/dev/null)" ]]; then
  print -u2 "恢复目录不是空目录，拒绝覆盖：$LIFEOS_RESTORE_DIR"
  exit 1
fi

LIFEOS_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-restore.XXXXXX")"
LIFEOS_TEMP_ZIP="$LIFEOS_TEMP_DIR/restore.zip"
trap 'rm -rf "$LIFEOS_TEMP_DIR"' EXIT

mkdir -p "$LIFEOS_RESTORE_DIR"
age --decrypt -i "$LIFEOS_IDENTITY_PATH" -o "$LIFEOS_TEMP_ZIP" "$LIFEOS_ARCHIVE"
unzip -q "$LIFEOS_TEMP_ZIP" -d "$LIFEOS_RESTORE_DIR"
print "已恢复到：$LIFEOS_RESTORE_DIR"
