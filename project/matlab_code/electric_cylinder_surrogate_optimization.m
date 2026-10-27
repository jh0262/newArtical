%% 基于代理模型的电动缸结构参数多目标优化程序
% 说明：
% 1. 本程序可直接运行。若当前目录存在 electric_cylinder_samples.xlsx 或
%    electric_cylinder_samples.csv，则读取样本数据；否则自动用解析数学模型
%    生成演示样本。
% 2. 程序对比响应面模型（RSM）、Kriging模型（用高斯过程回归 GPR 实现）
%    和随机森林模型（RF），并输出论文可用图。
% 3. 优化部分默认采用“加权多目标差分进化算法”生成近似 Pareto 解；
%    也可将 optimizerMethod 改为 "GA_MULTI"，调用 gamultiobj 进行多目标优化。
%
% 输入变量 X：
%   ds  : 滚珠丝杠直径 / mm
%   Ph  : 滚珠丝杠导程 / mm
%   Ln  : 螺母长度 / mm
%   Fp  : 预紧力 / N
%   dr  : 输出杆直径 / mm
%   Lg  : 导向套长度 / mm
%   tc  : 缸体壁厚 / mm
%
% 输出响应 Y：
%   k_total : 等效轴向刚度 / N/mm，越大越好
%   delta   : 最大轴向变形 / mm，越小越好
%   sigma   : 最大等效应力 / MPa，越小越好
%   eta     : 总传动效率，越大越好
%   mass    : 总质量 / kg，越小越好
%   life_h  : 寿命 / h。当前程序训练并评价该响应，但若代理模型精度不足，
%             不将其纳入多目标优化，仅作为后验参考指标。

clear; clc; close all;
rng(2026);

%% 0. 参数设置
figDir = fullfile(pwd, "figures");
if ~exist(figDir, "dir")
    mkdir(figDir);
end

inputNames = {'d_s','P_h','L_n','F_p','d_r','L_g','t_c'};
responseNames = {'k_total','delta','sigma','eta','mass','life_h'};
responseUnits = {'N/mm','mm','MPa','-','kg','h'};
objectiveResponseNames = {'mass','delta','sigma','k_total','eta'};

% 设计变量边界，可根据实际电动缸结构修改
lb = [25,  5,  45,  200, 40, 35,  5];
ub = [45, 20, 100, 2500, 65, 90, 12];

% 约束阈值，可根据论文设计要求修改
limit.deltaMax = 0.060;   % mm
limit.sigmaMax = 180;     % MPa
limit.massMax  = 18.0;    % kg
limit.lifeMin  = 8000;    % h，仅作为后验参考，不作为当前优化硬约束

% 优化算法选择：
% "DE_WEIGHTED"：默认，采用多组权重 + 差分进化算法生成近似 Pareto 解；
% "GA_MULTI"   ：调用 MATLAB gamultiobj，需 Global Optimization Toolbox。
optimizerMethod = "DE_WEIGHTED";

%% 1. 读取或生成样本数据
[X, Y, dataSource] = loadOrGenerateData(inputNames, responseNames, lb, ub);
fprintf("样本来源：%s\n", dataSource);
fprintf("样本数量：%d，设计变量数：%d，响应数：%d\n", size(X,1), size(X,2), size(Y,2));

%% 2. 样本划分与归一化
cv = cvpartition(size(X,1), "HoldOut", 0.2);
idxTrain = training(cv);
idxTest  = test(cv);

XTrain = X(idxTrain,:);
YTrain = Y(idxTrain,:);
XTest  = X(idxTest,:);
YTest  = Y(idxTest,:);

[XTrainN, xNorm] = normalizeMinMax(XTrain);
XTestN = applyNormalizeMinMax(XTest, xNorm);
[YTrainN, yNorm] = normalizeMinMax(YTrain);

%% 3. 训练 RSM、Kriging、RF 三类代理模型
modelNames = {'RSM','Kriging','RF'};
models = struct();
metricTable = table();
predTestAll = struct();

for m = 1:numel(modelNames)
    method = modelNames{m};
    fprintf("\n训练代理模型：%s\n", method);
    models.(method) = cell(1, numel(responseNames));
    predN = zeros(size(YTest));

    for j = 1:numel(responseNames)
        models.(method){j} = trainOneSurrogate(XTrainN, YTrainN(:,j), method);
        predN(:,j) = predictOneSurrogate(models.(method){j}, XTestN, method);
    end

    YPred = reverseNormalizeMinMax(predN, yNorm);
    predTestAll.(method) = YPred;

    for j = 1:numel(responseNames)
        met = calcMetrics(YTest(:,j), YPred(:,j));
        newRow = table({method}, {responseNames{j}}, met.R2, met.RMSE, met.MAE, met.MAPE, ...
            'VariableNames', {'Model','Response','R2','RMSE','MAE','MAPE'});
        metricTable = [metricTable; newRow]; %#ok<AGROW>
    end
end

disp(metricTable);
writetable(metricTable, fullfile(figDir, "surrogate_model_metrics.csv"));

%% 4. 选择综合最优代理模型
scoreTable = groupsummary(metricTable, 'Model', 'mean', {'R2','RMSE','MAE','MAPE'});
% R2 越大越好，RMSE/MAE/MAPE 越小越好；此处使用简单归一化综合评分
scoreTable.Score = normalizeScore(scoreTable.mean_R2, true) + ...
                   normalizeScore(scoreTable.mean_RMSE, false) + ...
                   normalizeScore(scoreTable.mean_MAE, false) + ...
                   normalizeScore(scoreTable.mean_MAPE, false);
[~, bestIdx] = max(scoreTable.Score);
bestModelName = char(scoreTable.Model(bestIdx));
fprintf("\n综合最优代理模型：%s\n", bestModelName);

%% 5. 绘制论文图：代理模型精度对比
plotMetricComparison(metricTable, figDir);
plotPredictedVsTrue(YTest, predTestAll, responseNames, responseUnits, figDir);
plotResidualBox(YTest, predTestAll, responseNames, figDir);

%% 6. 响应面示意图：以 d_r 和 P_h 为横纵坐标
plotResponseSurface(models.(bestModelName), bestModelName, xNorm, yNorm, inputNames, responseNames, lb, ub, figDir);

%% 7. 基于代理模型的多目标优化
% 优化目标统一为最小化：
%   f1 = mass
%   f2 = delta
%   f3 = sigma
%   f4 = -k_total
%   f5 = -eta
% life_h 在当前样本下预测精度较低，不参与优化目标，仅在优化后作为后验指标查看。
objFun = @(x) surrogateObjectives(x, models.(bestModelName), bestModelName, xNorm, yNorm);
conFun = @(x) surrogateConstraints(x, models.(bestModelName), bestModelName, xNorm, yNorm, limit);

if optimizerMethod == "GA_MULTI" && exist("gamultiobj", "file") == 2
    fprintf("\n开始 gamultiobj 多目标优化...\n");
    opts = optimoptions("gamultiobj", ...
        "PopulationSize", 120, ...
        "MaxGenerations", 120, ...
        "FunctionTolerance", 1e-4, ...
        "Display", "iter", ...
        "PlotFcn", []);
    [xPareto, fPareto] = gamultiobj(objFun, numel(lb), [], [], [], [], lb, ub, conFun, opts);
else
    fprintf("\n开始加权多目标差分进化优化...\n");
    [xPareto, fPareto, deHistory] = weightedDEPareto(objFun, conFun, lb, ub);
    plotDEConvergence(deHistory, figDir);
end

YPareto = predictSurrogateResponses(xPareto, models.(bestModelName), bestModelName, xNorm, yNorm);
paretoTable = array2table([xPareto, YPareto], ...
    'VariableNames', [inputNames, responseNames]);
writetable(paretoTable, fullfile(figDir, "pareto_solutions.csv"));

%% 8. 从 Pareto 解中选取一个折中最优解
bestCompromiseIndex = chooseCompromiseSolution(YPareto);
xBest = xPareto(bestCompromiseIndex,:);
yBest = YPareto(bestCompromiseIndex,:);

fprintf("\n折中最优设计变量：\n");
disp(array2table(xBest, 'VariableNames', inputNames));
fprintf("折中最优性能响应：\n");
disp(array2table(yBest, 'VariableNames', responseNames));

%% 9. 绘制论文图：Pareto 解与优化前后对比
plotParetoFigures(YPareto, figDir);
plotBeforeAfter(X, Y, xBest, yBest, inputNames, responseNames, responseUnits, figDir);

%% 10. 保存关键结果
save(fullfile(figDir, "electric_cylinder_surrogate_optimization_results.mat"), ...
    "X", "Y", "models", "metricTable", "scoreTable", "bestModelName", ...
    "xPareto", "YPareto", "xBest", "yBest", "lb", "ub", "limit", "optimizerMethod", "objectiveResponseNames");

fprintf("\n程序运行完成。论文图片和结果表已保存至：%s\n", figDir);

%% ========================= 局部函数区 =========================

function [X, Y, source] = loadOrGenerateData(inputNames, responseNames, lb, ub)
    xlsxFile = "electric_cylinder_samples.xlsx";
    csvFile = "electric_cylinder_samples.csv";

    if exist(xlsxFile, "file") == 2
        T = readtable(xlsxFile, 'VariableNamingRule', 'preserve');
        source = xlsxFile;
    elseif exist(csvFile, "file") == 2
        T = readtable(csvFile, 'VariableNamingRule', 'preserve');
        source = csvFile;
    else
        nSample = 160;
        if exist("lhsdesign", "file") == 2
            X = lhsdesign(nSample, numel(lb), "criterion", "maximin", "iterations", 50);
        else
            X = rand(nSample, numel(lb));
        end
        X = lb + X .* (ub - lb);
        Y = analyticalElectricCylinderModel(X);
        source = sprintf("拉丁超立方抽样%d组 + 解析数学模型计算响应", nSample);
        return;
    end

    X = zeros(height(T), numel(inputNames));
    Y = zeros(height(T), numel(responseNames));
    for i = 1:numel(inputNames)
        X(:,i) = T.(inputNames{i});
    end
    for j = 1:numel(responseNames)
        Y(:,j) = T.(responseNames{j});
    end
end

function Y = analyticalElectricCylinderModel(X)
    % 此函数用于在没有有限元样本时生成演示数据。
    % 后续有真实样本后，不建议把该函数结果当作最终论文数据。
    ds = X(:,1);       % mm
    Ph = X(:,2);       % mm
    Ln = X(:,3);       % mm
    Fp = X(:,4);       % N
    dr = X(:,5);       % mm
    Lg = X(:,6);       % mm
    tc = X(:,7);       % mm

    F = 100000;        % N
    E = 2.06e5;        % MPa = N/mm^2
    rho = 7.85e-6;     % kg/mm^3
    Lrod = 210;        % mm，按最大伸出有效长度
    Ls = 360;          % mm，等效丝杠长度
    Lc = 420;          % mm，缸体长度
    Di = 80;           % mm，缸体内径估算

    Ar = pi .* dr.^2 ./ 4;
    As = pi .* ds.^2 ./ 4;

    kRod = E .* Ar ./ Lrod;
    kScrew = E .* As ./ Ls;
    kNut = 1.2e5 + 950 .* Ln + 10 .* Fp;
    kGuide = 5.0e4 + 1800 .* Lg + 3000 .* tc;
    kSupport = 2.5e5 + 1200 .* ds;
    k_total = 1 ./ (1./kRod + 1./kScrew + 1./kNut + 1./kGuide + 1./kSupport);

    delta = F ./ k_total;

    % 构造一个可用于演示的应力模型，包含轴向、偏心弯曲和局部应力修正
    e = 3.5; % mm，等效偏心
    Wr = pi .* dr.^3 ./ 32;
    sigmaAxial = F ./ Ar;
    sigmaBending = F .* e ./ Wr;
    sigmaLocal = 18 + 0.020 .* Fp ./ max(Ln, 1) + 0.6 .* (12 - tc);
    sigma = sigmaAxial + sigmaBending + sigmaLocal;

    eta = 0.90 - 0.0025 .* Ph + 0.000006 .* Fp - 0.0008 .* abs(ds - 36);
    eta = min(max(eta, 0.78), 0.94);

    Do = Di + 2 .* tc;
    mRod = rho .* pi .* dr.^2 ./ 4 .* Lrod;
    mScrew = rho .* pi .* ds.^2 ./ 4 .* Ls;
    mNut = rho .* pi .* ((ds + 20).^2 - ds.^2) ./ 4 .* Ln;
    mCylinder = rho .* pi .* (Do.^2 - Di.^2) ./ 4 .* Lc;
    mGuide = rho .* pi .* ((dr + 24).^2 - dr.^2) ./ 4 .* Lg;
    mass = mRod + mScrew + mNut + mCylinder + mGuide + 3.5;

    % 寿命模型：用等效动载荷和结构参数构造演示响应
    Ca = 4.5e4 + 1500 .* ds + 280 .* Ln + 8 .* Fp;
    Pm = F + 0.35 .* Fp;
    L10 = (Ca ./ Pm).^3 .* 1e6; % rev
    ns = 900 ./ max(Ph, 1) .* 10; % 演示转速
    life_h = L10 ./ (60 .* ns);
    life_h = max(life_h, 500);

    % 加入很小扰动，模拟仿真噪声
    k_total = k_total .* (1 + 0.015 .* randn(size(k_total)));
    delta = delta .* (1 + 0.010 .* randn(size(delta)));
    sigma = sigma .* (1 + 0.012 .* randn(size(sigma)));
    eta = eta .* (1 + 0.004 .* randn(size(eta)));
    mass = mass .* (1 + 0.005 .* randn(size(mass)));
    life_h = life_h .* (1 + 0.020 .* randn(size(life_h)));

    Y = [k_total, delta, sigma, eta, mass, life_h];
end

function [XN, normInfo] = normalizeMinMax(X)
    xmin = min(X, [], 1);
    xmax = max(X, [], 1);
    range = xmax - xmin;
    range(range == 0) = 1;
    XN = (X - xmin) ./ range;
    normInfo.min = xmin;
    normInfo.range = range;
end

function XN = applyNormalizeMinMax(X, normInfo)
    XN = (X - normInfo.min) ./ normInfo.range;
end

function X = reverseNormalizeMinMax(XN, normInfo)
    X = XN .* normInfo.range + normInfo.min;
end

function model = trainOneSurrogate(X, y, method)
    switch char(method)
        case "RSM"
            model = fitlm(X, y, "quadratic");
        case "Kriging"
            model = fitrgp(X, y, ...
                "KernelFunction", "ardsquaredexponential", ...
                "Standardize", true, ...
                "BasisFunction", "constant");
        case "RF"
            model = TreeBagger(120, X, y, ...
                "Method", "regression", ...
                "MinLeafSize", 4, ...
                "OOBPrediction", "on");
        otherwise
            error("未知模型类型：%s", method);
    end
end

function yhat = predictOneSurrogate(model, X, method)
    switch char(method)
        case {"RSM","Kriging"}
            yhat = predict(model, X);
        case "RF"
            yhat = predict(model, X);
        otherwise
            error("未知模型类型：%s", method);
    end
    yhat = yhat(:);
end

function Yhat = predictSurrogateResponses(X, modelCell, method, xNorm, yNorm)
    XN = applyNormalizeMinMax(X, xNorm);
    YN = zeros(size(X,1), numel(modelCell));
    for j = 1:numel(modelCell)
        YN(:,j) = predictOneSurrogate(modelCell{j}, XN, method);
    end
    Yhat = reverseNormalizeMinMax(YN, yNorm);
end

function met = calcMetrics(y, yhat)
    err = y - yhat;
    sse = sum(err.^2);
    sst = sum((y - mean(y)).^2);
    met.R2 = 1 - sse / max(sst, eps);
    met.RMSE = sqrt(mean(err.^2));
    met.MAE = mean(abs(err));
    met.MAPE = mean(abs(err ./ max(abs(y), eps))) * 100;
end

function s = normalizeScore(v, largerBetter)
    v = double(v);
    if max(v) - min(v) < eps
        s = ones(size(v));
    else
        if largerBetter
            s = (v - min(v)) ./ (max(v) - min(v));
        else
            s = (max(v) - v) ./ (max(v) - min(v));
        end
    end
end

function f = surrogateObjectives(x, modelCell, method, xNorm, yNorm)
    y = predictSurrogateResponses(x, modelCell, method, xNorm, yNorm);
    k_total = y(:,1);
    delta = y(:,2);
    sigma = y(:,3);
    eta = y(:,4);
    mass = y(:,5);

    f = [mass, delta, sigma, -k_total ./ 1e6, -eta];
end

function [c, ceq] = surrogateConstraints(x, modelCell, method, xNorm, yNorm, limit)
    y = predictSurrogateResponses(x, modelCell, method, xNorm, yNorm);
    delta = y(:,2);
    sigma = y(:,3);
    mass = y(:,5);
    c = [delta - limit.deltaMax, ...
         sigma - limit.sigmaMax, ...
         mass - limit.massMax];
    ceq = [];
end

function [xPareto, fPareto, history] = weightedDEPareto(objFun, conFun, lb, ub)
    nWeight = 80;
    nObj = numel(objFun((lb + ub) ./ 2));
    xPareto = zeros(nWeight, numel(lb));
    history = cell(nWeight, 1);

    % 构造一组随机权重，覆盖不同目标偏好。
    W = rand(nWeight, nObj);
    W = W ./ sum(W, 2);

    for i = 1:nWeight
        scalarObj = @(x) weightedObjectiveWithPenalty(x, objFun, conFun, W(i,:));
        [xPareto(i,:), history{i}] = differentialEvolutionScalar(scalarObj, lb, ub);
    end
    fPareto = objFun(xPareto);
end

function [bestX, bestCurve] = differentialEvolutionScalar(objFun, lb, ub)
    nVar = numel(lb);
    popSize = 70;
    maxGen = 120;
    Fde = 0.65;
    CR = 0.85;

    pop = lb + rand(popSize, nVar) .* (ub - lb);
    fit = zeros(popSize, 1);
    for i = 1:popSize
        fit(i) = objFun(pop(i,:));
    end

    bestCurve = zeros(maxGen, 1);
    for g = 1:maxGen
        for i = 1:popSize
            idx = randperm(popSize, 3);
            while any(idx == i)
                idx = randperm(popSize, 3);
            end
            r1 = idx(1); r2 = idx(2); r3 = idx(3);
            mutant = pop(r1,:) + Fde .* (pop(r2,:) - pop(r3,:));
            mutant = max(min(mutant, ub), lb);

            trial = pop(i,:);
            jRand = randi(nVar);
            for j = 1:nVar
                if rand <= CR || j == jRand
                    trial(j) = mutant(j);
                end
            end

            trialFit = objFun(trial);
            if trialFit <= fit(i)
                pop(i,:) = trial;
                fit(i) = trialFit;
            end
        end
        bestCurve(g) = min(fit);
    end

    [~, bestIdx] = min(fit);
    bestX = pop(bestIdx,:);
end

function val = weightedObjectiveWithPenalty(x, objFun, conFun, w)
    f = objFun(x);
    [c, ~] = conFun(x);
    penalty = 1e4 .* sum(max(c, 0).^2);
    val = sum(w .* f) + penalty;
end

function idx = chooseCompromiseSolution(Y)
    % 将质量、变形、应力最小化；刚度、效率最大化。
    % life_h 因当前代理模型预测精度不足，不参与折中解选择。
    target = [ ...
        -Y(:,1), ... % k_total 越大越好，转为越小越好
         Y(:,2), ...
         Y(:,3), ...
        -Y(:,4), ...
         Y(:,5)];
    Z = (target - min(target, [], 1)) ./ max(max(target, [], 1) - min(target, [], 1), eps);
    dist = sqrt(sum(Z.^2, 2));
    [~, idx] = min(dist);
end

function plotMetricComparison(metricTable, figDir)
    metrics = {'R2','RMSE','MAE','MAPE'};
    for i = 1:numel(metrics)
        fig = figure("Color","w","Position",[100,100,1100,460]);
        T = unstack(metricTable(:, {'Model','Response',metrics{i}}), metrics{i}, 'Model');
        vals = T{:, 2:end};
        b = bar(vals, "grouped");
        grid on; box on;
        set(gca, "XTickLabel", T.Response, "FontName", "Times New Roman", "FontSize", 11);
        xtickangle(30);
        ylabel(metrics{i}, "FontName", "Times New Roman", "FontSize", 12);
        legend(string(T.Properties.VariableNames(2:end)), 'Location', 'best', 'Box', 'off');
        title("代理模型精度指标对比", "FontName", "SimHei", "FontSize", 13);
        for k = 1:numel(b)
            b(k).LineWidth = 0.8;
        end
        exportgraphics(fig, fullfile(figDir, "fig_metric_" + metrics{i} + ".png"), "Resolution", 600);
    end
end

function plotPredictedVsTrue(YTest, predTestAll, responseNames, responseUnits, figDir)
    methods = fieldnames(predTestAll);
    for j = 1:numel(responseNames)
        fig = figure("Color","w","Position",[100,100,1050,360]);
        tiledlayout(1, numel(methods), "Padding","compact", "TileSpacing","compact");
        for m = 1:numel(methods)
            method = methods{m};
            y = YTest(:,j);
            yhat = predTestAll.(method)(:,j);
            nexttile;
            scatter(y, yhat, 32, "filled", "MarkerFaceAlpha", 0.72);
            hold on;
            lo = min([y; yhat]);
            hi = max([y; yhat]);
            plot([lo,hi], [lo,hi], "k--", "LineWidth", 1.2);
            grid on; box on;
            met = calcMetrics(y, yhat);
            xlabel("真实值", "FontName", "SimHei");
            ylabel("预测值", "FontName", "SimHei");
            title(sprintf("%s: R^2=%.3f", method, met.R2), "FontName", "Times New Roman");
            axis tight;
        end
        sgtitle(sprintf("%s 预测值与真实值对比 / %s", responseNames{j}, responseUnits{j}), ...
            "FontName", "Times New Roman", "FontSize", 13);
        exportgraphics(fig, fullfile(figDir, "fig_pred_true_" + responseNames{j} + ".png"), "Resolution", 600);
    end
end

function plotResidualBox(YTest, predTestAll, responseNames, figDir)
    methods = fieldnames(predTestAll);
    fig = figure("Color","w","Position",[100,100,1150,520]);
    tiledlayout(2, 3, "Padding","compact", "TileSpacing","compact");
    for j = 1:numel(responseNames)
        nexttile;
        R = zeros(size(YTest,1), numel(methods));
        for m = 1:numel(methods)
            R(:,m) = YTest(:,j) - predTestAll.(methods{m})(:,j);
        end
        boxchart(categorical(repelem(methods', size(YTest,1))), R(:));
        grid on; box on;
        title(responseNames{j}, "FontName", "Times New Roman");
        ylabel("预测残差", "FontName", "SimHei");
    end
    sgtitle("不同代理模型预测残差分布", "FontName", "SimHei", "FontSize", 13);
    exportgraphics(fig, fullfile(figDir, "fig_residual_box.png"), "Resolution", 600);
end

function plotResponseSurface(modelCell, method, xNorm, yNorm, inputNames, responseNames, lb, ub, figDir)
    nGrid = 45;
    drRange = linspace(lb(5), ub(5), nGrid);
    phRange = linspace(lb(2), ub(2), nGrid);
    [DR, PH] = meshgrid(drRange, phRange);
    X0 = (lb + ub) ./ 2;
    XGrid = repmat(X0, numel(DR), 1);
    XGrid(:,5) = DR(:);
    XGrid(:,2) = PH(:);
    YGrid = predictSurrogateResponses(XGrid, modelCell, method, xNorm, yNorm);

    plotIdx = [1,2,3,5];
    for k = 1:numel(plotIdx)
        j = plotIdx(k);
        Z = reshape(YGrid(:,j), size(DR));
        fig = figure("Color","w","Position",[100,100,780,560]);
        surf(DR, PH, Z, "EdgeColor", "none");
        colormap(turbo);
        cb = colorbar;
        cb.Label.String = responseNames{j};
        grid on; box on; view(135, 28);
        xlabel("输出杆直径 d_r / mm", "FontName", "SimHei");
        ylabel("丝杠导程 P_h / mm", "FontName", "SimHei");
        zlabel(responseNames{j}, "FontName", "Times New Roman");
        title(sprintf("%s代理模型响应面：%s", method, responseNames{j}), ...
            "FontName", "SimHei", "FontSize", 13);
        exportgraphics(fig, fullfile(figDir, "fig_response_surface_" + responseNames{j} + ".png"), "Resolution", 600);
    end
end

function plotParetoFigures(YPareto, figDir)
    fig = figure("Color","w","Position",[100,100,780,580]);
    scatter3(YPareto(:,5), YPareto(:,2), YPareto(:,3), 48, YPareto(:,1), "filled");
    grid on; box on;
    xlabel("质量 / kg", "FontName", "SimHei");
    ylabel("最大变形 / mm", "FontName", "SimHei");
    zlabel("最大应力 / MPa", "FontName", "SimHei");
    cb = colorbar;
    cb.Label.String = "轴向刚度 / N/mm";
    title("多目标优化 Pareto 解集", "FontName", "SimHei", "FontSize", 13);
    view(135, 25);
    exportgraphics(fig, fullfile(figDir, "fig_pareto_3d.png"), "Resolution", 600);

    fig = figure("Color","w","Position",[100,100,760,520]);
    scatter(YPareto(:,5), YPareto(:,2), 48, YPareto(:,4), "filled");
    grid on; box on;
    xlabel("质量 / kg", "FontName", "SimHei");
    ylabel("最大变形 / mm", "FontName", "SimHei");
    cb = colorbar;
    cb.Label.String = "效率";
    title("质量-变形 Pareto 投影", "FontName", "SimHei", "FontSize", 13);
    exportgraphics(fig, fullfile(figDir, "fig_pareto_mass_delta.png"), "Resolution", 600);
end

function plotDEConvergence(history, figDir)
    nShow = min(10, numel(history));
    fig = figure("Color","w","Position",[100,100,820,520]);
    hold on;
    for i = 1:nShow
        plot(history{i}, "LineWidth", 1.1);
    end
    grid on; box on;
    xlabel("迭代代数", "FontName", "SimHei");
    ylabel("加权目标函数值", "FontName", "SimHei");
    title("差分进化算法收敛曲线", "FontName", "SimHei", "FontSize", 13);
    exportgraphics(fig, fullfile(figDir, "fig_de_convergence.png"), "Resolution", 600);
end

function plotBeforeAfter(X, Y, xBest, yBest, inputNames, responseNames, responseUnits, figDir)
    xBase = mean(X, 1);
    yBase = mean(Y, 1);

    fig = figure("Color","w","Position",[100,100,980,420]);
    tiledlayout(1, 2, "Padding","compact", "TileSpacing","compact");

    nexttile;
    vals = [xBase; xBest]';
    bar(vals);
    grid on; box on;
    set(gca, "XTickLabel", inputNames, "FontName", "Times New Roman", "FontSize", 11);
    xtickangle(30);
    ylabel("设计变量数值", "FontName", "SimHei");
    legend({"优化前均值","折中最优"}, 'Location', 'best', 'Box', 'off', 'FontName', 'SimHei');
    title("结构参数优化前后对比", "FontName", "SimHei");

    nexttile;
    direction = [1, -1, -1, 1, -1, 1]; % 越大越好为1，越小越好为-1
    improve = zeros(1, numel(responseNames));
    for j = 1:numel(responseNames)
        if direction(j) == 1
            improve(j) = (yBest(j) - yBase(j)) / abs(yBase(j)) * 100;
        else
            improve(j) = (yBase(j) - yBest(j)) / abs(yBase(j)) * 100;
        end
    end
    bar(improve);
    grid on; box on;
    yline(0, "k--");
    set(gca, "XTickLabel", responseNames, "FontName", "Times New Roman", "FontSize", 11);
    xtickangle(30);
    ylabel("改善率 / %", "FontName", "SimHei");
    title("性能指标改善率", "FontName", "SimHei");
    exportgraphics(fig, fullfile(figDir, "fig_before_after.png"), "Resolution", 600);

    responseNamesCol = responseNames(:);
    responseUnitsCol = responseUnits(:);
    yBaseCol = yBase(:);
    yBestCol = yBest(:);
    improveCol = improve(:);

    resultTable = table(responseNamesCol, responseUnitsCol, yBaseCol, yBestCol, improveCol, ...
        'VariableNames', {'Response','Unit','Before','After','ImprovementPercent'});
    writetable(resultTable, fullfile(figDir, "before_after_comparison.csv"));
end
