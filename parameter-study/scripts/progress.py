from pathlib import Path
import json
R=Path(__file__).resolve().parents[1]
for phase in ['screen','confirm']:
    plan=R/'data'/f'{phase}_plan.json'
    if not plan.exists():continue
    jobs=json.loads(plan.read_text(encoding='utf-8'));counts={};errors=[]
    for j in jobs:
        a=counts.setdefault(j['problem'],dict(planned=0,search_saved=0,completed=0,failed=0));a['planned']+=1
        p=R/'results'/phase/(j['id']+'.mat');a['search_saved']+=p.exists();status=p.with_name(p.stem+'_status.json')
        if status.exists():
            r=json.loads(status.read_text(encoding='utf-8'));a['completed']+=r['ok'];a['failed']+=not r['ok']
            if not r['ok']:errors.append(r)
    print(json.dumps({'phase':phase,'counts':counts,'errors':errors},ensure_ascii=False))
