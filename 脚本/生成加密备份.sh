#!/bin/zsh
set -euo pipefail

LIFEOS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIFEOS_PARENT="$(dirname "$LIFEOS_ROOT")"
LIFEOS_NAME="$(basename "$LIFEOS_ROOT")"
LIFEOS_RECIPIENT_FILE="$LIFEOS_ROOT/99-系统/配置/age-recipient.txt"
LIFEOS_STAMP="$(date '+%Y%m%d-%H%M%S')"
LIFEOS_OUTPUT="$LIFEOS_ROOT/LifeOS-$LIFEOS_STAMP.zip.age"
LIFEOS_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-backup.XXXXXX")"
LIFEOS_TEMP_ZIP="$LIFEOS_TEMP_DIR/LifeOS-$LIFEOS_STAMP.zip"

trap 'rm -rf "$LIFEOS_TEMP_DIR"' EXIT

command -v age >/dev/null || {
  print -u2 "缺少 age。请先运行：brew install age"
  exit 1
}

command -v zip >/dev/null || {
  print -u2 "缺少 zip 命令。"
  exit 1
}

if [[ ! -s "$LIFEOS_RECIPIENT_FILE" ]]; then
  print -u2 "尚未配置加密公钥。先运行：./脚本/初始化加密.sh /仓库外/人生库解密密钥.txt"
  exit 1
fi

LIFEOS_RECIPIENT="$(tr -d '[:space:]' < "$LIFEOS_RECIPIENT_FILE")"
if [[ "$LIFEOS_RECIPIENT" != age1* ]]; then
  print -u2 "加密公钥格式无效：$LIFEOS_RECIPIENT_FILE"
  exit 1
fi

(
  cd "$LIFEOS_PARENT"
  zip -qry "$LIFEOS_TEMP_ZIP" "$LIFEOS_NAME" \
    -x "$LIFEOS_NAME/.git/*" \
       "$LIFEOS_NAME/.trash/*" \
       "$LIFEOS_NAME/.template-backups/*" \
       "$LIFEOS_NAME/LifeOS-*.zip.age" \
       "$LIFEOS_NAME/LifeOS-*.zip.age.sha256" \
       "$LIFEOS_NAME/.DS_Store"
)

age -r "$LIFEOS_RECIPIENT" -o "$LIFEOS_OUTPUT" "$LIFEOS_TEMP_ZIP"
(
  cd "$LIFEOS_ROOT"
  shasum -a 256 "$(basename "$LIFEOS_OUTPUT")" > "$(basename "$LIFEOS_OUTPUT").sha256"
)

print "已生成：$LIFEOS_OUTPUT"
print "校验值：$LIFEOS_OUTPUT.sha256"
