classdef P5Variants
 methods(Static)
  function c=config(name,seed)
   c=P5Core.config(struct('seed',seed,'mechanism','directional','principalGain',.05,'sparseRate',.2,'areaMode','progressive'));
   switch char(name)
    case 'Full'
    case 'noNoise', c.principalGain=0;
    case 'noLock', c.useLock=false;
    case 'joint', c.principalGain=0;c.useLock=false;
    otherwise,error('P5:Variant','Unknown variant %s',name);
   end
  end
 end
end
