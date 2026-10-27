%% =========================================================================
%% PADE 算法 23 个国际标准基准测试函数 (F1~F23) 对比评测系统
%% 基准测试集完全对标: 王联国等 (2021)《基于采蜜机制的正弦余弦算法及其在机械优化设计中的应用》表 1
%% 
%% 测试函数分类体系:
%% 1. F1 ~ F7  : 单峰基准测试函数 (Unimodal, D=30, 检验局部精细开掘与极限收敛精度)
%% 2. F8 ~ F13 : 多峰基准测试函数 (Multimodal, D=30, 检验全局勘探与跳出局部极值早熟停滞)
%% 3. F14 ~ F23: 固定维度多峰测试函数 (Fixed-dimension, D=2~6, 检验低维复杂多谷地形适应力)
%% 
%% 对比算法:
%% 1. PADE (本文提出的主轴流形投影与构型熵双锁自适应差分进化算法)
%% 2. Standard DE (经典差分进化算法 DE/rand/1/bin, Storn & Price 1997)
%% =========================================================================

function PADE_Benchmark_Suite()
    clc; clear; close all;
    fprintf('=========================================================================\n');
    fprintf('   PADE 算法与经典 DE 在 23 个标准测试函数 (王联国 2021 对标) 横向评测\n');
    fprintf('=========================================================================\n\n');

    % ---------------- 运行模式配置 ----------------
    % 可选运行模式:
    % 'demo' : 快速评估 6 个最具代表性的核心函数 (F1 单峰, F5 病态谷, F8 多峰, F9 复杂多峰, F11 振荡, F23 固定维)
    % 'full' : 全量评估全部 23 个基准测试函数 (F1 ~ F23)
    run_mode = 'demo'; 
    
    if strcmp(run_mode, 'demo')
        test_func_ids = [1, 5, 8, 9, 11, 23];
        runs = 10; % 快速示范运行 10 次 (正式成文建议 30 次)
        fprintf('>>> 当前模式: [DEMO 示范评测] 评估经典代表性函数: F1, F5, F8, F9, F11, F23 (%d次独立运行)\n\n', runs);
    else
        test_func_ids = 1:23;
        runs = 30; % 顶刊统计规范: 30 次独立运行
        fprintf('>>> 当前模式: [FULL 全量评测] 评估全部 23 个测试函数 (%d次独立运行)\n\n', runs);
    end

    num_funcs = length(test_func_ids);
    
    % 算法统一超参数配置 (严格对标王联国论文表 1 及标准实验规范)
    opts.N = 30;                 % 种群规模 N = 30
    opts.T_max_dim30 = 1000;     % 30维函数最大迭代代数 T = 1000
    opts.T_max_fixed = 500;      % 固定维函数最大迭代代数 T = 500
    opts.runs = runs;
    opts.p_best_rate = 0.15;
    opts.warmup_ratio = 0.10;
    opts.stagnation_limit = 15;

    % 存储统计结果汇总
    results_summary = cell(num_funcs, 9);

    % 循环测试各基准函数
    for idx = 1:num_funcs
        f_id = test_func_ids(idx);
        prob = get_benchmark_func_info(f_id);
        
        if prob.D == 30
            opts.T_max = opts.T_max_dim30;
        else
            opts.T_max = opts.T_max_fixed;
        end

        fprintf('-------------------------------------------------------------------------\n');
        fprintf('正在测试 [%s] (%s, 维度 D=%d, 理论最优=%.4f) ...\n', ...
            prob.name, prob.type, prob.D, prob.f_opt);
        fprintf('-------------------------------------------------------------------------\n');

        % 运行 PADE 算法
        res_pade = run_benchmark_trials(@pade_solver, prob, opts);
        % 运行 Standard DE 算法 (DE/rand/1/bin)
        res_de   = run_benchmark_trials(@standard_de_solver, prob, opts);

        % 控制台打印单函数横向对比
        fprintf('  PADE:        最优 = %.4e | 均值 = %.4e | 标准差 = %.2e\n', ...
            res_pade.best, res_pade.mean, res_pade.std);
        fprintf('  Standard DE: 最优 = %.4e | 均值 = %.4e | 标准差 = %.2e\n', ...
            res_de.best, res_de.mean, res_de.std);

        % 保存数据用于绘制与制表
        results_summary{idx, 1} = prob.name;
        results_summary{idx, 2} = prob.type;
        results_summary{idx, 3} = prob.D;
        results_summary{idx, 4} = res_pade.best;
        results_summary{idx, 5} = res_pade.mean;
        results_summary{idx, 6} = res_pade.std;
        results_summary{idx, 7} = res_de.best;
        results_summary{idx, 8} = res_de.mean;
        results_summary{idx, 9} = res_de.std;

        % 记录收敛历史用于作图
        plot_data(idx).name = prob.name;
        plot_data(idx).his_pade = res_pade.history_mean;
        plot_data(idx).his_de   = res_de.history_mean;
    end

    % 打印完整的综合对标汇总表
    print_benchmark_table(results_summary);

    % 绘制收敛性能演化轨迹对比图
    plot_benchmark_convergence(plot_data);
end

%% =========================================================================
%% 求解器 1: 本文提出的 PADE 算法核心实现 (针对无约束函数的自洽退化版本)
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

    % 种群均匀初始化
    pop = repmat(lb, N, 1) + rand(N, D) .* repmat(ub - lb, N, 1);
    fitness = zeros(N, 1);
    for i = 1:N, fitness(i) = prob.eval(pop(i, :)); end

    [best_f, best_idx] = min(fitness);
    best_x = pop(best_idx, :);
    history = zeros(T_max, 1);

    archive_max_size = N;
    archive = zeros(0, D);
    mu_F = 0.5; mu_CR = 0.5; P_rot = 0.20;

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

        % 协方差张量与主轴分解 (PADO 模块)
        mu_elite = max(4, floor(N * 0.5));
        [~, sort_idx] = sort(fitness, 'ascend');
        elite_pop = pop(sort_idx(1:mu_elite), :);

        weights = log(mu_elite + 0.5) - log(1:mu_elite)';
        weights = weights / sum(weights);
        x_mean = weights' * elite_pop;
        X_diff = elite_pop - x_mean;

        alpha_shrink = D / (N + D);
        C_sample = X_diff' * (diag(weights) * X_diff);
        C_reg = (1 - alpha_shrink) * C_sample + alpha_shrink * diag(diag(C_sample)) + 1e-12 * eye(D);

        [V, Lambda] = eig(C_reg);
        eigvals = diag(Lambda);
        [eigvals_sorted, order] = sort(eigvals, 'descend');
        V = V(:, order);

        C_diag = diag(diag(C_reg));
        norm_total = norm(C_reg, 'fro');
        norm_offdiag = norm(C_reg - C_diag, 'fro');
        rho_couple = norm_offdiag / (norm_total + 1e-14);

        max_eig = max(eigvals_sorted(1), 1e-12);
        aniso_scales = (sqrt(max(0, eigvals_sorted)) / sqrt(max_eig)).^aniso_gamma;
        H_t = 0.5 * sum(log(max(eigvals_sorted, 1e-25))) + 0.5 * D * log(2 * pi * exp(1));

        % 双锁门控与零空间脉冲脱困
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

        % 变异与交叉生成
        new_pop = pop; new_fitness = fitness;
        success_F = []; success_CR = [];
        success_rot = false(N, 1); is_rot_track = false(N, 1);
        p_num = max(2, round(p_rate * N));

        for i = 1:N
            F_i = mu_F + 0.1 * tan(pi * (rand - 0.5));
            while F_i <= 0, F_i = mu_F + 0.1 * tan(pi * (rand - 0.5)); end
            F_i = min(F_i, 1.0);
            CR_i = min(max(normrnd(mu_CR, 0.1), 0), 1);

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

            use_rot = (t > warmup_gen) && (rho_couple > 0.20) && (rand < P_rot);
            is_rot_track(i) = use_rot;

            if use_rot
                z_i = pop(i, :) * V;
                d_pbest_z = diff_pbest * V; d_rand_z = diff_rand * V;
                F_eff = F_i .* aniso_scales';
                v_z = z_i + F_eff .* d_pbest_z + F_eff .* d_rand_z;

                j_rand = randi(D);
                mask = (rand(1, D) <= CR_i); mask(j_rand) = true;
                u_z = z_i; u_z(mask) = v_z(mask);
                u_trial = u_z * V';
            else
                v_trial = pop(i, :) + F_i * diff_pbest + F_i * diff_rand;
                j_rand = randi(D);
                mask = (rand(1, D) <= CR_i); mask(j_rand) = true;
                u_trial = pop(i, :); u_trial(mask) = v_trial(mask);
            end

            % 折返式越界平滑修复
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
%% 求解器 2: 经典差分进化算法 Standard DE (DE/rand/1/bin, Storn 1997)
%% =========================================================================
function [best_f, history] = standard_de_solver(prob, opts, seed)
    if nargin >= 3, rng(seed); end
    N = opts.N; T_max = opts.T_max; D = prob.D;
    lb = prob.lb; ub = prob.ub;
    F = 0.5; CR = 0.9; % 经典标准固定参数设置

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
            
            % DE/rand/1 经典正交基底变异
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
function res = run_benchmark_trials(solver_handle, prob, opts)
    runs = opts.runs;
    f_records = zeros(runs, 1);
    histories = zeros(opts.T_max, runs);

    for r = 1:runs
        [bf, his] = solver_handle(prob, opts, 2000 + r * 17);
        f_records(r) = bf;
        histories(:, r) = his;
    end

    res.best = min(f_records);
    res.mean = mean(f_records);
    res.worst = max(f_records);
    res.std = std(f_records);
    res.history_mean = mean(histories, 2);
end

%% =========================================================================
%% 基准测试函数定义库 (23 个函数严格对标王联国论文表 1)
%% =========================================================================
function prob = get_benchmark_func_info(f_id)
    switch f_id
        % -------- 单峰基准测试函数 F1 ~ F7 (D=30) --------
        case 1
            prob.name = 'F1: Sphere'; prob.type = '单峰'; prob.D = 30;
            prob.lb = -100 * ones(1, prob.D); prob.ub = 100 * ones(1, prob.D);
            prob.f_opt = 0.0; prob.eval = @(x) sum(x.^2);
        case 2
            prob.name = 'F2: Schwefel 2.22'; prob.type = '单峰'; prob.D = 30;
            prob.lb = -10 * ones(1, prob.D); prob.ub = 10 * ones(1, prob.D);
            prob.f_opt = 0.0; prob.eval = @(x) sum(abs(x)) + prod(abs(x));
        case 3
            prob.name = 'F3: Schwefel 1.2'; prob.type = '单峰'; prob.D = 30;
            prob.lb = -100 * ones(1, prob.D); prob.ub = 100 * ones(1, prob.D);
            prob.f_opt = 0.0; prob.eval = @(x) sum(cumsum(x).^2);
        case 4
            prob.name = 'F4: Schwefel 2.21'; prob.type = '单峰'; prob.D = 30;
            prob.lb = -100 * ones(1, prob.D); prob.ub = 100 * ones(1, prob.D);
            prob.f_opt = 0.0; prob.eval = @(x) max(abs(x));
        case 5
            prob.name = 'F5: Rosenbrock'; prob.type = '单峰病态谷'; prob.D = 30;
            prob.lb = -30 * ones(1, prob.D); prob.ub = 30 * ones(1, prob.D);
            prob.f_opt = 0.0;
            prob.eval = @(x) sum(100.0 * (x(2:end) - x(1:end-1).^2).^2 + (x(1:end-1) - 1.0).^2);
        case 6
            prob.name = 'F6: Step'; prob.type = '单峰阶梯'; prob.D = 30;
            prob.lb = -100 * ones(1, prob.D); prob.ub = 100 * ones(1, prob.D);
            prob.f_opt = 0.0; prob.eval = @(x) sum(floor(x + 0.5).^2);
        case 7
            prob.name = 'F7: Quartic with Noise'; prob.type = '单峰加噪'; prob.D = 30;
            prob.lb = -1.28 * ones(1, prob.D); prob.ub = 1.28 * ones(1, prob.D);
            prob.f_opt = 0.0; prob.eval = @(x) sum((1:length(x)) .* (x.^4)) + rand();

        % -------- 多峰基准测试函数 F8 ~ F13 (D=30) --------
        case 8
            prob.name = 'F8: Schwefel 2.26'; prob.type = '多峰多陷阱'; prob.D = 30;
            prob.lb = -500 * ones(1, prob.D); prob.ub = 500 * ones(1, prob.D);
            prob.f_opt = -12569.48; prob.eval = @(x) sum(-x .* sin(sqrt(abs(x))));
        case 9
            prob.name = 'F9: Rastrigin'; prob.type = '多峰强振荡'; prob.D = 30;
            prob.lb = -5.12 * ones(1, prob.D); prob.ub = 5.12 * ones(1, prob.D);
            prob.f_opt = 0.0; prob.eval = @(x) sum(x.^2 - 10.0 * cos(2.0 * pi * x) + 10.0);
        case 10
            prob.name = 'F10: Ackley'; prob.type = '多峰高振荡'; prob.D = 30;
            prob.lb = -32 * ones(1, prob.D); prob.ub = 32 * ones(1, prob.D);
            prob.f_opt = 0.0;
            prob.eval = @(x) -20.0 * exp(-0.2 * sqrt(sum(x.^2)/length(x))) - exp(sum(cos(2*pi*x))/length(x)) + 20.0 + exp(1);
        case 11
            prob.name = 'F11: Griewank'; prob.type = '多峰耦合振荡'; prob.D = 30;
            prob.lb = -600 * ones(1, prob.D); prob.ub = 600 * ones(1, prob.D);
            prob.f_opt = 0.0;
            prob.eval = @(x) sum(x.^2)/4000.0 - prod(cos(x ./ sqrt(1:length(x)))) + 1.0;
        case 12
            prob.name = 'F12: Penalized 1'; prob.type = '多峰带罚'; prob.D = 30;
            prob.lb = -50 * ones(1, prob.D); prob.ub = 50 * ones(1, prob.D);
            prob.f_opt = 0.0; prob.eval = @(x) eval_penalized1(x);
        case 13
            prob.name = 'F13: Penalized 2'; prob.type = '多峰带罚'; prob.D = 30;
            prob.lb = -50 * ones(1, prob.D); prob.ub = 50 * ones(1, prob.D);
            prob.f_opt = 0.0; prob.eval = @(x) eval_penalized2(x);

        % -------- 固定维度多峰测试函数 F14 ~ F23 (D=2~6) --------
        case 14
            prob.name = 'F14: Shekel Foxholes'; prob.type = '固定维多峰'; prob.D = 2;
            prob.lb = -65 * ones(1, 2); prob.ub = 65 * ones(1, 2);
            prob.f_opt = 1.0; prob.eval = @(x) eval_f14(x);
        case 15
            prob.name = 'F15: Kowalik'; prob.type = '固定维非线性拟合'; prob.D = 4;
            prob.lb = -5 * ones(1, 4); prob.ub = 5 * ones(1, 4);
            prob.f_opt = 0.0003075; prob.eval = @(x) eval_f15(x);
        case 16
            prob.name = 'F16: Six-Hump Camel'; prob.type = '固定维多极值'; prob.D = 2;
            prob.lb = -5 * ones(1, 2); prob.ub = 5 * ones(1, 2);
            prob.f_opt = -1.0316;
            prob.eval = @(x) 4.0*x(1)^2 - 2.1*x(1)^4 + (1/3)*x(1)^6 + x(1)*x(2) - 4.0*x(2)^2 + 4.0*x(2)^4;
        case 17
            prob.name = 'F17: Branin'; prob.type = '固定维多极值'; prob.D = 2;
            prob.lb = -5 * ones(1, 2); prob.ub = 5 * ones(1, 2);
            prob.f_opt = 0.398;
            prob.eval = @(x) (x(2) - (5.1/(4*pi^2))*x(1)^2 + (5/pi)*x(1) - 6)^2 + 10*(1 - 1/(8*pi))*cos(x(1)) + 10;
        case 18
            prob.name = 'F18: Goldstein-Price'; prob.type = '固定维多项式'; prob.D = 2;
            prob.lb = zeros(1, 2); prob.ub = 2 * ones(1, 2);
            prob.f_opt = 3.0; prob.eval = @(x) eval_f18(x);
        case 19
            prob.name = 'F19: Hartman 3D'; prob.type = '固定维多峰'; prob.D = 3;
            prob.lb = zeros(1, 3); prob.ub = ones(1, 3);
            prob.f_opt = -3.86; prob.eval = @(x) eval_f19(x);
        case 20
            prob.name = 'F20: Hartman 6D'; prob.type = '固定维多峰'; prob.D = 6;
            prob.lb = zeros(1, 6); prob.ub = ones(1, 6);
            prob.f_opt = -3.32; prob.eval = @(x) eval_f20(x);
        case 21
            prob.name = 'F21: Shekel 5'; prob.type = '固定维多谷'; prob.D = 4;
            prob.lb = zeros(1, 4); prob.ub = 10 * ones(1, 4);
            prob.f_opt = -10.1532; prob.eval = @(x) eval_shekel(x, 5);
        case 22
            prob.name = 'F22: Shekel 7'; prob.type = '固定维多谷'; prob.D = 4;
            prob.lb = zeros(1, 4); prob.ub = 10 * ones(1, 4);
            prob.f_opt = -10.4028; prob.eval = @(x) eval_shekel(x, 7);
        case 23
            prob.name = 'F23: Shekel 10'; prob.type = '固定维多谷'; prob.D = 4;
            prob.lb = zeros(1, 4); prob.ub = 10 * ones(1, 4);
            prob.f_opt = -10.5363; prob.eval = @(x) eval_shekel(x, 10);
    end
end

%% =========================================================================
%% 辅助函数: 复杂测试函数的严格数学计算
%% =========================================================================
function val = eval_penalized1(x)
    dim = length(x);
    y = 1.0 + (x + 1.0) / 4.0;
    term1 = 10.0 * sin(pi * y(1))^2;
    term2 = sum((y(1:dim-1) - 1.0).^2 .* (1.0 + 10.0 * sin(pi * y(2:dim)).^2));
    term3 = (y(dim) - 1.0)^2;
    val = (pi / dim) * (term1 + term2 + term3) + sum(u_pen(x, 10, 100, 4));
end

function val = eval_penalized2(x)
    dim = length(x);
    term1 = sin(3.0 * pi * x(1))^2;
    term2 = sum((x(1:dim-1) - 1.0).^2 .* (1.0 + sin(3.0 * pi * x(2:dim)).^2));
    term3 = (x(dim) - 1.0)^2 * (1.0 + sin(2.0 * pi * x(dim))^2);
    val = 0.1 * (term1 + term2 + term3) + sum(u_pen(x, 5, 100, 4));
end

function u_res = u_pen(x, a, k, m)
    u_res = zeros(size(x));
    idx_u = x > a; u_res(idx_u) = k * (x(idx_u) - a).^m;
    idx_l = x < -a; u_res(idx_l) = k * (-x(idx_l) - a).^m;
end

function val = eval_f14(x)
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

function val = eval_f15(x)
    aK = [0.1957, 0.1947, 0.1735, 0.1600, 0.1472, 0.1392, 0.1320, 0.1287, 0.1235, 0.1190, 0.1180];
    bK = 1.0 ./ [0.25, 0.5, 1, 2, 4, 6, 8, 10, 12, 14, 16];
    val = sum((aK - (x(1) .* (bK.^2 + x(2) .* bK)) ./ (bK.^2 + x(3) .* bK + x(4))).^2);
end

function val = eval_f18(x)
    t1 = 1.0 + (x(1) + x(2) + 1.0)^2 * (19.0 - 14.0*x(1) + 3.0*x(1)^2 - 14.0*x(2) + 6.0*x(1)*x(2) + 3.0*x(2)^2);
    t2 = 30.0 + (2.0*x(1) - 3.0*x(2))^2 * (18.0 - 32.0*x(1) + 12.0*x(1)^2 + 48.0*x(2) - 36.0*x(1)*x(2) + 27.0*x(2)^2);
    val = t1 * t2;
end

function val = eval_f19(x)
    aH = [3, 10, 30; 0.1, 10, 35; 3, 10, 30; 0.1, 10, 35];
    cH = [1, 1.2, 3, 3.2];
    pH = [0.3689, 0.1170, 0.2673; 0.4699, 0.4387, 0.7470; 0.1091, 0.8732, 0.5547; 0.03815, 0.5743, 0.8828];
    s = 0.0;
    for i = 1:4, s = s + cH(i) * exp(-sum(aH(i, :) .* (x - pH(i, :)).^2)); end
    val = -s;
end

function val = eval_f20(x)
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

function val = eval_shekel(x, m)
    aSH = [
        4, 4, 4, 4; 1, 1, 1, 1; 8, 8, 8, 8; 6, 6, 6, 6; 3, 7, 3, 7;
        2, 9, 2, 9; 5, 5, 3, 3; 8, 1, 8, 1; 6, 2, 6, 2; 7, 3.6, 7, 3.6
    ];
    cSH = [0.1, 0.2, 0.2, 0.4, 0.4, 0.6, 0.3, 0.7, 0.5, 0.5];
    s = 0.0;
    for i = 1:m, s = s + 1.0 / (sum((x - aSH(i, :)).^2) + cSH(i)); end
    val = -s;
end

%% =========================================================================
%% 格式化表格输出
%% =========================================================================
function print_benchmark_table(res_cell)
    fprintf('\n\n===============================================================================================================\n');
    fprintf('【论文对照表】 PADE 算法与 Standard DE 在 23 个标准基准测试函数上的实验结果统计汇总 (王联国 2021 格式)\n');
    fprintf('===============================================================================================================\n');
    fprintf('%-18s | %-6s | %-3s | %-12s | %-12s | %-10s | %-12s | %-12s | %-10s\n', ...
        '测试函数名称', '类别', 'Dim', 'PADE最优', 'PADE均值', 'PADE标差', 'DE最优', 'DE均值', 'DE标差');
    fprintf('---------------------------------------------------------------------------------------------------------------\n');
    for i = 1:size(res_cell, 1)
        fprintf('%-18s | %-6s | %-3d | %-12.4e | %-12.4e | %-10.2e | %-12.4e | %-12.4e | %-10.2e\n', ...
            res_cell{i, 1}, res_cell{i, 2}, res_cell{i, 3}, ...
            res_cell{i, 4}, res_cell{i, 5}, res_cell{i, 6}, ...
            res_cell{i, 7}, res_cell{i, 8}, res_cell{i, 9});
    end
    fprintf('===============================================================================================================\n\n');
end

%% =========================================================================
%% 绘制出版级收敛历程对比图 (对标王联国论文图 3 ~ 图 8)
%% =========================================================================
function plot_benchmark_convergence(plot_data)
    num_p = length(plot_data);
    cols = min(3, num_p);
    rows = ceil(num_p / cols);
    
    figure('Color', [1 1 1], 'Position', [100, 100, 320 * cols, 260 * rows]);
    
    for i = 1:num_p
        subplot(rows, cols, i);
        his_p = plot_data(i).his_pade;
        his_d = plot_data(i).his_de;
        
        % 针对非负函数采用半对数坐标，针对负最优函数采用线性坐标
        if min([his_p; his_d]) > 0
            semilogy(1:length(his_p), his_p, 'r-', 'LineWidth', 2.0, 'DisplayName', 'PADE (本文)'); hold on;
            semilogy(1:length(his_d), his_d, 'b--', 'LineWidth', 1.5, 'DisplayName', 'Standard DE');
        else
            plot(1:length(his_p), his_p, 'r-', 'LineWidth', 2.0, 'DisplayName', 'PADE (本文)'); hold on;
            plot(1:length(his_d), his_d, 'b--', 'LineWidth', 1.5, 'DisplayName', 'Standard DE');
        end
        grid on;
        xlabel('迭代代数 (Generations)', 'FontSize', 9);
        ylabel('目标函数平均值', 'FontSize', 9);
        title(plot_data(i).name, 'FontSize', 10, 'FontWeight', 'bold');
        legend('Location', 'best', 'FontSize', 8);
    end
end
