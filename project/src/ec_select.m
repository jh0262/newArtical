function [idx,info]=ec_select(F,N,useEar)
[rank,last]=NDSort(F,N);
idx=find(rank<last); overflow=find(rank==last); K=N-numel(idx);
info=struct('fallback',false,'coverage',0,'bound',0,'deletions',0,'earApplied',false);
if K>0
    if useEar && K<numel(overflow)
        [local,z]=ec_earclip(F(overflow,:),K);
        info.fallback=z.fallback; info.coverage=z.coverage;
        info.bound=z.bound; info.deletions=z.deletions; info.earApplied=true;
    else
        local=ec_cd_subset(F(overflow,:),K);
    end
    idx=[idx,overflow(local)];
end
assert(numel(idx)==N && numel(unique(idx))==N);
end
