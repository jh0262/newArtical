function tests = test_mdt_archive
%TEST_MDT_ARCHIVE Tests for the finite feasible nondominated archive.

tests = functiontests(localfunctions);
end

function testArchiveKeepsUniqueFeasibleNondominatedCandidates(testCase)
cfg = mdt.makeInstance("D", 3, 3, 0.15, 1);
X = [
    0.1, 0.5, 0, 0, 0;
    0.1, 0.5, 0, 0, 0;
    0.5, 0.5, 1, 1, 1;
    0.8, 0.5, 2, 2, 2;
    0.9, 0.5, 0, 1, 2];
obj = [0, 1; 0, 1; 0.5, 0.5; 1, 0; 0.4, 0.6];
con = [-0.1, -0.1; -0.1, -0.1; -0.1, -0.1; -0.1, -0.1; 1, -0.1];

archive = mdt.updateArchive([], X, obj, con, 5, cfg);

verifyEqual(testCase, size(archive.X, 1), 3);
verifyEqual(testCase, size(unique(archive.X, 'rows'), 1), 3);
verifyTrue(testCase, all(archive.con <= 0, 'all'));
verifyEqual(testCase, sortrows(archive.obj), sortrows(obj([1, 3, 4], :)), ...
    'AbsTol', 1e-14);
end

function testArchiveCapacityKeepsObjectiveBoundaries(testCase)
cfg = mdt.makeInstance("D", 3, 3, 0.15, 1);
X = [
    0.1, 0.5, 0, 0, 0;
    0.5, 0.5, 1, 1, 1;
    0.9, 0.5, 2, 2, 2];
obj = [0, 1; 0.5, 0.5; 1, 0];
con = -0.1*ones(3, 2);

archive = mdt.updateArchive([], X, obj, con, 2, cfg);

verifyEqual(testCase, sortrows(archive.obj), sortrows([0, 1; 1, 0]), ...
    'AbsTol', 1e-14);
end

function testArchiveIsRowPermutationInvariant(testCase)
cfg = mdt.makeInstance("D", 3, 3, 0.15, 1);
X = [
    0.1, 0.5, 0, 0, 0;
    0.3, 0.5, 1, 1, 1;
    0.5, 0.5, 2, 2, 2;
    0.7, 0.5, 0, 1, 2;
    0.9, 0.5, 2, 1, 0];
obj = [0, 1; 0.25, 0.75; 0.5, 0.5; 0.75, 0.25; 1, 0];
con = -0.1*ones(5, 2);
permutation = [4, 2, 5, 1, 3];

archiveA = mdt.updateArchive([], X, obj, con, 3, cfg);
archiveB = mdt.updateArchive([], X(permutation, :), obj(permutation, :), ...
    con(permutation, :), 3, cfg);

verifyEqual(testCase, sortrows([archiveA.X, archiveA.obj, archiveA.con]), ...
    sortrows([archiveB.X, archiveB.obj, archiveB.con]), 'AbsTol', 1e-14);
end

function testArchiveRejectsConflictingDuplicateEvaluation(testCase)
cfg = mdt.makeInstance("D", 3, 3, 0.15, 1);
X = repmat([0.1, 0.5, 0, 0, 0], 2, 1);
obj = [0, 1; 0.1, 0.9];
con = -0.1*ones(2, 2);

verifyError(testCase, @() mdt.updateArchive([], X, obj, con, 3, cfg), ...
    'mdt:ConflictingDuplicateEvaluation');
end
