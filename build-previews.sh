#!/bin/sh
# 发布前生成所有子主题的预览 PDF 与封面图，放进仓库。
# PDF 在仓库根目录（README 预览链接用），封面图在 preview/（README 缩略图用）。
# 主题自动发现：扫描 beamerthemehit*.sty（入口 beamerthemehit.sty 除外），
# 凡带下面这行标记的都算一个主题，新增主题只要加皮肤文件并在文件头写标记：
#   %% Preview: theme=<主题选项> aspectratio=<169|43> output=<预览 PDF 文件名>
# 在临时目录里编译，只把成品拷回仓库。需要 XeLaTeX、latexmk、biber 与
# poppler（pdftoppm 出封面图）。
set -eu
cd "$(dirname "$0")"
root=$(pwd)

# macOS 上 Xcode 许可可能挡 biber，改走命令行工具。
if [ "$(uname)" = "Darwin" ] && [ -d /Library/Developer/CommandLineTools ]; then
  DEVELOPER_DIR=/Library/Developer/CommandLineTools
  export DEVELOPER_DIR
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/hitouying-preview.XXXXXX")
trap 'rm -rf "$work"' EXIT INT TERM

cp template.tex ref.bib ./*.sty "$work"/
cp -R vi "$work"/
mkdir -p "$root/preview"

found=0
for f in beamerthemehit*.sty; do
  if [ "$f" = "beamerthemehit.sty" ]; then
    continue
  fi
  meta=$(grep -m1 '^%% Preview:' "$f" || true)
  if [ -z "$meta" ]; then
    continue
  fi
  theme=$(printf '%s\n' "$meta" | sed -n 's/.*theme=\([^ ]*\).*/\1/p')
  ar=$(printf '%s\n' "$meta" | sed -n 's/.*aspectratio=\([^ ]*\).*/\1/p')
  out=$(printf '%s\n' "$meta" | sed -n 's/.*output=\([^ ]*\).*/\1/p')
  if [ -z "$theme" ] || [ -z "$ar" ] || [ -z "$out" ]; then
    echo "跳过 ${f}：Preview 标记不完整" >&2
    continue
  fi

  echo "== 编译主题 ${theme}（aspectratio=${ar}）-> ${out}"
  job="preview-$theme"
  sed -e "s/\\\\usetheme{hit}/\\\\usetheme[$theme]{hit}/" \
      -e "s/aspectratio=169/aspectratio=$ar/" \
      template.tex > "$work/$job.tex"
  if ! (cd "$work" && latexmk -xelatex "$job.tex" > "$job.build.log" 2>&1); then
    echo "!! 主题 ${theme} 编译失败，日志尾部：" >&2
    tail -n 40 "$work/$job.build.log" >&2 || true
    exit 1
  fi
  cp "$work/$job.pdf" "$root/$out"
  pdftoppm -png -singlefile -r 100 -f 1 -l 1 "$work/$job.pdf" "$root/preview/$theme"
  found=$((found + 1))
done

if [ "$found" -eq 0 ]; then
  echo "没找到带 Preview 标记的主题" >&2
  exit 1
fi
echo "生成完成，共 $found 个主题预览。"
