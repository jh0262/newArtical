function matrix = makeP1Matrix()
%MAKEP1MATRIX Return the five frozen EXP-P1 disconnected instances.

ids = ["D-3-3-L", "D-3-3-S", "D-3-4-L", "D-3-4-S", "D-5-3-S"];
q = [3, 3, 3, 3, 5];
L = [3, 3, 4, 4, 3];
rho = [0.150, 0.075, 0.150, 0.075, 0.125];
N = [100, 100, 108, 108, 100];
budget = [50000, 50000, 54000, 54000, 50000];

matrix = repmat(struct(), 1, numel(ids));
for i = 1:numel(ids)
    matrix(i).instanceId = ids(i);
    matrix(i).family = "D";
    matrix(i).q = q(i);
    matrix(i).L = L(i);
    matrix(i).rho = rho(i);
    matrix(i).lambda = 1;
    matrix(i).N = N(i);
    matrix(i).budget = budget(i);
    matrix(i).archiveCapacity = N(i);
end
end
