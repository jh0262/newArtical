function variants = pade_variants(isDiscrete)
%PADE_VARIANTS Nonredundant nested factorial, plus classical DE comparator.
variants=struct('id',{},'geometry',{},'pulse',{},'jitter',{},'classic',{});
for g=0:2
    for p=0:1
        for j=0:double(isDiscrete)
            v=struct('id',sprintf('G%dP%dJ%d',g,p,j),'geometry',g,...
                'pulse',logical(p),'jitter',logical(j),'classic',false);
            variants(end+1)=v; %#ok<AGROW>
        end
    end
end
variants(end+1)=struct('id','CLASSIC_DE','geometry',0,'pulse',false,...
    'jitter',false,'classic',true);
end
