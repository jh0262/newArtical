function fraction = computeNoveltyFraction(stagnation, minimum, maximum, horizon)
%COMPUTENOVELTYFRACTION Linear bounded response to discovery stagnation.

arguments
    stagnation (1,1) double {mustBeNonnegative}
    minimum (1,1) double {mustBeNonnegative}
    maximum (1,1) double {mustBeNonnegative}
    horizon (1,1) double {mustBePositive}
end
if minimum > maximum || maximum > 1
    error('mdt:InvalidNoveltyFraction', ...
        'Novelty fractions must satisfy 0 <= minimum <= maximum <= 1.');
end
fraction = minimum + (maximum-minimum)*min(1, stagnation/horizon);
end
