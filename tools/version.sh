#!/bin/sh
# 版本号计算：v<主版本>.<年份><字母>，如 v2.2026b；字母 a..z 之后接 aa、ab……
#   tools/version.sh next  v2.2026b [当前年]   常规推进：字母 +1；跨年（当前年 > 版本年）时年份 +1、字母回到 a
#   tools/version.sh major v2.2026b [当前年]   大改：主版本 +1，年份取当前年、字母回到 a
# 当前年默认取系统时间，显式传入是为了脚本和测试可控。
set -eu
op=${1:-}
ver=${2:-}
ynow=${3:-$(date +%Y)}
if [ -z "$op" ] || [ -z "$ver" ]; then
  echo "用法：version.sh next|major v<主版本>.<年份><字母> [当前年]" >&2
  exit 2
fi
printf '%s\n' "$ver" | awk -v op="$op" -v ynow="$ynow" '
  {
    v=$0
    sub(/^v/, "", v)
    if (v !~ /^[0-9]+\.[0-9]{4}[a-z]+$/) {
      print "版本号格式不对：" $0 > "/dev/stderr"; exit 2
    }
    split(v, a, ".")
    major=a[1]; rest=a[2]
    year=substr(rest,1,4)+0; letters=substr(rest,5)
    if (op=="major") { major=major+1; year=ynow+0; letters="a" }
    else if (op=="next") {
      if (ynow+0 > year) { year=ynow+0; letters="a" }
      else letters=inc(letters)
    }
    else { print "未知操作：" op > "/dev/stderr"; exit 2 }
    printf "v%d.%d%s\n", major, year, letters
  }
  function inc(s,   i,c,out,carry,n) {
    carry=1; out=""
    for (i=length(s); i>0; i--) {
      c=substr(s,i,1)
      if (carry) {
        n=index("abcdefghijklmnopqrstuvwxyz", c)
        if (n==26) out="a" out
        else { out=sprintf("%c", 96+n+1) out; carry=0 }
      } else out=c out
    }
    if (carry) out="a" out
    return out
  }
'
