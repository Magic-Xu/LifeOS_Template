#!/bin/zsh
set -euo pipefail

LIFEOS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIFEOS_TODAY="$(date '+%Y-%m-%d')"
LIFEOS_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lifeos-quality.XXXXXX")"
trap 'rm -rf "$LIFEOS_TEMP_DIR"' EXIT

cd "$LIFEOS_ROOT"

command -v rg >/dev/null || {
  print -u2 "缺少 rg，无法检查知识库。"
  exit 2
}

typeset -i LIFEOS_ERRORS=0
typeset -i LIFEOS_WARNINGS=0

lifeos_info() {
  print "[信息] $1"
}

lifeos_warn() {
  print "[警告] $1"
  (( LIFEOS_WARNINGS += 1 ))
}

lifeos_error() {
  print -u2 "[错误] $1"
  (( LIFEOS_ERRORS += 1 ))
}

lifeos_date_epoch() {
  local LIFEOS_DATE_VALUE="$1"
  if date -j -f '%Y-%m-%d %H:%M:%S' "$LIFEOS_DATE_VALUE 00:00:00" '+%s' >/dev/null 2>&1; then
    date -j -f '%Y-%m-%d %H:%M:%S' "$LIFEOS_DATE_VALUE 00:00:00" '+%s'
  else
    date -d "$LIFEOS_DATE_VALUE 00:00:00" '+%s' 2>/dev/null
  fi
}

lifeos_file_size() {
  local LIFEOS_FILE="$1"
  if stat -f '%z' "$LIFEOS_FILE" >/dev/null 2>&1; then
    stat -f '%z' "$LIFEOS_FILE"
  else
    stat -c '%s' "$LIFEOS_FILE"
  fi
}

lifeos_file_mtime() {
  local LIFEOS_FILE="$1"
  if stat -f '%m' "$LIFEOS_FILE" >/dev/null 2>&1; then
    stat -f '%m' "$LIFEOS_FILE"
  else
    stat -c '%Y' "$LIFEOS_FILE"
  fi
}

LIFEOS_PERSONAL_ROOTS=(
  01-日记
  10-人生经历
  20-人物关系
  30-健康
  40-财务
  50-兴趣与生活
  99-系统/AI上下文
)

LIFEOS_LINK_SCOPES=("${LIFEOS_PERSONAL_ROOTS[@]}")
[[ -f 时光.md ]] && LIFEOS_LINK_SCOPES+=(时光.md)
[[ -f 99-系统/检索测试/检索基准.md ]] && LIFEOS_LINK_SCOPES+=(99-系统/检索测试/检索基准.md)

print "LifeOS 知识库质量检查（${LIFEOS_TODAY}）"
print

LIFEOS_RAW_LINKS_FILE="$LIFEOS_TEMP_DIR/raw-wikilinks.txt"
LIFEOS_LINKS_FILE="$LIFEOS_TEMP_DIR/wikilink-targets.txt"
rg -o --no-filename -uu -g '*.md' '\[\[[^]]+\]\]' "${LIFEOS_LINK_SCOPES[@]}" 2>/dev/null > "$LIFEOS_RAW_LINKS_FILE" || true

while IFS= read -r LIFEOS_LINK; do
  [[ -z "$LIFEOS_LINK" ]] && continue
  LIFEOS_TARGET="${LIFEOS_LINK#\[\[}"
  LIFEOS_TARGET="${LIFEOS_TARGET%\]\]}"
  LIFEOS_TARGET="${LIFEOS_TARGET%%|*}"
  LIFEOS_TARGET="${LIFEOS_TARGET%%#*}"
  [[ -n "$LIFEOS_TARGET" ]] && print -r -- "$LIFEOS_TARGET"
done < "$LIFEOS_RAW_LINKS_FILE" | sort -u > "$LIFEOS_LINKS_FILE"

typeset -i LIFEOS_LINK_COUNT=0
typeset -i LIFEOS_MISSING_LINKS=0
typeset -i LIFEOS_AMBIGUOUS_LINKS=0

while IFS= read -r LIFEOS_TARGET; do
  [[ -z "$LIFEOS_TARGET" ]] && continue
  (( LIFEOS_LINK_COUNT += 1 ))

  if [[ -f "$LIFEOS_TARGET" || -f "$LIFEOS_TARGET.md" ]]; then
    continue
  fi

  LIFEOS_BASENAME="${LIFEOS_TARGET:t}"
  LIFEOS_MATCHES=$(rg --files -uu -g '*.md' | awk -F/ -v b="$LIFEOS_BASENAME.md" '$NF == b { count++ } END { print count + 0 }')
  if (( LIFEOS_MATCHES == 0 )); then
    lifeos_error "失效 Wiki 链接：$LIFEOS_TARGET"
    (( LIFEOS_MISSING_LINKS += 1 ))
  elif (( LIFEOS_MATCHES > 1 )); then
    lifeos_warn "仅用文件名且存在多个候选：$LIFEOS_TARGET"
    (( LIFEOS_AMBIGUOUS_LINKS += 1 ))
  fi
done < "$LIFEOS_LINKS_FILE"

lifeos_info "Wiki 链接：${LIFEOS_LINK_COUNT} 个唯一目标，失效 ${LIFEOS_MISSING_LINKS}，歧义 ${LIFEOS_AMBIGUOUS_LINKS}。"

LIFEOS_IDS_FILE="$LIFEOS_TEMP_DIR/record-ids.txt"
rg --no-filename -uu -g '*.md' '^记录ID:[[:space:]]*[^[:space:]]' "${LIFEOS_PERSONAL_ROOTS[@]}" 2>/dev/null \
  | sed -E 's/^记录ID:[[:space:]]*//' \
  | sort > "$LIFEOS_IDS_FILE" || true

LIFEOS_DUPLICATES_FILE="$LIFEOS_TEMP_DIR/duplicate-ids.txt"
uniq -d "$LIFEOS_IDS_FILE" > "$LIFEOS_DUPLICATES_FILE"
while IFS= read -r LIFEOS_ID; do
  [[ -z "$LIFEOS_ID" ]] && continue
  lifeos_error "重复记录 ID：$LIFEOS_ID"
done < "$LIFEOS_DUPLICATES_FILE"

typeset -i LIFEOS_STRUCTURED_COUNT=0
while IFS= read -r LIFEOS_FILE; do
  [[ -z "$LIFEOS_FILE" ]] && continue
  (( LIFEOS_STRUCTURED_COUNT += 1 ))
  if ! sed -n '1,80p' "$LIFEOS_FILE" | rg -q '^来源:'; then
    lifeos_error "结构化记录缺少来源：$LIFEOS_FILE"
  fi
  if ! sed -n '1,80p' "$LIFEOS_FILE" | rg -q '^置信度:'; then
    lifeos_error "结构化记录缺少置信度：$LIFEOS_FILE"
  fi
done < <(rg -l -uu -g '*.md' '^记录ID:[[:space:]]*[^[:space:]]' "${LIFEOS_PERSONAL_ROOTS[@]}" 2>/dev/null | sort || true)
lifeos_info "结构化记录：${LIFEOS_STRUCTURED_COUNT} 个。"

LIFEOS_TODAY_EPOCH="$(lifeos_date_epoch "$LIFEOS_TODAY")"
typeset -i LIFEOS_FRESHNESS_COUNT=0
while IFS= read -r LIFEOS_FILE; do
  [[ -z "$LIFEOS_FILE" ]] && continue
  LIFEOS_CYCLE=$(sed -n '1,40p' "$LIFEOS_FILE" | awk -F: '/^复核周期天数:/ { value=$2; gsub(/[[:space:]]/, "", value); print value; exit }')
  LIFEOS_UPDATED=$(sed -n '1,40p' "$LIFEOS_FILE" | awk -F: '/^更新日期:/ { value=$2; sub(/^[[:space:]]+/, "", value); sub(/[[:space:]]+$/, "", value); print value; exit }')
  (( LIFEOS_FRESHNESS_COUNT += 1 ))

  if [[ "$LIFEOS_CYCLE" != <-> || -z "$LIFEOS_UPDATED" ]]; then
    lifeos_error "复核元数据无效：$LIFEOS_FILE"
    continue
  fi
  if ! LIFEOS_UPDATED_EPOCH="$(lifeos_date_epoch "$LIFEOS_UPDATED")"; then
    lifeos_error "更新日期格式无效：$LIFEOS_FILE（$LIFEOS_UPDATED）"
    continue
  fi
  LIFEOS_AGE_DAYS=$(( (LIFEOS_TODAY_EPOCH - LIFEOS_UPDATED_EPOCH) / 86400 ))
  if (( LIFEOS_AGE_DAYS < 0 )); then
    lifeos_error "更新日期晚于今天：$LIFEOS_FILE（$LIFEOS_UPDATED）"
  elif (( LIFEOS_AGE_DAYS > LIFEOS_CYCLE )); then
    lifeos_warn "当前状态建议复核：$LIFEOS_FILE（已 ${LIFEOS_AGE_DAYS} 天，周期 ${LIFEOS_CYCLE} 天）"
  fi
done < <(rg -l -uu -g '*.md' '^复核周期天数:' "${LIFEOS_PERSONAL_ROOTS[@]}" 2>/dev/null | sort || true)
lifeos_info "带复核周期的当前状态：${LIFEOS_FRESHNESS_COUNT} 个。"

typeset -i LIFEOS_PLAN_DECISIONS=0
while IFS= read -r LIFEOS_FILE; do
  [[ -z "$LIFEOS_FILE" ]] && continue
  LIFEOS_PLAN_STATUS=$(sed -n '1,50p' "$LIFEOS_FILE" | awk -F: '/^状态:/ { value=$2; gsub(/[[:space:]]/, "", value); print value; exit }')
  [[ "$LIFEOS_PLAN_STATUS" == "完成" || "$LIFEOS_PLAN_STATUS" == "放弃" ]] && continue
  LIFEOS_DECISION=$(sed -n '1,50p' "$LIFEOS_FILE" | awk -F: '/^下次决策点:/ { value=$2; sub(/^[[:space:]]+/, "", value); sub(/[[:space:]]+$/, "", value); print value; exit }')
  (( LIFEOS_PLAN_DECISIONS += 1 ))

  if [[ -z "$LIFEOS_DECISION" || "$LIFEOS_DECISION" == "尚未明确" ]]; then
    lifeos_warn "计划尚未明确下次决策点：$LIFEOS_FILE"
    continue
  fi
  if ! LIFEOS_DECISION_EPOCH="$(lifeos_date_epoch "$LIFEOS_DECISION")"; then
    lifeos_error "下次决策点格式无效：$LIFEOS_FILE（$LIFEOS_DECISION）"
    continue
  fi
  LIFEOS_DECISION_DAYS=$(( (LIFEOS_DECISION_EPOCH - LIFEOS_TODAY_EPOCH) / 86400 ))
  if (( LIFEOS_DECISION_DAYS < 0 )); then
    lifeos_warn "计划决策点已过：$LIFEOS_FILE（$LIFEOS_DECISION）"
  elif (( LIFEOS_DECISION_DAYS <= 14 )); then
    lifeos_info "计划决策点临近：$LIFEOS_FILE（${LIFEOS_DECISION_DAYS} 天后）"
  fi
done < <(rg -l -uu -g '*.md' '^下次决策点:' "${LIFEOS_PERSONAL_ROOTS[@]}" 2>/dev/null | sort || true)
lifeos_info "带下次决策点的计划：${LIFEOS_PLAN_DECISIONS} 个。"

typeset -i LIFEOS_ORPHAN_COUNT=0
while IFS= read -r LIFEOS_FILE; do
  [[ -z "$LIFEOS_FILE" ]] && continue
  LIFEOS_TARGET="${LIFEOS_FILE%.md}"
  LIFEOS_BASENAME="${LIFEOS_FILE:t:r}"
  LIFEOS_INCOMING="$LIFEOS_TEMP_DIR/incoming.txt"
  {
    rg -l -uu -g '*.md' -F "[[$LIFEOS_TARGET" "${LIFEOS_PERSONAL_ROOTS[@]}" 2>/dev/null || true
    rg -l -uu -g '*.md' -F "[[$LIFEOS_BASENAME" "${LIFEOS_PERSONAL_ROOTS[@]}" 2>/dev/null || true
  } | sort -u | awk -v self="$LIFEOS_FILE" '$0 != self' > "$LIFEOS_INCOMING"
  if [[ ! -s "$LIFEOS_INCOMING" ]]; then
    lifeos_warn "结构化记录没有入链：$LIFEOS_FILE"
    (( LIFEOS_ORPHAN_COUNT += 1 ))
  fi
done < <(rg -l -uu -g '*.md' '^记录ID:[[:space:]]*[^[:space:]]' "${LIFEOS_PERSONAL_ROOTS[@]}" 2>/dev/null | sort || true)
lifeos_info "无入链结构化记录：${LIFEOS_ORPHAN_COUNT} 个。"

LIFEOS_INBOX_COUNT=$(rg --files -uu 00-收件箱 2>/dev/null | awk '$0 !~ /\/\.gitkeep$/ { count++ } END { print count + 0 }')
lifeos_info "收件箱待处理文件：${LIFEOS_INBOX_COUNT} 个。"

typeset -i LIFEOS_TRASH_BATCHES=0
typeset -i LIFEOS_DUE_TRASH_BATCHES=0
for LIFEOS_TRASH_DIR in .trash/待清理-????-??-??(N/); do
  (( LIFEOS_TRASH_BATCHES += 1 ))
  LIFEOS_ARCHIVED_DATE="${LIFEOS_TRASH_DIR:t}"
  LIFEOS_ARCHIVED_DATE="${LIFEOS_ARCHIVED_DATE#待清理-}"
  if ! LIFEOS_ARCHIVED_EPOCH="$(lifeos_date_epoch "$LIFEOS_ARCHIVED_DATE")"; then
    lifeos_error "回收批次日期无效：$LIFEOS_TRASH_DIR"
    continue
  fi
  LIFEOS_TRASH_AGE=$(( (LIFEOS_TODAY_EPOCH - LIFEOS_ARCHIVED_EPOCH) / 86400 ))
  if (( LIFEOS_TRASH_AGE >= 30 )); then
    lifeos_warn "存在已保留 30 天、待确认清理的批次：$LIFEOS_TRASH_DIR"
    (( LIFEOS_DUE_TRASH_BATCHES += 1 ))
  fi
done
lifeos_info "回收区批次：${LIFEOS_TRASH_BATCHES} 个，其中到期 ${LIFEOS_DUE_TRASH_BATCHES} 个；本检查不会删除。"

LIFEOS_BACKUPS=(LifeOS-*.zip.age(N.om))
if (( ${#LIFEOS_BACKUPS[@]} == 0 )); then
  lifeos_warn "没有找到根目录加密备份。"
else
  LIFEOS_LATEST_BACKUP="${LIFEOS_BACKUPS[1]}"
  LIFEOS_BACKUP_SIZE="$(lifeos_file_size "$LIFEOS_LATEST_BACKUP")"
  LIFEOS_BACKUP_MIB=$(awk -v bytes="$LIFEOS_BACKUP_SIZE" 'BEGIN { printf "%.2f", bytes / 1048576 }')
  LIFEOS_BACKUP_AGE_DAYS=$(( (LIFEOS_TODAY_EPOCH - $(lifeos_file_mtime "$LIFEOS_LATEST_BACKUP")) / 86400 ))
  lifeos_info "最近备份：$LIFEOS_LATEST_BACKUP，${LIFEOS_BACKUP_MIB} MiB，${LIFEOS_BACKUP_AGE_DAYS} 天前。"

  if (( LIFEOS_BACKUP_SIZE >= 83886080 )); then
    lifeos_warn "加密备份已达到 80 MiB 预警线；在触及 95 MiB 提交保护前决定新的备份存储方式。"
  fi
  if (( LIFEOS_BACKUP_AGE_DAYS > 30 )); then
    lifeos_warn "最近备份超过 30 天。"
  fi
  if [[ ! -f "$LIFEOS_LATEST_BACKUP.sha256" ]]; then
    lifeos_error "最近备份缺少校验文件：$LIFEOS_LATEST_BACKUP.sha256"
  elif ! shasum -a 256 -c "$LIFEOS_LATEST_BACKUP.sha256" >/dev/null 2>&1; then
    lifeos_error "最近备份校验失败：$LIFEOS_LATEST_BACKUP"
  fi
fi

LIFEOS_BENCHMARK="99-系统/检索测试/检索基准.md"
if [[ ! -f "$LIFEOS_BENCHMARK" ]]; then
  lifeos_warn "尚未建立检索基准：$LIFEOS_BENCHMARK"
else
  LIFEOS_BENCHMARK_CASES=$(rg -c '^\| RET-[0-9]+' "$LIFEOS_BENCHMARK" 2>/dev/null || true)
  LIFEOS_BENCHMARK_CASES="${LIFEOS_BENCHMARK_CASES:-0}"
  if (( LIFEOS_BENCHMARK_CASES == 0 )); then
    lifeos_error "检索基准没有有效用例；请按 | RET-001 | 问题 | 入口 | 证据 | 格式记录真实用例。"
  else
    lifeos_info "检索基准：${LIFEOS_BENCHMARK_CASES} 个用例；本检查不验证检索排名，路由修改后需另行回归。"
  fi
fi

LIFEOS_REPORT="99-系统/AI整理报告/${LIFEOS_TODAY[1,7]}.md"
if [[ -f "$LIFEOS_REPORT" ]]; then
  lifeos_info "当月整理报告存在：$LIFEOS_REPORT。"
else
  lifeos_warn "当月尚无整理报告：$LIFEOS_REPORT。"
fi

print
if (( LIFEOS_ERRORS > 0 )); then
  print -u2 "检查未通过：${LIFEOS_ERRORS} 个错误，${LIFEOS_WARNINGS} 个警告。"
  exit 1
fi

print "检查通过：0 个错误，${LIFEOS_WARNINGS} 个警告。"
