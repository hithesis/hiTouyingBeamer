# 更现代的哈尔滨工业大学 Beamer 幻灯片主题 hiTouyingBeamer（读作「嗨！投影 Beamer」）

本主题的灵感来自于上海交通大学 Touying 幻灯片主题
（[touying-simpl-sjtu](https://github.com/sjtug/touying-sjtu)）。

## 文件结构

| 文件 | 说明 |
| --- | --- |
| `beamerthemehit.sty` | 主题样式（`\usetheme{hit}`）：颜色、字体、模板、版式 |
| `beamercmdhit.sty` | 文档命令（`\TitleSlide` 等），主题会自动加载 |
| `template.tex` | 模板兼完整示例（动画、TikZ、双栏、跨页、GB/T 7714 参考文献等），从这里开始写 |
| `vi/` | 哈尔滨工业大学视觉形象素材（均获取自网络，经 AI 处理，如有侵权请联系 hiThesis 团队） |

样式与命令是分开的。`beamercmdhit.sty` 里的专用命令在加载 hit 主题时会处理为定制版式，
而未加载时自动改用标准 Beamer 写法，例如 `\titlepage`、`\tableofcontents`。
所以只要文档里保留 `\usepackage{beamercmdhit}`，把 `\usetheme{hit}` 换成任意
内建主题（如 `Madrid`）仍可直接编译。

## 使用

```latex
\documentclass[aspectratio=169]{ctexbeamer}
\usetheme{hit}

\title{标题}
\subtitle{副标题}
\author{作者}
\institute{哈尔滨工业大学}
\date{\today}

\begin{document}
\TitleSlide      % 白色标题页（或 \BlueTitleSlide 蓝色标题页）
\OutlineSlide    % 目录页

\section{...}    % 每个 \section 自动生成章节过渡页
\subsection{...}
\begin{frame}{帧标题}
  ...
\end{frame}

\appendix        % 附录：隐藏页脚并冻结页码总数
\EndSlide{感谢使用\par\medskip Thanks for  Using!}
\end{document}
```

应使用 XeLaTeX 编译：

```console
latexmk -xelatex template.tex
```

`template.tex` 中的参考文献使用 `biblatex-gb7714-2015`，需要 `biber`
（`latexmk` 会自动调用）。章节过渡页与导航条需要编译两遍才能稳定。

## 专用命令

| 命令 | 说明 |
| --- | --- |
| `\TitleSlide` / `\BlueTitleSlide` | 白色 / 蓝色标题页 |
| `\OutlineSlide` | 目录页（标题文字可 `\renewcommand{\hitoutlinetitle}{...}`） |
| `\FocusSlide{...}` | 蓝底白字强调页 |
| `\EndSlide{...}` | 结束页 |
| `\hitfooter{...}` | 页脚左侧文字（默认继承  `\institute`） |
| `\renewcommand{\hitvipath}{...}` | `vi/` 视觉形象资产目录路径（默认 `vi/`） |

封面与目录属于前置页，用小写罗马数字计数（`i`、`ii`、`iii`），正文页码从 1 重新起算。

## 主题选项

```latex
\usetheme[serif]{hit}          % 使用衬线字体（默认非衬线）
\usetheme[top]{hit}            % 正文顶端对齐（默认垂直居中）
\usetheme[navsymbols]{hit}     % 显示右下角翻页按钮（默认隐藏），
\usetheme[nosectionpage]{hit}  % 不自动生成章节过渡页
```

## 把主题装进 TeX 目录树（可选）

若不想把 `beamerthemehit.sty` 和 `vi/` 复制到每个项目，可将它们放入
`TEXMFHOME`（如 `~/texmf/tex/latex/beamer-simpl-hit/`），并在文档中
`\renewcommand{\hitvipath}{<vi 的绝对路径>/}`。

## License

本项目采用 LaTeX Project Public License 1.3c（LPPL-1.3c）发布，详见 [LICENSE](LICENSE)。
维护状态为 `maintained`，当前维护者 @SchrodingerBlume。
