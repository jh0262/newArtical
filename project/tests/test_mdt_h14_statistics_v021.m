function tests = test_mdt_h14_statistics_v021
%TEST_MDT_H14_STATISTICS_V021 Regression for coordinate-normalized HV range.
tests = functiontests(localfunctions);
end

function testFormalResultsWithHvAboveOneAreAccepted(testCase)
rows = readFormalResults();
verifyGreaterThan(testCase, max(rows.normalizedFeasibleHv), 1);
verifyLessThanOrEqual(testCase, max(rows.normalizedFeasibleHv), 1.21);
stats = mdt.computeH14StatisticsV021(rows, 100, 2026083102);
verifyEqual(testCase, stats.algorithmRuns, 6720);
verifyEqual(testCase, stats.primaryFamilySize, 3);
verifyEqual(testCase, stats.metricRangeCorrection, ...
    "coordinate-normalized 2D HV has admissible range [0,1.21]");
end

function testHvBeyondReferenceBoxIsRejected(testCase)
rows = readFormalResults();
rows.normalizedFeasibleHv(1) = 1.21+1e-6;
verifyError(testCase, @() mdt.computeH14StatisticsV021( ...
    rows, 10, 2026083102), 'mdt:InvalidH14Results');
end

function rows = readFormalResults()
root = string(fileparts(fileparts(mfilename('fullpath'))));
path = fullfile(root, 'runs', 'H14_CONTROLLED', ...
    'formal-rc2-b', 'h14_results.csv');
if ~isfile(path)
    error('mdt:H14FormalRegressionInputMissing', ...
        'The audited formal H14 result table is required: %s', path);
end
rows = readtable(path, 'TextType', 'string');
end
