function s=ec_adapt(s,F,CR,gain,arm,allocate)
success=gain>1e-14;
if ~any(success), return; end
w=gain(success)/sum(gain(success)); sf=F(success); sc=CR(success);
s.MF(s.cursor)=sum(w.*sf.^2)/sum(w.*sf);
s.MCR(s.cursor)=sum(w.*sc);
s.cursor=mod(s.cursor,numel(s.MF))+1;
if allocate
    for j=1:2
        rows=arm==j;
        if any(rows), s.quality(j)=.9*s.quality(j)+.1*mean(gain(rows)); end
    end
    if sum(s.quality)>0, s.pLocal=.1+.8*s.quality(2)/sum(s.quality); end
end
end
