function value = h14FormalPerformanceFlag(mode)
%H14FORMALPERFORMANCEFLAG Derive the evidence role from execution mode.

arguments
    mode (1,1) string {mustBeMember(mode, ["formal", "preflight"])}
end
value = mode == "formal";
end
