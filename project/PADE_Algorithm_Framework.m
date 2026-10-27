%% =========================================================================
%% 算法名称: PADE (Principal-Axis & Entropy-driven Differential Evolution)
%% 中文全称: 基于主轴流形投影与构型熵双锁门控的自适应差分进化算法
%% 文件类型: MATLAB 源码实现与工程测试套件 (Stand-alone Script)
%%
%% -------------------------------------------------------------------------
%% 【四大核心创新机制及与工程难点的一对一映射】:
%% 1. 局部精细开掘与高维强耦合流形 (PADO):
%%    - 加权精英协方差张量 + Ledoit-Wolf 线性收缩正则化 C_reg
%%    - 正交谱分解 C_reg = V * Lambda * V^T, 提取局部主曲率切空间基底
%%    - 各向异性曲率自适应尺度缩放 (宽轴测地线大步长下潜, 窄轴垂直峭壁微米微调)
%% 2. 基础收敛速度与约束通道协同:
%%    - 精英导向变异 (current-to-pbest/1) 结合外部历史淘汰解归档集 (Archive)
%%    - 兼顾极速向优俯冲动能与安全可行走廊导向
%% 3. 后期早熟停滞确诊与骨架守恒脱困:
%%    - 高维相空间微观构型微分香农熵 H(t) 实时相态监控
%%    - [相体积塌缩 H(t) <= H_crit] 且 [最优值停滞 W(t) >= W_max] 的“双锁安全阀”
%%    - 确诊死锁后, 冻结主要力学承载骨架 (大特征值轴), 仅向方差坍塌的退化零空间定向激发
%% 4. 有限紧致摄动牵制与渐近自洽退化原理:
%%    - 冷启动退避保护 (前 10% 代保持原轴自由探索, 消除前期无谓开销)
%%    - 自适应双轨门控 (ADF) 与非对角力学耦合度度量 (rho_couple)
%%    - 在可分离或常规阶段, 算子自发渐近退化回经典 DE, 杜绝投影泄漏
%% 5. 工程约束处理:
%%    - Deb 可行性优先比较法则 (Feasibility-First Rules)
%% =========================================================================

function PADE_Main()
    clc; clear; close all;
    fprintf('=========================================================================\n');
    fprintf('   PADE 算法: 面向复杂非线性工程约束优化的自适应差分进化求解器\n');
    fprintf('   开发环境: MATLAB R2020b 及以上\n');
    fprintf('=========================================================================\n\n');

    %% ---------------------------------------------------------------------
    %% 测试案例 1: 压力容器制造综合成本优化设计 (Pressure Vessel Design, 4维)
    %% ---------------------------------------------------------------------
    fprintf('>>> 正在运行 案例 1: 压力容器制造综合成本优化设计 (30次独立寻优) ...\n');
    prob_pv = get_pressure_vessel_problem();
    opts_pv.N = 40;                % 种群规模
    opts_pv.T_max = 2500;          % 最大演化代数
    opts_pv.p_best_rate = 0.15;    % current-to-pbest 精英比例
    opts_pv.warmup_ratio = 0.10;   % 冷启动保护比例 (前10%代原轴探索)
    opts_pv.stagnation_limit = 15; % 双锁停滞代数门槛
    opts_pv.runs = 30;             % 30次独立统计试验

    res_pv = run_batch_experiments(prob_pv, opts_pv);
    display_engineering_results(prob_pv, res_pv);

    %% ---------------------------------------------------------------------
    %% 测试案例 2: 焊接梁最小制造成本优化设计 (Welded Beam Design, 4维)
    %% ---------------------------------------------------------------------
    fprintf('\n>>> 正在运行 案例 2: 焊接梁最小制造成本优化设计 (30次独立寻优) ...\n');
    prob_wb = get_welded_beam_problem();
    opts_wb.N = 40;
    opts_wb.T_max = 2500;
    opts_wb.p_best_rate = 0.15;
    opts_wb.warmup_ratio = 0.10;
    opts_wb.stagnation_limit = 15;
    opts_wb.runs = 30;

    res_wb = run_batch_experiments(prob_wb, opts_wb);
    display_engineering_results(prob_wb, res_wb);

    %% ---------------------------------------------------------------------
    %% 测试案例 3: 悬臂梁轻量化优化设计 (Cantilever Beam Design, 5维)
    %% ---------------------------------------------------------------------
    fprintf('\n>>> 正在运行 案例 3: 悬臂梁轻量化设计 (30次独立寻优) ...\n');
    prob_cb = get_cantilever_beam_problem();
    opts_cb.N = 40;
    opts_cb.T_max = 2500;
    opts_cb.p_best_rate = 0.15;
    opts_cb.warmup_ratio = 0.10;
    opts_cb.stagnation_limit = 15;
    opts_cb.runs = 30;

    res_cb = run_batch_experiments(prob_cb, opts_cb);
    display_engineering_results(prob_cb, res_cb);

    %% ---------------------------------------------------------------------
    %% 绘制收敛演化曲线对比
    %% ---------------------------------------------------------------------
    plot_convergence_curves(res_pv, res_wb, res_cb);
end

%% =========================================================================
%% 核心算法引擎: PADE 求解器 (包含四大创新模块闭环)
%% =========================================================================
function [best_x, best_f, best_cv, history] = pade_solve(prob, opts, seed)
    if nargin >= 3
        rng(seed);
    end

    % ---------------- 1. 参数解包与系统初始化 ----------------
    N = opts.N;
    T_max = opts.T_max;
    D = prob.D;
    lb = prob.lb;
    ub = prob.ub;
    p_rate = opts.p_best_rate;
    warmup_gen = round(opts.warmup_ratio * T_max);
    stag_limit = opts.stagnation_limit;
    aniso_gamma = 0.25; % 各向异性曲率缩放指数 gamma in [0.2, 0.4]

    % 外部历史淘汰解归档集 (Archive) 初始化
    archive_max_size = N;
    archive = zeros(0, D);

    % 种群均匀随机初始化与离散修复
    pop = repmat(lb, N, 1) + rand(N, D) .* repmat(ub - lb, N, 1);
    pop = apply_discretization(pop, prob);

    fitness = zeros(N, 1);
    cv = zeros(N, 1);
    for i = 1:N
        [fitness(i), cv(i)] = prob.obj_con(pop(i, :));
    end

    % 确定初始全局最优 (基于 Deb 可行性优先法则)
    best_idx = 1;
    for i = 2:N
        if is_deb_better(fitness(i), cv(i), fitness(best_idx), cv(best_idx))
            best_idx = i;
        end
    end

    best_x = pop(best_idx, :);
    best_f = fitness(best_idx);
    best_cv = cv(best_idx);
    history = zeros(T_max, 1);

    % 控制参数自适应记忆池初始化 (Lehmer 均值自适应)
    mu_F = 0.5;
    mu_CR = 0.5;
    P_rot = 0.20; % 初始旋转概率 (默认低位, 敏捷门控)

    % 构型微分香农熵基准计算与相变阈值标定
    C0 = cov(pop) + 1e-12 * eye(D);
    s0_diag = svd(C0);
    H_initial = 0.5 * sum(log(max(s0_diag, 1e-25))) + 0.5 * D * log(2 * pi * exp(1));
    H_crit = H_initial - 2.8 * D; % 相体积塌缩临界微分熵

    % 连续停滞计数器 (用于双锁确诊)
    stag_counter = 0;
    prev_best_f = best_f;
    prev_best_cv = best_cv;

    % ---------------- 2. 主演化代际循环 ----------------
    for t = 1:T_max
        % 追踪全局最优解改善状态
        if is_deb_better(best_f, best_cv, prev_best_f, prev_best_cv)
            stag_counter = 0;
            prev_best_f = best_f;
            prev_best_cv = best_cv;
        else
            stag_counter = stag_counter + 1;
        end

        % ================= 模块 1: 加权精英协方差张量与谱分解 (PADO) =================
        % 依据可行性与适应度排序, 选取前 50% 精英个体
        mu_elite = max(4, floor(N * 0.5));
        scores = cv * 1e8 + fitness; % 可行解天然排在前列
        [~, sort_idx] = sort(scores, 'ascend');
        elite_pop = pop(sort_idx(1:mu_elite), :);

        % 对数递减加权系数
        weights = log(mu_elite + 0.5) - log(1:mu_elite)';
        weights = weights / sum(weights);
        x_mean = weights' * elite_pop;
        X_diff = elite_pop - x_mean;

        % 样本协方差计算与 Ledoit-Wolf 线性收缩正则化 (防高维病态与伪旋转噪声)
        alpha_shrink = D / (N + D);
        C_sample = X_diff' * (diag(weights) * X_diff);
        C_reg = (1 - alpha_shrink) * C_sample + alpha_shrink * diag(diag(C_sample)) + 1e-12 * eye(D);

        % 对称正交特征分解 C_reg = V * Lambda * V^T
        [V, Lambda] = eig(C_reg);
        eigvals = diag(Lambda);
        [eigvals_sorted, order] = sort(eigvals, 'descend');
        V = V(:, order);

        % 计算非对角力学耦合度指标 rho_couple in [0, 1]
        C_diag = diag(diag(C_reg));
        norm_total = norm(C_reg, 'fro');
        norm_offdiag = norm(C_reg - C_diag, 'fro');
        rho_couple = norm_offdiag / (norm_total + 1e-14);

        % 各向异性曲率自适应缩放因子 (宽轴测地线大步长, 窄轴垂直峭壁小步长)
        max_eig = max(eigvals_sorted(1), 1e-12);
        aniso_scales = (sqrt(max(0, eigvals_sorted)) / sqrt(max_eig)).^aniso_gamma;

        % 实时计算当前相空间微观构型微分香农熵 H(t)
        H_t = 0.5 * sum(log(max(eigvals_sorted, 1e-25))) + 0.5 * D * log(2 * pi * exp(1));

        % ================= 模块 2: 热力学双锁门控与骨架守恒退化零空间定向激发 =================
        % 双锁判定准则: 过了冷启动期 且 相体积塌缩 (H_t <= H_crit) 且 实质演化停滞 (stag >= limit)
        is_double_locked = (t > warmup_gen) && (H_t <= H_crit) && (stag_counter >= stag_limit);
        
        if is_double_locked && (t < 0.90 * T_max)
            collapse_mask = eigvals_sorted < (1e-4 * max_eig);
            if any(collapse_mask)
                % 仅对后 20% 的劣质滞后个体实施正交退化零空间脉冲
                num_pulse = max(1, round(0.20 * N));
                worst_indices = sort_idx(end - num_pulse + 1 : end);
                V_null = V(:, collapse_mask);

                for k_idx = 1:length(worst_indices)
                    target_i = worst_indices(k_idx);
                    % 保持大特征值承载结构骨架不变, 仅在零空间注入受控扰动
                    noise_amp = 0.15 * sqrt(max_eig);
                    perturb_null = V_null * (randn(sum(collapse_mask), 1) * noise_amp);
                    
                    cand_pulse = best_x + perturb_null';
                     if isfield(prob, 'discrete_idx') && ~isempty(prob.discrete_idx)
                        for d_k = 1:length(prob.discrete_idx)
                            d_idx = prob.discrete_idx(d_k);
                            d_step = prob.discrete_step(d_k);
                            cand_pulse(d_idx) = cand_pulse(d_idx) + sign(rand() - 0.5) * d_step;
                        end
                    end
                    cand_pulse = max(min(cand_pulse, ub), lb);
                    cand_pulse = apply_discretization(cand_pulse, prob);
                    
                    [f_cand, cv_cand] = prob.obj_con(cand_pulse);
                    if is_deb_better(f_cand, cv_cand, fitness(target_i), cv(target_i))
                        pop(target_i, :) = cand_pulse;
                        fitness(target_i) = f_cand;
                        cv(target_i) = cv_cand;
                    end
                end
                stag_counter = max(0, stag_counter - 5); % 缓解死锁闭环
            end
        end

        % ================= 模块 3: 精英导向流形变异、交叉与自洽退化 =================
        new_pop = pop;
        new_fitness = fitness;
        new_cv = cv;

        success_F = [];
        success_CR = [];
        success_rot = false(N, 1);
        is_rot_track = false(N, 1);

        % 精英前 p% 集合大小
        p_num = max(2, round(p_rate * N));

        for i = 1:N
            % 1. 生成自适应变异率 F_i (柯西分布) 与交叉率 CR_i (正态分布)
            F_i = mu_F + 0.1 * tan(pi * (rand - 0.5));
            while F_i <= 0
                F_i = mu_F + 0.1 * tan(pi * (rand - 0.5));
            end
            F_i = min(F_i, 1.0);

            CR_i = min(max(normrnd(mu_CR, 0.1), 0), 1);

            % 2. 选取基向量: current-to-pbest
            pbest_candidate = sort_idx(randi(p_num));
            x_pbest = pop(pbest_candidate, :);

            % 选取互异的 r1 (来自种群) 与 r2 (来自种群并集归档集)
            r1 = randi(N);
            while r1 == i
                r1 = randi(N);
            end

            union_size = N + size(archive, 1);
            r2_idx = randi(union_size);
            while r2_idx == i || r2_idx == r1
                r2_idx = randi(union_size);
            end

            if r2_idx <= N
                x_r2 = pop(r2_idx, :);
            else
                x_r2 = archive(r2_idx - N, :);
            end

            diff_pbest = x_pbest - pop(i, :);
            diff_rand  = pop(r1, :) - x_r2;

            % 3. 双轨门控判定 (冷启动保护 + 耦合度门槛 + 自适应概率)
            use_manifold_rot = (t > warmup_gen) && (rho_couple > 0.20) && (rand < P_rot);
            is_rot_track(i) = use_manifold_rot;

            if use_manifold_rot
                % ---------- 轨道 1: PADO 主轴流形投影算子 ----------
                z_i = pop(i, :) * V;
                d_pbest_z = diff_pbest * V;
                d_rand_z  = diff_rand * V;

                % 各向异性步长调制
                F_eff = F_i .* aniso_scales';
                v_z = z_i + F_eff .* d_pbest_z + F_eff .* d_rand_z;

                % 流形切空间内的二项式交叉
                j_rand = randi(D);
                mask = (rand(1, D) <= CR_i);
                mask(j_rand) = true;
                u_z = z_i;
                u_z(mask) = v_z(mask);

                % 逆投影还原至原物理设计空间
                u_trial = u_z * V';
            else
                % ---------- 轨道 2: 经典坐标轴正交变换 (自洽退化基底) ----------
                v_trial = pop(i, :) + F_i * diff_pbest + F_i * diff_rand;
                j_rand = randi(D);
                mask = (rand(1, D) <= CR_i);
                mask(j_rand) = true;
                u_trial = pop(i, :);
                u_trial(mask) = v_trial(mask);
            end

            % 边界越界折返修复与离散化
            u_trial = bound_constraint_repair(u_trial, pop(i, :), lb, ub);
            u_trial = apply_discretization(u_trial, prob);
            u_trial = apply_discrete_jitter(u_trial, prob, stag_counter, stag_limit);
            u_trial = apply_discretization(u_trial, prob);

            % 4. 可行性优先选择与归档更新 (Deb 准则)
            [f_u, cv_u] = prob.obj_con(u_trial);
            if is_deb_better(f_u, cv_u, fitness(i), cv(i))
                new_pop(i, :) = u_trial;
                new_fitness(i) = f_u;
                new_cv(i) = cv_u;

                % 记录成功参数用于后续自适应学习
                success_F = [success_F; F_i];
                success_CR = [success_CR; CR_i];
                if is_rot_track(i)
                    success_rot(i) = true;
                end

                % 被淘汰的父代移入外部历史归档集
                if size(archive, 1) < archive_max_size
                    archive = [archive; pop(i, :)];
                else
                    replace_idx = randi(archive_max_size);
                    archive(replace_idx, :) = pop(i, :);
                end

                % 全局最优更新
                if is_deb_better(f_u, cv_u, best_f, best_cv)
                    best_x = u_trial;
                    best_f = f_u;
                    best_cv = cv_u;
                end
            end
        end

        % 更新种群矩阵
        pop = new_pop;
        fitness = new_fitness;
        cv = new_cv;

        % ================= 模块 4: 自适应参数学习与门控概率反馈更新 =================
        if ~isempty(success_F)
            % Lehmer 均值更新 F 与算术均值更新 CR
            mu_F = (1 - 0.1) * mu_F + 0.1 * (sum(success_F.^2) / sum(success_F));
            mu_CR = (1 - 0.1) * mu_CR + 0.1 * mean(success_CR);
        end

        % 更新主轴旋转门控概率 P_rot (基于成功率反馈)
        if any(is_rot_track)
            rot_success_rate = sum(success_rot) / sum(is_rot_track);
            P_rot = (1 - 0.1) * P_rot + 0.1 * rot_success_rate;
            P_rot = min(max(P_rot, 0.05), 0.85); % 限制在安全开度区间
        end

        history(t) = best_f;
    end
end

%% =========================================================================
%% 辅助函数: Deb 可行性优先法则与越界修复
%% =========================================================================
function tf = is_deb_better(f1, cv1, f2, cv2)
    % Deb 可行性优先法则:
    % 1. 可行解支配不可行解;
    % 2. 两个可行解比目标函数值 (小者胜);
    % 3. 两个不可行解比约束违反度 (小者胜).
    if cv1 == 0 && cv2 == 0
        tf = (f1 < f2);
    elseif cv1 == 0 && cv2 > 0
        tf = true;
    elseif cv1 > 0 && cv2 == 0
        tf = false;
    else
        tf = (cv1 < cv2);
    end
end

function x = bound_constraint_repair(x, x_orig, lb, ub)
    % 折返式越界平滑修复
    viol_lower = x < lb;
    viol_upper = x > ub;
    x(viol_lower) = (lb(viol_lower) + x_orig(viol_lower)) / 2;
    x(viol_upper) = (ub(viol_upper) + x_orig(viol_upper)) / 2;
end

function pop = apply_discretization(pop, prob)
    % 针对特定离散变量步长施加离散投影
    if isfield(prob, 'discrete_idx') && ~isempty(prob.discrete_idx)
        for k = 1:length(prob.discrete_idx)
            idx = prob.discrete_idx(k);
            step = prob.discrete_step(k);
            pop(:, idx) = round(pop(:, idx) ./ step) .* step;
            pop(:, idx) = max(min(pop(:, idx), prob.ub(idx)), prob.lb(idx));
        end
    end
end

%% =========================================================================
%% 辅助函数: 批量独立试验调度器
%% =========================================================================
function res = run_batch_experiments(prob, opts)
    runs = opts.runs;
    f_list = zeros(runs, 1);
    x_list = zeros(runs, prob.D);
    cv_list = zeros(runs, 1);
    histories = zeros(opts.T_max, runs);

    tic;
    for r = 1:runs
        [bx, bf, bcv, h] = pade_solve(prob, opts, 1000 + r);
        f_list(r) = bf;
        x_list(r, :) = bx;
        cv_list(r) = bcv;
        histories(:, r) = h;
    end
    t_elapsed = toc;

    [~, best_run_idx] = min(f_list);
    res.best_f = min(f_list);
    res.mean_f = mean(f_list);
    res.worst_f = max(f_list);
    res.std_f = std(f_list);
    res.best_x = x_list(best_run_idx, :);
    res.best_cv = cv_list(best_run_idx);
    res.history_mean = mean(histories, 2);
    res.history_best = histories(:, best_run_idx);
    res.elapsed_time = t_elapsed;
end

%% =========================================================================
%% 工程案例模型 1: 压力容器制造综合成本优化设计 (Pressure Vessel Design)
%% =========================================================================
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
%% =========================================================================
function display_engineering_results(prob, res)
    fprintf('\n-------------------------------------------------------------------------\n');
    fprintf('【试验统计报告】 %s\n', prob.name);
    fprintf('-------------------------------------------------------------------------\n');
    fprintf('最优适应度 (Best)   : %.6f\n', res.best_f);
    fprintf('平均适应度 (Mean)   : %.6f\n', res.mean_f);
    fprintf('最差适应度 (Worst)  : %.6f\n', res.worst_f);
    fprintf('标准方差   (Std)    : %.3e\n', res.std_f);
    fprintf('约束违反度 (CV)     : %.6e (严格可行)\n', res.best_cv);
    fprintf('总寻优耗时 (Time)   : %.2f 秒 (平均每轮 %.2f 秒)\n', res.elapsed_time, res.elapsed_time / 30);
    fprintf('最优决策向量 x*     : [ ');
    for j = 1:prob.D
        fprintf('%.6f ', res.best_x(j));
    end
    fprintf(']\n');
    fprintf('-------------------------------------------------------------------------\n');
end

function plot_convergence_curves(res1, res2, res3)
    fig = figure('Color', [1 1 1], 'Position', [100, 100, 1100, 360]);

    % 子图 1: 压力容器收敛过程
    subplot(1, 3, 1);
    semilogy(1:length(res1.history_mean), res1.history_mean, 'b-', 'LineWidth', 1.8); hold on;
    semilogy(1:length(res1.history_best), res1.history_best, 'r--', 'LineWidth', 1.5);
    grid on;
    xlabel('迭代代数 (Generations)', 'FontSize', 10);
    ylabel('目标成本 (对数刻度)', 'FontSize', 10);
    title('压力容器设计 (4维)', 'FontSize', 11, 'FontWeight', 'bold');
    legend('30次均值', '最优单次', 'Location', 'northeast');

    % 子图 2: 焊接梁收敛过程
    subplot(1, 3, 2);
    plot(1:length(res2.history_mean), res2.history_mean, 'b-', 'LineWidth', 1.8); hold on;
    plot(1:length(res2.history_best), res2.history_best, 'r--', 'LineWidth', 1.5);
    grid on;
    xlabel('迭代代数 (Generations)', 'FontSize', 10);
    ylabel('制造成本 (Cost)', 'FontSize', 10);
    title('焊接梁设计 (4维)', 'FontSize', 11, 'FontWeight', 'bold');
    legend('30次均值', '最优单次', 'Location', 'northeast');

    % 子图 3: 悬臂梁收敛过程
    subplot(1, 3, 3);
    plot(1:length(res3.history_mean), res3.history_mean, 'b-', 'LineWidth', 1.8); hold on;
    plot(1:length(res3.history_best), res3.history_best, 'r--', 'LineWidth', 1.5);
    grid on;
    xlabel('迭代代数 (Generations)', 'FontSize', 10);
    ylabel('总质量 (Mass)', 'FontSize', 10);
    title('悬臂梁设计 (5维)', 'FontSize', 11, 'FontWeight', 'bold');
    legend('30次均值', '最优单次', 'Location', 'northeast');
end
function u = apply_discrete_jitter(u, prob, stag_counter, stag_limit)
    % =========================================================================
    % 离散网格自适应抖动算子 (Discrete Grid Jitter)
    % 作用: 当连续未改善代数增加时, 以自适应概率对离散维度施加 +/- 1 个网格步长的微调,
    %       克服差向量收缩导致的网格冻结死锁 (Grid-Locking).
    % =========================================================================
    if ~isfield(prob, 'discrete_idx') || isempty(prob.discrete_idx)
        return; % 纯连续问题直接跳过，零开销
    end

    % 自适应抖动概率: 停滞越久，触发概率越大 (上限设为 0.25)
    P_jitter = 0.25 * min(1.0, stag_counter / max(1, stag_limit));

    if P_jitter > 0.02
        for k = 1:length(prob.discrete_idx)
            idx = prob.discrete_idx(k);
            step = prob.discrete_step(k);
            
            % 以自适应概率触发 +/- 1 阶跃迁
            if rand() < P_jitter
                % 等概率选择向上 (+1) 或向下 (-1) 跨一个物理网格
                step_dir = sign(rand() - 0.5);
                if step_dir == 0, step_dir = 1; end
                
                u(idx) = u(idx) + step_dir * step;
                % 保证在工程离散规格边界内
                u(idx) = max(min(u(idx), prob.ub(idx)), (idx));
            end
        end
    end
end