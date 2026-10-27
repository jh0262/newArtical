function idx=ec_nd_indices(F)
% Unique bi-objective nondominated indices, both objectives minimized.
assert(size(F,2)==2 && all(isfinite(F),'all'),'EC:InvalidObjectives','Finite M=2 objectives required.');
if isempty(F), idx=zeros(0,1); return; end
[S,o]=sortrows(F,[1 2]);
keep=S(:,2)<[inf;cummin(S(1:end-1,2))];
idx=o(keep);
end
