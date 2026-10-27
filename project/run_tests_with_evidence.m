projectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot, 'matlab'));
evidenceDir = fullfile(projectRoot, 'evidence');
if ~isfolder(evidenceDir)
    mkdir(evidenceDir);
end

import matlab.unittest.TestRunner
import matlab.unittest.TestSuite
import matlab.unittest.Verbosity
import matlab.unittest.plugins.XMLPlugin

suite = TestSuite.fromFolder(fullfile(projectRoot, 'tests'), ...
    'IncludingSubfolders', true);
runner = TestRunner.withTextOutput('OutputDetail', Verbosity.Detailed);
runner.addPlugin(XMLPlugin.producingJUnitFormat( ...
    fullfile(evidenceDir, 'e0_e1_junit.xml')));
results = runner.run(suite);
assertSuccess(results);

