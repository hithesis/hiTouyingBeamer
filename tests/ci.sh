#!/bin/sh
# hiTouyingBeamer 的检查，CI 与本地共用（需要 XeLaTeX、biber、poppler 的 pdftoppm）：
#   tests/ci.sh                      命令跨主题检查 + 各主题编译 + 版本/标记检查
#   tests/ci.sh --base <旧版目录>     再与旧版逐页回归对比（CI 的 PR 流水线用它）
# 环境变量 ALLOW_OUTPUT_CHANGE=1 时，回归差异只警告不失败（维护者审核 PR 用）。
set -eu
cd "$(dirname "$0")/.."
root=$(pwd)

base=""
while [ $# -gt 0 ]; do
  case "$1" in
    --base) base=${2:-}; shift 2 ;;
    *) echo "未知参数：$1" >&2; exit 2 ;;
  esac
done

# macOS 上 Xcode 许可可能挡 biber，改走命令行工具。
if [ "$(uname)" = "Darwin" ] && [ -d /Library/Developer/CommandLineTools ]; then
  DEVELOPER_DIR=/Library/Developer/CommandLineTools
  export DEVELOPER_DIR
fi

command -v pdftoppm > /dev/null 2>&1 || { echo "需要 poppler 的 pdftoppm" >&2; exit 2; }

failed=0
problem() { failed=1; printf '!! %s\n' "$*" >&2; }
note() { printf '%s\n' "$*"; }

work=$(mktemp -d "${TMPDIR:-/tmp}/hitouying-ci.XXXXXX")
trap 'rm -rf "$work"' EXIT INT TERM

# 待测版本的源码副本：探针与回归都在这里编译，免得从 ~/texmf 等地方误取 .sty。
head_tree="$work/head"
mkdir -p "$head_tree"
cp "$root/template.tex" "$root/ref.bib" "$root"/*.sty "$head_tree"/
cp -R "$root/vi" "$head_tree"/

# 主题发现：读 beamerthemehit*.sty 文件头的 %% Preview: 标记，输出 theme|aspectratio|output。
theme_list() {
  for f in "$1"/beamerthemehit*.sty; do
    [ -e "$f" ] || continue
    [ "${f##*/}" = "beamerthemehit.sty" ] && continue
    meta=$(grep -m1 '^%% Preview:' "$f" || true)
    [ -n "$meta" ] || continue
    t=$(printf '%s\n' "$meta" | sed -n 's/.*theme=\([^ ]*\).*/\1/p')
    a=$(printf '%s\n' "$meta" | sed -n 's/.*aspectratio=\([^ ]*\).*/\1/p')
    o=$(printf '%s\n' "$meta" | sed -n 's/.*output=\([^ ]*\).*/\1/p')
    [ -n "$t" ] && [ -n "$a" ] && [ -n "$o" ] && printf '%s|%s|%s\n' "$t" "$a" "$o"
  done
}

# ---------------------------------------------------------------- 标记与版本 ----
for f in "$root"/beamerthemehit*.sty; do
  [ -e "$f" ] || continue
  [ "${f##*/}" = "beamerthemehit.sty" ] && continue
  grep -q '^%% Preview:' "$f" || problem "${f##*/} 缺少 %% Preview: 标记，新增主题请按 CONTRIBUTING 补上"
done
themes=$(theme_list "$root")
[ -n "$themes" ] || problem "没有发现任何带 %% Preview: 标记的主题"

vers=$(sed -n 's/^\\ProvidesPackage{[^}]*}\[[0-9/]* *\(v[0-9A-Za-z.]*\).*/\1/p' "$root"/*.sty | sort -u)
if [ "$(printf '%s\n' "$vers" | grep -c .)" -ne 1 ]; then
  problem "各 .sty 的版本号不一致：$(printf '%s ' $vers)"
fi
sub=$(sed -n 's/^\\subtitle{\(.*\)}$/\1/p' "$root/template.tex" | head -n 1)
if [ "$(printf '%s' "$sub" | tr 'A-Z' 'a-z')" != "$(printf '%s' "$vers" | tr 'A-Z' 'a-z')" ]; then
  problem "template.tex 的 \\subtitle（${sub}）与 .sty 版本（${vers}）不一致"
fi

# ---------------------------------------------------------------- 命令跨主题 ----
# 公开命令 = 所有 .sty 里的 \newcommand / \providecommand / \def（排除带 @ 的内部名，
# 以及 beamer 的导航钩子 slideentry/sectionentry——主题里会 \def 覆写它们）。
cmds=$(
  {
    grep -hoE '\\(new|provide)command\{\\[A-Za-z][A-Za-z0-9]*\}' "$root"/*.sty | sed 's/.*{\\//; s/}$//'
    grep -hoE '\\def\\[A-Za-z][A-Za-z0-9]*#' "$root"/*.sty | sed 's/^\\def\\//; s/#$//'
  } | grep -vxE 'slideentry|sectionentry' | sort -u
)
[ -n "$cmds" ] || problem "没有从 .sty 里提取到公开命令"

for line in $themes; do
  t=${line%%|*}; rest=${line#*|}; ar=${rest%%|*}
  probe="$head_tree/probe-$t.tex"
  {
    printf '%s\n' "\\documentclass[aspectratio=$ar]{ctexbeamer}"
    printf '%s\n' "\\usetheme[$t]{hit}"
    printf '%s\n' "\\def\\checkcmd#1{\\ifcsname#1\\endcsname\\else\\errmessage{CI: command #1 is missing in theme $t}\\fi}"
    printf '%s\n' '\begin{document}'
    for c in $cmds; do printf '\\checkcmd{%s}\n' "$c"; done
    printf '%s\n' '\typeout{CI-COMMANDS-OK}'
    printf '%s\n' '\end{document}'
  } > "$probe"
  if ! (cd "$head_tree" && xelatex -no-pdf -interaction=nonstopmode "probe-$t.tex" > "probe-$t.log" 2>&1); then
    grep '^!' "$head_tree/probe-$t.log" | head -n 10 >&2 || true
    problem "主题 $t 的命令可用性检查未通过：有公开命令在这个主题下不存在"
  else
    note "主题 $t 命令检查通过（$(printf '%s\n' $cmds | grep -c .) 个公开命令）"
  fi
done

# 真实调用所有公开命令的文档，逐主题编译。
for line in $themes; do
  t=${line%%|*}
  sed "s/\\\\usetheme{hit}/\\\\usetheme[$t]{hit}/" "$root/tests/commands.tex" > "$head_tree/commands-$t.tex"
  if ! (cd "$head_tree" && xelatex -interaction=nonstopmode "commands-$t.tex" > /dev/null 2>&1 &&
        xelatex -interaction=nonstopmode "commands-$t.tex" > "commands-$t.log" 2>&1); then
    grep '^!' "$head_tree/commands-$t.log" | head -n 10 >&2 || true
    problem "主题 ${t}：tests/commands.tex 编译失败"
  else
    note "主题 ${t}：tests/commands.tex 编译通过"
  fi
done

# ------------------------------------------------------------------ 回归对比 ----
if [ -n "$base" ]; then
  base=$(cd "$base" && pwd)
  base_themes=$(theme_list "$base")
  # 删主题（base 有、head 没有）必须人工审核
  for bline in $base_themes; do
    bt=${bline%%|*}
    if ! printf '%s\n' "$themes" | grep -q "^$bt|"; then
      problem "主题 ${bt} 在当前版本里被删除，需要人工审核"
    fi
  done

  base_tree="$work/base"
  mkdir -p "$base_tree"
  cp "$base/template.tex" "$base/ref.bib" "$base"/*.sty "$base_tree"/
  cp -R "$base/vi" "$base_tree"/

  for line in $themes; do
    t=${line%%|*}; rest=${line#*|}; ar=${rest%%|*}
    bline=$(printf '%s\n' "$base_themes" | grep "^$t|" || true)
    if [ -z "$bline" ]; then
      note "主题 $t 在 base 版本里没有（新主题），跳过回归"
      continue
    fi

    ok=1
    for side in base head; do
      if [ "$side" = "base" ]; then tree=$base_tree; else tree=$head_tree; fi
      sed -e "s/\\\\usetheme{hit}/\\\\usetheme[$t]{hit}/" \
          -e "s/aspectratio=169/aspectratio=$ar/" \
          -e "s/\\\\subtitle{[^}]*}/\\\\subtitle{CI-NORMALIZED}/" \
          -e "s/\\\\date{[^}]*}/\\\\date{CI-NORMALIZED}/" \
          "$tree/template.tex" > "$tree/tpl-$t.tex"
      if ! (cd "$tree" && latexmk -xelatex -interaction=nonstopmode "tpl-$t.tex" > "tpl-$t.log" 2>&1); then
        grep '^!' "$tree/tpl-$t.log" | head -n 10 >&2 || true
        problem "$side 版主题 $t 编译失败"
        ok=0
      fi
    done
    [ "$ok" = 1 ] || continue

    bd="$work/render-base-$t"; hd="$work/render-head-$t"
    mkdir -p "$bd" "$hd"
    pdftoppm -r 100 -png "$base_tree/tpl-$t.pdf" "$bd/p"
    pdftoppm -r 100 -png "$head_tree/tpl-$t.pdf" "$hd/p"

    diff_pages=""
    for f in "$bd"/p-*.png; do
      n=${f##*/}
      cmp -s "$f" "$hd/$n" || diff_pages="$diff_pages ${n#p-}"
    done
    bc=$(ls "$bd" | wc -l | tr -d ' ')
    hc=$(ls "$hd" | wc -l | tr -d ' ')

    if [ -n "$diff_pages" ] || [ "$bc" -ne "$hc" ]; then
      mkdir -p "$root/ci-out"
      cp "$base_tree/tpl-$t.pdf" "$root/ci-out/$t-base.pdf"
      cp "$head_tree/tpl-$t.pdf" "$root/ci-out/$t-head.pdf"
      msg="主题 $t 的输出有变化：页数 $bc -> ${hc}，差异页${diff_pages:-（页数不同）}"
      if [ "${ALLOW_OUTPUT_CHANGE:-}" = "1" ]; then
        note "（已打标签，放行）$msg"
      else
        problem "${msg}。需要人工审核：确认是有意改动后，由维护者给 PR 打 theme-output-change 标签重跑；两份 PDF 已放进 ci-out/"
      fi
    else
      note "主题 $t 回归通过（$hc 页逐页一致）"
    fi
  done
fi

if [ "$failed" -eq 0 ]; then
  note "CI 通过"
else
  note "CI 未通过"
  exit 1
fi
