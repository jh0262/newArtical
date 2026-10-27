function reproduce_review
base=fileparts(mfilename('fullpath'));
p4=fullfile(base,'MO_PACPO_创新性对照修订_20261025','code');
addpath(p4,fullfile(p4,'reference'),fullfile(base,'review_analysis'));
clear ReviewAnalysis;rehash;
ReviewAnalysis.recompute(fullfile(base,'review_analysis'));
end
