# 贡献指南

欢迎提 issue 和 PR。CI（`.github/workflows/ci.yml`）会跑 `tests/ci.sh`，本地也可以先跑一遍。

## 硬规则（CI 会查）

### 1. 新增命令必须在所有主题下都可以用

公开命令统一定义在共用命令层 `beamercmdhit.sty`，不要定义只有某个主题能用的命令；
确实与主题相关的外观，放到主题文件里用模板/颜色实现，而不是新命令。

CI 会扫描所有 `.sty` 里的公开命令（`\newcommand`、`\providecommand`、`\def`，排除带
`@` 的内部名），逐主题用 `\ifcsname` 探测，缺一个就不通过。新命令请同时：

- 加进 `tests/commands.tex`（真实调用一遍）；
- 在 README 的命令表里记一笔；
- 确认它在 `\usetheme{hit}`、`\usetheme[classic]{hit}` 和 `\usetheme[minimalist]{hit}` 下行为一致，除非有意为之。

### 2. 主题输出变化必须人工审核

CI 会把 PR 的每个主题与目标分支逐页对比（同环境各编一遍，渲染成图后逐页比对）。
下面两种不算变化、自动放行：比对前会把 `template.tex` 的 `\subtitle` 与 `\date`
归一化（改版本号、换日期不拦）；新增主题没有对照基准，直接跳过。其余情况下任何一页
有变化都会失败，并把两份 PDF 传到 `ci-out/` 供查看；删除主题也按失败处理。

- 如果是**有意**的视觉改动：维护者审核产物后，给 PR 打上 `theme-output-change`
  标签再跑一次，回归检查放行。合并后，新输出就是后续 PR 的对照基准。
- 如果是**无意**的变化：请修到逐页一致再提交。

### 3. 发布流程

- **版本号**：所有 `.sty` 的 `\ProvidesPackage` 与 `template.tex` 的 `\subtitle`
  同步更新（`v2.2026b` 这样），CI 会核对一致。
- **预览 PDF 与封面图**：发布前跑一次 `./build-previews.sh`；它在临时目录里编译所有
  子主题，只把成品拷回仓库——PDF 在根目录（现代 `template.pdf`、经典
  `template-classic.pdf`、简约 `template-minimalist.pdf`），封面图在 `preview/`
  （README 的缩略图用它），不会在仓库里留中间产物。
- **新增主题**：加 `beamerthemehit<名字>.sty`，在文件头写标记
  `%% Preview: theme=<名字> aspectratio=<169|43> output=<预览文件名>`；
  `build-previews.sh` 与 CI 扫的就是这行标记，会自动发现新主题，不用改脚本。
- 打 tag（如 `v2.2026b`）并推送。

提交信息用 `feat:` / `fix:` / `docs:` 前缀加中文描述；版本 bump 单独一行
`bump: vX -> vY`。

## 本地自测

```console
./tests/ci.sh                    # 命令跨主题检查 + 各主题编译 + 版本/标记检查
./tests/ci.sh --base <旧版目录>   # 再加逐页回归对比
```

需要 TeX Live（XeLaTeX + biber）和 poppler（`pdftoppm`）。
