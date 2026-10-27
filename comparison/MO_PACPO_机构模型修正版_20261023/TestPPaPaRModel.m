classdef TestPPaPaRModel < matlab.unittest.TestCase
    properties (TestParameter)
        poseCase={ [500,0,-1000,0], [1000,300,-1100,pi/6], [1500,-100,-1500,-pi/9] };
    end
    methods (Test)
        function literatureInverse(t)
            m=PPaPaRModel.config(256); g=PPaPaRModel.geometry([400,700,1000,150],m);
            poses=[0,0,-1000,0;1000,300,-1100,pi/6;1500,-100,-1500,-pi/9];
            expected=[0,0,7.141,7.141;1038,963,41.882,-7.250;1474,1525.7,32.449,43.643];
            actual=cell2mat(arrayfun(@(i)PPaPaRModel.inverse(poses(i,:),g,m), (1:3)','UniformOutput',false));
            t.verifyEqual(actual(:,1:2),expected(:,1:2),'AbsTol',.6);
            t.verifyEqual(actual(:,3:4)*180/pi,expected(:,3:4),'AbsTol',.001);
        end
        function closedLoopAndRoundTrip(t,poseCase)
            m=PPaPaRModel.config(256); g=PPaPaRModel.geometry([400,700,1000,150],m);
            [v,valid]=PPaPaRModel.inverse(poseCase,g,m);
            [p,forwardValid]=PPaPaRModel.forward(v,g,m);
            [J,S,A,B,C,phi]=PPaPaRModel.differential(poseCase,v,g);
            t.verifyTrue(valid && forwardValid);
            t.verifyEqual(p,poseCase,'AbsTol',1e-9);
            t.verifyLessThan(max(abs(phi)),1e-8);
            t.verifyLessThan(norm(A*J+B,'fro'),1e-7);
            t.verifyLessThan(norm(A*S+C,'fro'),1e-8);
        end
        function inputDifferential(t,poseCase)
            m=PPaPaRModel.config(256); g=PPaPaRModel.geometry([400,700,1000,150],m);
            v=PPaPaRModel.inverse(poseCase,g,m); J=PPaPaRModel.differential(poseCase,v,g);
            numeric=TestPPaPaRModel.difference(v,[1e-3,1e-3,1e-6,1e-6],@(u)PPaPaRModel.forward(u,g,m));
            t.verifyLessThan(norm(J-numeric,'fro')/norm(J,'fro'),1e-7);
        end
        function geometricDifferential(t,poseCase)
            m=PPaPaRModel.config(256); g=PPaPaRModel.geometry([400,700,1000,150],m);
            v=PPaPaRModel.inverse(poseCase,g,m); [~,S]=PPaPaRModel.differential(poseCase,v,g);
            numeric=TestPPaPaRModel.difference(g,1e-3*ones(1,8),@(gg)PPaPaRModel.forward(v,gg,m));
            t.verifyLessThan(norm(S-numeric,'fro')/norm(S,'fro'),1e-7);
        end
        function vectorizedMatchesImplicit(t)
            m=PPaPaRModel.config(512); d=[400,700,1000,150]; g=PPaPaRModel.geometry(d,m);
            [w,v,k,p,u]=PPaPaRModel.integrand(d,m); ids=find(w>0); ids=ids(1:7:end);
            actual=TestPPaPaRModel.pointMetrics(p(ids,:),u(ids,:),g,m);
            t.verifyEqual(v(ids),actual(:,1),'RelTol',1e-10);
            t.verifyEqual(k(ids),actual(:,2),'RelTol',1e-10);
            t.verifyGreaterThan(k(ids),0); t.verifyLessThanOrEqual(k(ids),1);
        end
        function unitInvariance(t)
            m=PPaPaRModel.config(1024); d=[400,700,1000,150]; f=PPaPaRModel.evaluate(d,m);
            z=m; z.L=m.L/1000; z.n=m.n/1000; z.l0=m.l0/1000;
            z.sigmaQ=m.sigmaQ/1000; z.sigmaG=m.sigmaG/1000; z.unitToCm3=1e6;
            ff=PPaPaRModel.evaluate(d/1000,z);
            t.verifyEqual(ff,[f(1),f(2)/1000,f(3)],'RelTol',1e-10);
        end
        function invalidAndSingular(t)
            m=PPaPaRModel.config(256); g=PPaPaRModel.geometry([400,700,1000,150],m);
            [~,v1]=PPaPaRModel.inverse([1000,0,-3000,0],g,m);
            [~,v2]=PPaPaRModel.inverse([-100,0,-1000,0],g,m);
            [~,v3]=PPaPaRModel.forward([1075,925,.2,.2],g,m);
            [~,v4]=PPaPaRModel.inverse([1000,0,-1000,pi/2],g,m);
            [~,v5]=PPaPaRModel.forward([1000,1000,1.8,1.8],g,m);
            t.verifyFalse(any([v1,v2,v3,v4,v5]));
        end
        function zeroErrors(t)
            m=PPaPaRModel.config(1024); m.sigmaQ=0; m.sigmaAlpha=0; m.sigmaG(:)=0;
            f=PPaPaRModel.evaluate([400,700,1000,150],m);
            t.verifyEqual(f(2),0); t.verifyLessThan(f(1),0);
        end
        function noFeasibleSamples(t)
            m=PPaPaRModel.config(128); m.margin=2;
            [f,cv]=PPaPaRModel.evaluate([400,700,1000,150],m);
            t.verifyEqual(f,[0,100,0]); t.verifyGreaterThan(cv,0);
        end
        function separateSingularities(t)
            m=PPaPaRModel.config(256); d=[400,700,1000,150]; g=PPaPaRModel.geometry(d,m);
            [~,serialOK]=PPaPaRModel.inverse([1000,175,-340,0],g,m);
            al=.5; gp=g; gp(4:5)=125+700*cos(al);
            pp=[1000,0,-340-700*sin(al),0]; vv=[1000,1000,al,al];
            [~,parallelOK]=PPaPaRModel.inverse(pp,gp,m);
            [~,~,A,B]=PPaPaRModel.differential(pp,vv,gp);
            t.verifyFalse(serialOK || parallelOK);
            t.verifyLessThan(rank(A),4); t.verifyEqual(rank(B),4);
        end
        function sharedPointsDeterministic(t)
            m=PPaPaRModel.config(1024); z=PPaPaRModel.config(2048);
            t.verifyEqual(m.alpha,z.alpha(1:1024));
            t.verifyEqual(PPaPaRModel.evaluate([400,700,1000,150],m),PPaPaRModel.evaluate([400,700,1000,150],m));
        end
    end
    methods (Static)
        function D=difference(x,h,fun)
            D=zeros(4,numel(x));
            for i=1:numel(x)
                xp=x; xm=x; xp(i)=xp(i)+h(i); xm(i)=xm(i)-h(i);
                D(:,i)=(fun(xp)-fun(xm))'/(2*h(i));
            end
        end
        function a=pointMetrics(p,u,g,m)
            a=zeros(size(p,1),2);
            for i=1:size(p,1)
                [a(i,1),a(i,2)]=PPaPaRModel.local(p(i,:),u(i,:),g,m);
            end
        end
    end
end
