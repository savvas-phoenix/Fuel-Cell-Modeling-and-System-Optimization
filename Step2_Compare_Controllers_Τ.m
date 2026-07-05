%% ============================================================
%  Σύγκριση DDPG vs Rule-Based vs Fuzzy
%  Τρέχει αυτόματα και τους 3 controllers
%  Μετράει: H2, τάση, SOC, ενέργεια
%% ============================================================

clear; clc; close all;

%% --- Φόρτωσε παραμέτρους ---
FC_Parameters;
fuzzy_new      = readfis('fuzzy_new.fis');

%% --- Παράμετροι μπαταρίας ---
Q_batt_Ah = 6.5;    % Ah
V_batt    = 24;     % V
H2_LHV    = 33.3;   % Wh/g (κατώτερη θερμογόνος δύναμη H2)

%% --- Controllers ---
controllers = {'DDPG', 'Rule-Based', 'Fuzzy'};
switches    = [1, 2, 3];

%% --- Φόρτωσε DDPG agent ---
load('ddpg_best_agent.mat', 'agent');
fprintf('✔ DDPG agent φορτώθηκε.\n');

%% --- Αποτελέσματα ---
results = struct();

for ci = 1:3
    name   = controllers{ci};
    sw     = switches(ci);
    
    fprintf('\nΠροσομοίωση: %s ...\n', name);
    
    % Άλλαξε switch
    set_param('kyklomaMeRuleBaseKaiFuzzy/Constant3', 'Value', num2str(sw));
    
    % Τρέξε προσομοίωση
    simOut = sim('kyklomaMeRuleBaseKaiFuzzy');
    
    % Πάρε αποτελέσματα
    t       = simOut.tout;
    H2     = simOut.out_H2.Data;
    VBUS   = simOut.out_VBUS.Data;
    SOC    = simOut.out_SOC.Data;
    FC_REF = simOut.out_FC_REF.Data;
    LOAD   = simOut.out_LOAD.Data;
    
    % Υπολογισμοί
    H2_total   = H2(end);                          % g
    SOC_start  = SOC(1);                           % %
    SOC_end    = SOC(end);                         % %
    dSOC       = SOC_end - SOC_start;              % %
    
    % Ενέργεια μπαταρίας (Wh)
    E_batt = (dSOC/100) * Q_batt_Ah * V_batt;     % Wh
    
    % Ενέργεια H2 (Wh)
    E_H2   = H2_total * H2_LHV;                   % Wh
    
    % Συνολική ενέργεια
    E_total = E_H2 + E_batt;                       % Wh
    
    % Τάση - μέση τιμή και ελάχιστη
    V_mean = mean(VBUS(VBUS > 10));
    V_min  = min(VBUS(VBUS > 10));
    
    % Αποθήκευση
    fname = strrep(name, '-', '_');
    results.(fname).t        = t;
    results.(fname).H2       = H2;
    results.(fname).VBUS     = VBUS;
    results.(fname).SOC      = SOC;
    results.(fname).FC_REF   = FC_REF;
    results.(fname).LOAD     = LOAD;
    results.(fname).H2_total = H2_total;
    results.(fname).dSOC     = dSOC;
    results.(fname).E_batt   = E_batt;
    results.(fname).E_H2     = E_H2;
    results.(fname).E_total  = E_total;
    results.(fname).V_mean   = V_mean;
    results.(fname).V_min    = V_min;
    
    fprintf('  H2 = %.5f g\n', H2_total);
    fprintf('  ΔSOC = %.3f %%\n', dSOC);
    fprintf('  E_total = %.4f Wh\n', E_total);
    fprintf('  V_mean = %.2f V\n', V_mean);
end

%% --- Πίνακας αποτελεσμάτων ---
fprintf('\n================================================================\n');
fprintf('  %-14s %10s %8s %10s %8s %8s\n', ...
        'Controller','H2 [g]','ΔSOC [%%]','E_tot [Wh]','V_mean','V_min');
fprintf('----------------------------------------------------------------\n');

ref_E = results.Rule_Based.E_total;
for ci = 1:3
    fname = strrep(controllers{ci}, '-', '_');
    r     = results.(fname);
    delta = (r.E_total - ref_E) / ref_E * 100;
    tag   = '';
    if ci == 1, tag = ' ← ΚΑΛΥΤΕΡΟΣ'; end
    fprintf('  %-14s %10.5f %8.3f %10.4f %8.2f %8.2f%s\n', ...
            controllers{ci}, r.H2_total, r.dSOC, ...
            r.E_total, r.V_mean, r.V_min, tag);
end
fprintf('================================================================\n');

%% --- Γραφήματα ---
clrs = {'#2196F3', '#FF9800', '#9C27B0'};
t    = results.DDPG.t;

figure('Name','Σύγκριση Controllers','Position',[50 50 1200 900]);

%% Υποδιάγραμμα 1: Ρεύμα φορτίου
subplot(4,1,1);
plot(t, results.DDPG.LOAD, 'k-', 'LineWidth', 1.5);
ylabel('I_{load} [A]');
title('Σύγκριση DDPG vs Rule-Based vs Fuzzy', ...
      'FontSize', 13, 'FontWeight', 'bold');
grid on;

%% Υποδιάγραμμα 2: Ρεύμα κυψέλης
subplot(4,1,2); hold on;
for ci = 1:3
    fname = strrep(controllers{ci}, '-', '_');
    plot(t, results.(fname).FC_REF, ...
         'Color', clrs{ci}, 'LineWidth', 1.5, ...
         'DisplayName', controllers{ci});
end
ylabel('I_{fc} [A]');
legend('Location', 'northeast', 'FontSize', 8);
grid on;

%% Υποδιάγραμμα 3: Τάση DC Bus
subplot(4,1,3); hold on;
for ci = 1:3
    fname = strrep(controllers{ci}, '-', '_');
    plot(t, results.(fname).VBUS, ...
         'Color', clrs{ci}, 'LineWidth', 1.5, ...
         'DisplayName', controllers{ci});
end
yline(48, 'k--', 'LineWidth', 1, 'DisplayName', '48V ref');
ylabel('V_{bus} [V]');
legend('Location', 'northeast', 'FontSize', 8);
grid on;

%% Υποδιάγραμμα 4: Κατανάλωση H2
subplot(4,1,4); hold on;
for ci = 1:3
    fname = strrep(controllers{ci}, '-', '_');
    plot(t, results.(fname).H2, ...
         'Color', clrs{ci}, 'LineWidth', 1.5, ...
         'DisplayName', controllers{ci});
end
ylabel('H_2 [g]');
xlabel('Χρόνος [s]');
legend('Location', 'northwest', 'FontSize', 8);
grid on;

mkdir('results');
saveas(gcf, 'results/controller_comparison.png');
fprintf('\n✔ Γράφημα αποθηκεύτηκε → results/controller_comparison.png\n');

%% --- Bar chart ενέργειας ---
figure('Name','Σύγκριση Ενέργειας');

E_vals  = [results.DDPG.E_total, ...
           results.Rule_Based.E_total, ...
           results.Fuzzy.E_total];
H2_vals = [results.DDPG.H2_total, ...
           results.Rule_Based.H2_total, ...
           results.Fuzzy.H2_total];

subplot(1,2,1);
b = bar(H2_vals * 1000, 'FaceColor', 'flat');
b.CData = [0.13 0.59 0.95; 1 0.60 0; 0.61 0.15 0.69];
set(gca, 'XTickLabel', controllers);
ylabel('Κατανάλωση H_2 [mg]');
title('Κατανάλωση Υδρογόνου');
grid on;

subplot(1,2,2);
b2 = bar(E_vals * 1000, 'FaceColor', 'flat');
b2.CData = [0.13 0.59 0.95; 1 0.60 0; 0.61 0.15 0.69];
set(gca, 'XTickLabel', controllers);
ylabel('Συνολική Ενέργεια [mWh]');
title('Συνολική Ενέργεια (H2 + ΔSOC)');
grid on;

saveas(gcf, 'results/energy_comparison.png');
fprintf('✔ Bar chart αποθηκεύτηκε → results/energy_comparison.png\n');