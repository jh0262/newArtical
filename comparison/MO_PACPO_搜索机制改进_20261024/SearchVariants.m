classdef SearchVariants
    methods (Static)
        function c=config(name,seed)
            c=PACPOSearch.config(struct('seed',seed,'mechanism',name));
            if ismember(name,{'NSGAII','MOEAD','MOPSO'})
                c.mechanism='legacy';c.usePado=false;c.useLock=false;c.useEC=false;return;
            end
            if startsWith(name,'candidate')
                c.mechanism='directional';c.principalGain=.05;c.sparseRate=.2;
                switch name
                    case 'candidate'
                    case 'candidateDiagonal',c.usePado=false;
                    case 'candidateNoNoise',c.principalGain=0;
                    case 'candidateNoLock',c.useLock=false;
                    case 'candidateNoEC',c.useEC=false;
                    case 'candidateFixed',c.adaptiveStep=false;
                    otherwise,error('Search:Variant','Unknown candidate variant');
                end
                return;
            end
            if startsWith(name,'d') || startsWith(name,'rank')
                c.mechanism='directional';c.principalGain=.05;
                switch name
                    case 'd0',c.principalGain=0;
                    case 'd05'
                    case 'd10',c.principalGain=.1;
                    case 'dcr02',c.sparseRate=.2;
                    case 'dcr05',c.sparseRate=.5;
                    case 'rank',c.rankParents=true;
                    case 'rankRandom',c.rankParents=true;c.randomGain=true;
                    case 'rankGlobal',c.rankParents=true;c.localGuide=false;c.randomGain=true;
                end
            end
        end
    end
end
