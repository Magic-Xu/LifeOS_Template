#!/bin/zsh
set -euo pipefail

LIFEOS_ARCHIVE="${1:-}"
LIFEOS_IDENTITY_PATH="${2:-}"

if [[ -z "$LIFEOS_ARCHIVE" || -z "$LIFEOS_IDENTITY_PATH" ]]; then
  print -u2 "用法：$0 LifeOS-日期.zip.age /路径/人生库解密密钥.txt"
  exit 1
fi

if [[ ! -f "$LIFEOS_ARCHIVE" || ! -f "$LIFEOS_IDENTITY_PATH" ]]; then
  print -u2 "备份文件或解密密钥不存在。"
  exit 1
fi

LIFEOS_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-verify.XXXXXX")"
LIFEOS_TEMP_ZIP="$LIFEOS_TEMP_DIR/restore.zip"
trap 'rm -rf "$LIFEOS_TEMP_DIR"' EXIT

if [[ -f "$LIFEOS_ARCHIVE.sha256" ]]; then
  (cd "$(dirname "$LIFEOS_ARCHIVE")" && shasum -a 256 -c "$(basename "$LIFEOS_ARCHIVE").sha256")
fi

age --decrypt -i "$LIFEOS_IDENTITY_PATH" -o "$LIFEOS_TEMP_ZIP" "$LIFEOS_ARCHIVE"
unzip -tq "$LIFEOS_TEMP_ZIP" >/dev/null
print "备份验证通过：$LIFEOS_ARCHIVE"
