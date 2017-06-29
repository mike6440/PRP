function tr = Rayleigh(z, lat, w, co2, Tair, p)
%function tr = Rayleigh(z, lat, w, co2, Tair, p)
%====================================================
% COMPUTE RAYLEIGH AOT ON THE EARTH
%
% Taken from Bodhaine et. al, "ON Rayleigh Depth Calculations"
% JTEC, 16, 1854-1861.
%
%input
%  z = altitude in m above s.l.
%  lat = latitude if f.p. degrees
%  w = wavelength in nm
%  co2 = co2 concentration in ppm
%  Tair = temperature of the air degrees C
%  pressure in mb
%  gravity m/sec^2
%output
%  tr = Rayleigh optical thickness
% reynolds 010726
% MJBartholomew 010806
%======================================================

% TEST
%clear;  z = 3400;  lat = 19.533;  w = 500;  co2 = 360; Tair = 15; p=680.;
A=6.0221367e23;     % Avogadro's number

%==========================
% COMPUTE THE INDEX OF REFRACTION
%==========================
n = IndexOfRefraction(w,co2);

%========================
% Scattering Cross Section
%========================
sigma=ScatteringCrossSection(w,Tair,co2);

%===================
%  mean nolecular weight of dry air
%====================
concenCO2=co2/1e6;        % converts ppm to parts per volume
ma = (15.0556 * concenCO2) + 28.9595;           % # molecules per mole

%=================
%  gravitational constant
%==================
g = gravity(z, lat);
g=g*100;        % convert to gm cm/sec^2
%====================
%  calculate Rayleigh optical thickness
%===================
p=p*1e3;        % convert mb to gm cm/sec^2 /cm^2
tr=sigma * p * A /ma /g; 
return
