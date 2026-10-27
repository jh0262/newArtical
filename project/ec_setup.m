function root=ec_setup()
root=fileparts(mfilename('fullpath'));
addpath(fullfile(root,'src'),fullfile(root,'tests'));
addpath(genpath(fullfile(root,'vendor','PlatEMO','PlatEMO')));
addpath(fullfile(root,'src'));
end
