function verification=pade_verify_frozen(root)
%PADE_VERIFY_FROZEN Verify all frozen solver/model/protocol files before search.
% Windows host utility; uses the built-in PowerShell Get-FileHash, not Java.
arguments
    root (1,1) string
end
manifest=jsondecode(fileread(fullfile(root,'FROZEN_MANIFEST.json')));
groups={'code_files','protocol_files'};
names={{'pade_solve_fe.m','pade_problems.m','pade_defaults.m','pade_variants.m','pade_worker.m'},...
    {'CONFIG.json','PROTOCOL.md','comparisons.csv'}};
records=struct('file',{},'sha256',{},'matches',{});
for g=1:numel(groups)
    for k=1:numel(names{g})
        name=names{g}{k}; folder=root;
        if g==1, folder=fullfile(root,'code'); end
        path=fullfile(folder,name);
        escaped=strrep(char(path),'''','''''');
        command=sprintf('powershell -NoProfile -NonInteractive -Command "(Get-FileHash -LiteralPath ''%s'' -Algorithm SHA256).Hash"',escaped);
        [status,value]=system(command);
        actual=lower(strtrim(value));
        assert(status==0 && ~isempty(regexp(actual,'^[0-9a-f]{64}$','once')),...
            'pade:HashCommand','Unable to hash %s: %s',path,value);
        expected=manifest.(groups{g}).(matlab.lang.makeValidName(name));
        assert(strcmp(actual,expected),'pade:FrozenFileChanged','Frozen file changed: %s',path);
        records(end+1)=struct('file',name,'sha256',actual,'matches',true); %#ok<AGROW>
    end
end
verification=struct('passed',true,'files',records,'code_hash',manifest.code_hash,...
    'config_hash',manifest.config_hash,'problem_hash',manifest.problem_hash);
fprintf('Frozen files verified: %d\n',numel(records));
end
