This repository contains the complete implementation of a fuel cell hybrid power system, combining traditional control strategies with Deep Reinforcement Learning (DRL). The project models a fuel cell stack (Ballard Mark V), a boost converter, and a battery storage system.

Project Architecture
FC_Parameters.m: Initialization script for all system parameters (Fuel Cell, Boost Converter, Battery).

kyklomaMeRuleBaseKaiFuzzy.slx: The core Simulink model representing the integrated hybrid system.

mamdanitype1_1.fis: Mamdani-type Fuzzy Inference System used for battery management and power flow regulation.

Step1_Train_DDPG.m: Training script for the DDPG agent to optimize the energy management strategy.

ddpg_best_agent.mat: The pre-trained DDPG agent, optimized for hydrogen consumption efficiency.

Step2_Compare_Controllers_T.m: Performance benchmarking script comparing the Fuzzy Logic controller against the DDPG agent.

Getting Started
Requirements: MATLAB R202x, Simulink, Reinforcement Learning Toolbox, and Fuzzy Logic Toolbox.

Setup: Run FC_Parameters.m to load all necessary variables into the workspace.

Simulation: Open kyklomaMeRuleBaseKaiFuzzy.slx to inspect the physical system architecture.

Optimization: Execute Step1_Train_DDPG.m to initiate training or load the existing ddpg_best_agent.mat to evaluate the trained performance.

Evaluation: Run Step2_Compare_Controllers_T.m to generate comparative plots and analyze the efficiency gains of the DDPG agent over the rule-based Fuzzy logic controller.

Features
Hydrogen Consumption Optimization: The DDPG agent specifically targets minimizing hydrogen usage under variable load profiles.

Hybrid Management: Dynamic switching between Fuel Cell and Battery power using intelligent control logic.
