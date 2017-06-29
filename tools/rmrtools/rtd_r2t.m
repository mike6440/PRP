% RTD CALIBRATION
% 050627 rmr -- working script
% IEC 751, 1/3 DIN ???
%QUADRATIC FIT
% 1.002107,  2.35805856e2,  -2.45828974e2
%    rcal      rfit
% -50.0000  -49.9993
%          0   -0.0020
%    50.0000   50.0021
%   100.0000   99.9993
rtdcal = [-200  18.52  18.5201  18.52  -200  -150  39.72  39.7232  39.72  -150.008  -100  60.26  60.2558  60.26  -99.9897  -50  80.31  80.3063  80.31  -49.9906  0  100  100  100  0  50  119.4  119.3971  119.4  50.0075  100  138.51  138.5055  138.51  100.0119  150  157.33  157.3251  157.33  150.013  200  175.86  175.856  175.86  200.0109  250  194.1  194.0981  194.1  250.0052  300  212.05  212.0515  212.05  299.9958  350  229.72  229.7161  229.72  350.0111  400  247.09  247.092  247.09  399.9942  450  264.18  264.1791  264.18  450.0026  500  280.98  280.9775  280.98  500.0075  550  297.49  297.4871  297.49  550.0088  600  313.71  313.708  313.71  600.0062  650  329.64  329.6401  329.64  649.9996  700  345.28  345.2835  345.28  699.9887  750  360.64  360.6381  360.64  750.0062  800  375.7  375.704  375.7  799.9866  850  390.48  390.4811  390.48  849.996]';
tcal = rtdcal(1:5:end);
rcal = rtdcal(3:5:end);

ix = find(tcal>= -50 & tcal <= 100);
tcal = tcal(ix);  % temperature
rcal = rcal(ix);  % resistance

[p] = polyfit(rcal,tcal,2);
format long e
p
format short g
tfit = polyval(p,rcal);

% A FEW TEST RESISTANCES
rtest = [90, 95, 100, 105, 110, 115, 120]';
ttest = polyval(p,rtest);
[rtest ttest]



% EXPLORE THE EFFECT OF AN ERROR IN THE REF RESISTOR
Ratio = rcal ./ 1001; % a 1 ohm error in the resistance
rcal_e = 1000 .* Ratio; % we assume the resistance is 1 K exactly
tfit_e = polyval(p,rcal_e);


% COMPARE WITH THE COASTAL 
%    tfit above    tfitx from CES
%  -49.999      -51.152
%    -0.0020499            0
%        50.002       50.382
%        99.999       100.01
px = [0, 2597.4, -259.74];
tfitx = polyval(px,rcal/1000);
fprintf('FIT VAISALA HMP35 RTD\n');
fprintf('Rrtd  tcal  tfit  tfit_e  tfit_ces\n');
[rcal tcal tfit tfit_e  tfitx]


% PPART SN# 282 -- CR NCLIMATE REFERENCE NETWORK
rtd2cal = [-20 -15 -10 -5 0 5 10 15 20 25 30.01 34.99 40.95;
	.92117 .94086 .96059 .98029 .99975 1.01935 1.03897 1.05852 1.07808 1.09751 1.11697 1.13637 1.15912]';
rcal2 = rtd2cal(:,2);
tcal2 = rtd2cal(:,1);

[p2] = polyfit(rcal2,tcal2,2);
format long e
p2
format short g
tfit2 = polyval(p2,rcal2);
[rcal2 tcal2 tfit2]


