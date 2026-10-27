classdef GECMODE < ALGORITHM
    properties
        Telemetry=[];
    end
    methods
        function main(Algorithm,Problem)
            cfg=Algorithm.ParameterSet(struct('A',false,'B',false,'C',false,'adaptive',true,'shuffle',false));
            Pop=Problem.Initialization(); state=ec_state();
            ids=ec_nd_indices(Pop.objs); GX=Pop(ids).decs; GF=Pop(ids).objs;
            while Algorithm.NotTerminated(Pop)
                [Y,meta]=ec_offspring(Pop.decs,Pop.objs,GX,GF,Problem.lower,Problem.upper,state,cfg);
                Kids=Problem.Evaluation(Y);
                gain=ec_credit(Kids.objs,GF);
                if cfg.adaptive, state=ec_adapt(state,meta.F,meta.CR,gain,meta.arm,cfg.C); end
                Union=[Pop,Kids]; UF=Union.objs;
                ids=ec_nd_indices(UF); GX=Union(ids).decs; GF=UF(ids,:);
                [keep,info]=ec_select(UF,Problem.N,cfg.A); Pop=Union(keep);
                Algorithm.Telemetry(end+1,:)=[mean(meta.F),mean(meta.CR),meta.pLocal,mean(meta.arm==2),mean(gain),sum(gain>1e-14),info.earApplied,info.fallback,info.coverage,info.bound,numel(ids),mean(state.MF),mean(state.MCR)];
            end
        end
    end
end
