#!/bin/zsh
set -euo pipefail

LIFEOS_ROOT="$(cd -P "$(dirname "$0")/.." && pwd -P)"
LIFEOS_IDENTITY_PATH="${1:-}"
LIFEOS_RECIPIENT_FILE="$LIFEOS_ROOT/99-系统/配置/age-recipient.txt"

if (( $# != 1 )) || [[ -z "$LIFEOS_IDENTITY_PATH" ]]; then
  print -u2 "用法：$0 /仓库外/人生库解密密钥.txt"
  exit 1
fi

for LIFEOS_COMMAND in age-keygen mkdir chmod cmp; do
  command -v "$LIFEOS_COMMAND" >/dev/null || {
    print -u2 "缺少依赖：$LIFEOS_COMMAND（age-keygen 可通过 brew install age 安装）。"
    exit 1
  }
done

# 逐段解析真实父目录；处理 .. 后继续检查符号链接，不能仅比较输入前缀。
LIFEOS_REQUESTED_PARENT="${LIFEOS_IDENTITY_PATH:h}"
if [[ "$LIFEOS_REQUESTED_PARENT" == /* ]]; then
  LIFEOS_IDENTITY_PARENT="/"
else
  LIFEOS_IDENTITY_PARENT="$(pwd -P)"
fi
for LIFEOS_COMPONENT in "${(@s:/:)LIFEOS_REQUESTED_PARENT}"; do
  case "$LIFEOS_COMPONENT" in
    ""|.) continue ;;
    ..) LIFEOS_IDENTITY_PARENT="${LIFEOS_IDENTITY_PARENT:h}"; continue ;;
  esac
  LIFEOS_CANDIDATE="$LIFEOS_IDENTITY_PARENT/$LIFEOS_COMPONENT"
  if [[ -d "$LIFEOS_CANDIDATE" ]]; then
    LIFEOS_IDENTITY_PARENT="$(cd -P "$LIFEOS_CANDIDATE" && pwd -P)"
  elif [[ -e "$LIFEOS_CANDIDATE" || -L "$LIFEOS_CANDIDATE" ]]; then
    print -u2 "密钥父路径不是有效目录：$LIFEOS_CANDIDATE"
    exit 1
  else
    LIFEOS_IDENTITY_PARENT="$LIFEOS_CANDIDATE"
  fi
done
LIFEOS_IDENTITY_PATH="$LIFEOS_IDENTITY_PARENT/${LIFEOS_IDENTITY_PATH:t}"
LIFEOS_IDENTITY_PATH="${LIFEOS_IDENTITY_PATH:a}"

case "$LIFEOS_IDENTITY_PATH" in
  "$LIFEOS_ROOT"|"$LIFEOS_ROOT"/*)
    print -u2 "解密密钥必须保存在 LifeOS 仓库之外。"
    exit 1
    ;;
esac

if [[ -e "$LIFEOS_IDENTITY_PATH" || -L "$LIFEOS_IDENTITY_PATH" ]]; then
  print -u2 "目标密钥文件已存在，拒绝覆盖：$LIFEOS_IDENTITY_PATH"
  exit 1
fi

# 只允许首次配置时替换仓库自带的占位文本，避免静默轮换现有公钥。
if [[ -L "$LIFEOS_RECIPIENT_FILE" ]] || {
  [[ -e "$LIFEOS_RECIPIENT_FILE" ]] && ! cmp -s "$LIFEOS_RECIPIENT_FILE" <(
    print -r -- '# 运行 ./脚本/初始化加密.sh 后，这里会写入可公开提交的 age 公钥。'
  )
}; then
  print -u2 "公钥配置已存在或不是模板占位，拒绝覆盖：$LIFEOS_RECIPIENT_FILE"
  exit 1
fi

mkdir -p "${LIFEOS_IDENTITY_PATH:h}"
age-keygen -o "$LIFEOS_IDENTITY_PATH"
chmod 600 "$LIFEOS_IDENTITY_PATH"
age-keygen -y "$LIFEOS_IDENTITY_PATH" > "$LIFEOS_RECIPIENT_FILE"

print "加密配置已建立。"
print "私钥：$LIFEOS_IDENTITY_PATH"
print "公钥：$LIFEOS_RECIPIENT_FILE"
print "请把私钥另存到密码管理器或纸质密封件。"
