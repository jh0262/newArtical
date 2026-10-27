function futures=advance_pipeline()
% Resume the next frozen stage only after every planned record succeeds.
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'code'),fullfile(root,'code/reference'),fullfile(root,'scripts'));futures=[];
if ~isfile(fullfile(root,'data/selection.json'))
 phase='screen';
else
 phase='confirm';
end
jobs=ERStudy.jobs(phase);done=0;failed={};
for j=jobs
 p=fullfile(root,'results',phase,[j.id,'_status.json']);
 if isfile(p),s=jsondecode(fileread(p));done=done+s.ok;if ~s.ok,failed{end+1}=s;end;end %#ok<AGROW>
end
fprintf('%s: %d/%d complete, %d failed\n',phase,done,numel(jobs),numel(failed));assert(isempty(failed),'ER:RunFailure','Inspect failure records before proceeding.');
if done<numel(jobs),return;end
if ~isfile(fullfile(root,'data',[phase,'_table.mat'])),ERAnalysis.collect(phase);end
ERAnalysis.summarize(phase);ERAnalysis.statistics(phase);
if strcmp(phase,'screen'),ERAnalysis.select();futures=ERStudy.start('confirm');else,ERStudy.json(fullfile(root,'audit/numerical_stages_complete.json'),struct('status','complete','timestamp',char(datetime('now'))));end
end
