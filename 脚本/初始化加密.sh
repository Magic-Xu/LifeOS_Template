#!/bin/zsh
set -euo pipefail

LIFEOS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIFEOS_IDENTITY_PATH="${1:-}"
LIFEOS_RECIPIENT_FILE="$LIFEOS_ROOT/99-系统/配置/age-recipient.txt"

if [[ -z "$LIFEOS_IDENTITY_PATH" ]]; then
  print -u2 "用法：$0 /仓库外/人生库解密密钥.txt"
  exit 1
fi

case "$LIFEOS_IDENTITY_PATH" in
  "$LIFEOS_ROOT"/*)
    print -u2 "解密密钥必须保存在 LifeOS 仓库之外。"
    exit 1
    ;;
esac

command -v age-keygen >/dev/null || {
  print -u2 "缺少 age。请先运行：brew install age"
  exit 1
}

if [[ -e "$LIFEOS_IDENTITY_PATH" ]]; then
  print -u2 "目标密钥文件已存在，拒绝覆盖：$LIFEOS_IDENTITY_PATH"
  exit 1
fi

mkdir -p "$(dirname "$LIFEOS_IDENTITY_PATH")"
age-keygen -o "$LIFEOS_IDENTITY_PATH"
chmod 600 "$LIFEOS_IDENTITY_PATH"
age-keygen -y "$LIFEOS_IDENTITY_PATH" > "$LIFEOS_RECIPIENT_FILE"

print "加密配置已建立。"
print "私钥：$LIFEOS_IDENTITY_PATH"
print "公钥：$LIFEOS_RECIPIENT_FILE"
print "请把私钥另存到密码管理器或纸质密封件。"
