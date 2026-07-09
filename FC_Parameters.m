%Creator Savvas Eleftheriadis
% Παράμετροι Κυψέλης Καυσίμου (Ballard Mark V PEMFC)
clear; clc;

% Γενικά χαρακτηριστικά 
N_cells = 35;           % Αριθμός κελιών συστοιχίας(STACK)
Area = 50.6;            % Ενεργός επιφάνεια 

% Θερμοδυναμικές Παραμέτροι
T_K = 343;              % Θερμοκρασία λειτουργίας (Kelvin) ---70C
PH2 = 1;                % Μερική πίεση Υδρογόνου (atm)
PO2 = 0.2095;           % Μερική πίεση Οξυγόνου (atm - αέρας)


% Παραμετρικοί Συντελεστές (Mann/Amphlett Model coefficients)

ksi1 = -0.948;          
ksi2 = 0.00286 + 0.0002 * log(Area) + (4.3e-5) * log(PH2); 
ksi3 = 7.6e-5;          
ksi4 = -1.93e-4;        

% Ωμικές Απώλειες
R_internal = 0.0003;    % Εσωτερική αντίσταση (Ohm)

% Απώλειες Συγκέντρωσης/Concentration losses
B = 0.016;              % Συντελεστής
J_max = 1.5;            % Μέγιστη πυκνότητα ρεύματος-Όριο λειτουργίας


% Υπολογισμός Συγκέντρωσης Οξυγόνου (Henry's Law)
CO2_conc = PO2 / (5.08e6 * exp(-498/T_K)); 

% Υπολογισμός του σταθερού όρου (δεν αλλάζει με το ρεύμα)
% V_act_static = ksi1 + ksi2*T + ksi3*T*ln(CO2)
V_act_const = ksi1 + ksi2*T_K + ksi3*T_K*log(CO2_conc);


%% --- Μέρος 2: Σχεδίαση Μετατροπέα DC/DC (Boost Converter) ---

% 1. Προδιαγραφές Σχεδίασης 
V_out_target = 48;      
f_sw = 25000;           
P_max = 1800;          

% 2. Ακραίες Τιμές Εισόδου 
V_in_min = 25;          % Η ελάχιστη τάση της κυψέλης (σε πλήρες φορτίο)
V_in_nom = 41;          % Η ονομαστική τάση 

% 3. Υπολογισμός Κύκλου Λειτουργίας (Duty Cycle)
% D = 1 - (Vin / Vout)
D_max = 1 - (V_in_min / V_out_target); 

% 4. Υπολογισμός Πηνίου (Inductor - L)

I_in_max = P_max / V_in_min;       
dI_L = 0.20 * I_in_max;         % Επιτρεπτή κυμάτωση (Ripple)

L_calc = (V_in_min * D_max) / (f_sw * dI_L); 

% 5. Υπολογισμός Πυκνωτή (Capacitor - C)

% 
I_out_max = P_max / V_out_target; 
dV_out = 0.01 * V_out_target;      % Επιτρεπτή κυμάτωση τάσης

C_calc = (I_out_max * D_max) / (f_sw * dV_out); 

fprintf('--- Αποτελέσματα Σχεδίασης DC/DC ---\n');
fprintf('Απαιτούμενο Πηνίο (L): %.6f Henry\n', L_calc);
fprintf('Απαιτούμενος Πυκνωτής (C): %.6f Farad\n', C_calc);
fprintf('Μέγιστος Κύκλος Λειτουργίας (D): %.2f\n', D_max);

%% --- Μέρος 3: Παράμετροι Μπαταρίας & Αμφίδρομου Μετατροπέα ---

% Μπαταρία
V_batt_nom = 24;      
Q_batt = 10;         
SOC_init = 60;        

% Αμφίδρομος Μετατροπέας (Bidirectional Buck-Boost)
f_sw_batt = 25000;    % Συχνότητα μεταγωγής (ίδια με FC)
L_batt = 0.000150;    % Πηνίο μπαταρίας (150 uH)
C_bus = 0.002200;     % Πυκνωτής DC Bus
