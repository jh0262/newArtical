# MO-PACPO论文与冻结实验同步修订

交付文档：`MO_PACPO_机械工程学报_修正版程序与真实结果同步修订稿.docx`。

内容与来源说明见`修订与核对记录.md`。`audit/revision_preview.pdf`和逐页PNG为内部版面校样。正式编辑文件为DOCX。

## 目录

- `data/`：候选及代表尺寸、TOPSIS、加密积分、独立偏移和敏感性结果。`frozen_tables/`是冻结实验小型CSV表的原样副本。
- `figures/`：流程图及MATLAB科学图；`.fig`保留可编辑图对象，`.pdf`为矢量导出。
- `audit/`：源稿提取、结构和数据核对、全文语言检查、只读Word渲染、文件哈希与来源记录。

完整搜索原始数据继续保存在相邻的`MO_PACPO_搜索机制改进_20261024`中；既有机构模型及基线保存在`MO_PACPO_机构模型修正版_20261023`中。原Word辅助函数位于`MO_PACPO_修正版_20261023/build_manuscript.py`，本构建脚本只用AST提取指定函数，不执行旧构建流程。

## 复现

保持上述相邻目录结构。在MATLAB中进入本目录，依次运行：

```matlab
update_paper_data
make_paper_figures
enlarge_figure_fonts
```

上述操作读取已冻结搜索，重做候选评价、数值检查和绘图，不重新启动优化搜索。使用MATLAB R2025b及所需Statistics and Machine Learning、Parallel Computing工具箱；相关算法依赖以实际安装环境为准。

随后使用含`python-docx`、`lxml`、`numpy`、`Pillow`和`pypdfium2`的Python依次运行：

```text
python -X utf8 make_flow.py
python -X utf8 build_revision.py
python -X utf8 verify_revision.py
```

在已安装Microsoft Word的Windows中运行`render_word.ps1`，再运行`render_preview.py`生成逐页校样。阅读校样后运行`finalize_package.py`登记来源及哈希。本次已完成这些操作，记录对应本次交付文件。重新生成内容后应重新审查校样，不能直接沿用人工检查结论。

本次使用的Python为Codex捆绑运行时：
`C:\Users\hp\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe`。

`inspect_manuscript.py`及`prepare_postprocess.py`是过程辅助文件，正常复现无需再次执行。`audit`中可能留有早期排版迭代的校样图；最终有效页数以`native_render.json`记录的13页为准，最终PDF为`revision_preview.pdf`。
