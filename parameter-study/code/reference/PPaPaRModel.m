classdef PPaPaRModel
    % Rigid 3T1R closed-loop model; lengths mm, angles rad.
    % Pu et al. (2023), DOI 10.3969/j.issn.1004-132X.2023.19.004.
    methods (Static)
        function m = config(count, shift, margin)
            if nargin<1, count=4096; end
            if nargin<2, shift=zeros(1,3); end
            if nargin<3, margin=.02; end
            m=struct('L',2000,'n',340,'alphaLimits',[-10,50]*pi/180, ...
                'margin',margin,'l0',1000,'sigmaQ',.01,'sigmaAlpha',.01*pi/180, ...
                'sigmaG',.05*ones(1,8),'count',count,'shift',shift,'unitToCm3',.001);
            u=mod(net(sobolset(3,'Skip',1024),count)+shift,1);
            m.alpha=m.alphaLimits(1)+diff(m.alphaLimits)*u(:,1);
            m.beta=pi*u(:,2).^2; m.betaWeight=2*u(:,2);
            % Importance transform clusters theta points at rotational boundaries.
            % Integrate over cos(theta)>margin, with dtheta/dpsi=cos(theta).
            m.psiMax=acosh(1/margin);
            m.theta=asin(tanh((2*u(:,3)-1)*m.psiMax));
            m.ca=cos(m.alpha); m.sa=sin(m.alpha);
            m.cb=cos(m.beta); m.sb=sin(m.beta);
            m.ct=cos(m.theta); m.st=sin(m.theta);
            m.sinAB=sin(m.alpha+m.beta);
        end

        function g = geometry(d,m)
            g=[d(1),d(2),d(2),d(3),d(3),d(4),m.n,m.n];
        end

        function [v,ok,aux] = inverse(p,g,m)
            y=p(2); z=p(3); th=p(4); a=g(1); d=g(6);
            u=[y,-y]+(a-d*cos(th))/2; N=z+g(7:8);
            b=g(2:3); c=g(4:5); rr=hypot(u,N);
            ratio=(c.^2-rr.^2-b.^2)./(2*b.*rr);
            realOK=all(rr>0 & abs(ratio)<=1+1e-12);
            alpha=atan2(N,u)+acos(max(-1,min(1,ratio)));
            v=[p(1)+d*sin(th)/2,p(1)-d*sin(th)/2,alpha];
            hh=u+b.*cos(alpha); vv=N+b.*sin(alpha);
            kk=b.*(-hh.*sin(alpha)+vv.*cos(alpha));
            detU=hh(1)*vv(2)+hh(2)*vv(1);
            ok=realOK && all(v(1:2)>=-1e-9 & v(1:2)<=m.L+1e-9) ...
                && all(alpha>=m.alphaLimits(1)-1e-12 & alpha<=m.alphaLimits(2)+1e-12) ...
                && all(vv<0) && all(-kk./(b.*c)>m.margin) ...
                && -detU/prod(c)>m.margin && cos(th)>m.margin;
            aux=struct('h',hh,'v',vv,'k',kk,'detU',detU,'real',realOK);
            if ~realOK, v(:)=nan; end
        end

        function [p,ok,candidates] = forward(v,g,m)
            % Circle intersections give both assembly modes. Limits/aspect select one.
            p=nan(1,4); ok=false; candidates=nan(2,4);
            ratio=(v(1)-v(2))/g(6);
            if ~all(isfinite(v)) || abs(ratio)>=1, return; end
            th=asin(ratio); x=mean(v(1:2)); off=(g(1)-g(6)*cos(th))/2;
            centers=[-off-g(2)*cos(v(3)),-g(7)-g(2)*sin(v(3)); ...
                off+g(3)*cos(v(4)),-g(8)-g(3)*sin(v(4))];
            delta=centers(2,:)-centers(1,:); distance=norm(delta);
            if distance<1e-12 || distance>g(4)+g(5) || distance<abs(g(4)-g(5)), return; end
            along=(g(4)^2-g(5)^2+distance^2)/(2*distance);
            height2=g(4)^2-along^2;
            if height2<0, return; end
            center=centers(1,:)+along*delta/distance;
            perp=[-delta(2),delta(1)]/distance;
            yz=[center+sqrt(height2)*perp;center-sqrt(height2)*perp];
            candidates=[repmat(x,2,1),yz,repmat(th,2,1)];
            for k=1:2
                [vv,valid]=PPaPaRModel.inverse(candidates(k,:),g,m);
                if valid && max(abs(vv-v))<1e-7
                    p=candidates(k,:); ok=true; return;
                end
            end
        end

        function [J,S,A,B,C,phi] = differential(p,v,g)
            a=g(1); b=g(2:3); c=g(4:5); d=g(6); th=p(4);
            h=[p(2),-p(2)]+(a-d*cos(th))/2+b.*cos(v(3:4));
            z=p(3)+g(7:8)+b.*sin(v(3:4));
            k=b.*(-h.*sin(v(3:4))+z.*cos(v(3:4)));
            A=[-1,0,0,-d*cos(th)/2;-1,0,0,d*cos(th)/2; ...
                0,2*h(1),2*z(1),d*h(1)*sin(th); ...
                0,-2*h(2),2*z(2),d*h(2)*sin(th)];
            B=diag([1,1,2*k]); C=zeros(4,8);
            C(1,6)=-sin(th)/2; C(2,6)=sin(th)/2;
            C(3,[1,2,4,6,7])=[h(1),2*(h(1)*cos(v(3))+z(1)*sin(v(3))),-2*c(1),-h(1)*cos(th),2*z(1)];
            C(4,[1,3,5,6,8])=[h(2),2*(h(2)*cos(v(4))+z(2)*sin(v(4))),-2*c(2),-h(2)*cos(th),2*z(2)];
            if rcond(A)<eps, J=nan(4); S=nan(4,8);
            else, J=-A\B; S=-A\C; end
            phi=[v(1)-p(1)-d*sin(th)/2;v(2)-p(1)+d*sin(th)/2;(h.^2+z.^2-c.^2)'];
        end

        function [variance,kF,covariance] = local(p,v,g,m)
            [J,S]=PPaPaRModel.differential(p,v,g);
            covariance=J*diag([m.sigmaQ^2,m.sigmaQ^2,m.sigmaAlpha^2,m.sigmaAlpha^2])*J' ...
                +S*diag(m.sigmaG.^2)*S';
            variance=trace(covariance(1:3,1:3));
            jb=diag([1,1,1,m.l0])*J/diag([1,1,m.l0,m.l0]);
            kF=4/(norm(jb,'fro')*norm(jb\eye(4),'fro'));
        end

        function [f,cv,constraints,details] = evaluate(d,m)
            n=size(d,1); f=zeros(n,3); cv=zeros(n,1);
            constraints=[d(:,4)-d(:,1)+1e-6,d(:,1)+2*d(:,2)-2*d(:,3)-d(:,4)];
            cv=sum(max(constraints,0),2)/1000;
            details=struct('validFraction',zeros(n,1),'maxPositionRMS',zeros(n,1));
            for i=1:n
                [w,varPos,kF]=PPaPaRModel.integrand(d(i,:),m);
                total=sum(w); details.validFraction(i)=nnz(w)/m.count;
                if total>0
                    f(i,:)=[-diff(m.alphaLimits)*pi*mean(w)*m.unitToCm3, ...
                        sqrt(sum(w.*varPos)/total),-sum(w.*kF)/total];
                    details.maxPositionRMS(i)=sqrt(max(varPos(w>0)));
                else
                    f(i,:)=[0,100,0]; cv(i)=cv(i)+1;
                end
            end
            assert(all(isfinite(f),'all'),'PPaPaR:Nonfinite','Nonfinite objectives');
        end

        function [w,varPos,kF,pose,control] = integrand(d,m)
            a=d(1); b=d(2); c=d(3); dd=d(4);
            y=-(a-dd*m.ct)/2-b*m.ca+c*m.cb;
            N=-b*m.sa-c*m.sb;
            u2=-y+(a-dd*m.ct)/2; rr=hypot(u2,N);
            ratio=(c^2-rr.^2-b^2)./(2*b*rr);
            al2=atan2(N,u2)+acos(max(-1,min(1,ratio)));
            ca2=cos(al2); sa2=sin(al2);
            h1=c*m.cb; v1=-c*m.sb; h2=u2+b*ca2; v2=N+b*sa2;
            k1=-b*c*m.sinAB; k2=b*(-h2.*sa2+v2.*ca2);
            detU=h1.*v2+h2.*v1;
            valid=abs(ratio)<=1 & rr>0 & al2>=m.alphaLimits(1) & al2<=m.alphaLimits(2) ...
                & m.sinAB>m.margin & -k2/(b*c)>m.margin ...
                & -detU/c^2>m.margin & m.ct>m.margin & v1<0 & v2<0;
            w=zeros(m.count,1); varPos=w; kF=w;
            w(valid)=b*c*m.sinAB(valid).*(m.L-dd*abs(m.st(valid))) ...
                .*(2*m.psiMax/pi*m.ct(valid)).*m.betaWeight(valid);
            % Only calculate inverse sensitivities at regular feasible poses.
            h1=h1(valid); h2=h2(valid); v1=v1(valid); v2=v2(valid);
            k1=k1(valid); k2=k2(valid); detU=detU(valid);
            st=m.st(valid); ct=m.ct(valid);
            r11=v2./detU; r12=-v1./detU; r21=h2./detU; r22=h1./detU;
            wy=-(r11.*h1+r12.*h2).*dd.*st/2;
            wz=-(r21.*h1+r22.*h2).*dd.*st/2;
            p11=-r11.*k1; p12=-r12.*k2; p21=-r21.*k1; p22=-r22.*k2;
            psq=p11.^2+p12.^2+p21.^2+p22.^2; t=1./(dd*ct);
            j2=.5+2*t.^2.*(wy.^2+wz.^2+m.l0^2)+psq/m.l0^2;
            k2norm=2+(dd*ct).^2/(2*m.l0^2)+m.l0^2*((h1.^2+v1.^2)./k1.^2+(h2.^2+v2.^2)./k2.^2) ...
                +(dd*h1.*st./(2*k1)).^2+(dd*h2.*st./(2*k2)).^2;
            kF(valid)=4./sqrt(j2.*k2norm);
            avar=m.sigmaQ^2*(.5+2*t.^2.*(wy.^2+wz.^2))+m.sigmaAlpha^2*psq;
            % Eight geometric columns; x sensitivity is identically zero.
            daY=-(r11.*h1+r12.*h2)/2; daZ=-(r21.*h1+r22.*h2)/2;
            t1=h1.*m.ca(valid)+v1.*m.sa(valid); t2=h2.*ca2(valid)+v2.*sa2(valid);
            ddTheta=-st./(ct*dd);
            sy=[daY,-r11.*t1,-r12.*t2,c*r11,c*r12,wy.*ddTheta-daY.*ct,-r11.*v1,-r12.*v2];
            sz=[daZ,-r21.*t1,-r22.*t2,c*r21,c*r22,wz.*ddTheta-daZ.*ct,-r21.*v1,-r22.*v2];
            varPos(valid)=avar+(sy.^2+sz.^2)*(m.sigmaG.^2)';
            if nargout>3
                pose=[repmat(m.L/2,m.count,1),y,N-m.n,m.theta];
                control=[m.L/2+dd*m.st/2,m.L/2-dd*m.st/2,m.alpha,al2];
            end
        end
    end
end
