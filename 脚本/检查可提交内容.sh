#!/bin/zsh
set -euo pipefail

LIFEOS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIFEOS_SCOPE="${1:-all}"
cd "$LIFEOS_ROOT"

case "$LIFEOS_SCOPE" in
  all|--staged) ;;
  *)
    print -u2 "用法：$0 [--staged]"
    exit 2
    ;;
esac

lifeos_path_is_allowed() {
  case "$1" in
    .gitattributes|.gitignore|AGENTS.md|README.md|LICENSE)
      return 0
      ;;
    .agents/skills/lifeos/SKILL.md|.agents/skills/lifeos/agents/openai.yaml|.agents/skills/lifeos/references/archive-policy.md|.agents/skills/lifeos/references/context-routing.md|.agents/skills/lifeos/references/knowledge-schema.md|.githooks/pre-commit|脚本/初始化LifeOS.sh|脚本/初始化加密.sh|脚本/恢复加密备份.sh|脚本/同步到个人库.sh|脚本/检查可提交内容.sh|脚本/检查知识库质量.sh|脚本/生成加密备份.sh|脚本/验证备份.sh)
      return 0
      ;;
    00-收件箱/.gitkeep|01-日记/.gitkeep|10-人生经历/决定与结果/.gitkeep|10-人生经历/目标与复盘/.gitkeep|10-人生经历/职业经历/.gitkeep|10-人生经历/重要事件/.gitkeep|20-人物关系/.gitkeep|30-健康/.gitkeep|30-健康/亲友健康/.gitkeep|40-财务/.gitkeep|50-兴趣与生活/兴趣爱好/.gitkeep|50-兴趣与生活/外貌与护肤/.gitkeep|50-兴趣与生活/旅行/.gitkeep|50-兴趣与生活/读书与电影/.gitkeep|90-附件/.gitkeep|99-系统/AI上下文/.gitkeep|99-系统/AI整理报告/.gitkeep)
      return 0
      ;;
    99-系统/工作流/备份与恢复.md|99-系统/工作流/整理收件箱.md|99-系统/工作流/日常记录.md|99-系统/模板/AI上下文模板.md|99-系统/模板/人物模板.md|99-系统/模板/人物索引模板.md|99-系统/模板/人生事件模板.md|99-系统/模板/健康总览模板.md|99-系统/模板/健康记录模板.md|99-系统/模板/兴趣偏好模板.md|99-系统/模板/当前目标模板.md|99-系统/模板/待确认与冲突模板.md|99-系统/模板/我的概况模板.md|99-系统/模板/日记模板.md|99-系统/模板/经历索引模板.md|99-系统/模板/财务记录模板.md|99-系统/模板/财务总览模板.md|99-系统/模板/计划模板.md|99-系统/模板/系统状态模板.md|99-系统/模板/重要偏好与边界模板.md|99-系统/模板/随手记模板.md|99-系统/配置/age-recipient.txt|99-系统/配置/模板同步清单.txt)
      return 0
      ;;
    LifeOS-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9].zip.age|LifeOS-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9].zip.age.sha256)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

lifeos_file_exists() {
  if [[ "$LIFEOS_SCOPE" == "--staged" ]]; then
    git cat-file -e ":$1" 2>/dev/null
  else
    [[ -f "$1" && ! -L "$1" ]]
  fi
}

lifeos_file_size() {
  if [[ "$LIFEOS_SCOPE" == "--staged" ]]; then
    git cat-file -s ":$1"
  else
    stat -f '%z' "$1"
  fi
}

lifeos_file_content() {
  if [[ "$LIFEOS_SCOPE" == "--staged" ]]; then
    git show ":$1"
  else
    command cat -- "$1"
  fi
}

lifeos_file_line_count() {
  if [[ "$LIFEOS_SCOPE" == "--staged" ]]; then
    git show ":$1" | awk 'END { print NR }'
  else
    awk 'END { print NR }' "$1"
  fi
}

lifeos_file_header() {
  if [[ "$LIFEOS_SCOPE" == "--staged" ]]; then
    git show ":$1" | head -c 21
  else
    head -c 21 "$1"
  fi
}

lifeos_file_hash() {
  if [[ "$LIFEOS_SCOPE" == "--staged" ]]; then
    git show ":$1" | shasum -a 256 | awk '{ print $1 }'
  else
    shasum -a 256 "$1" | awk '{ print $1 }'
  fi
}

lifeos_file_is_symlink() {
  if [[ "$LIFEOS_SCOPE" == "--staged" ]]; then
    [[ "$(git ls-files -s -- "$1" | awk 'NR == 1 { print $1 }')" == "120000" ]]
  else
    [[ -L "$1" ]]
  fi
}

lifeos_file_contains_secret() {
  local LIFEOS_SECRET_PATTERN='AGE-SECRET-KEY-1[0-9A-Z]+|-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{36,}|sk-(proj-)?[A-Za-z0-9_-]{32,}'
  if [[ "$LIFEOS_SCOPE" == "--staged" ]]; then
    git show ":$1" | LC_ALL=C grep -aEiq "$LIFEOS_SECRET_PATTERN"
  else
    LC_ALL=C grep -aEiq "$LIFEOS_SECRET_PATTERN" "$1"
  fi
}

lifeos_file_contains_personal_identifier() {
  local LIFEOS_PERSONAL_PATTERN='/Users/[^/[:space:]]+/|/home/[^/[:space:]]+/|[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}|(^|[^0-9])1[3-9][0-9]{9}([^0-9]|$)|(^|[^0-9])[0-9]{17}[0-9Xx]([^0-9]|$)'
  if [[ "$LIFEOS_SCOPE" == "--staged" ]]; then
    git show ":$1" | LC_ALL=C grep -aEiq "$LIFEOS_PERSONAL_PATTERN"
  else
    LC_ALL=C grep -aEiq "$LIFEOS_PERSONAL_PATTERN" "$1"
  fi
}

lifeos_archive_checksum_is_valid() {
  local LIFEOS_ARCHIVE="$1"
  local LIFEOS_CHECKSUM="$1.sha256"
  local LIFEOS_CHECKSUM_CONTENT
  local LIFEOS_CHECKSUM_HASH
  local LIFEOS_CHECKSUM_NAME

  lifeos_file_exists "$LIFEOS_ARCHIVE" || return 1
  lifeos_file_exists "$LIFEOS_CHECKSUM" || return 1
  LIFEOS_CHECKSUM_CONTENT="$(lifeos_file_content "$LIFEOS_CHECKSUM")"
  (( $(lifeos_file_line_count "$LIFEOS_CHECKSUM") == 1 )) || return 1
  [[ "$LIFEOS_CHECKSUM_CONTENT" == *"  "* && "$LIFEOS_CHECKSUM_CONTENT" != *$'\n'* ]] || return 1

  LIFEOS_CHECKSUM_HASH="${LIFEOS_CHECKSUM_CONTENT%%  *}"
  LIFEOS_CHECKSUM_NAME="${LIFEOS_CHECKSUM_CONTENT#*  }"
  [[ ${#LIFEOS_CHECKSUM_HASH} -eq 64 && "$LIFEOS_CHECKSUM_HASH" != *[^0-9a-f]* ]] || return 1
  [[ "$LIFEOS_CHECKSUM_NAME" == "$LIFEOS_ARCHIVE" ]] || return 1
  [[ "$(lifeos_file_hash "$LIFEOS_ARCHIVE")" == "$LIFEOS_CHECKSUM_HASH" ]]
}

LIFEOS_FAILED=0

if [[ "$LIFEOS_SCOPE" == "--staged" ]]; then
  LIFEOS_FILE_LIST=(git diff --cached --name-only --diff-filter=ACMR -z)
else
  LIFEOS_FILE_LIST=(git ls-files -co --exclude-standard -z)
fi

while IFS= read -r -d '' LIFEOS_FILE; do
  if [[ "$LIFEOS_SCOPE" == "all" && ! -e "$LIFEOS_FILE" && ! -L "$LIFEOS_FILE" ]]; then
    continue
  fi

  LIFEOS_FILE_LOWER="${LIFEOS_FILE:l}"
  case "$LIFEOS_FILE_LOWER" in
    *解密密钥*|*.key|*.pem|*.p12|*.pfx|.env|.env.*|*/.env|*/.env.*)
      print -u2 "发现密钥或凭据：$LIFEOS_FILE"
      LIFEOS_FAILED=1
      continue
      ;;
    *.zip|*.tar|*.tar.gz|*.7z|*.rar)
      print -u2 "发现未加密压缩包：$LIFEOS_FILE"
      LIFEOS_FAILED=1
      continue
      ;;
  esac

  if ! lifeos_path_is_allowed "$LIFEOS_FILE"; then
    print -u2 "发现非白名单路径：$LIFEOS_FILE"
    LIFEOS_FAILED=1
    continue
  fi

  if lifeos_file_is_symlink "$LIFEOS_FILE"; then
    print -u2 "白名单文件不能是符号链接：$LIFEOS_FILE"
    LIFEOS_FAILED=1
    continue
  fi

  case "$LIFEOS_FILE" in
    */.gitkeep)
      if (( $(lifeos_file_size "$LIFEOS_FILE") != 0 )); then
        print -u2 "占位文件必须为空：$LIFEOS_FILE"
        LIFEOS_FAILED=1
      fi
      ;;
    99-系统/配置/age-recipient.txt)
      LIFEOS_CONTENT="$(lifeos_file_content "$LIFEOS_FILE")"
      LIFEOS_TEMPLATE_PLACEHOLDER='# 运行 ./脚本/初始化加密.sh 后，这里会写入可公开提交的 age 公钥。'
      if [[ "$LIFEOS_CONTENT" != "$LIFEOS_TEMPLATE_PLACEHOLDER" ]] && { (( $(lifeos_file_line_count "$LIFEOS_FILE") != 1 )) || [[ ${#LIFEOS_CONTENT} -ne 62 || "$LIFEOS_CONTENT" != age1* || "$LIFEOS_CONTENT" == *[^0-9a-z]* || "$LIFEOS_CONTENT" == *$'\n'* ]]; }; then
        print -u2 "age recipient 必须是模板占位说明或单行合法公钥：$LIFEOS_FILE"
        LIFEOS_FAILED=1
      fi
      ;;
    *.zip.age)
      LIFEOS_SIZE="$(lifeos_file_size "$LIFEOS_FILE")"
      if (( LIFEOS_SIZE > 99614720 )); then
        print -u2 "加密备份超过 95 MiB，普通 Git 推送会有失败风险：$LIFEOS_FILE"
        LIFEOS_FAILED=1
      fi
      if [[ "$(lifeos_file_header "$LIFEOS_FILE")" != "age-encryption.org/v1" ]]; then
        print -u2 "文件不是有效的 age 格式：$LIFEOS_FILE"
        LIFEOS_FAILED=1
      fi
      if ! lifeos_archive_checksum_is_valid "$LIFEOS_FILE"; then
        print -u2 "加密备份与校验文件不匹配：$LIFEOS_FILE"
        LIFEOS_FAILED=1
      fi
      ;;
    *.zip.age.sha256)
      LIFEOS_EXPECTED_ARCHIVE="${LIFEOS_FILE%.sha256}"
      if ! lifeos_archive_checksum_is_valid "$LIFEOS_EXPECTED_ARCHIVE"; then
        print -u2 "校验文件未严格绑定对应备份：$LIFEOS_FILE"
        LIFEOS_FAILED=1
      fi
      ;;
    *)
      if lifeos_file_contains_secret "$LIFEOS_FILE"; then
        print -u2 "白名单文件中发现高置信密钥或令牌：$LIFEOS_FILE"
        LIFEOS_FAILED=1
      fi
      if [[ "$LIFEOS_FILE" != "脚本/检查可提交内容.sh" ]] && lifeos_file_contains_personal_identifier "$LIFEOS_FILE"; then
        print -u2 "白名单文件中发现潜在个人标识，请改为占位符：$LIFEOS_FILE"
        LIFEOS_FAILED=1
      fi
      ;;
  esac
done < <("${LIFEOS_FILE_LIST[@]}")

if (( LIFEOS_FAILED != 0 )); then
  print -u2 "检查失败，未执行 Git 操作。"
  exit 1
fi

if [[ "$LIFEOS_SCOPE" == "--staged" ]]; then
  print "暂存区隐私检查通过。"
else
  print "检查通过：Git 可见内容全部属于白名单。"
  git status --short
fi
