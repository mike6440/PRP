function [Temp] = RL10052Temp (v2, ref, res)
%***********************************
%[Temp] = RL10052Temp(v2, ref, res)
%Calculates temperature for RL10052 circuit with the thermistor 
%  to ground and the reference to 'ref' 
%v2 = A to D Milli Volts 0-4096 (volts)
%ref = reference voltage to circuit (volts)
%res = reference divider resistor (ohms)
%***********************************/
%COEFFICIENTS FOR THERMOMETRICS RL1005 Thermistor
A = 3.3540172e-3; 
B =	3.2927261e-4; 
C = 4.1188325e-6; 
D = -1.6472972e-7; 

v1 = ref - v2;
it = v1 ./ res;
r2 = v2 ./ it;		    %find resistance of thermistor
dum = log(r2 ./ res);

% Diagnostic
fprintf('v2=%d, v1=%.3f, it=%.1f, r2=%.1f, dum=%.3f\n', v2, v1, it, r2, dum);

Temp = (A + (B .* dum) + (C .* (dum .* dum)) + (D .* ((dum .* dum) .* dum)) );
	Temp = (1 ./ Temp) - 273.0;	%Conversion from Kelvin to Centigrade

return
