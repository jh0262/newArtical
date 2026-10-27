function gains=ec_credit(Q,G)
% Individual potential HV gains against ONE fixed observed-data anchor.
lo=min(G,[],1); span=max(max(G,[],1)-lo,eps);
G=(G-lo)./span; Q=(Q-lo)./span; ref=[1.1 1.1];
G=G(ec_nd_indices(G),:); G=G(all(G<ref,2),:);
gains=zeros(size(Q,1),1);
for i=1:size(Q,1)
    q=Q(i,:); if any(q>=ref), continue; end
    below=find(G(:,1)<=q(1),1,'last'); old=ref(2);
    if ~isempty(below), old=G(below,2); end
    middle=G(:,1)>q(1) & G(:,1)<ref(1);
    edges=[q(1);G(middle,1);ref(1)]; heights=[old;G(middle,2)];
    gains(i)=sum(diff(edges).*max(0,heights-q(2)));
end
gains=max(gains,0);
assert(all(isfinite(gains)),'EC:Credit','Nonfinite credit.');
end
