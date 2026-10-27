# 独立核算的依赖修正

2026-10-27，首次Python核算在导入scipy.stats.rankdata时报告ModuleNotFoundError；尚未开始核算数据。改为按绝对差排序、显式平均并列秩，移除SciPy依赖。Matlab统计程序、原始实验和候选选择均未改变。之后重新运行独立核算，以实际结果判定。
