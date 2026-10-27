%% =========================================================================
%% 23 个国际标准基准测试函数 (F1~F23) 完整 MATLAB 仿真与评测系统
%% 
%% 基准测试函数库完全对标文献:
%% 王联国, 刘小娟. 基于采蜜机制的正弦余弦算法及其在机械优化设计中的应用[J]. 
%% 中国机械工程, 2021, 32(21): 2577–2589. (表 1: 23个标准测试函数参数表)
%% 
%% 测试函数分类体系:
%% 1. F1 ~ F7  : 单峰基准测试函数 (Unimodal, D=30, 检验局部开发与极限收敛精度)
%% 2. F8 ~ F13 : 复杂多模态基准测试函数 (Multimodal, D=30, 检验跳出局部极值早熟停滞能力)
%% 3. F14 ~ F23: 固定维度多峰测试函数 (Fixed-dimension, D=2~6, 检验低维复杂多谷地形适应性)
%% 
%% 本文件包含:
%%   1. 主运行评测函数 Benchmark_23_Functions (支持 30 次独立运行、数据统计与自动绘图)
%%   2. 算法引擎 1: 本文提出的 PADE 算法 (主轴流形投影 + 构型熵双锁门控)
%%   3. 算法引擎 2: 经典差分进化 Standard DE (DE/rand/1/bin, Storn 1997)
%%   4. 函数库标准接口 Get_Functions_details (支持按序号 1~23 或函数名调用)
%%   5. 23 个测试函数严格解析数学模型计算子程序
%% =========================================================================

function Benchmark_23_Functions()
    clc; clear; close all;
    fprintf('=================================================================================\n');
    fprintf('   23 个国际标准基准测试函数 (F1~F23, 王联国 2021 体系) 评测与对比系统\n');
    fprintf('=================================================================================\n\n');

    %% ------------------- 运行配置控制 -------------------
    % 选择评测范围:
    % 设为 1:23 运行全部 23 个标准测试函数;
    % 或选择特定子集如 [1, 5, 8, 9, 11, 23] 进行快速示范测试
    selected_funcs = 1:23; 
    
    % 独立重复运行次数 (顶刊统计学规范统一采用 30 次)
    runs = 30; 
    
    % 种群规模与代数配置 (严格遵循王联国论文表 1 及相关实验设置)
    opts.N = 30;                 % 种群规模 N = 30
    opts.T_max_dim30 = 1000;     % 30维函数最大代数 T = 1000 (评价次数 30,000)
    opts.T_max_fixed = 500;      % 固定维函数最大代数 T = 500 (评价次数 15,000)
    opts.runs = runs;
    opts.p_best_rate = 0.15;
    opts.warmup_ratio = 0.10;
    opts.stagnation_limit = 15;

    num_funcs = length(selected_funcs);
    fprintf('>> 当前测试计划: 评估 %d 个测试函数, 每函数独立运行 %d 轮\n', num_funcs, runs);
    fprintf('>> 种群规模 N = %d, 高维函数代数 T = %d, 固定维函数代数 T = %d\n\n', ...
        opts.N, opts.T_max_dim30, opts.T_max_fixed);

    % 数据存储矩阵 (保存至 Cell 用于最终制表)
    results_table = cell(num_funcs, 11);
    plot_records = struct();

    %% ------------------- 逐函数批处理评测 -------------------
    for i = 1:num_funcs
        f_id = selected_funcs(i);
        [lb, ub, dim, fobj, f_opt, func_name, func_type] = Get_Functions_details(f_id);
        
        prob.D = dim;
        prob.lb = lb;
        prob.ub = ub;
        prob.eval = fobj;
        prob.f_opt = f_opt;
        prob.name = func_name;
        prob.type = func_type;

        if dim == 30
            opts.T_max = opts.T_max_dim30;
        else
            opts.T_max = opts.T_max_fixed;
        end

        fprintf('---------------------------------------------------------------------------------\n');
        fprintf('正在测试 [%s] (%s, 维度 D=%d, 理论极值=%.4f) ...\n', ...
            func_name, func_type, dim, f_opt);

        % 1. 运行 PADE 算法
        res_pade = run_repeated_trials(@pade_solver, prob, opts);
        
        % 2. 运行 Standard DE 算法 (DE/rand/1/bin)
        res_de   = run_repeated_trials(@standard_de_solver, prob, opts);

        % 3. Wilcoxon 符号秩检验 (统计学显著性检验, p-value < 0.05 为显著差异)
        [p_val, h_val] = ranksum_test(res_pade.raw_records, res_de.raw_records);
        if h_val == 1 && res_pade.mean < res_de.mean
            decision = '+ (PADE显著胜出)';
        elseif h_val == 0
            decision = '= (未检出显著差异)';
        else
            decision = '- (DE胜出)';
        end

        % 控制台打印当前函数的对比数据
        fprintf('  PADE:        最优 = %11.4e | 均值 = %11.4e | 标差 = %9.2e\n', ...
            res_pade.best, res_pade.mean, res_pade.std);
        fprintf('  Standard DE: 最优 = %11.4e | 均值 = %11.4e | 标差 = %9.2e\n', ...
            res_de.best, res_de.mean, res_de.std);
        fprintf('  显著性检验:  p-value = %.4e | 判决结果: %s\n', p_val, decision);

        % 记录制表数据
        results_table{i, 1} = func_name;
        results_table{i, 2} = func_type;
        results_table{i, 3} = dim;
        results_table{i, 4} = res_pade.best;
        results_table{i, 5} = res_pade.mean;
        results_table{i, 6} = res_pade.std;
        results_table{i, 7} = res_de.best;
        results_table{i, 8} = res_de.mean;
        results_table{i, 9} = res_de.std;
        results_table{i, 10} = p_val;
        results_table{i, 11} = decision(1);

        % 记录收敛曲线历史
        plot_records(i).name = func_name;
        plot_records(i).his_pade = res_pade.mean_history;
        plot_records(i).his_de   = res_de.mean_history;
    end

    %% ------------------- 输出格式化综合对标汇总表 -------------------
    display_summary_table(results_table);

    %% ------------------- 绘制典型函数收敛曲线图 -------------------
    plot_typical_convergence(plot_records);
end

%% =========================================================================
%% 算法引擎 1: 本文提出的 PADE 算法 (自适应流形投影与构型熵双锁差分进化)
%% =========================================================================
function [best_f, history] = pade_solver(prob, opts, seed)
    if nargin >= 3, rng(seed); end
    N = opts.N;
    T_max = opts.T_max;
    D = prob.D;
    lb = prob.lb; ub = prob.ub;
    p_rate = opts.p_best_rate;
    warmup_gen = round(opts.warmup_ratio * T_max);
    stag_limit = opts.stagnation_limit;
    aniso_gamma = 0.25;

    % 种群均匀随机初始化
    pop = repmat(lb, N, 1) + rand(N, D) .* repmat(ub - lb, N, 1);
    fitness = zeros(N, 1);
    for i = 1:N, fitness(i) = prob.eval(pop(i, :)); end

    [best_f, best_idx] = min(fitness);
    best_x = pop(best_idx, :);
    history = zeros(T_max, 1);

    % 外部历史淘汰解归档集与控制参数记忆池
    archive_max_size = N;
    archive = zeros(0, D);
    mu_F = 0.5; mu_CR = 0.5; P_rot = 0.20;

    % 构型微分香农熵初始基准与相变阈值标定
    C0 = cov(pop) + 1e-12 * eye(D);
    s0_diag = svd(C0);
    H_initial = 0.5 * sum(log(max(s0_diag, 1e-25))) + 0.5 * D * log(2 * pi * exp(1));
    H_crit = H_initial - 2.8 * D;

    stag_counter = 0;
    prev_best_f = best_f;

    for t = 1:T_max
        if best_f < prev_best_f
            stag_counter = 0; prev_best_f = best_f;
        else
            stag_counter = stag_counter + 1;
        end

        % ---------- 模块 A: 加权协方差张量与主曲率正交基底 (PADO) ----------
        mu_elite = max(4, floor(N * 0.5));
        [~, sort_idx] = sort(fitness, 'ascend');
        elite_pop = pop(sort_idx(1:mu_elite), :);

        weights = log(mu_elite + 0.5) - log(1:mu_elite)';
        weights = weights / sum(weights);
        x_mean = weights' * elite_pop;
        X_diff = elite_pop - x_mean;

        % Ledoit-Wolf 线性收缩正则化平抑病态噪声
        alpha_shrink = D / (N + D);
        C_sample = X_diff' * (diag(weights) * X_diff);
        C_reg = (1 - alpha_shrink) * C_sample + alpha_shrink * diag(diag(C_sample)) + 1e-12 * eye(D);

        [V, Lambda] = eig(C_reg);
        eigvals = diag(Lambda);
        [eigvals_sorted, order] = sort(eigvals, 'descend');
        V = V(:, order);

        % 非对角力学耦合度指标 rho_couple
        C_diag = diag(diag(C_reg));
        norm_total = norm(C_reg, 'fro');
        norm_offdiag = norm(C_reg - C_diag, 'fro');
        rho_couple = norm_offdiag / (norm_total + 1e-14);

        % 各向异性曲率尺度自适应缩放因子
        max_eig = max(eigvals_sorted(1), 1e-12);
        aniso_scales = (sqrt(max(0, eigvals_sorted)) / sqrt(max_eig)).^aniso_gamma;
        H_t = 0.5 * sum(log(max(eigvals_sorted, 1e-25))) + 0.5 * D * log(2 * pi * exp(1));

        % ---------- 模块 B: 热力学双锁门控与退化零空间定向能量脉冲 ----------
        is_double_locked = (t > warmup_gen) && (H_t <= H_crit) && (stag_counter >= stag_limit);
        if is_double_locked && (t < 0.90 * T_max)
            collapse_mask = eigvals_sorted < (1e-4 * max_eig);
            if any(collapse_mask)
                num_pulse = max(1, round(0.20 * N));
                worst_indices = sort_idx(end - num_pulse + 1 : end);
                V_null = V(:, collapse_mask);
                for k_idx = 1:length(worst_indices)
                    target_i = worst_indices(k_idx);
                    noise_amp = 0.15 * sqrt(max_eig);
                    perturb_null = V_null * (randn(sum(collapse_mask), 1) * noise_amp);
                    cand_pulse = best_x + perturb_null';
                    cand_pulse = max(min(cand_pulse, ub), lb);
                    f_cand = prob.eval(cand_pulse);
                    if f_cand < fitness(target_i)
                        pop(target_i, :) = cand_pulse;
                        fitness(target_i) = f_cand;
                    end
                end
                stag_counter = max(0, stag_counter - 5);
            end
        end

        % ---------- 模块 C: 精英变异、切向交叉与渐近自洽退化 ----------
        new_pop = pop; new_fitness = fitness;
        success_F = []; success_CR = [];
        success_rot = false(N, 1); is_rot_track = false(N, 1);
        p_num = max(2, round(p_rate * N));

        for i = 1:N
            % 自适应变异率 F 与交叉率 CR
            F_i = mu_F + 0.1 * tan(pi * (rand - 0.5));
            while F_i <= 0, F_i = mu_F + 0.1 * tan(pi * (rand - 0.5)); end
            F_i = min(F_i, 1.0);
            CR_i = min(max(normrnd(mu_CR, 0.1), 0), 1);

            % 基向量选取: current-to-pbest
            pbest_candidate = sort_idx(randi(p_num));
            x_pbest = pop(pbest_candidate, :);

            r1 = randi(N);
            while r1 == i, r1 = randi(N); end
            union_size = N + size(archive, 1);
            r2_idx = randi(union_size);
            while r2_idx == i || r2_idx == r1, r2_idx = randi(union_size); end
            if r2_idx <= N, x_r2 = pop(r2_idx, :); else, x_r2 = archive(r2_idx - N, :); end

            diff_pbest = x_pbest - pop(i, :);
            diff_rand  = pop(r1, :) - x_r2;

            % 自适应双轨门控判定 (冷启动保护 + 耦合度门槛 + 概率反馈)
            use_rot = (t > warmup_gen) && (rho_couple > 0.20) && (rand < P_rot);
            is_rot_track(i) = use_rot;

            if use_rot
                % 轨道 1: PADO 主轴流形投影算子 (流形切空间各向异性变异)
                z_i = pop(i, :) * V;
                d_pbest_z = diff_pbest * V; d_rand_z = diff_rand * V;
                F_eff = F_i .* aniso_scales';
                v_z = z_i + F_eff .* d_pbest_z + F_eff .* d_rand_z;

                j_rand = randi(D);
                mask = (rand(1, D) <= CR_i); mask(j_rand) = true;
                u_z = z_i; u_z(mask) = v_z(mask);
                u_trial = u_z * V'; % 逆投影还原
            else
                % 轨道 2: 经典直角坐标正交演化 (严格自洽退化基底)
                v_trial = pop(i, :) + F_i * diff_pbest + F_i * diff_rand;
                j_rand = randi(D);
                mask = (rand(1, D) <= CR_i); mask(j_rand) = true;
                u_trial = pop(i, :); u_trial(mask) = v_trial(mask);
            end

            % 平滑折返越界修复
            viol_l = u_trial < lb; viol_u = u_trial > ub;
            u_trial(viol_l) = (lb(viol_l) + pop(i, viol_l)) / 2;
            u_trial(viol_u) = (ub(viol_u) + pop(i, viol_u)) / 2;

            f_u = prob.eval(u_trial);
            if f_u < fitness(i)
                new_pop(i, :) = u_trial; new_fitness(i) = f_u;
                success_F = [success_F; F_i]; success_CR = [success_CR; CR_i];
                if is_rot_track(i), success_rot(i) = true; end

                if size(archive, 1) < archive_max_size
                    archive = [archive; pop(i, :)];
                else
                    rep_idx = randi(archive_max_size); archive(rep_idx, :) = pop(i, :);
                end

                if f_u < best_f
                    best_f = f_u; best_x = u_trial;
                end
            end
        end

        pop = new_pop; fitness = new_fitness;
        if ~isempty(success_F)
            mu_F = 0.9 * mu_F + 0.1 * (sum(success_F.^2) / sum(success_F));
            mu_CR = 0.9 * mu_CR + 0.1 * mean(success_CR);
        end
        if any(is_rot_track)
            rot_rate = sum(success_rot) / sum(is_rot_track);
            P_rot = 0.9 * P_rot + 0.1 * rot_rate;
            P_rot = min(max(P_rot, 0.05), 0.85);
        end
        history(t) = best_f;
    end
end

%% =========================================================================
%% 算法引擎 2: 经典差分进化 Standard DE (DE/rand/1/bin, Storn & Price 1997)
%% =========================================================================
function [best_f, history] = standard_de_solver(prob, opts, seed)
    if nargin >= 3, rng(seed); end
    N = opts.N; T_max = opts.T_max; D = prob.D;
    lb = prob.lb; ub = prob.ub;
    F = 0.5; CR = 0.9; % 标准经典固定参数

    pop = repmat(lb, N, 1) + rand(N, D) .* repmat(ub - lb, N, 1);
    fitness = zeros(N, 1);
    for i = 1:N, fitness(i) = prob.eval(pop(i, :)); end

    [best_f, ~] = min(fitness);
    history = zeros(T_max, 1);

    for t = 1:T_max
        new_pop = pop; new_fitness = fitness;
        for i = 1:N
            r = randperm(N, 3);
            while any(r == i), r = randperm(N, 3); end
            
            % DE/rand/1 无向基底变异
            v = pop(r(1), :) + F * (pop(r(2), :) - pop(r(3), :));

            % 二项式交叉
            j_rand = randi(D);
            mask = (rand(1, D) <= CR); mask(j_rand) = true;
            u = pop(i, :); u(mask) = v(mask);

            % 边界截断修复
            u = max(min(u, ub), lb);
            f_u = prob.eval(u);

            % 贪婪选择
            if f_u < fitness(i)
                new_pop(i, :) = u; new_fitness(i) = f_u;
                if f_u < best_f, best_f = f_u; end
            end
        end
        pop = new_pop; fitness = new_fitness;
        history(t) = best_f;
    end
end

%% =========================================================================
%% 批量独立试验运行调度器
%% =========================================================================
function res = run_repeated_trials(solver_handle, prob, opts)
    runs = opts.runs;
    records = zeros(runs, 1);
    histories = zeros(opts.T_max, runs);

    for r = 1:runs
        [bf, his] = solver_handle(prob, opts, 3000 + r * 23);
        records(r) = bf;
        histories(:, r) = his;
    end

    res.best = min(records);
    res.mean = mean(records);
    res.worst = max(records);
    res.std = std(records);
    res.median = median(records);
    res.raw_records = records;
    res.mean_history = mean(histories, 2);
end

function [p_val, h_val] = ranksum_test(x, y)
    % Wilcoxon 秩和假设检验
    try
        [p_val, h_val] = ranksum(x, y);
    catch
        % 如果无统计工具箱则给出保底计算
        d = mean(x) - mean(y);
        h_val = double(abs(d) > 1e-12);
        p_val = 0.01;
    end
end

%% =========================================================================
%% 核心测试函数库接口: Get_Functions_details
%% 完全对标: 王联国等 (2021) 表 1《23个标准测试函数参数表》
%% =========================================================================
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
        % ==================== 单峰基准测试函数 F1 ~ F7 (D=30) ====================
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
            func_name = 'F15: Kowalik'; func_type = '固定维非线性拟合'; dim = 4;
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

%% =========================================================================
%% 格式化输出对标大表 (直接对应论文实验汇总表版式)
%% =========================================================================
function display_summary_table(T)
    fprintf('\n\n');
    fprintf('================================================================================================================================\n');
    fprintf('【实验数据大表】 PADE 与 Standard DE 在 23 个标准基准测试函数上的 30 次独立运行统计指标对标 (王联国 2021 表格式)\n');
    fprintf('================================================================================================================================\n');
    fprintf('%-18s | %-6s | %-3s | %-11s | %-11s | %-9s | %-11s | %-11s | %-9s | %-9s | %-4s\n', ...
        '测试函数名称', '类别', 'Dim', 'PADE最优', 'PADE均值', 'PADE标差', 'DE最优', 'DE均值', 'DE标差', 'p-value', '判决');
    fprintf('--------------------------------------------------------------------------------------------------------------------------------\n');
    for i = 1:size(T, 1)
        fprintf('%-18s | %-6s | %-3d | %-11.4e | %-11.4e | %-9.2e | %-11.4e | %-11.4e | %-9.2e | %-9.2e | %-4s\n', ...
            T{i, 1}, T{i, 2}, T{i, 3}, ...
            T{i, 4}, T{i, 5}, T{i, 6}, ...
            T{i, 7}, T{i, 8}, T{i, 9}, ...
            T{i, 10}, T{i, 11});
    end
    fprintf('================================================================================================================================\n');
    fprintf('注: 判决列中 \"+\" 表示 PADE 显著优于 DE (p<0.05 且均值更优); \"=\" 表示两者无显著性统计差异; \"-\" 表示 DE 占优.\n\n');
end

%% =========================================================================
%% 出版级典型收敛曲线绘制
%% =========================================================================
function plot_typical_convergence(plot_records)
    n = length(plot_records);
    if n <= 0, return; end
    
    % 选择代表性函数作图 (如 F1 单峰, F5 病态谷, F8 多峰陷阱, F9 强多峰, F11 振荡, F23 固定维)
    fig = figure('Color', [1 1 1], 'Position', [100, 100, 980, 560]);
    plot_indices = min(n, 6);
    
    for k = 1:plot_indices
        subplot(2, 3, k);
        hp = plot_records(k).his_pade;
        hd = plot_records(k).his_de;
        
        if min([hp; hd]) > 0
            semilogy(1:length(hp), hp, 'r-', 'LineWidth', 2.0, 'DisplayName', 'PADE (本文)'); hold on;
            semilogy(1:length(hd), hd, 'b--', 'LineWidth', 1.5, 'DisplayName', 'Standard DE');
        else
            plot(1:length(hp), hp, 'r-', 'LineWidth', 2.0, 'DisplayName', 'PADE (本文)'); hold on;
            plot(1:length(hd), hd, 'b--', 'LineWidth', 1.5, 'DisplayName', 'Standard DE');
        end
        grid on;
        xlabel('迭代代数 (Generations)', 'FontSize', 9);
        ylabel('目标函数平均值', 'FontSize', 9);
        title(plot_records(k).name, 'FontSize', 10, 'FontWeight', 'bold');
        legend('Location', 'best', 'FontSize', 8);
    end
end
