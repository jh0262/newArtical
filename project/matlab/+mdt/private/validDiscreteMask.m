function valid = validDiscreteMask(semanticStates, cfg)
%VALIDDISCRETEMASK Evaluate the frozen discrete feasibility rule.

switch string(cfg.family)
    case {"D", "IR"}
        valid = mod(sum(semanticStates, 2), cfg.q) == 0;
    case "C"
        valid = semanticStates(:, 1) == 0;
    case "WM"
        weights = 1:cfg.L;
        valid = mod(semanticStates*weights', cfg.q) == 0;
    case "DM2"
        weights = 1:cfg.L;
        valid = mod(sum(semanticStates, 2), cfg.q) == 0 & ...
            mod(semanticStates*weights', cfg.q) == 0;
    otherwise
        error('mdt:InvalidFamily', ...
            'Unsupported family: %s.', string(cfg.family));
end
end
