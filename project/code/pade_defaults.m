function opts = pade_defaults(problemIndex)
%PADE_DEFAULTS Frozen source-scale per-run budgets and original parameters.
opts=struct('N',30,'maxFE',15030,'pBestRate',0.15,'warmupRatio',0.10,...
    'pulseEndRatio',0.90,'stagnationLimit',15,'betaCrit',2.8,'gamma',0.25);
if problemIndex<=13, opts.maxFE=30030; end
if problemIndex>=24, opts.N=40; opts.maxFE=100040; end
end
