classdef P3Variants
    methods (Static)
        function c=config(name,seed)
            c=P3Core.config(struct('seed',seed,'mechanism','directional','principalGain',.05,'sparseRate',.2,'areaMode','progressive'));
            switch name
                case 'revised'
                case 'oldArea',c.areaMode='onepass';
                case 'Diagonal',c.usePado=false;
                case 'noNoise',c.principalGain=0;
                case 'noLock',c.useLock=false;
                case 'noEC',c.useEC=false;
                case 'Fixed',c.adaptiveStep=false;
                case 'GDE3',c.usePado=false;c.useLock=false;c.useEC=false;
                otherwise,error('P1:Variant','Unknown configuration');
            end
        end
    end
end
