classdef P4Variants
 methods(Static)
  function c=config(name,seed)
   c=P4Core.config(struct('seed',seed,'mechanism','directional','principalGain',.05,'sparseRate',.2,'areaMode','progressive'));
   switch name
    case 'DL' % Published Full: double condition, low-variance direction
    case 'DR',c.pulseDirection='random';
    case 'SL',c.pulseTrigger='single';
    case 'SR',c.pulseDirection='random';c.pulseTrigger='single';
    otherwise,error('P4:Variant','Unknown variant %s',name);
   end
  end
 end
end
