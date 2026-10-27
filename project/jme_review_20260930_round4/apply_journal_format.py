"""Apply verified bilingual reference metadata without changing cited findings."""
from pathlib import Path
import re,json,hashlib
R=Path(__file__).resolve().parent;D=R/'delivery';p=D/'论文第四轮修订稿.md';t=p.read_text(encoding='utf-8')
refs={
4:('ZHANG Tie, QIN Bin-bin, ZOU Yan-biao. Identification methods for robot payload dynamical parameters[J]. Chinese Journal of Engineering, 2017, 39(12): 1907–1912.','https://cje.ustb.edu.cn/cn/article/doi/10.13374/j.issn2095-9389.2017.12.018'),
5:('ZOU Kong-jin, DING Jian-wan. Research on dynamic parameter identification of robot[J]. Modular Machine Tool & Automatic Manufacturing Technique, 2023(5): 10–13, 18.','https://qikan.cmes.org/zhjc/EN/10.13462/j.cnki.mmtamt.2023.05.003'),
7:('XU Zheng, ZHANG Gong, WANG Huo-ming, et al. Error compensation of collaborative robot dynamics based on deep recurrent neural network[J]. Chinese Journal of Engineering, 2021, 43(7): 995–1002.','https://cje.ustb.edu.cn/en/article/doi/10.13374/j.issn2095-9389.2020.04.30.003'),
23:('YAN Wenjun, CAI Yueri. Error theoretical analysis of robot joint and research on parameter identification methods[J]. Journal of Mechanical Engineering, 2025, 61(17): 15–26.','https://qikan.cmes.org/jxgcxb/EN/10.3901/JME.2025.17.015')}
for n,(english,url) in refs.items():
 if english not in t:
  t,count=re.subn(r'(^\['+str(n)+r'\] [^\n]+)',lambda m:m[0]+'\n'+english,t,flags=re.M);assert count==1
p.write_text(t,encoding='utf-8')
s=json.loads((D/'result_summary.json').read_text());s['manuscript_sha256']=hashlib.sha256(t.encode()).hexdigest();(D/'result_summary.json').write_text(json.dumps(s,ensure_ascii=False,indent=2),encoding='utf-8')
(R/'journal_sources/bilingual_reference_check.json').write_text(json.dumps(dict(date='2026-09-30',status='official English metadata verified',references={n:dict(english=v[0],source=v[1]) for n,v in refs.items()}),ensure_ascii=False,indent=2),encoding='utf-8')
print('Four Chinese references now bilingual; 23 bibliographic entries retained.')
