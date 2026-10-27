classdef ERTape
    % Exact replay of previously evaluated points. No objective approximation.
    methods (Static)
        function out=store(action,value)
            persistent data index
            if isempty(index),index=0;end
            switch action
                case 'set',data=value;index=0;out=[];
                case 'clear',data=[];index=0;out=[];
                case 'active',out=~isempty(data);
                case 'next'
                    n=value;assert(index+n<=size(data,1));out=data(index+(1:n),:);index=index+n;
                case 'count',out=index;
            end
        end
        function yes=active(),yes=ERTape.store('active',[]);end
        function [f,cv,g]=take(p,x)
            q=ERTape.store('next',size(x,1));
            assert(isequal(x,p.lb+q(:,1:p.D).*(p.ub-p.lb)),'P4:Replay','Replay decision mismatch');
            f=q(:,p.D+(1:p.M));cv=q(:,end-1);g=zeros(size(x,1),0);
        end
    end
end
