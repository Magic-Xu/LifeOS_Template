#!/bin/zsh
set -euo pipefail

LIFEOS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$LIFEOS_ROOT"

LIFEOS_FAILED=0

while IFS= read -r -d '' LIFEOS_FILE; do
  case "$LIFEOS_FILE" in
    00-收件箱/*|01-日记/*|10-人生经历/*|20-人物关系/*|30-健康/*|40-财务/*|50-兴趣与生活/*|90-附件/*|99-系统/AI上下文/*|99-系统/AI整理报告/*)
      if [[ "$LIFEOS_FILE" != */.gitkeep ]]; then
        print -u2 "发现个人明文：$LIFEOS_FILE"
        LIFEOS_FAILED=1
      fi
      ;;
    *解密密钥*|*.key|*.pem|.env|.env.*)
      print -u2 "发现密钥或凭据：$LIFEOS_FILE"
      LIFEOS_FAILED=1
      ;;
    *.zip|*.tar|*.tar.gz)
      print -u2 "发现未加密压缩包：$LIFEOS_FILE"
      LIFEOS_FAILED=1
      ;;
    *.zip.age)
      LIFEOS_SIZE="$(wc -c < "$LIFEOS_FILE" | tr -d '[:space:]')"
      if (( LIFEOS_SIZE > 99614720 )); then
        print -u2 "加密备份超过 95 MiB，普通 Git 推送会有失败风险：$LIFEOS_FILE"
        LIFEOS_FAILED=1
      fi
      ;;
    *.zip.age.sha256)
      if [[ "$LIFEOS_FILE" == */* || "$LIFEOS_FILE" != LifeOS-*.zip.age.sha256 ]]; then
        print -u2 "备份校验文件位置或名称无效：$LIFEOS_FILE"
        LIFEOS_FAILED=1
      fi
      ;;
  esac
done < <(git ls-files -co --exclude-standard -z)

if (( LIFEOS_FAILED != 0 )); then
  print -u2 "检查失败，未执行 Git 操作。"
  exit 1
fi

print "检查通过：没有发现可见的个人明文、密钥或超大备份。"
git status --short
