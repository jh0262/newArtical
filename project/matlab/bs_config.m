function p=bs_config()
% Explicit assumed numerical case, not identified physical parameters.
root=fileparts(fileparts(mfilename('fullpath')));
p=jsondecode(fileread(fullfile(root,'config.json')));
p.catalog=readtable(fullfile(root,'literature','catalog_btkv.csv'),'TextType','string');
extra=readtable(fullfile(root,'literature','catalog_inertia.csv'),'TextType','string');
assert(isequal(p.catalog.model,extra.model));
p.catalog.shaft_inertia_kg_m2_per_mm=extra.shaft_inertia_kg_m2_per_mm;
p.catalog.axial_clearance_mm=extra.axial_clearance_mm;
p.root=root;
end
