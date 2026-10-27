classdef ECProblem < PROBLEM
    properties
        Base;
        InitialX;
    end
    methods
        function Setting(obj)
            args=obj.parameter; name=args{1}; dimensions=args{2}; initialSeed=args{3};
            obj.Base=feval(name,'N',obj.N,'M',2,'D',dimensions,'maxFE',obj.maxFE);
            obj.M=obj.Base.M; obj.D=obj.Base.D;
            obj.encoding=obj.Base.encoding; obj.lower=obj.Base.lower; obj.upper=obj.Base.upper;
            stream=RandStream('mt19937ar','Seed',initialSeed);
            obj.InitialX=obj.lower+rand(stream,obj.N,obj.D).*(obj.upper-obj.lower);
        end
        function P=Initialization(obj,N)
            if nargin<2, N=obj.N; end
            assert(N==size(obj.InitialX,1),'EC:Initialization','Algorithm changed N.');
            P=obj.Evaluation(obj.InitialX);
        end
        function F=CalObj(obj,X)
            F=obj.Base.CalObj(X);
            assert(size(F,2)==2 && all(isfinite(F),'all'),'EC:InvalidObjectives','Nonfinite benchmark objective.');
        end
        function R=GetOptimum(obj,N)
            R=obj.Base.GetOptimum(N);
        end
        function R=GetPF(~)
            R=[];
        end
    end
end
