#!/bin/sh
# 推送包装：代替 git push 用。推送前自动完成：
#   1. 与 $remote/main 逐页回归对比（复跑 tests/ci.sh --base），统计差异页占比；
#   2. 按规则前进版本号（tools/version.sh）：常规字母 +1；差异 >30% 主版本 +1；
#      跨年年份 +1、字母重置。所有 .sty 与 template.tex 的版本号同步更新；
#   3. 重建预览（build-previews.sh），提交一条 "bump: vX -> vY"；
#   4. 推送当前分支。
# 用法：
#   tools/push.sh [remote] [branch]      默认 origin 与当前分支
#   tools/push.sh --dry-run [remote] [branch]   只做到提交，不推送
# 规则说明见 CONTRIBUTING「发布流程」。
set -eu
cd "$(dirname "$0")/.."
root=$(pwd)

dry=""
if [ "${1:-}" = "--dry-run" ]; then dry=1; shift; fi
remote=${1:-origin}
branch=${2:-$(git rev-parse --abbrev-ref HEAD)}
if [ "$branch" = "HEAD" ]; then echo "当前是 detached HEAD，请显式给出分支名" >&2; exit 2; fi
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "工作区有未提交改动，先提交或 stash 再推送" >&2; exit 2
fi

ver=$(sed -n 's/^\\ProvidesPackage{beamerthemehit}\[[0-9/]* *\(v[0-9A-Za-z.]*\).*/\1/p' beamerthemehit.sty | head -n 1)
if [ -z "$ver" ]; then echo "读不到当前版本号（beamerthemehit.sty 的 \\ProvidesPackage）" >&2; exit 2; fi

# 与 $remote/main 对比：取旧版源码树，让 ci.sh 做逐页回归并给出差异统计。
echo "== 与 $remote/main 逐页对比（要编译几分钟）=="
git fetch -q "$remote" main
base=$(mktemp -d "${TMPDIR:-/tmp}/hitouying-push.XXXXXX")
trap 'rm -rf "$base"' EXIT INT TERM
git archive "$remote/main" | tar -x -C "$base"
out=$(ALLOW_OUTPUT_CHANGE=1 sh tests/ci.sh --base "$base" 2>&1) || {
  printf '%s\n' "$out" | tail -n 20 >&2
  echo "CI 检查未通过，先修复再推送（差异本身不拦，其他问题会）" >&2
  exit 1
}
diff_line=$(printf '%s\n' "$out" | sed -n 's/^CI-DIFF: \([0-9][0-9]*\)\/\([0-9][0-9]*\)$/\1 \2/p' | tail -n 1)
set -- $diff_line
dp=${1:-0}; tp=${2:-0}
pct=$(awk -v d="$dp" -v t="$tp" 'BEGIN{ if (t+0<1) print "0.0"; else printf "%.1f", 100*d/t }')
echo "差异页 $dp/${tp}（${pct}%），当前版本 $ver"

op=next
if awk -v p="$pct" 'BEGIN{ exit !(p+0 > 30) }'; then op=major; fi
new=$(sh tools/version.sh "$op" "$ver")

# 同步版本号：所有 .sty 的 \ProvidesPackage 与 template.tex 的 \subtitle。
vdate=$(date +%Y/%-m/%-d)
for f in *.sty; do
  perl -pi -e "s{\[([0-9/]+) (v[0-9A-Za-z.]+)([^\]]*)\]}{[$vdate $new\3]} if /^\\\\ProvidesPackage/" "$f"
done
perl -pi -e "s!\\\\subtitle\\{[^}]*\\}!\\\\subtitle{V${new#v}}!" template.tex
if [ "$op" = "major" ]; then
  why="与 main 的逐页差异 ${pct}%（>30%），主版本 +1"
else
  why="常规推进（与 main 的逐页差异 ${pct}%）"
fi
echo "版本 $ver -> ${new}（${why}）"

echo "== 重建预览 =="
sh build-previews.sh

git add -A
git commit -q -m "bump: $ver -> $new" -m "${why}；预览已按新版本号重建。"
echo "已提交：$(git log --oneline -1)"

if [ -n "$dry" ]; then
  echo "（--dry-run）未推送；要推送就执行：git push $remote $branch"
elif git rev-parse --abbrev-ref --symbolic-full-name "$branch@{u}" > /dev/null 2>&1; then
  git push "$remote" "$branch"
else
  git push -u "$remote" "$branch"
fi
