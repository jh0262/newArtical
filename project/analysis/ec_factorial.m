function E=ec_factorial(Y)
% Columns G000,G001,...,G111. Main effects are ON minus OFF.
% Interactions are differences of differences, averaged over other factors.
assert(size(Y,2)==8);
bits=dec2bin(0:7,3)-'0'; signs=2*bits-1;
terms={[1],[2],[3],[1 2],[1 3],[2 3],[1 2 3]};
E=zeros(size(Y,1),7);
for k=1:7
    cols=terms{k}; contrast=prod(signs(:,cols),2);
    E(:,k)=Y*contrast/(2^(3-numel(cols)));
end
end
