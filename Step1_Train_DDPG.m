%% ============================================================
%  DDPG Energy Management System
%  Είσοδοι : I_load (A) , SOC (%)
%  Έξοδος  : I_fc_ref (A)
%
%
%% ============================================================

clear; clc; close all;

%% 
FC_Parameters;

%% --- Φυσικές παράμετροι ---
I_fc_max  = Area * J_max;       % 75.9 A  (μέγιστο ρεύμα κυψέλης)
I_fc_min  = 0.0;
I_load_max = 15;                % ΑΛΛΑΞΕ ΑΝ ΧΡΕΙΑΣΤΕΙ - μέγιστο ρεύμα φορτίου (A)
SOC_min   = 20;                 % %
SOC_max   = 80;                 % %
SOC_ref   = 60;                 % %

assignin('base','I_fc_max',   I_fc_max);
assignin('base','I_fc_min',   I_fc_min);
assignin('base','I_load_max', I_load_max);

fprintf('✔ Παράμετροι φορτώθηκαν.\n');
fprintf('  I_fc_max  = %.1f A\n', I_fc_max);
fprintf('  I_load_max = %.1f A\n', I_load_max);

%% ============================================================
%  ΟΡΙΣΜΟΣ OBSERVATION SPACE  (2 είσοδοι)
%  [I_load_norm, SOC_norm]  - κανονικοποιημένες σε [0,1]
%% ============================================================
obsInfo = rlNumericSpec([3 1], ...
    'LowerLimit', [0; 0; 0], ...
    'UpperLimit', [1; 1; 1.5]);
obsInfo.Name        = 'EMS Observations';
obsInfo.Description = '[I_load_norm, SOC_norm, V_bus_norm]';

%% ============================================================
actInfo = rlNumericSpec([1 1], ...
    'LowerLimit', -1, ...
    'UpperLimit',  1);
actInfo.Name = 'I_fc_ref (normalised)';

%% ============================================================
%  SIMULINK ENVIRONMENT
%% ============================================================
mdl      = 'kyklomaMeRuleBaseKaiFuzzy';
agentBlk = [mdl '/RL Agent'];   % <-- ΑΛΛΑΞΕ ΑΝ ΧΡΕΙΑΣΤΕΙ
                                %     να ταιριάζει με το όνομα
                                %     του block στο Simulink σου

env = rlSimulinkEnv(mdl, agentBlk, obsInfo, actInfo);
env.ResetFcn = @(in) ems_reset_fcn(in);

fprintf('✔ Simulink environment δημιουργήθηκε.\n');

%% ============================================================
%  ACTOR NETWORK
%  Είσοδος: 2  →  Κρυφά στρώματα  →  Έξοδος: 1 (tanh)
%% ============================================================
actorNet = [
    featureInputLayer(3,    'Name','obs')
    fullyConnectedLayer(128,'Name','fc1')
    reluLayer(              'Name','relu1')
    fullyConnectedLayer(128,'Name','fc2')
    reluLayer(              'Name','relu2')
    fullyConnectedLayer(64, 'Name','fc3')
    reluLayer(              'Name','relu3')
    fullyConnectedLayer(1,  'Name','fc_out')
    tanhLayer(              'Name','tanh_out')
];

actor = rlContinuousDeterministicActor( ...
    dlnetwork(layerGraph(actorNet)), obsInfo, actInfo);
%% ============================================================
%  CRITIC NETWORK
%  Είσοδος: obs(2) + action(1)  →  Έξοδος: Q value (scalar)
%% ============================================================

% Κλάδος παρατήρησης
obsPath = [
    featureInputLayer(3,    'Name','obs_in')
    fullyConnectedLayer(128,'Name','obs_fc1')
    reluLayer(              'Name','obs_relu1')
];

% Κλάδος action
actPath = [
    featureInputLayer(1,    'Name','act_in')
    fullyConnectedLayer(128,'Name','act_fc1')
];

% Συγχώνευση
mergePath = [
    additionLayer(2,        'Name','add')
    reluLayer(              'Name','merge_relu')
    fullyConnectedLayer(128,'Name','fc2')
    reluLayer(              'Name','relu2')
    fullyConnectedLayer(64, 'Name','fc3')
    reluLayer(              'Name','relu3')
    fullyConnectedLayer(1,  'Name','q_out')
];

criticGraph = layerGraph(obsPath);
criticGraph = addLayers(criticGraph, actPath);
criticGraph = addLayers(criticGraph, mergePath);
criticGraph = connectLayers(criticGraph, 'obs_relu1', 'add/in1');
criticGraph = connectLayers(criticGraph, 'act_fc1',   'add/in2');

critic = rlQValueFunction( ...
    dlnetwork(criticGraph), obsInfo, actInfo, ...
    'ObservationInputNames', {'obs_in'}, ...
    'ActionInputNames',      {'act_in'});

%% ============================================================
%  DDPG AGENT OPTIONS
%% ============================================================
agentOpts = rlDDPGAgentOptions( ...
    'SampleTime',              0.1, ...
    'DiscountFactor',          0.99, ...
    'MiniBatchSize',           128, ...
    'ExperienceBufferLength',  50000, ...
    'TargetSmoothFactor',      0.005);

% Ornstein-Uhlenbeck noise (εξερεύνηση)
agentOpts.NoiseOptions.StandardDeviation          = 0.30;
agentOpts.NoiseOptions.StandardDeviationDecayRate = 1e-5;
agentOpts.NoiseOptions.StandardDeviationMin       = 0.05;
agentOpts.NoiseOptions.MeanAttractionConstant     = 0.15;

agent = rlDDPGAgent(actor, critic, agentOpts);
fprintf('✔ DDPG Agent δημιουργήθηκε.\n');

%% ============================================================
%  TRAINING OPTIONS
%% ============================================================
mkdir('checkpoints');
mkdir('results');

trainOpts = rlTrainingOptions( ...
    'MaxEpisodes',                200, ...
    'MaxStepsPerEpisode',         20, ...
    'ScoreAveragingWindowLength', 25, ...
    'Verbose',                    true, ...
    'Plots',                      'training-progress', ...
    'SaveAgentCriteria',          'EpisodeReward', ...
    'SaveAgentValue',             -10, ...
    'SaveAgentDirectory',         'checkpoints');

mamdanitype1_1 = readfis('mamdanitype1_1.fis');
mamdanitypel_1 = mamdanitype1_1;

%% ============================================================
%  ΕΚΠΑΙΔΕΥΣΗ
%% ============================================================
fprintf('\n⏳ Ξεκινά η εκπαίδευση DDPG...\n');
fprintf('   Περίμενε 20-40 λεπτά.\n\n');

trainingStats = train(agent, env, trainOpts);

%% --- Αποθήκευση ---
save('ddpg_trained_agent.mat', 'agent', 'trainingStats');
fprintf('\n✔ Εκπαίδευση ολοκληρώθηκε!\n');
fprintf('   Agent αποθηκεύτηκε → ddpg_trained_agent.mat\n');

%% --- Γράφημα εκπαίδευσης ---
figure('Name','Αποτελέσματα Εκπαίδευσης');
subplot(2,1,1)
plot(trainingStats.EpisodeReward,  'b-', 'LineWidth', 1.2); hold on
plot(trainingStats.AverageReward,  'r-', 'LineWidth', 2.0);
xlabel('Episode'); ylabel('Reward');
title('Reward ανά Episode');
legend('Episode','Μέσος όρος (25 ep)');
grid on;

subplot(2,1,2)
plot(movmean(trainingStats.EpisodeReward, 50), 'g-', 'LineWidth', 2);
xlabel('Episode'); ylabel('Smoothed Reward');
title('Πρόοδος Εκπαίδευσης');
grid on;

saveas(gcf, 'results/training_curve.png');
fprintf('✔ Γράφημα αποθηκεύτηκε → results/training_curve.png\n');
