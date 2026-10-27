function hv=ec_hv2(F,ref)
% Exact union of dominated rectangles to a fixed worse reference point.
assert(numel(ref)==2 && all(isfinite(ref)),'EC:Reference','Invalid reference.');
assert(size(F,2)==2 && all(isfinite(F),'all'),'EC:InvalidObjectives','Invalid objectives.');
F=F(all(F<ref,2),:);
if isempty(F), hv=0; return; end
F=F(ec_nd_indices(F),:);
hv=sum(diff([F(:,1);ref(1)]).*(ref(2)-F(:,2)));
end
