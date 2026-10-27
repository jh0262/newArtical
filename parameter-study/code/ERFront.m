classdef ERFront
 methods(Static)
 function idx=nd(f)
  % Exact minimization, with duplicate objectives represented once.
  [a,ia]=unique(f,'rows','sorted');n=size(a,1);keep=false(n,1);
  if size(a,2)==2
   best=inf;for i=1:n,if a(i,2)<best,keep(i)=true;best=a(i,2);end;end
  else
   assert(size(a,2)==3);[~,~,rank]=unique(a(:,2));k=max(rank);tree=inf(k,1);low=(1:k)-bitand(1:k,(1:k)-1);
   for i=1:n
    j=rank(i);best=inf;while j>0,best=min(best,tree(j));j=j-low(j);end
    if a(i,3)<best,keep(i)=true;end
    j=rank(i);while j<=k,tree(j)=min(tree(j),a(i,3));j=j+low(j);end
   end
  end
  idx=ia(keep);
 end
 function ix=cap(f)
  % f is unique lexicographically ordered nondominated data.
  n=size(f,1);if n<=100,ix=(1:n)';return;end
  cd=zeros(n,1);for j=1:size(f,2)
   [s,o]=sortrows([f(:,j),(1:n)'],[1 2]);r=s(end,1)-s(1,1);
   if r>0,cd(o([1,end]))=inf;cd(o(2:end-1))=cd(o(2:end-1))+(s(3:end,1)-s(1:end-2,1))/r;end
  end
  [~,o]=sortrows([-cd,(1:n)'],[1 2]);ix=sort(o(1:100));
 end
 end
end
