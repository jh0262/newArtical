classdef P1Stats
    methods (Static)
        function s=paired(a,b,direction)
            assert(isequal(size(a),size(b)),'P1:PairShape','Paired arrays must match');
            good=isfinite(a)&isfinite(b);delta=a(good)-b(good);
            s=struct('NTotal',numel(a),'NValid',nnz(good),'NMissing',nnz(~good), ...
                'MeanDifference',NaN,'MedianDifference',NaN,'CandidateEffect',NaN,'RawP',NaN);
            if isempty(delta),return;end
            s.MeanDifference=mean(delta);s.MedianDifference=median(delta);nz=delta(delta~=0);
            if isempty(nz),s.RawP=1;s.CandidateEffect=0;return;end
            s.RawP=signrank(delta,0,'method','approximate');w=tiedrank(abs(nz));
            s.CandidateEffect=direction*sum(sign(nz).*w)/sum(w);
        end
        function t=adjust(t)
            t.HolmP=nan(height(t),1);t.Outcome=repmat("not_evaluable",height(t),1);
            for metric=unique(t.Metric,'stable')'
                idx=find(t.Metric==metric);p=t.RawP(idx);bad=~isfinite(p);p(bad)=1;
                q=PACPOP1.holm(p);q(bad)=NaN;t.HolmP(idx)=q;
            end
            good=isfinite(t.HolmP);t.Outcome(good)="not_significant";
            t.Outcome(good&t.HolmP<.05&t.CandidateEffect>0)="candidate_better";
            t.Outcome(good&t.HolmP<.05&t.CandidateEffect<0)="candidate_worse";
        end
        function corrected_old()
            root=fileparts(mfilename('fullpath'));old=fullfile(fileparts(root),'MO_PACPO_搜索机制改进_20261024');
            phases={'confirmation','external','ablation','external_ablation','physical'};
            for i=1:numel(phases)
                phase=phases{i};folder=fullfile(old,'results',phase);physical=strcmp(phase,'physical');
                runfile='runs.csv';if physical,runfile='comparison_runs.csv';end
                r=readtable(fullfile(folder,runfile),'TextType','string');
                if contains(phase,'ablation')
                    parent='confirmation';if strcmp(phase,'external_ablation'),parent='external';end
                    q=readtable(fullfile(old,'results',parent,'runs.csv'),'TextType','string');r=[r;q(q.Variant=="candidate",:)];
                end
                prior=readtable(fullfile(folder,'paired_statistics.csv'),'TextType','string');parts=cell(height(prior),1);
                for j=1:height(prior)
                    a=r.Variant=="candidate";b=r.Variant==prior.Comparator(j);
                    if ~physical,a=a&r.Problem==prior.Problem(j);b=b&r.Problem==prior.Problem(j);end
                    aa=sortrows(r(a,:),'Seed');bb=sortrows(r(b,:),'Seed');assert(isequal(aa.Seed,bb.Seed));
                    met=prior.Metric(j);direction=-1;if contains(met,'HV'),direction=1;end
                    row=struct2table(P1Stats.paired(aa.(met),bb.(met),direction));
                    row.Comparator=prior.Comparator(j);row.Metric=met;
                    if ~physical,row.Problem=prior.Problem(j);end
                    parts{j}=row;
                end
                t=P1Stats.adjust(vertcat(parts{:}));dest=fullfile(root,'results','statistics_corrected',phase);
                if ~isfolder(dest),mkdir(dest);end
                writetable(t,fullfile(dest,'paired_statistics.csv'));
            end
        end
    end
end
