function reproduce_all
base=fileparts(mfilename('fullpath'));old=pwd;cleanup=onCleanup(@()cd(old));cd(base);addpath(base);maxNumCompThreads(1);
folders=dir(fullfile(base,'MO_*'));for d=folders',if d.isdir,for n=["audit","data","figures"],p=fullfile(d.folder,d.name,n);if ~isfolder(p),mkdir(p);end;end;end;end
fprintf('Recalculating saved records; no optimizer searches.\n');run_reproduction('analysis');
recompute_exact;
reproduce_review;
names=string(jsondecode(fileread(fullfile(base,'expected_tables.json'))));checked=0;rows=0;
for i=1:numel(names)
 a=readtable(fullfile(base,'expected',names(i)),'TextType','string','VariableNamingRule','preserve');b=readtable(fullfile(base,names(i)),'TextType','string','VariableNamingRule','preserve');
 assert(isequal(a.Properties.VariableNames,b.Properties.VariableNames)&&height(a)==height(b),'Table layout mismatch: %s',names(i));
 for k=1:width(a)
  x=a{:,k};y=b{:,k};if isnumeric(x)&&isnumeric(y)
   assert(all((isnan(x)&isnan(y))|(x==y)|(abs(x-y)<=1e-12+1e-10*abs(x)),'all'),'Numeric mismatch: %s %s',names(i),a.Properties.VariableNames{k});
  else,assert(isequaln(x,y),'Text mismatch: %s %s',names(i),a.Properties.VariableNames{k});end
 end
 checked=checked+1;rows=rows+height(a);
end
fprintf('Verified %d reference tables (%d rows). Rendering figures.\n',checked,rows);make_figures;
writelines(jsonencode(struct('status','pass','tables',checked,'rows',rows,'optimizerSearches',0,'MATLAB',version,'figures',11)),fullfile(base,'reproduction_verification.json'));
fprintf('Reproduction complete: figures/ and reproduction_verification.json\n');
end
