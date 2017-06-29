function sigma = ScatteringCrossSection(w, Tair, co2) 
%===========================================
% COMPUTE SIGMA, THE SCATTERING CROSS SECTION
%
% Taken from Bodhaine et. al, "ON Rayleigh Depth Calculations"
% JTEC, 16, 1854-1861.
%
%input
%  ref_index = refractive index (see function RefractionIndex.m)
%  Tair = temperature of the air in degrees C
%  w = wavelength in nm
%  co2 = co2 concentration in ppm
%
%output
%  sigma 
%
% reynolds 010726
%======================================================

%TEST
%clear, 
%w=415;  co2 = 360;
%Tair = 15;

%========================
% REFRACTION INDEX
%========================
n = IndexOfRefraction(w,co2);

%=======================
% MOLECULAR DENSITY
% molecules per cm^-3
%=====================
Ns = 6.0221367e23 .* 273.15 ./ (Tair+273.15) ./ 22.4141 ./1000;

%===================
% Depolarization term
%====================
wmu=w/1000;           % convert wavelength in nanometers to micrometers
FN2 = 1.034 + (3.17e-4/(wmu^2));
FO2 = 1.096 + (1.385e-3/(wmu^2)) + (1.448e-4/(wmu^4));
FAr = 1.0;
concenCO2=co2/10000;        % converts ppm to parts per volume by percent of CO2
Fair = (78.084*FN2 + 20.946*FO2 + 0.934*FAr + concenCO2*1.15)/(78.084 + 20.946 + 0.934 + concenCO2);

wcm=w/1e7;  % converts wavelength in nanometers to centimeters
sigma_term1 = 24*(pi^3)*((n^2)-1)^2;
sigma_term2 = (wcm^4)*(Ns^2)*((n^2)+2)^2;
sigma=sigma_term1/sigma_term2*Fair;

return


