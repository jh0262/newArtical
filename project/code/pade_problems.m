function probs = pade_problems()
%PADE_PROBLEMS Return the 26 problems used in the PADE supplement.
%   PROBS = PADE_PROBLEMS() returns a 1-by-26 struct array with common fields
%   id, name, D, lb, ub, discrete_idx, discrete_step and eval.
%   [F, CV] = PROBS(K).eval(X) evaluates one row or column vector. CV is the
%   raw sum of positive supplied inequality residuals; box and grid repair
%   belong to the solver. All 23 unconstrained functions return CV = 0.
%   F07 deliberately consumes one RAND draw at every evaluation.
%   This file preserves the actual supplied constants, including F15 and
%   the pressure-vessel head-thickness coefficient 0.0095.
%
%   Sources (unchanged): Benchmark_23_Functions.m and
%   PADE_Algorithm_Framework.m in the parent source directory.
%   See PROBLEM_LIBRARY_NOTES.md for conventions, units and source hashes.

    template = struct('id', '', 'name', '', 'D', 0, 'lb', [], 'ub', [], ...
        'discrete_idx', [], 'discrete_step', [], 'eval', []);
    probs = repmat(template, 1, 26);
    for k = 1:23
        [lb, ub, dim, fobj, ~, name] = Get_Functions_details(k);
        probs(k).id = sprintf('F%02d', k);
        probs(k).name = name;
        probs(k).D = dim;
        probs(k).lb = lb;
        probs(k).ub = ub;
        probs(k).eval = @(x) evaluate_scalar(fobj, x, dim);
    end

    engineering = {get_welded_beam_problem(), ...
        get_cantilever_beam_problem(), get_pressure_vessel_problem()};
    ids = {'WB', 'CB', 'PV'};
    for k = 1:numel(engineering)
        source = engineering{k};
        index = 23 + k;
        probs(index).id = ids{k};
        probs(index).name = source.name;
        probs(index).D = source.D;
        probs(index).lb = source.lb;
        probs(index).ub = source.ub;
        probs(index).discrete_idx = source.discrete_idx;
        probs(index).discrete_step = source.discrete_step;
        probs(index).eval = @(x) evaluate_engineering(source.obj_con, x, source.D);
    end
end

function [f, cv] = evaluate_scalar(objective, x, dimension)
    validateattributes(x, {'numeric'}, {'real', 'vector', 'numel', dimension});
    f = objective(reshape(x, 1, dimension));
    cv = 0;
end

function [f, cv] = evaluate_engineering(objective, x, dimension)
    validateattributes(x, {'numeric'}, {'real', 'vector', 'numel', dimension});
    [f, cv] = objective(reshape(x, 1, dimension));
end

function [lb, ub, dim, fobj, f_opt, func_name, func_type] = Get_Functions_details(F)
    % 支持传入数值 1~23 或字符串如 'F1', 'f1', 'Sphere'
    if ischar(F)
        if strncmpi(F, 'F', 1)
            F = str2double(F(2:end));
        else
            F = map_name_to_id(F);
        end
    end

    switch F
        % ==================== Single-mode test functions F1 ~ F7 (D=30) ====================
        case 1
            func_name = 'F1: Sphere'; func_type = '单峰连续'; dim = 30;
            lb = -100 * ones(1, dim); ub = 100 * ones(1, dim); f_opt = 0.0;
            fobj = @(x) sum(x.^2);

        case 2
            func_name = 'F2: Schwefel 2.22'; func_type = '单峰连续'; dim = 30;
            lb = -10 * ones(1, dim); ub = 10 * ones(1, dim); f_opt = 0.0;
            fobj = @(x) sum(abs(x)) + prod(abs(x));

        case 3
            func_name = 'F3: Schwefel 1.2'; func_type = '单峰连续'; dim = 30;
            lb = -100 * ones(1, dim); ub = 100 * ones(1, dim); f_opt = 0.0;
            fobj = @(x) sum(cumsum(x).^2);

        case 4
            func_name = 'F4: Schwefel 2.21'; func_type = '单峰连续'; dim = 30;
            lb = -100 * ones(1, dim); ub = 100 * ones(1, dim); f_opt = 0.0;
            fobj = @(x) max(abs(x));

        case 5
            func_name = 'F5: Rosenbrock'; func_type = '单峰病态谷'; dim = 30;
            lb = -30 * ones(1, dim); ub = 30 * ones(1, dim); f_opt = 0.0;
            fobj = @(x) sum(100.0 * (x(2:end) - x(1:end-1).^2).^2 + (x(1:end-1) - 1.0).^2);

        case 6
            func_name = 'F6: Step'; func_type = '单峰阶梯'; dim = 30;
            lb = -100 * ones(1, dim); ub = 100 * ones(1, dim); f_opt = 0.0;
            fobj = @(x) sum(floor(x + 0.5).^2);

        case 7
            func_name = 'F7: Quartic with Noise'; func_type = '单峰随机加噪'; dim = 30;
            lb = -1.28 * ones(1, dim); ub = 1.28 * ones(1, dim); f_opt = 0.0;
            fobj = @(x) sum((1:length(x)) .* (x.^4)) + rand();

        % ==================== 复杂多模态基准测试函数 F8 ~ F13 (D=30) ====================
        case 8
            func_name = 'F8: Schwefel 2.26'; func_type = '多峰多陷阱'; dim = 30;
            lb = -500 * ones(1, dim); ub = 500 * ones(1, dim); f_opt = -12569.48;
            fobj = @(x) sum(-x .* sin(sqrt(abs(x))));

        case 9
            func_name = 'F9: Rastrigin'; func_type = '多峰强振荡'; dim = 30;
            lb = -5.12 * ones(1, dim); ub = 5.12 * ones(1, dim); f_opt = 0.0;
            fobj = @(x) sum(x.^2 - 10.0 * cos(2.0 * pi * x) + 10.0);

        case 10
            func_name = 'F10: Ackley'; func_type = '多峰高振荡'; dim = 30;
            lb = -32 * ones(1, dim); ub = 32 * ones(1, dim); f_opt = 0.0;
            fobj = @(x) -20.0 * exp(-0.2 * sqrt(sum(x.^2)/length(x))) - ...
                        exp(sum(cos(2*pi*x))/length(x)) + 20.0 + exp(1);

        case 11
            func_name = 'F11: Griewank'; func_type = '多峰高维耦合'; dim = 30;
            lb = -600 * ones(1, dim); ub = 600 * ones(1, dim); f_opt = 0.0;
            fobj = @(x) sum(x.^2)/4000.0 - prod(cos(x ./ sqrt(1:length(x)))) + 1.0;

        case 12
            func_name = 'F12: Penalized 1'; func_type = '多峰带惩罚项'; dim = 30;
            lb = -50 * ones(1, dim); ub = 50 * ones(1, dim); f_opt = 0.0;
            fobj = @(x) calc_penalized1(x);

        case 13
            func_name = 'F13: Penalized 2'; func_type = '多峰带惩罚项'; dim = 30;
            lb = -50 * ones(1, dim); ub = 50 * ones(1, dim); f_opt = 0.0;
            fobj = @(x) calc_penalized2(x);

        % ==================== 固定维度多峰测试函数 F14 ~ F23 (D=2~6) ====================
        case 14
            func_name = 'F14: Shekel Foxholes'; func_type = '固定维多峰'; dim = 2;
            lb = -65 * ones(1, 2); ub = 65 * ones(1, 2); f_opt = 0.9980;
            fobj = @(x) calc_f14(x);

        case 15
            func_name = 'F15: Kowalik-type fit (source constants)'; func_type = '固定维非线性拟合'; dim = 4;
            lb = -5 * ones(1, 4); ub = 5 * ones(1, 4); f_opt = 0.0003075;
            fobj = @(x) calc_f15(x);

        case 16
            func_name = 'F16: Six-Hump Camel'; func_type = '固定维多极值'; dim = 2;
            lb = -5 * ones(1, 2); ub = 5 * ones(1, 2); f_opt = -1.0316;
            fobj = @(x) 4.0*x(1)^2 - 2.1*x(1)^4 + (1/3)*x(1)^6 + x(1)*x(2) - 4.0*x(2)^2 + 4.0*x(2)^4;

        case 17
            func_name = 'F17: Branin'; func_type = '固定维多极值'; dim = 2;
            lb = [-5, 0]; ub = [10, 15]; f_opt = 0.3979;
            fobj = @(x) (x(2) - (5.1/(4*pi^2))*x(1)^2 + (5/pi)*x(1) - 6)^2 + 10*(1 - 1/(8*pi))*cos(x(1)) + 10;

        case 18
            func_name = 'F18: Goldstein-Price'; func_type = '固定维多项式'; dim = 2;
            lb = -2 * ones(1, 2); ub = 2 * ones(1, 2); f_opt = 3.0;
            fobj = @(x) calc_f18(x);

        case 19
            func_name = 'F19: Hartman 3D'; func_type = '固定维多峰'; dim = 3;
            lb = zeros(1, 3); ub = ones(1, 3); f_opt = -3.8628;
            fobj = @(x) calc_f19(x);

        case 20
            func_name = 'F20: Hartman 6D'; func_type = '固定维多峰'; dim = 6;
            lb = zeros(1, 6); ub = ones(1, 6); f_opt = -3.3224;
            fobj = @(x) calc_f20(x);

        case 21
            func_name = 'F21: Shekel 5'; func_type = '固定维多极小谷'; dim = 4;
            lb = zeros(1, 4); ub = 10 * ones(1, 4); f_opt = -10.1532;
            fobj = @(x) calc_shekel(x, 5);

        case 22
            func_name = 'F22: Shekel 7'; func_type = '固定维多极小谷'; dim = 4;
            lb = zeros(1, 4); ub = 10 * ones(1, 4); f_opt = -10.4028;
            fobj = @(x) calc_shekel(x, 7);

        case 23
            func_name = 'F23: Shekel 10'; func_type = '固定维多极小谷'; dim = 4;
            lb = zeros(1, 4); ub = 10 * ones(1, 4); f_opt = -10.5363;
            fobj = @(x) calc_shekel(x, 10);
            
        otherwise
            error('测试函数编号错误! 仅支持 1 到 23.');
    end
end

%% =========================================================================
%% 辅助计算子程序: 复杂测试函数精确解析表达式
%% =========================================================================
function val = calc_penalized1(x)
    dim = length(x);
    y = 1.0 + (x + 1.0) / 4.0;
    term1 = 10.0 * sin(pi * y(1))^2;
    term2 = sum((y(1:dim-1) - 1.0).^2 .* (1.0 + 10.0 * sin(pi * y(2:dim)).^2));
    term3 = (y(dim) - 1.0)^2;
    val = (pi / dim) * (term1 + term2 + term3) + sum(u_penalty(x, 10, 100, 4));
end

function val = calc_penalized2(x)
    dim = length(x);
    term1 = sin(3.0 * pi * x(1))^2;
    term2 = sum((x(1:dim-1) - 1.0).^2 .* (1.0 + sin(3.0 * pi * x(2:dim)).^2));
    term3 = (x(dim) - 1.0)^2 * (1.0 + sin(2.0 * pi * x(dim))^2);
    val = 0.1 * (term1 + term2 + term3) + sum(u_penalty(x, 5, 100, 4));
end

function u_res = u_penalty(x, a, k, m)
    u_res = zeros(size(x));
    idx_u = x > a;  u_res(idx_u) = k * (x(idx_u) - a).^m;
    idx_l = x < -a; u_res(idx_l) = k * (-x(idx_l) - a).^m;
end

function val = calc_f14(x)
    aS = [
        -32, -16, 0, 16, 32, -32, -16, 0, 16, 32, -32, -16, 0, 16, 32, -32, -16, 0, 16, 32, -32, -16, 0, 16, 32;
        -32, -32, -32, -32, -32, -16, -16, -16, -16, -16, 0, 0, 0, 0, 0, 16, 16, 16, 16, 16, 32, 32, 32, 32, 32
    ];
    s = 0.002;
    for j = 1:25
        s = s + 1.0 / (j + (x(1) - aS(1, j))^6 + (x(2) - aS(2, j))^6);
    end
    val = 1.0 / s;
end

function val = calc_f15(x)
    aK = [0.1957, 0.1947, 0.1735, 0.1600, 0.1472, 0.1392, 0.1320, 0.1287, 0.1235, 0.1190, 0.1180];
    bK = 1.0 ./ [0.25, 0.5, 1, 2, 4, 6, 8, 10, 12, 14, 16];
    val = sum((aK - (x(1) .* (bK.^2 + x(2) .* bK)) ./ (bK.^2 + x(3) .* bK + x(4))).^2);
end

function val = calc_f18(x)
    t1 = 1.0 + (x(1) + x(2) + 1.0)^2 * (19.0 - 14.0*x(1) + 3.0*x(1)^2 - 14.0*x(2) + 6.0*x(1)*x(2) + 3.0*x(2)^2);
    t2 = 30.0 + (2.0*x(1) - 3.0*x(2))^2 * (18.0 - 32.0*x(1) + 12.0*x(1)^2 + 48.0*x(2) - 36.0*x(1)*x(2) + 27.0*x(2)^2);
    val = t1 * t2;
end

function val = calc_f19(x)
    aH = [3, 10, 30; 0.1, 10, 35; 3, 10, 30; 0.1, 10, 35];
    cH = [1, 1.2, 3, 3.2];
    pH = [0.3689, 0.1170, 0.2673; 0.4699, 0.4387, 0.7470; 0.1091, 0.8732, 0.5547; 0.03815, 0.5743, 0.8828];
    s = 0.0;
    for i = 1:4, s = s + cH(i) * exp(-sum(aH(i, :) .* (x - pH(i, :)).^2)); end
    val = -s;
end

function val = calc_f20(x)
    aH = [
        10, 3, 17, 3.5, 1.7, 8;
        0.05, 10, 17, 0.1, 8, 14;
        3, 3.5, 1.7, 10, 17, 8;
        17, 8, 0.05, 10, 0.1, 14
    ];
    cH = [1, 1.2, 3, 3.2];
    pH = [
        0.1312, 0.1696, 0.5569, 0.0124, 0.8283, 0.5886;
        0.2329, 0.4135, 0.8307, 0.3736, 0.1004, 0.9991;
        0.2348, 0.1451, 0.3522, 0.2883, 0.3047, 0.6650;
        0.4047, 0.8828, 0.8732, 0.5743, 0.1091, 0.0381
    ];
    s = 0.0;
    for i = 1:4, s = s + cH(i) * exp(-sum(aH(i, :) .* (x - pH(i, :)).^2)); end
    val = -s;
end

function val = calc_shekel(x, m)
    aSH = [
        4, 4, 4, 4; 1, 1, 1, 1; 8, 8, 8, 8; 6, 6, 6, 6; 3, 7, 3, 7;
        2, 9, 2, 9; 5, 5, 3, 3; 8, 1, 8, 1; 6, 2, 6, 2; 7, 3.6, 7, 3.6
    ];
    cSH = [0.1, 0.2, 0.2, 0.4, 0.4, 0.6, 0.3, 0.7, 0.5, 0.5];
    s = 0.0;
    for i = 1:m, s = s + 1.0 / (sum((x - aSH(i, :)).^2) + cSH(i)); end
    val = -s;
end

function id = map_name_to_id(name)
    names = {'Sphere', 'Schwefel 2.22', 'Schwefel 1.2', 'Schwefel 2.21', 'Rosenbrock', ...
             'Step', 'Quartic', 'Schwefel 2.26', 'Rastrigin', 'Ackley', 'Griewank', ...
             'Penalized 1', 'Penalized 2', 'Foxholes', 'Kowalik', 'Camel', 'Branin', ...
             'Goldstein', 'Hartman 3D', 'Hartman 6D', 'Shekel 5', 'Shekel 7', 'Shekel 10'};
    for k = 1:length(names)
        if contains(lower(name), lower(names{k}))
            id = k; return;
        end
    end
    id = 1;
end


function prob = get_pressure_vessel_problem()
    prob.name = '压力容器设计 (Pressure Vessel Design)';
    prob.D = 4;
    prob.lb = [0.0625, 0.0625, 10.0, 10.0];
    prob.ub = [6.1875, 6.1875, 200.0, 200.0];
    prob.discrete_idx = [1, 2];              % x1: 壳厚, x2: 封头厚 (0.0625 整数倍)
    prob.discrete_step = [0.0625, 0.0625];
    prob.obj_con = @pressure_vessel_eval;
end

function [f, cv] = pressure_vessel_eval(x)
    % 目标函数: 制造与材料总成本
    f = 0.6224 * x(1) * x(3) * x(4) + ...
        1.7781 * x(2) * (x(3)^2) + ...
        3.1661 * (x(1)^2) * x(4) + ...
        19.84 * (x(1)^2) * x(3);

    % 4项工程力学与几何容积约束 g_i(x) <= 0
    g1 = 0.0193 * x(3) - x(1);
    g2 = 0.0095 * x(3) - x(2);
    g3 = -pi * (x(3)^2) * x(4) - (4.0/3.0) * pi * (x(3)^3) + 1296000.0;
    g4 = x(4) - 240.0;

    cv = max(0.0, g1) + max(0.0, g2) + max(0.0, g3) + max(0.0, g4);
end

%% =========================================================================
%% 工程案例模型 2: 焊接梁最小制造成本优化设计 (Welded Beam Design)
%% =========================================================================
function prob = get_welded_beam_problem()
    prob.name = '焊接梁设计 (Welded Beam Design)';
    prob.D = 4;
    prob.lb = [0.1, 0.1, 0.1, 0.1];
    prob.ub = [2.0, 10.0, 10.0, 2.0];
    prob.discrete_idx = [];
    prob.discrete_step = [];
    prob.obj_con = @welded_beam_eval;
end

function [f, cv] = welded_beam_eval(x)
    h = x(1); l = x(2); t = x(3); b = x(4);
    
    % 目标函数: 构件制造成本
    f = 1.10471 * (h^2) * l + 0.04811 * t * b * (14.0 + l);

    % 工程力学参数
    P = 6000.0; L = 14.0; E = 30e6; G = 12e6;
    tau_max = 13600.0; sigma_max = 30000.0; delta_max = 0.25;

    M = P * (L + l / 2.0);
    R = sqrt((l^2) / 4.0 + ((h + t) / 2.0)^2);
    J = 2.0 * (sqrt(2.0) * h * l * ((l^2) / 12.0 + ((h + t) / 2.0)^2));

    tau_prime = P / (sqrt(2.0) * h * l);
    tau_double_prime = (M * R) / J;
    tau = sqrt(tau_prime^2 + 2.0 * tau_prime * tau_double_prime * (l / (2.0 * R)) + tau_double_prime^2);

    sigma = (6.0 * P * L) / (b * (t^2));
    delta = (4.0 * P * (L^3)) / (E * (t^3) * b);
    P_c = (4.013 * E * sqrt((t^2 * b^6) / 36.0) / (L^2)) * (1.0 - (t / (2.0 * L)) * sqrt(E / (4.0 * G)));

    % 7项工程力学约束 g_i(x) <= 0
    g1 = tau - tau_max;
    g2 = sigma - sigma_max;
    g3 = h - b;
    g4 = 0.10471 * (h^2) + 0.04811 * t * b * (14.0 + l) - 5.0;
    g5 = 0.125 - h;
    g6 = delta - delta_max;
    g7 = P - P_c;

    cv = max(0.0, g1) + max(0.0, g2) + max(0.0, g3) + ...
         max(0.0, g4) + max(0.0, g5) + max(0.0, g6) + max(0.0, g7);
end

%% =========================================================================
%% 工程案例模型 3: 悬臂梁矩形截面轻量化优化设计 (Cantilever Beam Design)
%% =========================================================================
function prob = get_cantilever_beam_problem()
    prob.name = '悬臂梁设计 (Cantilever Beam Design)';
    prob.D = 5;
    prob.lb = 0.01 * ones(1, prob.D);
    prob.ub = 100.0 * ones(1, prob.D);
    prob.discrete_idx = [];
    prob.discrete_step = [];
    prob.obj_con = @cantilever_beam_eval;
end

function [f, cv] = cantilever_beam_eval(x)
    % 目标函数: 结构总质量
    f = 0.0624 * sum(x);

    % 挠度力学硬约束 g(x) <= 1
    g = 61.0 / (x(1)^3) + 37.0 / (x(2)^3) + 19.0 / (x(3)^3) + ...
        7.0 / (x(4)^3) + 1.0 / (x(5)^3) - 1.0;

    cv = max(0.0, g);
end

%% =========================================================================
%% 格式化输出与可视化展示
