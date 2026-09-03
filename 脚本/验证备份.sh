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

if [[ ! -f "$LIFEOS_ARCHIVE.sha256" ]]; then
  print -u2 "缺少校验文件：$LIFEOS_ARCHIVE.sha256"
  exit 1
fi

LIFEOS_CHECKSUM_CONTENT="$(< "$LIFEOS_ARCHIVE.sha256")"
LIFEOS_CHECKSUM_LINES="$(awk 'END { print NR }' "$LIFEOS_ARCHIVE.sha256")"
LIFEOS_EXPECTED_NAME="$(basename "$LIFEOS_ARCHIVE")"
LIFEOS_EXPECTED_HASH="${LIFEOS_CHECKSUM_CONTENT%%  *}"
LIFEOS_HASHED_NAME="${LIFEOS_CHECKSUM_CONTENT#*  }"
if (( LIFEOS_CHECKSUM_LINES != 1 )) || [[ "$LIFEOS_CHECKSUM_CONTENT" != *"  "* || "$LIFEOS_CHECKSUM_CONTENT" == *$'\n'* || ${#LIFEOS_EXPECTED_HASH} -ne 64 || "$LIFEOS_EXPECTED_HASH" == *[^0-9a-f]* || "$LIFEOS_HASHED_NAME" != "$LIFEOS_EXPECTED_NAME" ]]; then
  print -u2 "校验文件格式无效或未绑定当前备份：$LIFEOS_ARCHIVE.sha256"
  exit 1
fi

LIFEOS_ACTUAL_HASH="$(shasum -a 256 "$LIFEOS_ARCHIVE" | awk '{ print $1 }')"
if [[ "$LIFEOS_ACTUAL_HASH" != "$LIFEOS_EXPECTED_HASH" ]]; then
  print -u2 "备份校验失败：$LIFEOS_ARCHIVE"
  exit 1
fi
print "$LIFEOS_EXPECTED_NAME: OK"

age --decrypt -i "$LIFEOS_IDENTITY_PATH" -o "$LIFEOS_TEMP_ZIP" "$LIFEOS_ARCHIVE"
unzip -tq "$LIFEOS_TEMP_ZIP" >/dev/null
print "备份验证通过：$LIFEOS_ARCHIVE"
